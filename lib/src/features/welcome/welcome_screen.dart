import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../data/seed/seed_data.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/pattern.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _starting = false;

  Future<void> _startDemo({String? asMember}) async {
    setState(() => _starting = true);
    try {
      await ref.read(sessionProvider.notifier).startDemo(asMemberId: asMember);
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        showMessage(context, friendlyError(e));
      }
    }
  }

  void _account(String route) {
    final hasBackend =
        ref.read(appConfigProvider).hasBackend &&
        ref.read(accountGatewayProvider) != null;
    if (hasBackend) {
      context.push(route);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_off_outlined),
        title: const Text('Accounts aren’t available here'),
        content: const Text(
          'This copy of the app isn’t connected to a community server, so sign-in and new accounts are turned off. You can still try every feature in the demo with fictional members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _startDemo();
            },
            child: const Text('Try the demo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const BrandMark(size: 44),
            const SizedBox(width: Space.sm),
            Flexible(child: Text('Muslim Marketplace', style: t.titleLarge)),
          ],
        ),
        const SizedBox(height: Space.xl),
        Semantics(
          header: true,
          child: Text(
            'Discover the skills, services and opportunities in your community.',
            style: t.displaySmall,
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          'Tell us what you offer and what you need. We’ll show you mentors, jobs, internships, local help and volunteer roles from Muslims across Central Jersey, and explain why each one fits.',
          style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            FilledButton.icon(
              onPressed: _starting ? null : () => _startDemo(),
              icon: _starting
                  ? const ButtonSpinner()
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('Try the demo'),
            ),
            OutlinedButton(
              onPressed: _starting ? null : () => _account('/sign-in'),
              child: const Text('Sign in'),
            ),
            TextButton(
              onPressed: _starting ? null : () => _account('/sign-up'),
              child: const Text('Create an account'),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          'The demo uses fictional members and listings and saves only on this device. No account needed.',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );

    final highlights = _Highlights(
      onExplore: _starting ? null : () => _startDemo(asMember: SeedIds.amina),
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: StarLattice(color: c.primary, opacity: 0.06)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: ContentWidth.gutter(context),
                  vertical: Space.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 6, child: copy),
                            const SizedBox(width: Space.xxl),
                            Expanded(flex: 5, child: highlights),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            copy,
                            const SizedBox(height: Space.xl),
                            highlights,
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.onExplore});
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    Widget item(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(icon, color: c.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(
            Icons.edit_note,
            'Describe yourself in plain words',
            'Say what you offer and what you’re looking for. Review and edit what we picked up.',
          ),
          item(
            Icons.auto_awesome_outlined,
            'See why each listing fits',
            'Results match your goal and role: someone looking for a mentor sees mentors, not other mentees.',
          ),
          item(
            Icons.lock_outline,
            'Connect privately',
            'Send a request. If it’s accepted, continue in a private conversation.',
          ),
          const Divider(),
          const SizedBox(height: Space.sm),
          Text('Short on time?', style: t.labelLarge),
          const SizedBox(height: Space.xxs),
          Text(
            'Skip setup and explore as Amina, a sample engineering student.',
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xs),
          TextButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Explore as a sample member'),
          ),
        ],
      ),
    );
  }
}
