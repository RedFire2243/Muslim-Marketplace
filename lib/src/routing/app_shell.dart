import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/demo/demo_switcher.dart';
import '../state/data_providers.dart';
import '../state/session.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/pattern.dart';
import 'router.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Discover', Icons.explore_outlined, Icons.explore),
  _Destination('Saved', Icons.bookmarks_outlined, Icons.bookmarks),
  _Destination('Inbox', Icons.forum_outlined, Icons.forum),
  _Destination('Profile', Icons.person_outline, Icons.person),
];

/// Adaptive navigation: a bottom bar on phones, a rail on tablets and an
/// extended sidebar on wide screens.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final pending = ref.watch(pendingIncomingCountProvider);
    final isDemo = ref.watch(sessionProvider).value?.isDemo ?? false;

    Widget icon(int i, {required bool selected}) {
      final d = _destinations[i];
      final glyph = Icon(selected ? d.selectedIcon : d.icon);
      if (i == 2 && pending > 0) {
        // The destination label already names the tab; announce the count.
        return Badge(
          label: ExcludeSemantics(child: Text('$pending')),
          child: Semantics(
            label: '$pending new request${pending == 1 ? '' : 's'}',
            child: glyph,
          ),
        );
      }
      return glyph;
    }

    final body = Column(
      children: [
        if (isDemo) const DemoBanner(),
        // Each branch has its own Navigator, whose route barrier blocks the
        // semantics of anything painted before it in the same container. A
        // separate container keeps the banner and side navigation available
        // to screen readers.
        Expanded(child: Semantics(container: true, child: shell)),
      ],
    );

    if (width < Breakpoints.medium) {
      return Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (var i = 0; i < _destinations.length; i++)
              NavigationDestination(
                icon: icon(i, selected: false),
                selectedIcon: icon(i, selected: true),
                label: _destinations[i].label,
                tooltip: '',
              ),
          ],
        ),
      );
    }

    final extended = width >= Breakpoints.large;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _SideNav(
              extended: extended,
              selectedIndex: shell.currentIndex,
              onSelect: _select,
              iconFor: icon,
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _SideNav extends ConsumerWidget {
  const _SideNav({
    required this.extended,
    required this.selectedIndex,
    required this.onSelect,
    required this.iconFor,
  });

  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget Function(int, {required bool selected}) iconFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final profile = ref.watch(myProfileProvider).value;
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 248,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      groupAlignment: -0.85,
      leading: Padding(
        padding: const EdgeInsets.only(top: Space.md, bottom: Space.md),
        child: Column(
          crossAxisAlignment: extended
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (extended)
              SizedBox(
                width: 216,
                child: Row(
                  children: [
                    const BrandMark(size: 36),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        'Muslim Marketplace',
                        style: t.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Tooltip(
                message: 'Muslim Marketplace',
                child: BrandMark(size: 36),
              ),
            const SizedBox(height: Space.lg),
            if (extended)
              SizedBox(
                width: 216,
                child: FilledButton.icon(
                  onPressed: () => context.openPost(),
                  icon: const Icon(Icons.add),
                  label: const Text('Post an opportunity'),
                ),
              )
            else
              FloatingActionButton(
                heroTag: 'rail-post',
                tooltip: 'Post an opportunity',
                elevation: 0,
                onPressed: () => context.openPost(),
                child: const Icon(Icons.add),
              ),
          ],
        ),
      ),
      trailing: extended && profile != null
          ? Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: SizedBox(
                    width: 216,
                    child: Row(
                      children: [
                        MemberAvatar(
                          name: profile.displayName,
                          id: profile.id,
                          size: 32,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            profile.displayName,
                            style: t.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      destinations: [
        for (var i = 0; i < _destinations.length; i++)
          NavigationRailDestination(
            icon: iconFor(i, selected: false),
            selectedIcon: iconFor(i, selected: true),
            label: Text(_destinations[i].label),
          ),
      ],
    );
  }
}
