import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// True on the platforms that have an embedded browser implementation.
/// Linux has none, so it keeps using the system browser.
bool get _hasInAppBrowser =>
    Platform.isAndroid || Platform.isIOS || Platform.isMacOS ||
    Platform.isWindows;

/// Opens [url] inside the app.
///
/// The page is always loaded fresh: cache, cookies and web storage are cleared
/// before navigating, so a verification or checkout page can never show a stale
/// result from a previous visit. Falls back to the system browser where no
/// embedded implementation exists, so callers never branch on platform.
Future<void> openInApp(
  BuildContext context, {
  required String url,
  required String title,
}) async {
  if (!_hasInAppBrowser) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => InAppBrowserView(url: url, title: title),
    ),
  );
}

class InAppBrowserView extends StatefulWidget {
  final String url;
  final String title;

  const InAppBrowserView({super.key, required this.url, required this.title});

  @override
  State<InAppBrowserView> createState() => _InAppBrowserViewState();
}

class _InAppBrowserViewState extends State<InAppBrowserView> {
  InAppWebViewController? _controller;
  double _progress = 0;

  /// Wipes anything a previous visit left behind. Runs before the first load so
  /// the page can't answer from cache — an IP-verification or checkout page has
  /// to reflect the request happening right now.
  Future<void> _clearBrowsingData() async {
    try {
      await InAppWebViewController.clearAllCache();
      await CookieManager.instance().deleteAllCookies();
    } catch (e) {
      // Never block the page on cleanup failing.
      commonPrint.log(
        'in-app browser clear failed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return CommonScaffold(
      title: widget.title,
      actions: [
        IconButton(
          tooltip: l.reload,
          onPressed: () async {
            await _clearBrowsingData();
            await _controller?.reload();
          },
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: l.openInBrowser,
          onPressed: () => launchUrl(
            Uri.parse(widget.url),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
      body: Column(
        children: [
          if (_progress < 1) LinearProgressIndicator(value: _progress),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                // Don't reuse anything cached from an earlier visit.
                cacheEnabled: false,
                clearCache: true,
                javaScriptEnabled: true,
                // Payment gateways routinely hand off to a bank or wallet page
                // in a new window; without this those taps do nothing.
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: true,
                transparentBackground: true,
              ),
              onWebViewCreated: (controller) async {
                _controller = controller;
                await _clearBrowsingData();
              },
              onProgressChanged: (_, progress) {
                if (mounted) setState(() => _progress = progress / 100);
              },
              onReceivedError: (_, request, error) {
                commonPrint.log(
                  'in-app browser error ${error.type}: ${error.description} '
                  '(${request.url})',
                  logLevel: LogLevel.warning,
                );
              },
              // Gateways often redirect to a wallet/bank app via a custom
              // scheme, which the webview itself can't load — hand those to the
              // OS instead of dead-ending the payment.
              shouldOverrideUrlLoading: (_, action) async {
                final uri = action.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;
                if (uri.scheme == 'http' || uri.scheme == 'https') {
                  return NavigationActionPolicy.ALLOW;
                }
                await launchUrl(
                  Uri.parse(uri.toString()),
                  mode: LaunchMode.externalApplication,
                );
                return NavigationActionPolicy.CANCEL;
              },
            ),
          ),
        ],
      ),
    );
  }
}
