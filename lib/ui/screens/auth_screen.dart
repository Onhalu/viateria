import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/repositories.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../theme/brand_assets.dart';

enum _AuthStep { signIn, register, confirmEmail }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _otp = TextEditingController();
  _AuthStep _step = _AuthStep.signIn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _goTo(_AuthStep step) {
    setState(() {
      _step = step;
      _error = null;
      _busy = false;
    });
  }

  String _messageFor(Object error, String fallback) {
    if (error is AuthFailure && error.message.isNotEmpty) {
      return error.message;
    }
    return fallback;
  }

  Future<void> _run(Future<void> Function() action) async {
    final strings = context.read<LocaleController>().strings;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error, strings.errorGeneric));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = context.read<LocaleController>().strings.errorGeneric);
      return;
    }
    await _run(() async {
      await context.read<AppServices>().auth.signIn(
        email: email,
        password: password,
      );
    });
  }

  Future<void> _register() async {
    final strings = context.read<LocaleController>().strings;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = strings.errorGeneric);
      return;
    }
    await _run(() async {
      final result = await context.read<AppServices>().auth.signUp(
        email: email,
        password: password,
        displayName: name,
      );
      if (!mounted) return;
      if (!result.sessionEstablished) {
        _otp.clear();
        setState(() {
          _step = _AuthStep.confirmEmail;
          _error = null;
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    final strings = context.read<LocaleController>().strings;
    final token = _otp.text.trim();
    if (token.length < 6) {
      setState(() => _error = strings.errorGeneric);
      return;
    }
    await _run(() async {
      await context.read<AppServices>().auth.verifyEmailOtp(
        email: _email.text.trim(),
        token: token,
      );
    });
  }

  Future<void> _enterAfterConfirm() async {
    await _run(() async {
      await context.read<AppServices>().auth.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            const Center(
              child: BrandLockup(width: BrandAssets.splashLockupWidth),
            ),
            if (_step != _AuthStep.signIn) ...[
              const SizedBox(height: 8),
              Text(
                _step == _AuthStep.register
                    ? strings.registerTitle
                    : strings.confirmEmailTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 32),
            ..._fields(strings),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            ..._actions(strings),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields(AppStrings strings) {
    switch (_step) {
      case _AuthStep.signIn:
        return [
          TextField(
            key: const Key('auth-email'),
            controller: _email,
            decoration: InputDecoration(labelText: strings.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          TextField(
            key: const Key('auth-password'),
            controller: _password,
            decoration: InputDecoration(labelText: strings.password),
            obscureText: true,
            onSubmitted: (_) => _signIn(),
            autofillHints: const [AutofillHints.password],
          ),
        ];
      case _AuthStep.register:
        return [
          TextField(
            key: const Key('auth-display-name'),
            controller: _name,
            decoration: InputDecoration(labelText: strings.displayName),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
          TextField(
            key: const Key('auth-email'),
            controller: _email,
            decoration: InputDecoration(labelText: strings.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          TextField(
            key: const Key('auth-password'),
            controller: _password,
            decoration: InputDecoration(labelText: strings.password),
            obscureText: true,
            onSubmitted: (_) => _register(),
            autofillHints: const [AutofillHints.newPassword],
          ),
        ];
      case _AuthStep.confirmEmail:
        return [
          Text(strings.confirmEmailBody),
          const SizedBox(height: 16),
          TextField(
            key: const Key('auth-otp'),
            controller: _otp,
            decoration: InputDecoration(labelText: strings.otpCode),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _verifyOtp(),
          ),
        ];
    }
  }

  List<Widget> _actions(AppStrings strings) {
    switch (_step) {
      case _AuthStep.signIn:
        return [
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: _busyChild(strings.signIn),
          ),
          TextButton(
            key: const Key('auth-open-register'),
            onPressed: _busy ? null : () => _goTo(_AuthStep.register),
            child: Text(strings.registerAction),
          ),
        ];
      case _AuthStep.register:
        return [
          FilledButton(
            key: const Key('auth-submit-register'),
            onPressed: _busy ? null : _register,
            child: _busyChild(strings.signUp),
          ),
          TextButton(
            key: const Key('auth-back-sign-in'),
            onPressed: _busy ? null : () => _goTo(_AuthStep.signIn),
            child: Text(strings.backToSignIn),
          ),
        ];
      case _AuthStep.confirmEmail:
        return [
          FilledButton(
            key: const Key('auth-verify-otp'),
            onPressed: _busy ? null : _verifyOtp,
            child: _busyChild(strings.verifyOtp),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('auth-enter-after-confirm'),
            onPressed: _busy ? null : _enterAfterConfirm,
            child: Text(strings.enterAfterConfirm),
          ),
          TextButton(
            onPressed: _busy ? null : () => _goTo(_AuthStep.signIn),
            child: Text(strings.backToSignIn),
          ),
        ];
    }
  }

  Widget _busyChild(String label) {
    if (!_busy) return Text(label);
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
