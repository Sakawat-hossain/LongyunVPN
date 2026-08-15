import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

/// The primary call-to-action for the two places that hand the user off to a
/// web page — verifying an IP and going to checkout.
///
/// Both used a stock filled button, which read as ordinary next to the cards
/// around them and gave no hint that tapping leaves for a page. This gives them
/// one shared treatment: a gradient drawn from the theme's own primary, the
/// icon set in a translucent chip, and a trailing arrow that says "this opens
/// something". Purely presentational — the caller still owns what the tap does.
class LinkActionButton extends StatefulWidget {
  final IconData icon;
  final String label;

  /// Null disables the button, matching the convention of the Material buttons
  /// this replaces.
  final VoidCallback? onPressed;

  /// Optional second line, e.g. the price on the checkout button.
  final String? subtitle;

  const LinkActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtitle,
  });

  @override
  State<LinkActionButton> createState() => _LinkActionButtonState();
}

class _LinkActionButtonState extends State<LinkActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final enabled = widget.onPressed != null;
    // Disabled keeps the same shape and spacing so the layout never shifts —
    // only the colour drops back to the standard disabled container.
    final start = enabled
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.12);
    final end = enabled
        ? Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.45)!
        : colorScheme.onSurface.withValues(alpha: 0.12);
    final foreground = enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [start, end],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: _pressed ? 0.18 : 0.32,
                    ),
                    blurRadius: _pressed ? 10 : 18,
                    offset: Offset(0, _pressed ? 2 : 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            splashColor: foreground.withValues(alpha: 0.12),
            highlightColor: foreground.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(widget.icon, size: 19, color: foreground),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: foreground.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: foreground.withValues(alpha: 0.9),
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
