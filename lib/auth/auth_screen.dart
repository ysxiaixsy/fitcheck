import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';
import 'auth_gateway.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});
  final AuthGateway auth;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _creating = false, _busy = false, _obscured = true, _isError = false;
  String? _message;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) =>
      value == null ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? 'Enter a valid email address.'
      : null;
  Future<void> _request(
    Future<void> Function() action, {
    String? success,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted && success != null) {
        setState(() {
          _message = success;
          _isError = false;
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _isError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Could not complete this request. Please try again.';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    await _request(
      () => _creating
          ? widget.auth.createAccount(_email.text, _password.text)
          : widget.auth.signIn(_email.text, _password.text),
    );
  }

  Future<void> _reset() async {
    if (_validateEmail(_email.text) != null) {
      setState(() {
        _message =
            'Enter your email address first, then choose Reset password.';
        _isError = true;
      });
      return;
    }
    await _request(
      () => widget.auth.resetPassword(_email.text),
      success:
          'If an account uses this email, a password reset link is on its way.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = FitCheckColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.contentWidth),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('FitCheck', style: text.displayLarge),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Your clothes. Your plans. Your day.',
                        style: text.bodyMedium?.copyWith(color: c.secondary),
                      ),
                      const SizedBox(height: AppSpace.xxxl),
                      Text(
                        _creating ? 'Create your account' : 'Welcome back',
                        style: text.headlineLarge,
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Sign in to keep your wardrobe and plans together.',
                        style: text.bodyMedium?.copyWith(color: c.secondary),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      TextFormField(
                        key: const Key('auth-email'),
                        controller: _email,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        key: const Key('auth-password'),
                        controller: _password,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: _creating
                              ? 'At least 8 characters'
                              : null,
                          suffixIcon: IconButton(
                            tooltip: _obscured
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _obscured = !_obscured),
                            icon: Icon(
                              _obscured
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        obscureText: _obscured,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: [
                          _creating
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password.';
                          }
                          if (_creating && value.length < 8) {
                            return 'Use at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: AppSpace.lg),
                        InlineMessage(_message!, isError: _isError),
                      ],
                      const SizedBox(height: AppSpace.xxl),
                      FilledButton(
                        key: const Key('auth-submit'),
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          _busy
                              ? 'Please wait…'
                              : _creating
                              ? 'Create account'
                              : 'Sign in',
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _creating = !_creating;
                                _message = null;
                                _form.currentState?.reset();
                              }),
                        child: Text(
                          _creating
                              ? 'Already have an account? Sign in'
                              : 'Create an account',
                        ),
                      ),
                      if (!_creating)
                        TextButton(
                          onPressed: _busy ? null : _reset,
                          child: const Text('Reset password'),
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
