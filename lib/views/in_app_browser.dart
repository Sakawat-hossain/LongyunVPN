import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens [url] inside the app.
///
/// Android/iOS get a real in-app WebView ([InAppBrowserView]). Desktop has no
/// webview_flutter implementation, so it falls back to the system browser —
/// callers do not need to branch on platform themselves.
///
/// The page is always loaded fresh: cache, cookies and local storage are
/// cleared before navigating, so a verification or checkout page can never show
/// a stale result from a previous visit.
Future<void> openInApp(
  BuildContext context, {
  required String url,
  required String title,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
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
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _loading = false);
            commonPrint.log(
              'in-app browser error ${error.errorCode}: ${error.description}',
              logLevel: LogLevel.warning,
            );
          },
        ),
      );
    _startFresh();
  }

  /// Wipes anything cached from a previous visit, then loads the page.
  Future<void> _startFresh() async {
    try {
      await WebViewCookieManager().clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
    } catch (e) {
      // Never block the page on cleanup failing.
      commonPrint.log('in-app browser clear failed: $e',
          logLevel: LogLevel.warning);
    }
    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _reload() async {
    await _startFresh();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.title,
      actions: [
        IconButton(
          tooltip: context.appLocalizations.reload,
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: context.appLocalizations.openInBrowser,
          onPressed: () => launchUrl(
            Uri.parse(widget.url),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
