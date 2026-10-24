import 'package:flutter/material.dart';

import '../../domain/areas.dart';
import '../theme.dart';

/// Editable list of short terms (skills, interests, tags) shown as chips.
class ChipEditor extends StatefulWidget {
  const ChipEditor({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.hint = 'Add and press Enter',
    this.helper,
    this.maxItems = 15,
    this.errorText,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String hint;
  final String? helper;
  final int maxItems;
  final String? errorText;

  @override
  State<ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<ChipEditor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final parts = _controller.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length <= 40)
        .toList();
    if (parts.isEmpty) return;
    final next = [...widget.values];
    for (final p in parts) {
      if (next.length >= widget.maxItems) break;
      if (!next.any((v) => v.toLowerCase() == p.toLowerCase())) next.add(p);
    }
    widget.onChanged(next);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final full = widget.values.length >= widget.maxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: t.titleSmall),
        if (widget.helper != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.helper!,
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Space.xs),
        if (widget.values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final v in widget.values)
                  InputChip(
                    label: Text(v),
                    onDeleted: () =>
                        widget.onChanged([...widget.values]..remove(v)),
                    deleteButtonTooltipMessage: 'Remove $v',
                  ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: !full,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            hintText: full ? 'Limit reached' : widget.hint,
            errorText: widget.errorText,
            isDense: true,
            suffixIcon: IconButton(
              tooltip: 'Add ${widget.label.toLowerCase()}',
              onPressed: full ? null : _add,
              icon: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}

/// Area selector with "Not specified".
class AreaDropdown extends StatelessWidget {
  const AreaDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Area',
    this.emptyLabel = 'Not specified',
    this.errorText,
    this.helperText,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final String emptyLabel;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: const Icon(Icons.place_outlined),
      ),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(emptyLabel)),
        for (final a in Areas.all)
          DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
      ],
      onChanged: onChanged,
    );
  }
}

/// A labelled switch row with an explanation underneath.
class ExplainedSwitch extends StatelessWidget {
  const ExplainedSwitch({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.xxs,
        ),
        secondary: icon == null ? null : Icon(icon, color: c.primary),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(description),
        ),
      ),
    );
  }
}
