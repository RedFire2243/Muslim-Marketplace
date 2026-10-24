import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../domain/profile.dart';
import '../../state/data_providers.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';

/// Explains demo mode and offers member switching. Only shown in demo mode.
class DemoBanner extends ConsumerWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = ref.watch(myProfileProvider).value?.displayName ?? '';
    final compact = Breakpoints.isCompact(context);
    return Material(
      color: c.secondaryContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ContentWidth.gutter(context),
          vertical: 2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.science_outlined,
              size: 18,
              color: c.onSecondaryContainer,
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Demo',
                      style: t.labelMedium?.copyWith(
                        color: c.onSecondaryContainer,
                      ),
                    ),
                    TextSpan(
                      text: compact
                          ? ' · Fictional data on this device'
                          : ' · Fictional community data, saved only on this device',
                      style: t.bodySmall?.copyWith(
                        color: c.onSecondaryContainer,
                      ),
                    ),
                    if (!compact && name.isNotEmpty)
                      TextSpan(
                        text: ' · You are $name',
                        style: t.bodySmall?.copyWith(
                          color: c.onSecondaryContainer,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: c.onSecondaryContainer,
                minimumSize: const Size(44, 40),
              ),
              onPressed: () => showDemoSwitcher(context),
              icon: const Icon(Icons.switch_account_outlined, size: 18),
              label: Text(compact ? 'Switch' : 'Switch member'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDemoSwitcher(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const DemoSwitcherSheet(),
    );

final _demoMembersProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  ref.watch(myProfileProvider);
  final demo = ref.watch(backendProvider)?.demo;
  if (demo == null) return const [];
  return demo.members();
});

class DemoSwitcherSheet extends ConsumerStatefulWidget {
  const DemoSwitcherSheet({super.key});

  @override
  ConsumerState<DemoSwitcherSheet> createState() => _DemoSwitcherSheetState();
}

class _DemoSwitcherSheetState extends ConsumerState<DemoSwitcherSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await action();
      nav.pop();
      router.go('/');
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final me = ref.watch(currentUserIdProvider);
    final members = ref.watch(_demoMembersProvider);
    final session = ref.read(sessionProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg),
        children: [
          Text('Switch demo member', style: t.titleLarge),
          const SizedBox(height: Space.xxs),
          Text(
            'Try both sides of a request: send one as one member, then switch to the other to accept it and reply. Everyone here is fictional.',
            style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.md),
          AsyncView(
            value: members,
            data: (list) => Column(
              children: [
                for (final p in list)
                  ListTile(
                    enabled: !_busy,
                    leading: MemberAvatar(
                      name: p.displayName.isEmpty ? '?' : p.displayName,
                      id: p.id,
                    ),
                    title: Text(
                      p.displayName.isEmpty
                          ? 'New member (setup not finished)'
                          : p.displayName,
                    ),
                    subtitle: Text(
                      p.isSample
                          ? (p.headline.isEmpty ? 'Sample member' : p.headline)
                          : 'Created on this device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: p.id == me
                        ? const StatusBadge(
                            label: 'You',
                            tone: BadgeTone.positive,
                            icon: Icons.check,
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: p.id == me
                        ? null
                        : () => _run(
                            () => session.switchDemoMember(p.id),
                            'You are now ${p.displayName.isEmpty ? 'a new member' : p.displayName}',
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    () => session.startDemo(),
                    'Started a new demo member',
                  ),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Start as a new member'),
          ),
        ],
      ),
    );
  }
}
