import 'dart:async';
import 'dart:io';

import 'package:longyunvpn/common/cache.dart';
import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/database/database.dart';
import 'package:longyunvpn/plugins/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';

class CommonTargetIcon extends StatelessWidget {
  final String src;

  const CommonTargetIcon({super.key, required this.src});

  Widget _defaultIcon() {
    return const Icon(IconsExt.target);
  }

  Widget _buildIcon() {
    if (src.isEmpty) {
      return _defaultIcon();
    }

    final base64 = src.getBase64;
    if (base64 != null) {
      return Image.memory(
        base64,
        gaplessPlayback: true,
        errorBuilder: (_, error, _) {
          return _defaultIcon();
        },
      );
    }

    return ImageCacheWidget(src: src, defaultWidget: _defaultIcon());
  }

  @override
  Widget build(BuildContext context) {
    return _buildIcon();
  }
}

final _cacheMange = DefaultCacheManager();

class ImageCacheWidget extends StatefulWidget {
  final String src;
  final Widget defaultWidget;

  const ImageCacheWidget({
    super.key,
    required this.src,
    required this.defaultWidget,
  });

  @override
  State<ImageCacheWidget> createState() => _ImageCacheWidgetState();
}

class _ImageCacheWidgetState extends State<ImageCacheWidget> {
  final ValueNotifier<File?> _imageNotifier = ValueNotifier(null);
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _getImageFormCache();
  }

  @override
  void didUpdateWidget(covariant ImageCacheWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _getImageFormCache();
    }
  }

  void _getImageFormCache() {
    _imageNotifier.value = null;
    final src = widget.src;
    if (src.isEmpty) {
      return;
    }
    _streamSubscription?.cancel();
    _streamSubscription = _cacheMange
        .getFileStreamV2(
          src,
          onRemoteNewLoaded: () {
            commonPrint.log('The icon has been recorded: $src');
            database.iconRecordsDao.putIfAbsent(src);
          },
        )
        .listen((data) {
          if (mounted) {
            _imageNotifier.value = data.file;
          }
        });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _imageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<File?>(
      valueListenable: _imageNotifier,
      builder: (_, data, _) {
        if (data == null) {
          return widget.defaultWidget;
        }
        return CommonImage(
          data: data,
          isSvg: widget.src.isSvg,
          errorBuilder: (_, _, _) {
            return widget.defaultWidget;
          },
        );
      },
    );
  }
}

/// An installed app's launcher icon, resolved through [App]'s icon cache.
///
/// Stateful on purpose. The obvious spelling — a `FutureBuilder` fed from
/// `build()` — creates a fresh Future on every rebuild, which both re-crosses
/// the method channel and resets the builder to its empty state. The lists that
/// show these icons rebuild about once a second, so that was a channel call per
/// visible row per second, and a blink each time. Holding the resolved provider
/// in State keeps it across rebuilds; a warm cache paints on the first frame.
class PackageIcon extends StatefulWidget {
  final String packageName;
  final double size;

  /// Stands in for the global [app], which is null off Android and so would
  /// make this widget untestable on the host.
  final App? source;

  const PackageIcon({
    super.key,
    required this.packageName,
    required this.size,
    @visibleForTesting this.source,
  });

  @override
  State<PackageIcon> createState() => _PackageIconState();
}

class _PackageIconState extends State<PackageIcon> {
  ImageProvider? _icon;

  /// Guards against a stale async load painting over a newer one after the row
  /// has been recycled onto a different package.
  int _generation = 0;

  /// One retry per package, so a genuinely unreadable icon cannot loop.
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PackageIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _retried = false;
      _load();
    }
  }

  void _load() {
    final generation = ++_generation;
    final packageName = widget.packageName;
    final currentApp = widget.source ?? app;
    if (currentApp == null || packageName.isEmpty) {
      _icon = null;
      return;
    }
    if (currentApp.hasPackageIcon(packageName)) {
      _icon = currentApp.cachedPackageIcon(packageName);
      return;
    }
    _icon = null;
    currentApp.getPackageIcon(packageName).then((icon) {
      if (!mounted || generation != _generation || icon == null) {
        return;
      }
      setState(() {
        _icon = icon;
      });
    });
  }

  /// The file behind a cached icon went away — the package was updated, or the
  /// native side aged the icon out. Drop the entry and resolve once more.
  void _handleLoadError() {
    if (_retried) return;
    _retried = true;
    // errorBuilder runs during build, where setState is illegal. A microtask
    // runs as soon as the frame's synchronous work finishes, which is early
    // enough to retry within the same frame budget and late enough to be out of
    // the build phase.
    scheduleMicrotask(() {
      if (!mounted) return;
      (widget.source ?? app)?.evictPackageIcon(widget.packageName);
      setState(_load);
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return Image(
      image: icon,
      gaplessPlayback: true,
      width: widget.size,
      height: widget.size,
      errorBuilder: (_, _, _) {
        _handleLoadError();
        return SizedBox(width: widget.size, height: widget.size);
      },
    );
  }
}

class CommonImage extends StatelessWidget {
  final File data;
  final bool isSvg;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  errorBuilder;

  const CommonImage({
    super.key,
    required this.data,
    this.errorBuilder,
    this.isSvg = false,
  });

  @override
  Widget build(BuildContext context) {
    return isSvg
        ? SvgPicture.file(data, errorBuilder: errorBuilder)
        : Image.file(data, errorBuilder: errorBuilder);
  }
}
