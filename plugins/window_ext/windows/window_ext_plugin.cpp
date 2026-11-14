#include "window_ext_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>
#include <flutter_windows.h>
#include <cmath>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace window_ext {


std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>,
    std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
    channel = nullptr;


namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
Map RectMap(const RECT& rect) {
  return {{Value("x"), Value(static_cast<double>(rect.left))},
          {Value("y"), Value(static_cast<double>(rect.top))},
          {Value("width"), Value(static_cast<double>(rect.right - rect.left))},
          {Value("height"), Value(static_cast<double>(rect.bottom - rect.top))}};
}
BOOL CALLBACK CollectMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM context) {
  MONITORINFO info = {sizeof(info)};
  if (!GetMonitorInfo(monitor, &info)) return TRUE;
  auto data = RectMap(info.rcWork);
  data[Value("scale")] = Value(FlutterDesktopGetDpiForMonitor(monitor) / 96.0);
  data[Value("primary")] = Value((info.dwFlags & MONITORINFOF_PRIMARY) != 0);
  reinterpret_cast<flutter::EncodableList*>(context)->push_back(Value(data));
  return TRUE;
}
Map Snapshot(HWND hwnd) {
  RECT rect{};
  GetWindowRect(hwnd, &rect);
  auto data = RectMap(rect);
  const auto monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  data[Value("scale")] = Value(FlutterDesktopGetDpiForMonitor(monitor) / 96.0);
  data[Value("visible")] = Value(IsWindowVisible(hwnd) != FALSE);
  data[Value("minimized")] = Value(IsIconic(hwnd) != FALSE);
  data[Value("maximized")] = Value(IsZoomed(hwnd) != FALSE);
  MONITORINFO info = {sizeof(info)};
  GetMonitorInfo(monitor, &info);
  data[Value("fullscreen")] = Value(
      (GetWindowLongPtr(hwnd, GWL_STYLE) & WS_CAPTION) == 0 &&
      EqualRect(&rect, &info.rcMonitor));
  flutter::EncodableList displays;
  EnumDisplayMonitors(nullptr, nullptr, CollectMonitor,
                      reinterpret_cast<LPARAM>(&displays));
  data[Value("displays")] = Value(displays);
  return data;
}
}  // namespace

// static
void WindowExtPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "window_ext",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WindowExtPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WindowExtPlugin::WindowExtPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar(registrar) {
  WM_TASKBARCREATED = RegisterWindowMessage(TEXT("TaskbarCreated"));
  window_proc_id = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
}

WindowExtPlugin::~WindowExtPlugin() {
  registrar->UnregisterTopLevelWindowProcDelegate(window_proc_id);
}

std::optional<LRESULT> WindowExtPlugin::HandleWindowProc(HWND hWnd,
                                                           UINT message,
                                                           WPARAM wParam,
                                                           LPARAM lParam) {
  std::optional<LRESULT> result;
  if (message == WM_DISPLAYCHANGE || message == WM_DPICHANGED ||
      (message == WM_SETTINGCHANGE && wParam == SPI_SETWORKAREA)) {
    channel->InvokeMethod("displayChanged", nullptr);
  }
  if(message == WM_TASKBARCREATED){
    channel -> InvokeMethod("taskbarCreated", std::make_unique<flutter::EncodableValue>());
  }
  return result;
}



void WindowExtPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto name = method_call.method_name();
  HWND hwnd = nullptr;
  if (name == "getGeometrySnapshot" || name == "setPhysicalBounds") {
    if (registrar && registrar->GetView()) {
      hwnd = GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
    }
    if (!hwnd || !IsWindow(hwnd)) {
      result->Error("geometry", "Main window unavailable"); return;
    }
  }
  if (name == "getGeometrySnapshot") {
    result->Success(Value(Snapshot(hwnd)));
  } else if (name == "setPhysicalBounds") {
    const auto* args = std::get_if<Map>(method_call.arguments());
    double values[4]{};
    const char* keys[] = {"x", "y", "width", "height"};
    for (int i = 0; i < 4; ++i) {
      if (!args) { result->Error("geometry", "Missing bounds"); return; }
      const auto entry = args->find(Value(keys[i]));
      const auto* value = entry == args->end() ? nullptr : std::get_if<double>(&entry->second);
      // Bound all conversions and additions well inside the Win32 LONG range.
      if (!value || !std::isfinite(*value) || std::abs(*value) > 10000000 ||
          (i >= 2 && *value < 1)) {
        result->Error("geometry", "Invalid physical bounds"); return;
      }
      values[i] = *value;
    }
    // Crossing monitors synchronously sends WM_DPICHANGED. Reapply once after
    // its suggested rect has been processed, so the requested physical bounds win.
    const int x = static_cast<int>(std::lround(values[0]));
    const int y = static_cast<int>(std::lround(values[1]));
    // Round edges, not width independently: otherwise a fractional scale can
    // push the right/bottom edge one physical pixel outside the work area.
    const int width = static_cast<int>(std::lround(values[0] + values[2])) - x;
    const int height = static_cast<int>(std::lround(values[1] + values[3])) - y;
    for (int pass = 0; pass < 2; ++pass) {
      if (!SetWindowPos(hwnd, nullptr, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE)) {
        result->Error("geometry", "SetWindowPos failed"); return;
      }
    }
    result->Success(Value(Snapshot(hwnd)));
  } else if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else {
    result->NotImplemented();
  }
}

}  // namespace window_ext
