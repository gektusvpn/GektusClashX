import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/common/profile_import.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/tv_controls.dart';
import 'package:gektusclashx/widgets/tv_navigation_drawer.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

/// Apply lifecycle shared between the TV UI and the phone (over `GET /status`).
enum _SyncStatus { waiting, applying, success, error }

class ReceiveProfileDialog extends StatelessWidget {
  const ReceiveProfileDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: context.colorScheme.surfaceContainerHigh,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const ReceiveProfileView(),
      );
}

/// Shared receiver for a dialog or the TV's first-profile screen.
class ReceiveProfileView extends StatefulWidget {
  const ReceiveProfileView({super.key, this.onOtherMethods});

  // The empty TV dashboard already exposes the receiver. Other entry points
  // should offer URL/file instead of binding a second server to the same port.
  static int _activeViews = 0;
  static Future<void> _pendingShutdown = Future.value();
  static bool get isActive => _activeViews > 0;

  final VoidCallback? onOtherMethods;

  @override
  State<ReceiveProfileView> createState() => _ReceiveProfileViewState();
}

class _ReceiveProfileViewState extends State<ReceiveProfileView> {
  static const _syncPort = 8899;

  HttpServer? _server;
  Future<void>? _activeTransfer;
  Future<void>? _startingFuture;
  String? _qrData;
  bool _isLoading = true;
  _SyncStatus _status = _SyncStatus.waiting;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    ReceiveProfileView._activeViews++;
    _startingFuture = _startServerAndGenerateQr();
    unawaited(_startingFuture);
  }

  Future<void> _startServerAndGenerateQr() async {
    try {
      // A previous view may still be serving the phone's final status poll.
      await ReceiveProfileView._pendingShutdown;
      if (!mounted) return;
      // TV sets commonly use Ethernet. Select a LAN interface directly rather
      // than requiring Wi-Fi information (and its Android permissions).
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final lanInterface = interfaces
          .where((item) =>
              item.isWifi || item.name.toLowerCase().startsWith('eth'))
          .firstOrNull;
      final ip = lanInterface?.addresses.firstOrNull?.address;
      if (ip == null) {
        throw StateError(appLocalizations.noNetwork);
      }

      final router = shelf_router.Router();

      // Landing page for phones without the app (e.g. iPhone): the native
      // camera opens this URL in the browser, where the user pastes the link.
      // Served from the TV itself so the form's POST is same-origin http→http
      // (a page hosted over https couldn't reach this LAN http endpoint).
      router.get(
        '/',
        (shelf.Request request) => shelf.Response.ok(
          _pageHtml,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );

      // Phones poll this to watch the real apply result on the TV.
      router.get(
        '/status',
        (shelf.Request request) => shelf.Response.ok(
          jsonEncode({'status': _status.name, 'message': _statusMessage}),
          headers: {
            'content-type': 'application/json',
            'cache-control': 'no-store',
          },
        ),
      );

      router.post(
        '/add-profile',
        createProfileImportHandler(
          isAvailable: () => mounted,
          isBusy: () =>
              _status == _SyncStatus.applying || _status == _SyncStatus.success,
          onReceive: (url) {
            _setStatus(_SyncStatus.applying);
            // Apply in the background; the phone watches progress via /status.
            _activeTransfer = _applyReceivedUrl(url);
            unawaited(_activeTransfer);
          },
          onInvalidRequest: (error) =>
              commonPrint.log('Invalid TV sync request: $error'),
        ),
      );

      final server = await shelf_io.serve(router.call, ip, _syncPort);
      if (!mounted) {
        await server.close(force: true);
        return;
      }
      _server = server;
      commonPrint.log(
        'TV sync server started at http://${_server?.address.host}:${_server?.port}',
      );

      // A plain URL lets the native phone camera open the browser directly.
      setState(() {
        _qrData = 'http://$ip:$_syncPort/';
        _isLoading = false;
      });
    } catch (e) {
      commonPrint.log('Error starting TV sync server: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = _SyncStatus.error;
        _statusMessage = e is StateError ? e.message.toString() : e.toString();
      });
    }
  }

  Future<void> _applyReceivedUrl(String url) async {
    try {
      await globalState.appController.addProfileFromUrlForSync(url);
      _setStatus(_SyncStatus.success);
      // Let the phone's poll and the TV both show success briefly, then close.
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted && widget.onOtherMethods == null) Navigator.of(context).pop();
    } catch (e) {
      commonPrint.log('TV sync apply failed: $e');
      // Keep the server alive so the phone sees the error and can retry.
      _setStatus(_SyncStatus.error, e.toString());
    }
  }

  void _setStatus(_SyncStatus status, [String? message]) {
    if (!mounted) {
      _status = status;
      _statusMessage = message;
      return;
    }
    setState(() {
      _status = status;
      _statusMessage = message;
    });
  }

  Future<void> _closeServer() async {
    await _server?.close(force: true);
    commonPrint.log('TV sync server stopped');
  }

  @override
  void dispose() {
    ReceiveProfileView._activeViews--;
    // Adding the first profile replaces onboarding immediately. Let the phone
    // read the successful /status response before shutting down its server.
    final transfer = _activeTransfer;
    final shutdown = Future.wait<void>([
      ReceiveProfileView._pendingShutdown,
      if (_startingFuture != null) _startingFuture!,
      if (transfer != null) transfer,
    ]).then((_) => _closeServer());
    ReceiveProfileView._pendingShutdown = shutdown.catchError((Object error) {
      commonPrint.log('Unable to close TV sync server: $error');
    });
    unawaited(ReceiveProfileView._pendingShutdown);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.onOtherMethods != null;
    final action = TVActionButton(
      autofocus: true,
      icon: embedded ? Icons.more_horiz_rounded : Icons.close_rounded,
      label: embedded
          ? appLocalizations.otherAddMethods
          : MaterialLocalizations.of(context).closeButtonLabel,
      onPressed: widget.onOtherMethods ?? () => Navigator.of(context).pop(),
    );
    return SizedBox(
      width: 680,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              embedded
                  ? appLocalizations.addFromPhoneTitle
                  : appLocalizations.receiveSubscriptionTitle,
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(height: 200, child: _buildBody(context)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (embedded) TVDrawerEdge(child: action) else action,
                if (_status == _SyncStatus.error && _server == null) ...[
                  const SizedBox(width: 12),
                  TVActionButton(
                    icon: Icons.refresh_rounded,
                    label: appLocalizations.retry,
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _status = _SyncStatus.waiting;
                        _statusMessage = null;
                      });
                      _startingFuture = _startServerAndGenerateQr();
                      unawaited(_startingFuture);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_status) {
      case _SyncStatus.waiting:
        return _buildQr(context);
      case _SyncStatus.applying:
        return _buildStatus(
          context,
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(),
          ),
          appLocalizations.receivingProfile,
        );
      case _SyncStatus.success:
        return _buildStatus(
          context,
          Icon(Icons.check_circle_outline,
              size: 56, color: context.colorScheme.primary),
          appLocalizations.profileReceived,
        );
      case _SyncStatus.error:
        return _buildStatus(
          context,
          Icon(Icons.error_outline, size: 56, color: context.colorScheme.error),
          appLocalizations.profileReceiveFailed,
          detail: _statusMessage,
        );
    }
  }

  Widget _buildQr(BuildContext context) => Row(children: [
        TVQrCode(data: _qrData!),
        const SizedBox(width: 28),
        Expanded(
            child: Text(appLocalizations.scanProfileWithPhone,
                style: context.textTheme.bodyLarge?.copyWith(height: 1.4))),
      ]);

  Widget _buildStatus(
    BuildContext context,
    Widget icon,
    String title, {
    String? detail,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Static, self-contained landing page. Relative endpoints keep every request
  // same-origin with the TV. Raw string: `$` is literal (no Dart interpolation).
  static const String _pageHtml = r'''<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>GektusClashX — подписка на ТВ</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh;
    display: flex; align-items: center; justify-content: center;
    background: #0e0f13; color: #e9eaee;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    padding: 24px;
  }
  .card {
    width: 100%; max-width: 440px;
    background: #181a20; border: 1px solid #262a33; border-radius: 20px;
    padding: 28px 22px; box-shadow: 0 12px 40px rgba(0,0,0,.45);
  }
  h1 { font-size: 20px; margin: 0 0 6px; }
  p.sub { margin: 0 0 20px; color: #9aa0ab; font-size: 14px; line-height: 1.4; }
  textarea {
    width: 100%; min-height: 88px; resize: vertical;
    background: #0e0f13; color: #e9eaee;
    border: 1px solid #2d323c; border-radius: 12px;
    padding: 14px; font-size: 15px; outline: none;
    -webkit-appearance: none;
  }
  textarea:focus { border-color: #5b8cff; }
  .row { display: flex; gap: 10px; margin-top: 14px; }
  button {
    flex: 1; border: 0; border-radius: 12px;
    padding: 14px 16px; font-size: 15px; font-weight: 600;
    cursor: pointer; transition: opacity .15s, background .15s;
  }
  button:disabled { opacity: .5; }
  .primary { background: #5b8cff; color: #fff; }
  .ghost { background: #23262e; color: #cdd2db; flex: 0 0 auto; }
  #msg {
    margin-top: 18px; min-height: 22px; text-align: center;
    font-size: 14.5px; line-height: 1.4; color: #b9bfca;
  }
  #msg.ok { color: #56d18a; }
  #msg.err { color: #ff6b6b; }
</style>
</head>
<body>
  <div class="card">
    <h1>Подписка на телевизор</h1>
    <p class="sub">Вставьте ссылку на подписку и нажмите «Отправить» — она появится на телевизоре автоматически.</p>
    <textarea id="url" inputmode="url" autocapitalize="off" autocorrect="off" spellcheck="false" placeholder="https://..."></textarea>
    <div class="row">
      <button class="ghost" id="paste" onclick="paste()">Вставить</button>
      <button class="primary" id="send" onclick="send()">Отправить</button>
    </div>
    <div id="msg"></div>
  </div>
<script>
  var q = function(s){ return document.querySelector(s); };
  function setMsg(t, cls){ var m = q('#msg'); m.textContent = t; m.className = cls || ''; }
  function paste(){
    if (navigator.clipboard && navigator.clipboard.readText) {
      navigator.clipboard.readText().then(function(t){ if(t) q('#url').value = t; })
        .catch(function(){ q('#url').focus(); });
    } else { q('#url').focus(); }
  }
  function send(){
    var url = q('#url').value.trim();
    if (!url){ setMsg('Вставьте ссылку подписки', 'err'); return; }
    q('#send').disabled = true;
    setMsg('Отправляю…');
    fetch('/add-profile', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ url: url })
    }).then(function(r){
      return r.json().catch(function(){ return {}; }).then(function(j){
        if (!r.ok || !j.ok){ setMsg('Телевизор отклонил ссылку', 'err'); q('#send').disabled = false; return; }
        poll();
      });
    }).catch(function(){
      setMsg('Не удалось связаться с телевизором', 'err'); q('#send').disabled = false;
    });
  }
  function poll(){
    fetch('/status').then(function(r){ return r.json(); }).then(function(j){
      if (j.status === 'applying'){ setMsg('Телевизор добавляет профиль…'); setTimeout(poll, 800); }
      else if (j.status === 'success'){ setMsg('✅ Готово! Профиль добавлен на телевизор', 'ok'); }
      else if (j.status === 'error'){ setMsg('❌ Ошибка: ' + (j.message || 'не удалось добавить'), 'err'); q('#send').disabled = false; }
      else { setMsg('Телевизор получил ссылку…'); setTimeout(poll, 800); }
    }).catch(function(){ setMsg('Связь с телевизором потеряна', 'err'); q('#send').disabled = false; });
  }
</script>
</body>
</html>''';
}
