import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../data/repositories.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/inputs.dart';
import '../demo/demo_switcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && success != null) showMessage(context, success);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final profile = ref.watch(myProfileProvider).value;
    final session = ref.watch(sessionProvider).value;
    final prefs = ref.watch(preferenceModelProvider);
    final actions = ref.read(actionsProvider);
    final isDemo = session?.isDemo ?? false;
    final signals = prefs.describe();

    if (profile == null || session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    Widget section(String title, List<Widget> children, {String? subtitle}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: Space.xxs,
                  bottom: Space.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: t.titleMedium),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and settings')),
      body: ListView(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl),
        children: [
          ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section('Visibility', [
                  ExplainedSwitch(
                    icon: Icons.groups_outlined,
                    title: 'List me in the member directory',
                    description: profile.directoryVisible
                        ? 'On. Signed-in members can find you in search and see your profile details. Turn off to withdraw from the directory right away.'
                        : 'Off. You don’t appear in member search, and listings you publish show only your name.',
                    value: profile.directoryVisible,
                    onChanged: _busy
                        ? null
                        : (v) => _run(
                            () => actions.setDirectoryVisible(v),
                            success: v
                                ? 'You’re now in the directory'
                                : 'You’ve left the directory',
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      0,
                      Space.md,
                      Space.md,
                    ),
                    child: Text(
                      'Published listings stay visible until you pause, close or delete them. Your goals, saved listings, activity and conversations are always private.',
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                ]),
                section(
                  'Personalization',
                  subtitle: 'How your activity shapes recommendations.',
                  [
                    ExplainedSwitch(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Use my activity to personalize',
                      description:
                          'Saves, requests, “show less” choices and (a little) the listings you open adjust your ranking. Your profile goals and interests always count.',
                      value: profile.personalizationEnabled,
                      onChanged: _busy
                          ? null
                          : (v) => _run(
                              () => actions.setPersonalization(v),
                              success: v
                                  ? 'Personalization on'
                                  : 'Personalization off. New activity won’t be recorded.',
                            ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(Space.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What we’ve learned', style: t.labelLarge),
                          const SizedBox(height: Space.xs),
                          if (signals.isEmpty)
                            Text(
                              'Nothing yet. Save or request listings to see this change.',
                              style: t.bodySmall?.copyWith(
                                color: c.onSurfaceVariant,
                              ),
                            )
                          else
                            for (final s in signals.take(6))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      s.value >= 0
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 18,
                                      color: s.value >= 0 ? c.primary : c.error,
                                    ),
                                    const SizedBox(width: Space.xs),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${s.value >= 0 ? 'More' : 'Less'} ${s.label.toLowerCase()}',
                                            style: t.bodyMedium,
                                          ),
                                          Text(
                                            s.evidence,
                                            style: t.bodySmall?.copyWith(
                                              color: c.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          const SizedBox(height: Space.xs),
                          OutlinedButton.icon(
                            onPressed: _busy || prefs.eventCount == 0
                                ? null
                                : () async {
                                    final ok = await confirmAction(
                                      context,
                                      title: 'Reset personalization?',
                                      message:
                                          'This clears the activity used for recommendations, including “show less” choices. Your saved listings and profile stay as they are.',
                                      confirmLabel: 'Reset',
                                    );
                                    if (ok) {
                                      await _run(
                                        actions.resetPersonalization,
                                        success: 'Personalization reset',
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset personalization'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isDemo)
                  section('Demo', subtitle: 'Only available in the local demo.', [
                    ListTile(
                      leading: const Icon(Icons.switch_account_outlined),
                      title: const Text('Switch demo member'),
                      subtitle: const Text(
                        'See the other side of a request or conversation',
                      ),
                      onTap: () => showDemoSwitcher(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.restore, color: c.error),
                      title: const Text('Reset demo data'),
                      subtitle: const Text(
                        'Restores the original fictional members and listings on this device',
                      ),
                      onTap: _busy
                          ? null
                          : () async {
                              final ok = await confirmAction(
                                context,
                                title: 'Reset the demo?',
                                message:
                                    'Everything created in the demo on this device (members, listings, requests and messages) will be replaced with the original sample data.',
                                confirmLabel: 'Reset demo',
                                destructive: true,
                              );
                              if (!ok || !context.mounted) return;
                              final messenger = ScaffoldMessenger.of(context);
                              await _run(
                                () => ref
                                    .read(sessionProvider.notifier)
                                    .resetDemo(),
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Demo data reset'),
                                ),
                              );
                            },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Leave the demo'),
                      subtitle: const Text(
                        'Your demo data stays on this device',
                      ),
                      onTap: _busy
                          ? null
                          : () => _run(
                              () => ref
                                  .read(sessionProvider.notifier)
                                  .leaveDemo(),
                            ),
                    ),
                  ])
                else
                  section('Account', [
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign out'),
                      onTap: _busy
                          ? null
                          : () => _run(
                              () =>
                                  ref.read(sessionProvider.notifier).signOut(),
                            ),
                    ),
                  ]),
                section('About', [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Muslim Marketplace'),
                    subtitle: Text(
                      isDemo
                          ? 'Local demonstration with fictional data. Nothing here is a real member, job opening or endorsement.'
                          : 'Connected to your community server.',
                    ),
                  ),
                  if (kDebugMode) _Diagnostics(mode: session.mode),
                ]),
                TextButton(
                  onPressed: () => context.go('/profile'),
                  child: const Text('Back to profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Developer diagnostics, visible only in debug builds.
class _Diagnostics extends ConsumerWidget {
  const _Diagnostics({required this.mode});
  final AppMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      child: Text(
        'Debug: mode=${mode.name}, backendConfigured=${config.hasBackend}, aiExtraction=${config.aiExtraction}, voiceSearch=${config.hasVoiceSearch}',
        style: t.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
