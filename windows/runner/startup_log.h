#ifndef GEKTUS_STARTUP_LOG_H_
#define GEKTUS_STARTUP_LOG_H_
#include <windows.h>
#include <cstdio>
#include <cwchar>

// Available even if the Dart isolate never starts. One small file per process
// slot, overwritten on the next matching PID; no arguments or profile data.
inline void StartupLog(const char* event) {
  static bool first = true;
  wchar_t path[MAX_PATH]{};
  const DWORD length = GetTempPathW(MAX_PATH, path);
  if (length == 0 || length > MAX_PATH - 64) return;
  swprintf_s(path + length, MAX_PATH - length, L"GektusClashX-startup-%lu.log",
             GetCurrentProcessId() % 8);
  HANDLE file = CreateFileW(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
      nullptr, first ? CREATE_ALWAYS : OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  first = false;
  if (file == INVALID_HANDLE_VALUE) return;
  char line[512]{};
  const int count = sprintf_s(line, "pid=%lu tick=%llu %s\r\n",
      GetCurrentProcessId(), GetTickCount64(), event);
  if (count > 0) { DWORD written; WriteFile(file, line, static_cast<DWORD>(count), &written, nullptr); }
  CloseHandle(file);
}
#endif
