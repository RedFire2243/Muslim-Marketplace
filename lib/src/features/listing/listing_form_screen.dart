import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../domain/listing.dart';
import '../../domain/taxonomy.dart';
import '../../matching/lexicon.dart';
import '../../routing/router.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/inputs.dart';

/// Create a listing, or edit one you own when [editId] is set.
class ListingFormScreen extends ConsumerWidget {
  const ListingFormScreen({super.key, this.editId});
  final String? editId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (editId == null) return const _ListingForm();
    final listing = ref.watch(listingByIdProvider(editId!));
    final me = ref.watch(currentUserIdProvider);
    return listing.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const ContentWidth(child: LoadingBlocks(count: 2)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(error: e),
      ),
      data: (l) {
        if (l == null || l.ownerId != me) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.lock_outline,
              title: 'You can only edit your own listings',
              message:
                  'This listing belongs to another member or is no longer available.',
            ),
          );
        }
        if (l.status == ListingStatus.closed) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.do_not_disturb_on_outlined,
              title: 'Closed listings can’t be edited',
              message:
                  'Post a new listing if the opportunity is available again.',
            ),
          );
        }
        return _ListingForm(existing: l);
      },
    );
  }
}

class _ListingForm extends ConsumerStatefulWidget {
  const _ListingForm({this.existing});
  final Listing? existing;

  @override
  ConsumerState<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends ConsumerState<_ListingForm> {
  late ListingDraft _draft = widget.existing == null
      ? const ListingDraft()
      : ListingDraft.fromListing(widget.existing!);
  late final _title = TextEditingController(text: _draft.title);
  late final _description = TextEditingController(text: _draft.description);
  late final _compDetails = TextEditingController(
    text: _draft.compensationDetails,
  );
  bool _submitted = false;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _compDetails.dispose();
    super.dispose();
  }

  void _update(ListingDraft next) => setState(() {
    _draft = next;
    _dirty = true;
  });

  Map<String, String> get _errors => _submitted ? _draft.validate() : const {};

  Future<void> _submit() async {
    if (_saving) return; // Guards against double submission.
    setState(() {
      _submitted = true;
      _error = null;
    });
    final errors = _draft.validate();
    if (errors.isNotEmpty) {
      setState(
        () => _error =
            'Please fix ${errors.length == 1 ? 'the highlighted field' : 'the ${errors.length} highlighted fields'}.',
      );
      return;
    }
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final prefix = context.branchPrefix;
    try {
      final actions = ref.read(actionsProvider);
      final saved = _editing
          ? await actions.updateListing(widget.existing!.id, _draft)
          : await actions.createListing(_draft);
      if (!mounted) return;
      _dirty = false;
      showMessage(
        context,
        _editing
            ? 'Changes saved'
            : 'Listing published. Members can now find it.',
      );
      if (_editing) {
        router.pop();
      } else {
        router.pushReplacement('$prefix/listing/${saved.id}').ignore();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirmAction(
      context,
      title: 'Discard your changes?',
      message: 'What you’ve entered on this form will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final errors = _errors;
    final type = _draft.type;
    final suggested = _draft.category == null
        ? Lexicon.suggestCategory('${_draft.title} ${_draft.description}')
        : null;
    final listed =
        ref.watch(myProfileProvider).value?.directoryVisible ?? false;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          setState(() => _dirty = false);
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit listing' : 'Post an opportunity'),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl),
          child: ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_editing)
                  Text(
                    'Share something you offer or something you need. Keep it short and specific.',
                    style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant),
                  ),
                const SizedBox(height: Space.lg),
                _Label('What kind of listing is it?', error: errors['type']),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    for (final lt in ListingType.values)
                      ChoiceChip(
                        avatar: Icon(typeIcon(lt), size: 18),
                        label: Text(lt.label),
                        selected: type == lt,
                        onSelected: (_) => _update(
                          _draft.copyWith(
                            type: () => lt,
                            direction: () => lt == ListingType.business
                                ? ListingDirection.offer
                                : _draft.direction,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                if (type != null) ...[
                  _Label(
                    'Are you offering it or looking for it?',
                    error: errors['direction'],
                  ),
                  if (type.allowsRequests) ...[
                    SegmentedButton<ListingDirection>(
                      emptySelectionAllowed: true,
                      showSelectedIcon: true,
                      segments: [
                        for (final d in ListingDirection.values)
                          ButtonSegment(
                            value: d,
                            icon: Icon(
                              d == ListingDirection.offer
                                  ? Icons.volunteer_activism_outlined
                                  : Icons.search,
                            ),
                            label: Text(type.directionLabel(d)),
                          ),
                      ],
                      selected: {?_draft.direction},
                      onSelectionChanged: (s) => _update(
                        _draft.copyWith(
                          direction: () => s.isEmpty ? null : s.first,
                        ),
                      ),
                    ),
                    if (_draft.direction != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        type.directionHelp(_draft.direction!),
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ] else
                    Text(
                      'Business listings are for the business owner. Looking for a business? Post a service request instead.',
                      style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                    ),
                  const SizedBox(height: Space.lg),
                ],
                TextField(
                  controller: _title,
                  maxLength: ListingDraft.titleMax,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => _update(_draft.copyWith(title: v)),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'For example: Math tutoring for grades 8–12',
                    errorText: errors['title'],
                  ),
                ),
                const SizedBox(height: Space.sm),
                TextField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: ListingDraft.descriptionMax,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => _update(_draft.copyWith(description: v)),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'What is it, who is it for, and what should people know before reaching out?',
                    alignLabelWithHint: true,
                    errorText: errors['description'],
                  ),
                ),
                const SizedBox(height: Space.sm),
                DropdownButtonFormField<ListingCategory>(
                  key: ValueKey(_draft.category),
                  initialValue: _draft.category,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    errorText: errors['category'],
                    prefixIcon: Icon(
                      _draft.category == null
                          ? Icons.category_outlined
                          : categoryIcon(_draft.category!),
                    ),
                  ),
                  items: [
                    for (final cat in ListingCategory.values)
                      DropdownMenuItem(value: cat, child: Text(cat.label)),
                  ],
                  onChanged: (v) => _update(_draft.copyWith(category: () => v)),
                ),
                if (suggested != null) ...[
                  const SizedBox(height: Space.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 18),
                      label: Text('Use “${suggested.label}”'),
                      onPressed: () =>
                          _update(_draft.copyWith(category: () => suggested)),
                    ),
                  ),
                ],
                const SizedBox(height: Space.lg),
                ChipEditor(
                  label: 'Tags',
                  helper:
                      'Optional keywords that help people find this, like “calculus” or “weekends”.',
                  values: _draft.tags,
                  maxItems: ListingDraft.maxTags,
                  errorText: errors['tags'],
                  onChanged: (v) => _update(_draft.copyWith(tags: v)),
                ),
                const SizedBox(height: Space.lg),
                _Label('Where does it happen?', error: errors['location']),
                AreaDropdown(
                  value: _draft.areaId,
                  label: 'In-person area',
                  emptyLabel: 'No in-person location',
                  onChanged: (v) => _update(_draft.copyWith(areaId: () => v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.remoteAvailable,
                  onChanged: (v) =>
                      _update(_draft.copyWith(remoteAvailable: v)),
                  title: const Text('Can be done remotely'),
                ),
                const SizedBox(height: Space.md),
                const _Label('Compensation (optional)'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final type = DropdownButtonFormField<CompensationType?>(
                      initialValue: _draft.compensationType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        const DropdownMenuItem<CompensationType?>(
                          value: null,
                          child: Text('Not specified'),
                        ),
                        for (final ct in CompensationType.values)
                          DropdownMenuItem<CompensationType?>(
                            value: ct,
                            child: Text(ct.label),
                          ),
                      ],
                      onChanged: (v) =>
                          _update(_draft.copyWith(compensationType: () => v)),
                    );
                    final details = TextField(
                      controller: _compDetails,
                      maxLength: 80,
                      onChanged: (v) =>
                          _update(_draft.copyWith(compensationDetails: v)),
                      decoration: InputDecoration(
                        labelText: 'Details',
                        hintText: r'For example: $20/hr',
                        errorText: errors['compensation'],
                      ),
                    );
                    if (constraints.maxWidth < 480) {
                      return Column(
                        children: [
                          type,
                          const SizedBox(height: Space.sm),
                          details,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: type),
                        const SizedBox(width: Space.sm),
                        Expanded(flex: 3, child: details),
                      ],
                    );
                  },
                ),
                const SizedBox(height: Space.md),
                Container(
                  padding: const EdgeInsets.all(Space.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 20,
                        color: c.onSurfaceVariant,
                      ),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: Text(
                          'Publishing makes this listing visible to signed-in members: its title, description, category, tags, location, compensation and your name${listed ? ', with a link to your directory profile' : ''}. You can edit, pause, close or delete it any time.',
                          style: t.bodySmall?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: Space.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: t.bodyMedium?.copyWith(color: c.error),
                    ),
                  ),
                ],
                const SizedBox(height: Space.lg),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const ButtonSpinner()
                      : Icon(_editing ? Icons.check : Icons.publish),
                  label: Text(
                    _saving
                        ? 'Saving…'
                        : _editing
                        ? 'Save changes'
                        : 'Publish listing',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.error});
  final String text;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: t.titleSmall),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(error!, style: t.bodySmall?.copyWith(color: c.error)),
            ),
        ],
      ),
    );
  }
}
