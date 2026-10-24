import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/errors.dart';
import '../../domain/profile.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import 'profile_form.dart';

class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return profile.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const ContentWidth(child: LoadingBlocks()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(error: e),
      ),
      data: (p) => p == null ? const SizedBox.shrink() : _Editor(profile: p),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late ProfileDraft _draft = ProfileDraft.fromProfile(widget.profile);
  Map<String, String> _errors = const {};
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    final errors = _draft.validate();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(actionsProvider).saveProfile(_draft);
      if (!mounted) return;
      _dirty = false;
      showMessage(context, 'Profile saved. Recommendations are updated.');
      context.go('/profile');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
          if (e is ValidationException) _errors = e.fieldErrors;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final ok = await confirmAction(
          context,
          title: 'Discard your changes?',
          message: 'Your edits haven’t been saved.',
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (ok) {
          setState(() => _dirty = false);
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl),
          child: ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Text(_error!, style: TextStyle(color: c.error)),
                  ),
                ProfileForm(
                  draft: _draft,
                  errors: _errors,
                  onChanged: (d) => setState(() {
                    _draft = d;
                    _dirty = true;
                    _errors = const {};
                  }),
                ),
                const SizedBox(height: Space.lg),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Save profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
