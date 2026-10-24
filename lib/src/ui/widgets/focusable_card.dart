import 'package:flutter/material.dart';

import '../theme.dart';

/// A tappable card with a clearly visible keyboard focus ring.
class FocusableCard extends StatefulWidget {
  const FocusableCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.color,
    this.padding = const EdgeInsets.all(Space.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final borderColor = _focused
        ? c.primary
        : _hovered
        ? c.outline.withValues(alpha: 0.7)
        : c.outlineVariant;
    return AnimatedContainer(
      duration: motion(context, 120),
      decoration: BoxDecoration(
        color: widget.color ?? c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: borderColor, width: _focused ? 2 : 1),
        boxShadow: _hovered && widget.onTap != null
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          label: widget.semanticLabel,
          button: widget.onTap != null,
          child: InkWell(
            onTap: widget.onTap,
            onFocusChange: (v) => setState(() => _focused = v),
            onHover: (v) => setState(() => _hovered = v),
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Padding(
              padding: _focused
                  ? widget.padding
                        .subtract(const EdgeInsets.all(1))
                        .clamp(EdgeInsets.zero, const EdgeInsets.all(100))
                  : widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
