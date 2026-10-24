import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../matching/intent_parser.dart';
import '../../state/data_providers.dart';
import '../../state/onboarding.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/pattern.dart';
import '../profile/profile_form.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    final isDemo = ref.watch(sessionProvider).value?.isDemo ?? false;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final isReview = state.step == OnboardingState.reviewStep;

    // Prefill the name from the account (connected sign-up) once.
    final profileName = ref.watch(myProfileProvider).value?.displayName ?? '';
    if (state.name.isEmpty && profileName.isNotEmpty && state.step == 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.setName(profileName),
      );
    }

    final step = switch (state.step) {
      0 => _NameStep(
        key: const ValueKey('name'),
        initial: state.name,
        error: state.fieldErrors['name'],
      ),
      1 => _TextStep(
        key: const ValueKey('offer'),
        title: 'What can you offer the community?',
        subtitle:
            'Skills, services, mentoring, a business, or time to volunteer. Plain words are perfect.',
        hint: 'For example: I can tutor high school math and help with Python.',
        initial: state.answers.offer,
        examples: const [
          'I can tutor high school math and physics',
          'I’m a mechanical engineer and can mentor students in robotics',
          'I run a small bakery and do catering for events',
        ],
        onChanged: (v) =>
            controller.setAnswers(state.answers.copyWith(offer: v)),
        optionalNote:
            'Nothing to offer right now? That’s fine, leave it blank.',
      ),
      2 => _TextStep(
        key: const ValueKey('seek'),
        title: 'What are you looking for?',
        subtitle:
            'A mentor, a job or internship, help with something, collaborators, or a place to volunteer.',
        hint:
            'For example: A robotics mentor and a summer engineering internship.',
        initial: state.answers.seek,
        examples: const [
          'A robotics mentor and a summer engineering internship',
          'Someone to build a website for my small business',
          'Volunteer opportunities with youth programs on weekends',
        ],
        onChanged: (v) =>
            controller.setAnswers(state.answers.copyWith(seek: v)),
      ),
      3 => _InterestsAreaStep(
        key: const ValueKey('interests'),
        answers: state.answers,
        onChanged: controller.setAnswers,
      ),
      _ => const _ReviewStep(key: ValueKey('review')),
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 28),
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                isReview ? 'Review your profile' : 'Set up your profile',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isDemo)
            const Padding(
              padding: EdgeInsets.only(right: Space.md),
              child: StatusBadge(
                label: 'Demo',
                tone: BadgeTone.warning,
                icon: Icons.science_outlined,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${state.step + 1} of ${OnboardingState.stepCount}',
                  style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (state.step + 1) / OnboardingState.stepCount,
                    minHeight: 6,
                    // The visible "Step N of 5" text above names the step;
                    // the bar reports its numeric progress.
                    semanticsLabel: 'Setup progress',
                  ),
                ),
                const SizedBox(height: Space.xs),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(vertical: Space.lg),
                child: ContentWidth(
                  maxWidth: 720,
                  child: AnimatedSwitcher(
                    duration: motion(context),
                    child: step,
                  ),
                ),
              ),
            ),
            _BottomBar(state: state),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.state});
  final OnboardingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingProvider.notifier);
    final c = Theme.of(context).colorScheme;
    final isReview = state.step == OnboardingState.reviewStep;
    final busy = state.extracting || state.saving;
    return Material(
      color: c.surfaceContainerLowest,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: ContentWidth(
          maxWidth: 720,
          // OverflowBar stacks the buttons when they don't fit (narrow
          // screens, large text) instead of overflowing.
          child: OverflowBar(
            alignment: state.step > 0
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: Space.xs,
            children: [
              if (state.step > 0)
                TextButton.icon(
                  onPressed: busy ? null : controller.back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              if (!isReview)
                FilledButton.icon(
                  onPressed: busy ? null : controller.next,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    state.step == OnboardingState.reviewStep - 1
                        ? 'Review'
                        : 'Next',
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: busy || state.review == null
                      ? null
                      : () async {
                          final ok = await controller.finish();
                          if (ok && context.mounted) {
                            showMessage(
                              context,
                              'Profile saved. Here are your matches.',
                            );
                          }
                        },
                  icon: state.saving
                      ? const ButtonSpinner()
                      : const Icon(Icons.check),
                  label: const Text('Save and see matches'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: t.headlineSmall)),
        if (subtitle != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            subtitle!,
            style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

class _NameStep extends ConsumerStatefulWidget {
  const _NameStep({super.key, required this.initial, this.error});
  final String initial;
  final String? error;

  @override
  ConsumerState<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<_NameStep> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void didUpdateWidget(_NameStep old) {
    super.didUpdateWidget(old);
    if (widget.initial != _controller.text &&
        widget.initial.isNotEmpty &&
        _controller.text.isEmpty) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Salaam! What should we call you?',
          subtitle:
              'Next, you’ll describe what you offer and what you’re looking for, in your own words. It takes about two minutes.',
        ),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: ref.read(onboardingProvider.notifier).setName,
          onSubmitted: (_) => ref.read(onboardingProvider.notifier).next(),
          decoration: InputDecoration(
            labelText: 'Your name',
            helperText: 'Shown on your listings and requests',
            errorText: widget.error,
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Text(
                'Nothing is shared until you choose to. You’ll decide about the member directory on the last step.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TextStep extends StatefulWidget {
  const _TextStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.initial,
    required this.examples,
    required this.onChanged,
    this.optionalNote,
  });

  final String title;
  final String subtitle;
  final String hint;
  final String initial;
  final List<String> examples;
  final ValueChanged<String> onChanged;
  final String? optionalNote;

  @override
  State<_TextStep> createState() => _TextStepState();
}

class _TextStepState extends State<_TextStep> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _useExample(String e) {
    final current = _controller.text.trim();
    final next = current.isEmpty ? e : '$current. $e';
    _controller.text = next;
    _controller.selection = TextSelection.collapsed(offset: next.length);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(title: widget.title, subtitle: widget.subtitle),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          maxLength: 600,
          textCapitalization: TextCapitalization.sentences,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Need a starting point?',
          style: t.labelMedium?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final e in widget.examples)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(e),
                onPressed: () => _useExample(e),
              ),
          ],
        ),
        if (widget.optionalNote != null) ...[
          const SizedBox(height: Space.md),
          Text(
            widget.optionalNote!,
            style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _InterestsAreaStep extends StatefulWidget {
  const _InterestsAreaStep({
    super.key,
    required this.answers,
    required this.onChanged,
  });
  final OnboardingAnswers answers;
  final ValueChanged<OnboardingAnswers> onChanged;

  @override
  State<_InterestsAreaStep> createState() => _InterestsAreaStepState();
}

class _InterestsAreaStepState extends State<_InterestsAreaStep> {
  late final _interests = TextEditingController(text: widget.answers.interests);
  late final _area = TextEditingController(text: widget.answers.area);

  @override
  void dispose() {
    _interests.dispose();
    _area.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
    widget.answers.copyWith(interests: _interests.text, area: _area.text),
  );

  void _appendArea(String s) {
    final current = _area.text.trim();
    _area.text = current.isEmpty ? s : '$current, $s';
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Your interests and area',
          subtitle:
              'Both are optional and help us rank what’s most relevant to you.',
        ),
        TextField(
          controller: _interests,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _emit(),
          decoration: const InputDecoration(
            labelText: 'Interests',
            hintText: 'For example: robotics, renewable energy, soccer',
            helperText: 'Separate with commas',
          ),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _area,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _emit(),
          decoration: const InputDecoration(
            labelText: 'Where should we look?',
            hintText: 'For example: New Brunswick, open to remote',
            helperText:
                'A town in Central Jersey, and whether remote works for you',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final s in const [
              'New Brunswick',
              'Edison',
              'Piscataway',
              'Princeton',
              'East Brunswick',
              'Open to remote',
            ])
              ActionChip(label: Text(s), onPressed: () => _appendArea(s)),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          'We only use a location you name here. Leaving it blank is fine.',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ReviewStep extends ConsumerWidget {
  const _ReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    if (state.extracting || state.review == null) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xxl),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: Space.md),
                Text('Reading your answers…', style: t.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Here’s what we picked up',
          subtitle:
              'We only used your own words. Fix anything that’s off and add what we missed.',
        ),
        if (state.extractionFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Container(
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: c.secondaryContainer,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: c.onSecondaryContainer),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      'We couldn’t read your answers automatically. Your answers are safe; add details below or try again.',
                      style: t.bodyMedium?.copyWith(
                        color: c.onSecondaryContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.extract,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Semantics(
              liveRegion: true,
              child: Text(
                state.error!,
                style: t.bodyMedium?.copyWith(color: c.error),
              ),
            ),
          ),
        ProfileForm(
          draft: state.review!,
          errors: state.fieldErrors,
          onChanged: controller.updateReview,
          showName: true,
        ),
      ],
    );
  }
}
