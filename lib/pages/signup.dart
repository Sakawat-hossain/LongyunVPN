import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignUpPage extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SignUpPage({super.key, required this.onBack});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _submitError;

  XboardCommConfig? _config;
  bool _isLoadingConfig = true;
  String? _configError;

  bool _isSendingCode = false;
  String? _sendCodeError;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await xboardApi.getCommConfig();
      setState(() {
        _config = config;
        _isLoadingConfig = false;
      });
    } catch (e) {
      setState(() {
        _configError = e.toString();
        _isLoadingConfig = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final l = context.appLocalizations;
    final email = value?.trim() ?? '';
    if (email.isEmpty) return l.emailRequired;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) return l.emailInvalid;
    final whitelist = _config?.emailWhitelistSuffix ?? const [];
    if (whitelist.isNotEmpty) {
      final domain = email.split('@').last.toLowerCase();
      if (!whitelist.contains(domain)) {
        return l.emailDomainNotAllowed(whitelist.join(', '));
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final l = context.appLocalizations;
    if (value == null || value.isEmpty) return l.passwordRequired;
    if (value.length < 8) return l.passwordTooShort;
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return context.appLocalizations.passwordsDoNotMatch;
    }
    return null;
  }

  String? _validateEmailCode(String? value) {
    if (_config?.isEmailVerify != true) return null;
    if (value == null || value.trim().isEmpty) {
      return context.appLocalizations.verificationCodeRequired;
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
      _startCooldown();
    } catch (e) {
      setState(() => _sendCodeError = e.toString());
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleSignUp() async {
    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // On success, AuthGate reacts to the auth state change and swaps to
    // HomePage automatically — no navigation needed here.
    await ref
        .read(authProvider.notifier)
        .register(
          _emailController.text.trim(),
          _passwordController.text,
          emailCode: _emailCodeController.text.trim(),
          inviteCode: _inviteCodeController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final authState = ref.watch(authProvider);
    final showInviteCode = _config != null;
    final requiresInviteCode = _config?.isInviteForce == true;
    final requiresEmailCode = _config?.isEmailVerify == true;

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
              child: _isLoadingConfig
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.appLocalizations.signUp,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_configError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              context.appLocalizations
                                  .signupConfigError(_configError!),
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                            decoration: InputDecoration(
                              labelText: context.appLocalizations.email,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          if (requiresEmailCode) ...[
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
                                      labelText:
                                          context.appLocalizations.verificationCode,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed:
                                        (_isSendingCode ||
                                            _cooldownSeconds > 0)
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
                                                : context.appLocalizations.sendCode,
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
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            validator: _validatePassword,
                            decoration: InputDecoration(
                              labelText: context.appLocalizations.password,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(
                                    () =>
                                        _obscurePassword = !_obscurePassword,
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
                              labelText: context.appLocalizations.confirmPassword,
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
                          if (showInviteCode) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _inviteCodeController,
                              onFieldSubmitted: (_) => _handleSignUp(),
                              validator: requiresInviteCode
                                  ? (value) => (value == null || value.isEmpty)
                                        ? context
                                              .appLocalizations
                                              .invitationCodeRequired
                                        : null
                                  : null,
                              decoration: InputDecoration(
                                labelText: requiresInviteCode
                                    ? context.appLocalizations.invitationCode
                                    : context
                                          .appLocalizations
                                          .invitationCodeOptional,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                          if (_submitError != null ||
                              authState.error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _submitError ?? authState.error!,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: authState.isLoading
                                ? null
                                : _handleSignUp,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(context.appLocalizations.signUp),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: widget.onBack,
                            child: Text(
                              context.appLocalizations.alreadyHaveAccountSignIn,
                            ),
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
