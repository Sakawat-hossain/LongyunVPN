import 'dart:async';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/state.dart';
import 'package:flutter/material.dart';

/// Password reset, from inside the app.
///
/// The panel has had `/passport/auth/forget` all along and the website offers
/// it; the app did not, so anyone who forgot their password had to be told to
/// go and find the website — at the one moment they cannot get in.
///
/// The code is the same one sign-up sends. The panel's send-code endpoint takes
/// only an address and does not care what the code will be used for, so this
/// reuses it unchanged.
class ResetPasswordPage extends StatefulWidget {
  /// Returns to the sign-in form. AuthGate swaps these pages with local state
  /// rather than Navigator routes — see the note there about the black screen
  /// on Windows — so leaving is the parent's job, not a pop.
  final VoidCallback onBack;

  const ResetPasswordPage({super.key, required this.onBack});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isSubmitting = false;
  String? _submitError;

  bool _isSendingCode = false;
  String? _sendCodeError;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _emailCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final l = context.appLocalizations;
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l.emailRequired;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return l.emailInvalid;
    }
    return null;
  }

  String? _validateEmailCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.appLocalizations.verificationCodeRequired;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final l = context.appLocalizations;
    if (value == null || value.isEmpty) return l.passwordRequired;
    // The panel rejects anything shorter, and it does so only after the user
    // has waited for a code and filled the whole form.
    if (value.length < 8) return l.passwordTooShort;
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return context.appLocalizations.passwordsDoNotMatch;
    }
    return null;
  }

  Future<void> _handleSendCode() async {
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _sendCodeError = emailError);
      return;
    }
    setState(() {
      _isSendingCode = true;
      _sendCodeError = null;
    });
    try {
      await xboardApi.sendEmailVerifyCode(_emailController.text.trim());
      if (mounted) _startCooldown();
    } catch (e) {
      // Logged as well as shown. A code that never arrives is the whole failure
      // mode of this screen, and the banner is gone as soon as the screen is.
      commonPrint.log(
        'reset: send verification code failed: $e',
        logLevel: LogLevel.warning,
      );
      if (mounted) setState(() => _sendCodeError = e.toString());
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  void _startCooldown() {
    // The panel rate-limits per address and answers "already sent, try again
    // later". Holding the button matches what the server will allow instead of
    // letting people earn that error.
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      await xboardApi.resetPassword(
        email: _emailController.text.trim(),
        emailCode: _emailCodeController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Back to sign-in rather than signing them in: the panel's forget
      // endpoint answers with a bare success and no token, so there is nothing
      // to log in with, and typing the new password once confirms it took.
      globalState.showNotifier(context.appLocalizations.resetPasswordSuccess);
      widget.onBack();
    } catch (e) {
      commonPrint.log('reset password failed: $e', logLevel: LogLevel.warning);
      if (mounted) setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.resetPassword,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.resetPasswordSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      decoration: InputDecoration(
                        labelText: l.email,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailCodeController,
                            keyboardType: TextInputType.number,
                            validator: _validateEmailCode,
                            decoration: InputDecoration(
                              labelText: l.verificationCode,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: (_isSendingCode || _cooldownSeconds > 0)
                                ? null
                                : _handleSendCode,
                            child: _isSendingCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _cooldownSeconds > 0
                                        ? '${_cooldownSeconds}s'
                                        : l.sendCode,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (_sendCodeError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _sendCodeError!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      decoration: InputDecoration(
                        labelText: l.newPassword,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      validator: _validateConfirmPassword,
                      decoration: InputDecoration(
                        labelText: l.confirmPassword,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ),
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submitError!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l.resetPassword),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: widget.onBack,
                      child: Text(l.backToSignIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
