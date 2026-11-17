import 'package:flutter/material.dart';

import '../models/board_models.dart';
import '../validation.dart';

enum EntryMode { login, register, profile }

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    required this.mode,
    required this.onSubmit,
    this.onAlternate,
    this.initialDetails,
  });

  final EntryMode mode;
  final Future<void> Function(
    String email,
    String password,
    ProfileDetails details,
  )
  onSubmit;
  final VoidCallback? onAlternate;
  final ProfileDetails? initialDetails;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscured = true;
  String? _error;

  bool get _login => widget.mode == EntryMode.login;
  bool get _profile => widget.mode == EntryMode.profile;
  bool get _register => widget.mode == EntryMode.register;

  @override
  void initState() {
    super.initState();
    _first.text = widget.initialDetails?.firstName ?? '';
    _last.text = widget.initialDetails?.lastName ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _email.text.trim(),
        _password.text,
        ProfileDetails(_first.text.trim(), _last.text.trim()),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyError(
            error,
            'Could not continue. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Common Room',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _profile
                            ? 'Complete your profile'
                            : _login
                            ? 'Welcome back'
                            : 'Join the board',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _profile
                            ? 'Add the name that will appear on your posts.'
                            : _login
                            ? 'Sign in to read and post messages.'
                            : 'Create an account to join the conversation.',
                      ),
                      const SizedBox(height: 24),
                      if (!_login) ...[
                        _field(
                          'First name',
                          _first,
                          nameError,
                          autofill: AutofillHints.givenName,
                        ),
                        _field(
                          'Last name',
                          _last,
                          nameError,
                          autofill: AutofillHints.familyName,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Text('Role  ·  Member'),
                        ),
                      ],
                      if (!_profile) ...[
                        _field(
                          'Email address',
                          _email,
                          emailError,
                          keyboard: TextInputType.emailAddress,
                          autofill: AutofillHints.email,
                        ),
                        _field(
                          'Password',
                          _password,
                          (value) =>
                              passwordError(value, registering: _register),
                          secret: true,
                          autofill: _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                          suffix: IconButton(
                            tooltip: _obscured
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscured = !_obscured),
                            icon: Icon(
                              _obscured
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ],
                      if (_register)
                        _field(
                          'Confirm password',
                          _confirmation,
                          (value) =>
                              (value?.isEmpty ?? true) ||
                                  value != _password.text
                              ? 'Enter the same password.'
                              : null,
                          secret: true,
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Submitting',
                                ),
                              )
                            : Text(
                                _profile
                                    ? 'Save profile'
                                    : _login
                                    ? 'Sign in'
                                    : 'Create account',
                              ),
                      ),
                      if (widget.onAlternate != null)
                        TextButton(
                          onPressed: _busy ? null : widget.onAlternate,
                          child: Text(
                            _profile
                                ? 'Sign out'
                                : _login
                                ? 'Create an account'
                                : 'Back to sign in',
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

  Widget _field(
    String label,
    TextEditingController controller,
    String? Function(String?) validate, {
    TextInputType? keyboard,
    String? autofill,
    bool secret = false,
    Widget? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      validator: validate,
      keyboardType: keyboard,
      autofillHints: autofill == null ? null : [autofill],
      obscureText: secret && _obscured,
      autocorrect: !secret && keyboard != TextInputType.emailAddress,
      decoration: InputDecoration(labelText: label, suffixIcon: suffix),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(large ? 24 : 17),
      ),
      child: Padding(
        padding: EdgeInsets.all(large ? 22 : 13),
        child: Icon(
          Icons.forum_outlined,
          color: colors.onPrimary,
          size: large ? 40 : 24,
        ),
      ),
    );
  }
}
