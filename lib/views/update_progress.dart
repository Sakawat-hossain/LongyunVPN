import 'package:dio/dio.dart';
import 'package:longyunvpn/common/common.dart';
import 'package:flutter/material.dart';

/// Download progress for the in-app updater.
///
/// Replaces the indeterminate "please wait" spinner the installer download used
/// to show: for a ~40 MB file that gave no indication of progress and no way
/// out. This reports percent and megabytes, and lets the user cancel.
class UpdateProgressDialog extends StatefulWidget {
  /// Download URL of the installer asset.
  final String url;

  /// Where the installer is written.
  final String savePath;

  /// Cancels the underlying request when the user backs out.
  final CancelToken cancelToken;

  const UpdateProgressDialog({
    super.key,
    required this.url,
    required this.savePath,
    required this.cancelToken,
  });

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  int _received = 0;
  int _total = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await request.downloadFile(
      widget.url,
      widget.savePath,
      cancelToken: widget.cancelToken,
      onProgress: (received, total) {
        if (!mounted || _done) return;
        setState(() {
          _received = received;
          _total = total;
        });
      },
    );
    _done = true;
    if (mounted) Navigator.of(context).pop(ok);
  }

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    // total is -1 until the server reports Content-Length; show an
    // indeterminate bar until then rather than a bogus 0%.
    final known = _total > 0;
    final fraction = known ? (_received / _total).clamp(0.0, 1.0) : null;
    return PopScope(
      // Only the Cancel button ends this, so the download can't be orphaned by
      // a stray back gesture while the file is still being written.
      canPop: false,
      child: AlertDialog(
        title: Text(l.downloadingUpdate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 12),
            Text(
              known
                  ? '${_mb(_received)} / ${_mb(_total)}  ·  '
                      '${((fraction ?? 0) * 100).toStringAsFixed(0)}%'
                  : _mb(_received),
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.cancelToken.cancel();
              Navigator.of(context).pop(false);
            },
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }
}
