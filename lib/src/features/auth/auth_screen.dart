import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/account_gateway.dart';
import '../../data/errors.dart';
import '../../state/session.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/pattern.dart';

enum AuthMode { signIn, signUp }

/// Email and password sign-in for connected mode.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.mode});
  final AuthMode mode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  bool get _signUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final session = ref.read(sessionProvider.notifier);
    try {
      if (_signUp) {
        final result = await session.signUp(
          _name.text,
          _email.text,
          _password.text,
        );
        if (result is ConfirmationRequired && mounted) {
          setState(
            () => _notice =
                'Check ${result.email} for a confirmation link, then sign in.',
          );
        }
      } else {
        await session.signIn(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final configured = ref.watch(appConfigProvider).hasBackend;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/welcome'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark(size: 40),
                      ),
                      const SizedBox(height: Space.lg),
                      Semantics(
                        header: true,
                        child: Text(
                          _signUp ? 'Create your account' : 'Welcome back',
                          style: t.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        _signUp
                            ? 'Your account keeps your profile, listings and conversations in sync across devices.'
                            : 'Sign in to see your recommendations, requests and messages.',
                        style: t.bodyMedium?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      if (!configured)
                        Text(
                          'Accounts aren’t available in this build.',
                          style: t.bodyMedium,
                        ),
                      if (_signUp) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            helperText: 'Shown to other members',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Add your name.'
                              : null,
                        ),
                        const SizedBox(height: Space.md),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Add your email.';
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(s)) {
                            return 'That email doesn’t look right.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: Space.md),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: [
                          _signUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: _signUp ? 'At least 8 characters' : null,
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = v ?? '';
                          if (s.isEmpty) return 'Add your password.';
                          if (_signUp && s.length < 8) {
                            return 'Use at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Space.md),
                        _Notice(text: _error!, error: true),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: Space.md),
                        _Notice(text: _notice!),
                      ],
                      const SizedBox(height: Space.lg),
                      FilledButton(
                        onPressed: _busy || !configured ? null : _submit,
                        child: _busy
                            ? const ButtonSpinner()
                            : Text(_signUp ? 'Create account' : 'Sign in'),
                      ),
                      const SizedBox(height: Space.sm),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.pushReplacement(
                                _signUp ? '/sign-in' : '/sign-up',
                              ),
                        child: Text(
                          _signUp
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: error ? c.errorContainer : c.primaryContainer,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.mark_email_read_outlined,
              color: error ? c.onErrorContainer : c.onPrimaryContainer,
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: error ? c.onErrorContainer : c.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
