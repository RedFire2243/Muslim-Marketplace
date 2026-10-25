import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/voice_search.dart';
import '../../ui/theme.dart';

/// Voice is the primary way into discovery; typing is available on demand.
class VoiceSearchHero extends StatefulWidget {
  const VoiceSearchHero({
    super.key,
    required this.voice,
    required this.hasQuery,
    required this.controller,
    required this.focusNode,
    required this.onVoice,
    required this.onSubmit,
    required this.onClear,
  });

  final VoiceSearchState? voice;
  final bool hasQuery;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onVoice;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  State<VoiceSearchHero> createState() => _VoiceSearchHeroState();
}

class _VoiceSearchHeroState extends State<VoiceSearchHero> {
  static const _prompts = [
    'What are you looking for?',
    'What can we help you find?',
    'Who could help you grow?',
  ];

  Timer? _promptTimer;
  var _promptIndex = 0;
  var _typing = false;
  var _animate = false;

  VoicePhase get _phase => widget.voice?.phase ?? VoicePhase.idle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _syncPrompts();
  }

  @override
  void didUpdateWidget(covariant VoiceSearchHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPrompts();
  }

  void _syncPrompts() {
    if (!_animate || _phase != VoicePhase.idle || _typing || widget.hasQuery) {
      _promptTimer?.cancel();
      _promptTimer = null;
      if (!_animate) _promptIndex = 0;
      return;
    }
    _promptTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      setState(() => _promptIndex = (_promptIndex + 1) % _prompts.length);
    });
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    super.dispose();
  }

  void _toggleTyping() {
    setState(() => _typing = !_typing);
    _syncPrompts();
    if (_typing) {
      widget.focusNode.requestFocus();
    } else {
      widget.focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final compact = Breakpoints.isCompact(context);
    final idle = _phase == VoicePhase.idle;
    final heading = switch (_phase) {
      VoicePhase.idle =>
        widget.hasQuery
            ? 'What else can we help you find?'
            : _prompts[_promptIndex],
      VoicePhase.listening => 'Listening…',
      VoicePhase.transcribing => 'Finding your matches…',
    };
    final status = switch (_phase) {
      VoicePhase.idle =>
        widget.voice == null
            ? 'Voice search is unavailable right now.'
            : 'Tap to speak',
      VoicePhase.listening => 'Tap again when you’re done',
      VoicePhase.transcribing => 'Turning your words into connections',
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? Space.md : Space.xl,
        compact ? Space.lg : Space.xl,
        compact ? Space.md : Space.xl,
        Space.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: c.primary.withValues(alpha: 0.1)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surfaceContainerLowest, const Color(0xFFEDF5EF)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'GOOD THINGS START WITH A CONVERSATION',
            textAlign: TextAlign.center,
            style: t.labelSmall?.copyWith(
              color: c.primary,
              letterSpacing: 1.3,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: Space.md),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: compact ? 80 : 96,
              maxWidth: 580,
            ),
            child: Center(
              child: Semantics(
                header: true,
                // Rotating decorative prompts should not keep interrupting
                // screen readers with a new question.
                label: idle ? _prompts.first : heading,
                excludeSemantics: true,
                child: AnimatedSwitcher(
                  duration: motion(context, 650),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child: Text(
                    heading,
                    key: ValueKey(heading),
                    textAlign: TextAlign.center,
                    style: t.displaySmall?.copyWith(
                      fontSize: compact ? 30 : 40,
                      height: 1.2,
                      color: Brand.emeraldDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'A mentor, a new opportunity, a little local help.\nTell us what you need.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: Space.xs),
          _VoiceOrb(voice: widget.voice, onPressed: widget.onVoice),
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: t.titleSmall?.copyWith(color: c.primary),
            ),
          ),
          const SizedBox(height: Space.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              idle
                  ? widget.voice == null
                        ? 'Type what you need to explore your community.'
                        : 'Speak naturally. We’ll find the closest matches.'
                  : 'Your recording is sent to Google Gemini to turn it into text.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: Space.sm),
          TextButton.icon(
            onPressed: idle ? _toggleTyping : null,
            icon: Icon(
              _typing ? Icons.mic_none : Icons.keyboard_outlined,
              size: 18,
            ),
            label: Text(_typing ? 'Use voice instead' : 'Type instead'),
          ),
          AnimatedSize(
            duration: motion(context),
            alignment: Alignment.topCenter,
            child: _typing && idle
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: TextField(
                        key: const ValueKey('discovery-search-input'),
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => widget.onSubmit(),
                        decoration: InputDecoration(
                          labelText: 'What are you looking for?',
                          hintText: 'Try “a robotics mentor near me”',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListenableBuilder(
                                listenable: widget.controller,
                                builder: (context, _) =>
                                    widget.controller.text.isEmpty
                                    ? const SizedBox.shrink()
                                    : IconButton(
                                        tooltip: 'Clear search text',
                                        onPressed: widget.onClear,
                                        icon: const Icon(Icons.close, size: 20),
                                      ),
                              ),
                              IconButton(
                                tooltip: 'Search',
                                onPressed: widget.onSubmit,
                                icon: const Icon(Icons.arrow_forward),
                              ),
                              const SizedBox(width: Space.xxs),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({required this.voice, required this.onPressed});

  final VoiceSearchState? voice;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final compact = Breakpoints.isCompact(context);
    final phase = voice?.phase ?? VoicePhase.idle;
    final listening = phase == VoicePhase.listening;
    final busy = phase == VoicePhase.transcribing;
    final level = listening ? voice!.level : 0.0;
    final size = compact ? 116.0 : 128.0;
    final label = voice == null
        ? 'Voice search unavailable'
        : switch (phase) {
            VoicePhase.idle => 'Search by voice',
            VoicePhase.listening => 'Stop and search',
            VoicePhase.transcribing => 'Finding your matches',
          };

    return SizedBox.square(
      dimension: compact ? 208 : 224,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: AnimatedContainer(
              duration: motion(context, 140),
              width: size + 64 + level * 20,
              height: size + 64 + level * 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: listening ? 0.08 : 0.035),
                border: Border.all(color: c.primary.withValues(alpha: 0.06)),
              ),
            ),
          ),
          ExcludeSemantics(
            child: AnimatedContainer(
              duration: motion(context, 140),
              width: size + 28 + level * 16,
              height: size + 28 + level * 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: listening ? 0.14 : 0.07),
                border: Border.all(color: c.primary.withValues(alpha: 0.08)),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(
                    alpha: voice == null ? 0.08 : 0.22,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: IconButton.filled(
              key: const ValueKey('discovery-voice-button'),
              tooltip: label,
              onPressed: voice == null || busy ? null : onPressed,
              style: IconButton.styleFrom(
                fixedSize: Size.square(size),
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                disabledBackgroundColor: busy
                    ? c.primary
                    : c.primary.withValues(alpha: 0.3),
                disabledForegroundColor: c.onPrimary,
                shape: const CircleBorder(),
              ),
              icon: busy
                  ? SizedBox.square(
                      dimension: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: c.onPrimary,
                        semanticsLabel: label,
                      ),
                    )
                  : Icon(
                      listening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 48,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
