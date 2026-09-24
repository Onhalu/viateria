import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/repositories.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../theme/brand_assets.dart';
import '../../theme/brand_colors.dart';

enum _AuthStep {
  signIn,
  register,
  confirmEmail,
  magicLink,
  forgotPassword,
  forgotPasswordSent,
  setPassword,
}

const _minPasswordLength = 6;

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
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  _AuthStep _step = _AuthStep.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  StreamSubscription<Object>? _authFailures;
  StreamSubscription<bool>? _recoverySub;

  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    foregroundColor: BrandColors.bark,
  );

  static final ButtonStyle _socialStyle = OutlinedButton.styleFrom(
    backgroundColor: BrandColors.cream,
    foregroundColor: BrandColors.forest,
    side: const BorderSide(color: BrandColors.forest),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AppServices>().auth;
    _authFailures ??= auth.authFailures().listen((error) {
      if (!mounted) return;
      final strings = context.read<LocaleController>().strings;
      setState(() {
        _busy = false;
        _error = _messageFor(error, strings);
      });
    });
    if (_recoverySub == null) {
      // The recovery event can arrive before this screen subscribes.
      // The repository flag covers that cold start.
      if (auth.pendingPasswordRecovery) {
        _step = _AuthStep.setPassword;
      }
      _recoverySub = auth.passwordRecovery().listen((pending) {
        if (!mounted || !pending) return;
        setState(_openSetPassword);
      });
    }
  }

  @override
  void dispose() {
    unawaited(_authFailures?.cancel());
    unawaited(_recoverySub?.cancel());
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _goTo(_AuthStep step) {
    setState(() {
      _step = step;
      _error = null;
      _busy = false;
      _obscurePassword = true;
    });
  }

  void _openSetPassword() {
    _newPassword.clear();
    _confirmPassword.clear();
    _obscureNewPassword = true;
    _obscureConfirmPassword = true;
    _step = _AuthStep.setPassword;
    _error = null;
    _busy = false;
  }

  String _messageFor(Object error, AppStrings strings) {
    if (error is AuthProviderUnavailable) {
      final provider = error.provider;
      if (provider == null) return strings.authProviderUnavailableGeneric;
      return strings.authProviderUnavailable(provider.label);
    }
    if (error is AuthBrowserLaunchFailed) return strings.authBrowserFailed;
    if (error is AuthFailure && error.message.isNotEmpty) return error.message;
    return strings.errorGeneric;
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
        setState(() => _error = _messageFor(error, strings));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(
        () => _error = context.read<LocaleController>().strings.errorGeneric,
      );
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

  Future<void> _sendMagicLink() async {
    final strings = context.read<LocaleController>().strings;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = strings.errorGeneric);
      return;
    }
    await _run(() async {
      await context.read<AppServices>().auth.sendMagicLink(email: email);
      if (!mounted) return;
      _otp.clear();
      setState(() {
        _step = _AuthStep.magicLink;
        _error = null;
      });
    });
  }

  Future<void> _sendPasswordReset() async {
    final strings = context.read<LocaleController>().strings;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = strings.errorGeneric);
      return;
    }
    await _run(() async {
      await context.read<AppServices>().auth.sendPasswordReset(email: email);
      if (!mounted) return;
      setState(() {
        _step = _AuthStep.forgotPasswordSent;
        _error = null;
      });
    });
  }

  Future<void> _savePassword() async {
    final strings = context.read<LocaleController>().strings;
    final password = _newPassword.text;
    final confirm = _confirmPassword.text;
    if (password.length < _minPasswordLength) {
      setState(() => _error = strings.passwordTooShort);
      return;
    }
    if (password != confirm) {
      setState(() => _error = strings.passwordMismatch);
      return;
    }
    await _run(() async {
      await context.read<AppServices>().auth.updatePassword(password);
    });
  }

  Future<void> _oauth(AuthProvider provider) async {
    await _run(() async {
      await context.read<AppServices>().auth.signInWithProvider(provider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      backgroundColor: BrandColors.cream,
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
                switch (_step) {
                  _AuthStep.register => strings.registerTitle,
                  _AuthStep.confirmEmail => strings.confirmEmailTitle,
                  _AuthStep.magicLink => strings.magicLinkSentTitle,
                  _AuthStep.forgotPassword => strings.forgotPasswordTitle,
                  _AuthStep.forgotPasswordSent => strings.resetEmailSentTitle,
                  _AuthStep.setPassword => strings.setPasswordTitle,
                  _AuthStep.signIn => '',
                },
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: BrandColors.forest),
              ),
            ],
            const SizedBox(height: 32),
            ..._fields(strings),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('auth-error'),
                style: const TextStyle(color: BrandColors.error),
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
          _passwordField(
            fieldKey: const Key('auth-password'),
            toggleKey: const Key('auth-toggle-password'),
            controller: _password,
            label: strings.password,
            obscure: _obscurePassword,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            strings: strings,
            onSubmitted: (_) => _signIn(),
            autofillHints: const [AutofillHints.password],
          ),
          _forgotPasswordLink(strings),
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
          _passwordField(
            fieldKey: const Key('auth-password'),
            toggleKey: const Key('auth-toggle-password'),
            controller: _password,
            label: strings.password,
            obscure: _obscurePassword,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            strings: strings,
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
      case _AuthStep.magicLink:
        return [
          Text(strings.magicLinkSentBody),
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
      case _AuthStep.forgotPassword:
        return [
          TextField(
            key: const Key('auth-email'),
            controller: _email,
            decoration: InputDecoration(labelText: strings.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendPasswordReset(),
          ),
        ];
      case _AuthStep.forgotPasswordSent:
        return [Text(strings.resetEmailSentBody)];
      case _AuthStep.setPassword:
        return [
          _passwordField(
            fieldKey: const Key('auth-new-password'),
            toggleKey: const Key('auth-toggle-new-password'),
            controller: _newPassword,
            label: strings.newPassword,
            obscure: _obscureNewPassword,
            onToggle: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
            strings: strings,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          _passwordField(
            fieldKey: const Key('auth-confirm-password'),
            toggleKey: const Key('auth-toggle-confirm-password'),
            controller: _confirmPassword,
            label: strings.confirmPassword,
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            strings: strings,
            onSubmitted: (_) => _savePassword(),
            autofillHints: const [AutofillHints.newPassword],
          ),
        ];
    }
  }

  Widget _forgotPasswordLink(AppStrings strings) {
    return Row(
      children: [
        const Spacer(),
        TextButton(
          key: const Key('auth-forgot-password'),
          style: _linkStyle,
          onPressed: _busy ? null : () => _goTo(_AuthStep.forgotPassword),
          child: Text(strings.forgotPassword),
        ),
      ],
    );
  }

  Widget _passwordField({
    required Key fieldKey,
    required Key toggleKey,
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required AppStrings strings,
    TextInputAction textInputAction = TextInputAction.done,
    Iterable<String>? autofillHints,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          key: toggleKey,
          tooltip: obscure ? strings.showPassword : strings.hidePassword,
          color: BrandColors.bark,
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: BrandColors.bark,
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(AppStrings strings) {
    switch (_step) {
      case _AuthStep.signIn:
        return [
          FilledButton(
            key: const Key('auth-sign-in'),
            onPressed: _busy ? null : _signIn,
            child: _busyChild(strings.signIn),
          ),
          TextButton(
            key: const Key('auth-magic-link'),
            style: _linkStyle,
            onPressed: _busy ? null : _sendMagicLink,
            child: Text(strings.sendMagicLink),
          ),
          ..._providers(strings),
          TextButton(
            key: const Key('auth-open-register'),
            style: _linkStyle,
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
          ..._providers(strings),
          TextButton(
            key: const Key('auth-back-sign-in'),
            style: _linkStyle,
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
            style: _linkStyle,
            onPressed: _busy ? null : () => _goTo(_AuthStep.signIn),
            child: Text(strings.backToSignIn),
          ),
        ];
      case _AuthStep.magicLink:
        return [
          FilledButton(
            key: const Key('auth-verify-otp'),
            onPressed: _busy ? null : _verifyOtp,
            child: _busyChild(strings.verifyOtp),
          ),
          TextButton(
            style: _linkStyle,
            onPressed: _busy ? null : () => _goTo(_AuthStep.signIn),
            child: Text(strings.backToSignIn),
          ),
        ];
      case _AuthStep.forgotPassword:
        return [
          FilledButton(
            key: const Key('auth-send-reset'),
            onPressed: _busy ? null : _sendPasswordReset,
            child: _busyChild(strings.sendResetLink),
          ),
          TextButton(
            key: const Key('auth-back-sign-in'),
            style: _linkStyle,
            onPressed: _busy ? null : () => _goTo(_AuthStep.signIn),
            child: Text(strings.backToSignIn),
          ),
        ];
      case _AuthStep.forgotPasswordSent:
        return [
          TextButton(
            key: const Key('auth-back-sign-in'),
            style: _linkStyle,
            onPressed: _busy ? null : () => _goTo(_AuthStep.signIn),
            child: Text(strings.backToSignIn),
          ),
        ];
      case _AuthStep.setPassword:
        return [
          FilledButton(
            key: const Key('auth-save-password'),
            onPressed: _busy ? null : _savePassword,
            child: _busyChild(strings.savePassword),
          ),
        ];
    }
  }

  List<Widget> _providers(AppStrings strings) {
    return [
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(child: Divider(color: BrandColors.beige)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              strings.authOrDivider,
              style: const TextStyle(color: BrandColors.bark),
            ),
          ),
          const Expanded(child: Divider(color: BrandColors.beige)),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('auth-google'),
        style: _socialStyle,
        onPressed: _busy ? null : () => _oauth(AuthProvider.google),
        child: Text(strings.continueWithGoogle),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('auth-apple'),
        style: _socialStyle,
        onPressed: _busy ? null : () => _oauth(AuthProvider.apple),
        icon: const Icon(Icons.apple),
        label: Text(strings.continueWithApple),
      ),
    ];
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
