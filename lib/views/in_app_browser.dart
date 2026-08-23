import 'dart:ui';
import 'dart:io';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/widgets/widgets.dart';
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
  // showGeneralDialog rather than showDialog: the blur belongs to the whole
  // screen behind the chooser, not to each card. Blurring inside the cards only
  // frosted the strip of page directly under them, which left a hard edge where
  // the sharp background resumed and made the pair look pasted on.
  final choice = await showGeneralDialog<_OpenTarget>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => const _OpenTargetDialog(),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 14 * curved.value,
            sigmaY: 14 * curved.value,
          ),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.42 * curved.value),
            child: child,
          ),
        ),
      );
    },
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
    // Fills the screen so the blur behind it does too, with the cards centred
    // inside. Tapping the empty space dismisses, same as a barrier.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            // Swallow taps on the cards themselves so choosing doesn't also
            // trigger the dismiss above.
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _OpenTargetCard(
                          // The app's own mark, not a stand-in shield — this is
                          // the option that keeps you inside LongyunVPN, so it
                          // should look like LongyunVPN.
                          image: 'assets/images/icon.png',
                          label: context.appLocalizations.openInApp,
                          accent: true,
                          onTap: () =>
                              Navigator.of(context).pop(_OpenTarget.inApp),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _OpenTargetCard(
                          icon: Icons.language_rounded,
                          label: context.appLocalizations.openInBrowser,
                          accent: false,
                          onTap: () =>
                              Navigator.of(context).pop(_OpenTarget.browser),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two choices.
///
/// The icon sits in a tinted, softly-lit disc rather than floating loose above
/// the label, which is what made the two cards read as flat dark rectangles.
/// [accent] marks the recommended option so the pair has a clear primary
/// without needing a second colour: it gets the theme's primary tint, the other
/// a neutral one.
class _OpenTargetCard extends StatefulWidget {
  /// Either an [icon] or an [image] asset path — the in-app option uses the
  /// app's own mark, the browser option a glyph.
  final IconData? icon;
  final String? image;
  final String label;
  final bool accent;
  final VoidCallback onTap;

  const _OpenTargetCard({
    this.icon,
    this.image,
    required this.label,
    required this.accent,
    required this.onTap,
  }) : assert(icon != null || image != null);

  @override
  State<_OpenTargetCard> createState() => _OpenTargetCardState();
}

class _OpenTargetCardState extends State<_OpenTargetCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tint = widget.accent ? colorScheme.primary : colorScheme.tertiary;
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          // A wash of the card's tint over the surface, brightest at the top
          // where the icon sits, so it has some depth of its own instead of
          // reading as a flat panel. Opaque: the screen behind the chooser is
          // already blurred, and letting the page show through here as well
          // made the labels hard to read.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(tint.withValues(alpha: 0.16), colorScheme.surface),
              colorScheme.surface,
            ],
          ),
          border: Border.all(
            color: tint.withValues(alpha: _pressed ? 0.55 : 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            splashColor: tint.withValues(alpha: 0.12),
            highlightColor: tint.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint.withValues(alpha: 0.16),
                      border: Border.all(color: tint.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.22),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: widget.image != null
                        ? Padding(
                            // The mark has no built-in padding, so inset it to
                            // sit like the glyph on the other card.
                            padding: const EdgeInsets.all(11),
                            child: Image.asset(
                              widget.image!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          )
                        : Icon(widget.icon, size: 27, color: tint),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
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
    // Reload only. clearAllCache() here wiped the cache out from under a
    // load that was already starting, which on Android can leave the webview
    // surface blank. It was redundant anyway: cacheEnabled false and
    // clearCache true in the settings above already guarantee nothing is
    // served from an earlier visit.
    await _controller?.reload();
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
                      // Deliberately NOT transparentBackground. With a
                      // transparent surface the webview paints nothing of its
                      // own, so any moment the page is not painting — during a
                      // reload, or a redirect after verifying — the dark
                      // scaffold shows straight through and reads as a black
                      // screen. Letting the webview own its background costs
                      // nothing visually and removes that whole failure mode.
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
