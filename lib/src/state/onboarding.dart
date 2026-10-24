import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/errors.dart';
import '../domain/json.dart';
import '../domain/profile.dart';
import '../matching/extraction.dart';
import '../matching/intent_parser.dart';
import 'data_providers.dart';
import 'session.dart';

class OnboardingState {
  const OnboardingState({
    this.step = 0,
    this.name = '',
    this.answers = const OnboardingAnswers(),
    this.review,
    this.source,
    this.extracting = false,
    this.extractionFailed = false,
    this.saving = false,
    this.error,
    this.fieldErrors = const {},
  });

  static const stepCount = 5;
  static const reviewStep = 4;

  final int step;
  final String name;
  final OnboardingAnswers answers;

  /// Editable suggestions shown on the review step.
  final ProfileDraft? review;
  final ExtractionSource? source;
  final bool extracting;
  final bool extractionFailed;
  final bool saving;
  final String? error;
  final Map<String, String> fieldErrors;

  OnboardingState copyWith({
    int? step,
    String? name,
    OnboardingAnswers? answers,
    ProfileDraft? Function()? review,
    ExtractionSource? Function()? source,
    bool? extracting,
    bool? extractionFailed,
    bool? saving,
    String? Function()? error,
    Map<String, String>? fieldErrors,
  }) => OnboardingState(
    step: step ?? this.step,
    name: name ?? this.name,
    answers: answers ?? this.answers,
    review: review != null ? review() : this.review,
    source: source != null ? source() : this.source,
    extracting: extracting ?? this.extracting,
    extractionFailed: extractionFailed ?? this.extractionFailed,
    saving: saving ?? this.saving,
    error: error != null ? error() : this.error,
    fieldErrors: fieldErrors ?? this.fieldErrors,
  );

  Map<String, Object?> toJson() => {
    'step': step,
    'name': name,
    'answers': answers.toJson(),
    'review': review?.toJson(),
  };

  factory OnboardingState.fromJson(Map<String, Object?> json) =>
      OnboardingState(
        step: (json['step'] as int? ?? 0).clamp(0, stepCount - 1),
        name: json['name'] as String? ?? '',
        answers: OnboardingAnswers.fromJson(asJsonMap(json['answers'])),
        review: json['review'] == null
            ? null
            : ProfileDraft.fromJson(asJsonMap(json['review'])),
      );
}

/// Drives onboarding. Answers are saved on every change, so going back,
/// a failed save, or a refresh never loses what was typed.
class OnboardingController extends Notifier<OnboardingState> {
  String get _key =>
      'mm.onboarding.${ref.read(currentUserIdProvider) ?? 'none'}';

  @override
  OnboardingState build() {
    ref.watch(currentUserIdProvider);
    final raw = ref.read(keyValueStoreProvider).getString(_key);
    if (raw != null) {
      try {
        final restored = OnboardingState.fromJson(asJsonMap(jsonDecode(raw)));
        // Never resume mid-extraction; re-run when the review is missing.
        if (restored.step == OnboardingState.reviewStep &&
            restored.review == null) {
          return restored.copyWith(step: OnboardingState.reviewStep - 1);
        }
        return restored;
      } catch (_) {
        // Ignore an unreadable draft.
      }
    }
    return const OnboardingState();
  }

  void _persist() {
    ref
        .read(keyValueStoreProvider)
        .setString(_key, jsonEncode(state.toJson()))
        .ignore();
  }

  void setName(String value) {
    state = state.copyWith(name: value, fieldErrors: const {});
    _persist();
  }

  void setAnswers(OnboardingAnswers answers) {
    state = state.copyWith(answers: answers);
    _persist();
  }

  void back() {
    if (state.step == 0) return;
    state = state.copyWith(
      step: state.step - 1,
      error: () => null,
      fieldErrors: const {},
    );
    _persist();
  }

  /// Validates the current step and advances. Moving onto the review step
  /// runs extraction.
  Future<void> next() async {
    if (state.step == 0 && state.name.trim().isEmpty) {
      state = state.copyWith(
        fieldErrors: {'name': 'Add the name other members will see.'},
      );
      return;
    }
    if (state.step >= OnboardingState.reviewStep) return;
    final nextStep = state.step + 1;
    state = state.copyWith(
      step: nextStep,
      error: () => null,
      fieldErrors: const {},
    );
    _persist();
    if (nextStep == OnboardingState.reviewStep) await extract();
  }

  Future<void> extract() async {
    final backend = ref.read(backendProvider);
    if (backend == null) return;
    state = state.copyWith(
      extracting: true,
      extractionFailed: false,
      error: () => null,
    );
    try {
      final outcome = await backend.extractor.extract(state.answers);
      if (!ref.mounted) return;
      final e = outcome.extraction;
      final previous = state.review;
      final draft = ProfileDraft(
        displayName: state.name.trim(),
        headline: previous?.headline ?? '',
        skills: e.skills,
        interests: e.interests,
        offeringSummary: e.offeringSummary,
        seekingSummary: e.seekingSummary,
        goals: e.goals,
        areaId: e.areaId,
        openToRemote: e.openToRemote ?? previous?.openToRemote ?? true,
        communityAffiliation: previous?.communityAffiliation,
        linkedinUrl: previous?.linkedinUrl,
        // Opt-in: off until the member turns it on.
        directoryVisible: previous?.directoryVisible ?? false,
      );
      state = state.copyWith(
        extracting: false,
        review: () => draft,
        source: () => outcome.source,
      );
      _persist();
    } catch (_) {
      if (!ref.mounted) return;
      // Keep every answer; offer manual entry.
      state = state.copyWith(
        extracting: false,
        extractionFailed: true,
        review: () =>
            state.review ??
            ProfileDraft(
              displayName: state.name.trim(),
              offeringSummary: state.answers.offer.trim(),
              seekingSummary: state.answers.seek.trim(),
            ),
      );
    }
  }

  void updateReview(ProfileDraft draft) {
    state = state.copyWith(review: () => draft, fieldErrors: const {});
    _persist();
  }

  /// Saves the profile and completes onboarding. Returns true on success.
  Future<bool> finish() async {
    final backend = ref.read(backendProvider);
    final draft = state.review;
    if (backend == null || draft == null || state.saving) return false;
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return false;
    }
    state = state.copyWith(saving: true, error: () => null);
    try {
      await backend.profiles.saveMine(draft, completeOnboarding: true);
      await ref.read(keyValueStoreProvider).remove(_key);
      if (!ref.mounted) return true;
      state = state.copyWith(saving: false);
      ref.invalidate(myProfileProvider);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        saving: false,
        error: () => friendlyError(e),
        fieldErrors: e is ValidationException ? e.fieldErrors : const {},
      );
      return false;
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
