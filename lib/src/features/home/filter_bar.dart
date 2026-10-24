import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/areas.dart';
import '../../domain/taxonomy.dart';
import '../../state/discovery.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';

/// Explicit filters (hard constraints) with a visible reset.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(discoveryProvider.select((s) => s.filters));
    final controller = ref.read(discoveryProvider.notifier);
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final category = filters.categories.isEmpty
        ? null
        : filters.categories.first;
    final area = Areas.byId(filters.areaId);

    final typeChips = [
      for (final type in ListingType.values)
        FilterChip(
          avatar: filters.types.contains(type)
              ? null
              : Icon(typeIcon(type), size: 16),
          label: Text(type.pluralLabel),
          selected: filters.types.contains(type),
          onSelected: (_) => controller.toggleType(type),
        ),
    ];
    final otherChips = <Widget>[
      _MenuChip<ListingCategory?>(
        icon: Icons.category_outlined,
        label: category == null ? 'Any category' : category.label,
        selected: category != null,
        semanticLabel: 'Category filter',
        items: [
          const _MenuItem(null, 'Any category'),
          for (final c in ListingCategory.values) _MenuItem(c, c.label),
        ],
        onSelected: controller.setCategory,
      ),
      _MenuChip<String?>(
        icon: Icons.place_outlined,
        label: area == null ? 'Any area' : 'Near ${area.name}',
        selected: area != null,
        semanticLabel: 'Area filter',
        items: [
          const _MenuItem(null, 'Any area'),
          for (final a in Areas.all) _MenuItem(a.id, a.name),
        ],
        onSelected: controller.setArea,
      ),
      FilterChip(
        avatar: filters.remoteOnly ? null : const Icon(Icons.public, size: 16),
        label: const Text('Remote only'),
        selected: filters.remoteOnly,
        onSelected: controller.setRemoteOnly,
      ),
    ];
    final clear = TextButton.icon(
      onPressed: controller.clearFilters,
      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
      label: Text(
        'Clear ${filters.activeCount == 1 ? 'filter' : '${filters.activeCount} filters'}',
      ),
    );

    Widget row(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: Space.xs),
            chips[i],
          ],
        ],
      ),
    );

    final compact = Breakpoints.isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          // Phones: one scrollable row, selected filters first.
          row([if (!filters.isEmpty) clear, ...otherChips, ...typeChips]),
        ] else ...[
          row(typeChips),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [...otherChips, if (!filters.isEmpty) clear],
          ),
        ],
        if (area != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xxs),
            child: Text(
              'Within about 15 miles of ${area.name}, plus remote listings.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _MenuItem<T> {
  const _MenuItem(this.value, this.label);
  final T value;
  final String label;
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.items,
    required this.onSelected,
    required this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final List<_MenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren: [
        for (final item in items)
          MenuItemButton(
            onPressed: () => onSelected(item.value),
            child: Text(item.label),
          ),
      ],
      builder: (context, menu, child) => Semantics(
        label: semanticLabel,
        child: FilterChip(
          avatar: Icon(
            icon,
            size: 16,
            color: selected ? c.onPrimaryContainer : null,
          ),
          showCheckmark: false,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
          selected: selected,
          onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
        ),
      ),
    );
  }
}
