import 'dart:ui';
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
/// The page is always loaded fresh: cached responses are dropped so a
/// verification or checkout page cannot show a stale result from a previous
/// visit. Cookies are kept — clearing them signed the user out of the very page
/// being opened. Falls back to the system browser where no embedded
/// implementation exists, so callers never branch on platform.
Future<void> openInApp(
  BuildContext context, {
  required String url,
  required String title,
}) async {
  if (!_hasInAppBrowser) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }
  final choice = await showDialog<_OpenTarget>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _OpenTargetDialog(),
  );
  // Dismissed without choosing — do nothing rather than guessing.
  if (choice == null) return;
  if (choice == _OpenTarget.browser) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => InAppBrowserView(url: url, title: title),
    ),
  );
}

enum _OpenTarget { inApp, browser }

/// Centred chooser for where to open a page.
///
/// Deliberately minimal: no heading, no descriptions, just the two choices side
/// by side. The dialog surface itself is transparent — the cards are the only
/// thing painted, over a blur — so it reads as two floating options rather than
/// a panel with content in it.
class _OpenTargetDialog extends StatelessWidget {
  const _OpenTargetDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        builder: (_, value, child) => Transform.scale(
          scale: 0.94 + 0.06 * value.clamp(0.0, 1.0),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _OpenTargetCard(
                    icon: Icons.shield_rounded,
                    label: context.appLocalizations.openInApp,
                    onTap: () =>
                        Navigator.of(context).pop(_OpenTarget.inApp),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _OpenTargetCard(
                    icon: Icons.language_rounded,
                    label: context.appLocalizations.openInBrowser,
                    onTap: () =>
                        Navigator.of(context).pop(_OpenTarget.browser),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two choices. Frosted rather than solid so the page stays faintly
/// visible behind it and the dialog keeps its transparent feel.
class _OpenTargetCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OpenTargetCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.72),
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 30, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class InAppBrowserView extends StatefulWidget {
  final String url;
  final String title;

  const InAppBrowserView({super.key, required this.url, required this.title});

  @override
  State<InAppBrowserView> createState() => _InAppBrowserViewState();
}

/// Windows-only WebView2 environment, created once and reused.
///
/// WebView2 otherwise puts its user data folder next to the executable, which
/// under C:\Program Files is not writable by a standard user — the webview then
/// fails to start at all. The plugin passes this folder straight to
/// CreateCoreWebView2EnvironmentWithOptions, so setting it here is the
/// supported way to move it somewhere writable.
WebViewEnvironment? _webViewEnvironment;
Future<void>? _webViewEnvironmentInit;

/// Set when the environment could not be created at all — almost always a
/// missing WebView2 Runtime. Building an InAppWebView anyway throws
/// "Cannot create the InAppWebView instance!" from inside platform-view
/// creation, which surfaces as a broken screen rather than something the user
/// can act on, so this lets the page offer the system browser instead.
bool _webViewEnvironmentFailed = false;

Future<void> _ensureWebViewEnvironment() async {
  if (!Platform.isWindows || _webViewEnvironment != null) return;
  _webViewEnvironmentInit ??= () async {
    try {
      final dir = await appPath.webViewDataDirPath;
      _webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: dir),
      );
      _webViewEnvironmentFailed = false;
    } catch (e) {
      _webViewEnvironmentFailed = true;
      commonPrint.log(
        'webview environment init failed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }();
  await _webViewEnvironmentInit;
}

class _InAppBrowserViewState extends State<InAppBrowserView> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _envReady = !Platform.isWindows;
  // Until the first page finishes, the webview is an empty rectangle — a thin
  // progress bar alone left users staring at a blank screen with no idea
  // whether anything was happening.
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // On Windows the webview can't be built until its environment exists, so
    // hold off the first frame of it rather than letting the plugin fail with
    // "Cannot create the InAppWebView instance!".
    if (!_envReady) {
      _ensureWebViewEnvironment().then((_) {
        if (!mounted) return;
        setState(() {
          _envReady = true;
          // No environment means no webview. Go straight to the error state,
          // which offers a retry and a system-browser fallback, instead of
          // rendering a widget that cannot initialise.
          if (_webViewEnvironmentFailed) {
            _failed = true;
            _loading = false;
          }
        });
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failed = false;
      _progress = 0;
    });
    // If the environment never came up there is no controller to reload, and
    // retrying would just spin forever. Try to build it again first — the user
    // may have installed the runtime since.
    if (_webViewEnvironmentFailed) {
      _webViewEnvironmentInit = null;
      await _ensureWebViewEnvironment();
      if (!mounted) return;
      if (_webViewEnvironmentFailed) {
        setState(() {
          _failed = true;
          _loading = false;
        });
        return;
      }
      setState(() {});
      return;
    }
    await _clearBrowsingData();
    await _controller?.reload();
  }

  /// Drops cached responses so a verification or checkout page reflects the
  /// request happening right now rather than a previous visit.
  ///
  /// Cookies are deliberately left alone. Deleting them all took the panel
  /// session with them, so the page loaded logged-out and could not do its job;
  /// the webview is also configured with cacheEnabled false and clearCache
  /// true, which already covers the staleness this was meant to prevent.
  Future<void> _clearBrowsingData() async {
    try {
      await InAppWebViewController.clearAllCache();
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
          onPressed: _reload,
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
          if (_loading) LinearProgressIndicator(value: _progress),
          Expanded(
            child: Stack(
              children: [
                if (_envReady)
                  InAppWebView(
                    webViewEnvironment: _webViewEnvironment,
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
                    onWebViewCreated: (controller) {
                      // Just keep the controller. Clearing here ran against a
                      // load that initialUrlRequest had already started, which
                      // could abort it — the page then never reached
                      // onLoadStop and sat on the spinner indefinitely.
                      _controller = controller;
                    },
                    onProgressChanged: (_, progress) {
                      if (mounted) setState(() => _progress = progress / 100);
                    },
                    onLoadStop: (_, _) {
                      if (mounted) setState(() => _loading = false);
                    },
                    onReceivedError: (_, request, error) {
                      commonPrint.log(
                        'in-app browser error ${error.type}: ${error.description} '
                        '(${request.url})',
                        logLevel: LogLevel.warning,
                      );
                      // Only surface failures of the page itself; a sub-resource
                      // (an image, a tracker) failing shouldn't blank the screen.
                      if (mounted && request.isForMainFrame == true) {
                        setState(() {
                          _loading = false;
                          _failed = true;
                        });
                      }
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
                // No full-screen cover while loading. An opaque box over the
                // webview meant that any page which never fires onLoadStop —
                // a long redirect chain, a checkout page holding a connection
                // open — left the user staring at a spinner with the working
                // page hidden underneath and unreachable. The progress bar
                // above reports loading without being able to trap anyone.
                if (_failed)
                  ColoredBox(
                    color: context.colorScheme.surface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off,
                              size: 44,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l.networkException,
                              textAlign: TextAlign.center,
                              style: context.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.tonalIcon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(l.retry),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => launchUrl(
                                Uri.parse(widget.url),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Text(l.openInBrowser),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
