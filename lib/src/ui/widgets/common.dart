import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/errors.dart';
import '../../domain/taxonomy.dart';
import '../theme.dart';

/// Centers content with a readable maximum width and responsive gutters.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  static double gutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= Breakpoints.expanded) return Space.xl;
    if (w >= Breakpoints.medium) return Space.lg;
    return Space.md;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: gutter(context)),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: t.titleLarge),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Friendly empty state with an optional next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? Space.lg : Space.xxl,
            horizontal: Space.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
                child: Icon(icon, size: 30, color: c.onPrimaryContainer),
              ),
              const SizedBox(height: Space.md),
              Text(title, style: t.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: Space.xs),
              Text(
                message,
                style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'That didn’t load',
      message: friendlyError(error),
      compact: compact,
      actions: [
        if (onRetry != null)
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
      ],
    );
  }
}

/// Neutral placeholder blocks while content loads.
class LoadingBlocks extends StatelessWidget {
  const LoadingBlocks({super.key, this.count = 3, this.height = 150});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              height: height,
              margin: const EdgeInsets.only(bottom: Space.sm),
              decoration: BoxDecoration(
                color: c.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(
                  color: c.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.compactError = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const LoadingBlocks(),
      error: (e, _) =>
          ErrorState(error: e, onRetry: onRetry, compact: compactError),
    );
  }
}

/// Labels fictional seed content.
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Fictional sample content for the demo',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Sample',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  factory StatusBadge.listing(ListingStatus s) => StatusBadge(
    label: s.label,
    tone: switch (s) {
      ListingStatus.active => BadgeTone.positive,
      ListingStatus.paused => BadgeTone.warning,
      ListingStatus.closed => BadgeTone.neutral,
    },
    icon: switch (s) {
      ListingStatus.active => Icons.check_circle_outline,
      ListingStatus.paused => Icons.pause_circle_outline,
      ListingStatus.closed => Icons.do_not_disturb_on_outlined,
    },
  );

  factory StatusBadge.request(RequestStatus s) => StatusBadge(
    label: s.label,
    tone: switch (s) {
      RequestStatus.pending => BadgeTone.warning,
      RequestStatus.accepted => BadgeTone.positive,
      RequestStatus.declined || RequestStatus.withdrawn => BadgeTone.neutral,
    },
    icon: switch (s) {
      RequestStatus.pending => Icons.schedule,
      RequestStatus.accepted => Icons.check_circle_outline,
      RequestStatus.declined => Icons.block,
      RequestStatus.withdrawn => Icons.undo,
    },
  );

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      BadgeTone.positive => (c.primaryContainer, c.onPrimaryContainer),
      BadgeTone.warning => (c.secondaryContainer, c.onSecondaryContainer),
      BadgeTone.neutral => (c.surfaceContainerHigh, c.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

enum BadgeTone { positive, warning, neutral }

/// Initials avatar with a stable color; no network images.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.id,
    this.size = 40,
  });

  final String name;
  final String id;
  final double size;

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        Brand.avatarColors[id.hashCode.abs() % Brand.avatarColors.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          initials(name),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
            height: 1,
          ),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

/// Small icon + text line used for metadata.
class MetaLine extends StatelessWidget {
  const MetaLine({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.maxLines = 1,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: c),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final c = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: c.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

void showMessage(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        width: wide ? 480 : null,
      ),
    );
}

String relativeTime(DateTime when, DateTime now) {
  final diff = now.difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  if (diff.inDays < 28) return '${diff.inDays ~/ 7} wk ago';
  return DateFormat.yMMMd().format(when.toLocal());
}

String clockTime(DateTime when) => DateFormat.jm().format(when.toLocal());

String dayLabel(DateTime when, DateTime now) {
  final a = when.toLocal();
  final b = now.toLocal();
  final da = DateTime(a.year, a.month, a.day);
  final db = DateTime(b.year, b.month, b.day);
  final d = db.difference(da).inDays;
  if (d == 0) return 'Today';
  if (d == 1) return 'Yesterday';
  if (d < 7) return DateFormat.EEEE().format(a);
  return DateFormat.yMMMMd().format(a);
}

/// A small progress indicator for use inside buttons; it takes the button's
/// current foreground color so it stays visible while the button is disabled.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: IconTheme.of(context).color,
        semanticsLabel: 'Working',
      ),
    );
  }
}

/// A bordered surface for list content. Being a [Material], it lets list
/// tiles and switches inside it show their hover, focus and ink effects.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.highlighted = false});

  final Widget child;

  /// Draws the border in the primary color.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: highlighted ? c.primary : c.outlineVariant),
      ),
      child: child,
    );
  }
}
