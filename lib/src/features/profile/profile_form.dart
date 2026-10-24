import 'package:flutter/material.dart';

import '../../domain/goal.dart';
import '../../domain/profile.dart';
import '../../domain/taxonomy.dart';
import '../../ui/icons.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/inputs.dart';

/// Editable profile fields shared by onboarding review and profile editing.
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.draft,
    required this.onChanged,
    this.errors = const {},
    this.showName = true,
  });

  final ProfileDraft draft;
  final ValueChanged<ProfileDraft> onChanged;
  final Map<String, String> errors;
  final bool showName;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final _name = TextEditingController(text: widget.draft.displayName);
  late final _headline = TextEditingController(text: widget.draft.headline);
  late final _offer = TextEditingController(text: widget.draft.offeringSummary);
  late final _seek = TextEditingController(text: widget.draft.seekingSummary);
  late final _affiliation = TextEditingController(
    text: widget.draft.communityAffiliation ?? '',
  );
  late final _linkedin = TextEditingController(
    text: widget.draft.linkedinUrl ?? '',
  );

  ProfileDraft get d => widget.draft;

  @override
  void didUpdateWidget(ProfileForm old) {
    super.didUpdateWidget(old);
    void sync(TextEditingController c, String value) {
      if (c.text != value) c.text = value;
    }

    // Reflect external changes (such as a re-run of suggestions) when the
    // field text was not what the member just typed.
    if (old.draft.offeringSummary != d.offeringSummary &&
        _offer.text == old.draft.offeringSummary) {
      sync(_offer, d.offeringSummary);
    }
    if (old.draft.seekingSummary != d.seekingSummary &&
        _seek.text == old.draft.seekingSummary) {
      sync(_seek, d.seekingSummary);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _headline,
      _offer,
      _seek,
      _affiliation,
      _linkedin,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit(ProfileDraft next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    const gap = SizedBox(height: Space.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'About you',
          children: [
            if (widget.showName) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) => _emit(d.copyWith(displayName: v)),
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: widget.errors['displayName'],
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            TextField(
              controller: _headline,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => _emit(d.copyWith(headline: v)),
              decoration: InputDecoration(
                labelText: 'One-line introduction (optional)',
                hintText: 'For example: Engineering student who loves robotics',
                errorText: widget.errors['headline'],
              ),
            ),
          ],
        ),
        gap,
        _Section(
          title: 'What you offer and what you’re looking for',
          subtitle: 'Your own words. Goals below are what we use for matching.',
          children: [
            TextField(
              controller: _offer,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => _emit(d.copyWith(offeringSummary: v)),
              decoration: const InputDecoration(
                labelText: 'You offer',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _seek,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => _emit(d.copyWith(seekingSummary: v)),
              decoration: const InputDecoration(
                labelText: 'You’re looking for',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Space.md),
            GoalEditor(
              goals: d.goals,
              onChanged: (g) => _emit(d.copyWith(goals: g)),
            ),
          ],
        ),
        gap,
        _Section(
          title: 'Skills and interests',
          children: [
            ChipEditor(
              label: 'Skills',
              helper:
                  'Things you can do. Only add what you’re comfortable being asked about.',
              values: d.skills,
              onChanged: (v) => _emit(d.copyWith(skills: v)),
            ),
            const SizedBox(height: Space.md),
            ChipEditor(
              label: 'Interests',
              values: d.interests,
              onChanged: (v) => _emit(d.copyWith(interests: v)),
            ),
          ],
        ),
        gap,
        _Section(
          title: 'Area',
          children: [
            AreaDropdown(
              value: d.areaId,
              label: 'Preferred area',
              helperText:
                  'Used to rank nearby listings. Leave as not specified if you prefer.',
              onChanged: (v) => _emit(d.copyWith(areaId: () => v)),
            ),
            const SizedBox(height: Space.xs),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: d.openToRemote,
              onChanged: (v) => _emit(d.copyWith(openToRemote: v)),
              title: const Text('Open to remote opportunities'),
            ),
          ],
        ),
        gap,
        _Section(
          title: 'Optional details',
          children: [
            TextField(
              controller: _affiliation,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) =>
                  _emit(d.copyWith(communityAffiliation: () => v)),
              decoration: const InputDecoration(
                labelText: 'Masjid or community (optional)',
                hintText: 'For example: Attends a masjid in Edison',
                helperText:
                    'Self-reported. It doesn’t mean the masjid has verified or endorsed you.',
                prefixIcon: Icon(Icons.mosque_outlined),
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _linkedin,
              keyboardType: TextInputType.url,
              onChanged: (v) => _emit(d.copyWith(linkedinUrl: () => v)),
              decoration: InputDecoration(
                labelText: 'LinkedIn profile link (optional)',
                hintText: 'https://www.linkedin.com/in/your-name',
                helperText:
                    'Shown as a link if you join the directory. Nothing is imported from LinkedIn.',
                errorText: widget.errors['linkedinUrl'],
                prefixIcon: const Icon(Icons.link),
              ),
            ),
          ],
        ),
        gap,
        SurfaceCard(
          highlighted: d.directoryVisible,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.md,
                  Space.md,
                  0,
                ),
                child: Text('Who can see your profile?', style: t.titleMedium),
              ),
              ExplainedSwitch(
                icon: Icons.groups_outlined,
                title: 'List me in the member directory',
                description: d.directoryVisible
                    ? 'On. Signed-in members can find you and see your name, introduction, area, skills, interests, what you offer and what you’re looking for, plus your community and LinkedIn link if added.'
                    : 'Off. Only your name appears on listings you publish and requests you send. You can turn this on any time.',
                value: d.directoryVisible,
                onChanged: (v) => _emit(d.copyWith(directoryVisible: v)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  0,
                  Space.md,
                  Space.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: c.onSurfaceVariant,
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        'Always private: your goals, saved listings, activity and conversations. Publishing a listing is a separate choice you make each time.',
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: t.titleMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Space.sm),
        ...children,
      ],
    );
  }
}

/// Goals as editable chips: "Looking for a mentor · Robotics".
class GoalEditor extends StatelessWidget {
  const GoalEditor({super.key, required this.goals, required this.onChanged});
  final List<Goal> goals;
  final ValueChanged<List<Goal>> onChanged;

  Future<void> _edit(BuildContext context, {Goal? goal, int? index}) async {
    final result = await showDialog<Goal>(
      context: context,
      builder: (_) => _GoalDialog(initial: goal),
    );
    if (result == null) return;
    final next = [...goals];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Goals', style: t.titleSmall),
        const SizedBox(height: 2),
        Text(
          goals.isEmpty
              ? 'We didn’t find a specific goal. Add one so we can recommend the right listings.'
              : 'Tap a goal to edit it.',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (var i = 0; i < goals.length; i++)
              InputChip(
                avatar: Icon(typeIcon(goals[i].type), size: 18),
                label: Text(goals[i].fullLabel),
                onPressed: () => _edit(context, goal: goals[i], index: i),
                onDeleted: () => onChanged([...goals]..removeAt(i)),
                deleteButtonTooltipMessage: 'Remove goal',
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add a goal'),
              onPressed: () => _edit(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.initial});
  final Goal? initial;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late GoalRole _role = widget.initial?.role ?? GoalRole.seeking;
  late ListingType _type = widget.initial?.type ?? ListingType.mentorship;
  late List<String> _subjects = [...?widget.initial?.subjects];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add a goal' : 'Edit goal'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<GoalRole>(
                segments: const [
                  ButtonSegment(
                    value: GoalRole.seeking,
                    label: Text('Looking for'),
                    icon: Icon(Icons.search),
                  ),
                  ButtonSegment(
                    value: GoalRole.offering,
                    label: Text('Offering'),
                    icon: Icon(Icons.volunteer_activism_outlined),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<ListingType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Kind of opportunity',
                ),
                items: [
                  for (final t in ListingType.values)
                    DropdownMenuItem(
                      value: t,
                      child: Text(Goal(type: t, role: _role).label),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: Space.md),
              ChipEditor(
                label: 'Topics',
                hint: 'For example: robotics',
                helper: 'Optional. What it should be about.',
                values: _subjects,
                maxItems: 6,
                onChanged: (v) => setState(() => _subjects = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            Goal(type: _type, role: _role, subjects: _subjects),
          ),
          child: const Text('Save goal'),
        ),
      ],
    );
  }
}
