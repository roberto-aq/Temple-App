import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';

/// Entrar o crear cuenta con correo y contraseña.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) => setState(() {
    _signUp = signUp;
    _error = null;
    _info = null;
  });

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return setState(() => _error = 'Escribe un correo válido.');
    }
    if (password.isEmpty) {
      return setState(() => _error = 'Escribe tu contraseña.');
    }
    if (_signUp && password.length < 6) {
      return setState(
        () => _error = 'La contraseña debe tener al menos 6 caracteres.',
      );
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_signUp) {
        final res = await auth.signUp(email: email, password: password);
        // Con confirmación por correo activada, la cuenta queda sin sesión hasta confirmar.
        if (res.session == null && mounted) {
          setState(() {
            _signUp = false;
            _info =
                'Te enviamos un correo a $email. Abre el enlace para confirmar la cuenta y después entra aquí.';
          });
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
      // Con sesión abierta, AuthGate cambia a la app.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _authMessage(e));
    } catch (e) {
      if (mounted) setState(() => _error = _offlineMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _offlineMessage =
      'No se pudo conectar. Revisa tu internet e inténtalo de nuevo.';

  String _authMessage(AuthException e) {
    if (e is AuthRetryableFetchException) return _offlineMessage;
    return switch (e.code) {
      'invalid_credentials' => 'Correo o contraseña incorrectos.',
      'email_not_confirmed' =>
        'Aún no confirmas tu correo. Abre el enlace que te enviamos.',
      'user_already_exists' || 'email_exists' =>
        'Ya hay una cuenta con ese correo. Entra con tu contraseña.',
      'weak_password' =>
        'Esa contraseña es muy débil. Prueba con una más larga.',
      'email_address_invalid' => 'Ese correo no es válido.',
      'over_email_send_rate_limit' =>
        'Se enviaron demasiados correos. Espera unos minutos e inténtalo otra vez.',
      'over_request_rate_limit' => 'Demasiados intentos. Espera un momento.',
      'signup_disabled' || 'email_provider_disabled' =>
        'El registro con correo está desactivado en el servidor.',
      _ => e.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const TempleLogo(size: 52),
                        const SizedBox(width: 12),
                        Text(
                          'TEMPLE',
                          style: AppText.display(
                            56,
                            height: 0.9,
                            letterSpacing: 5.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Fuerza que se templa, sesión a sesión.',
                      style: AppText.body(16, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 44),
                    SectionLabel(_signUp ? 'Nueva cuenta' : 'Tu cuenta'),
                    const SizedBox(height: 2),
                    ScreenTitle(_signUp ? 'Crear cuenta' : 'Entrar'),
                    const SizedBox(height: 20),
                    _Field(
                      label: 'Correo',
                      hint: 'tu@correo.com',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'Contraseña',
                      hint: _signUp ? 'Mínimo 6 caracteres' : '••••••••',
                      controller: _password,
                      obscure: !_showPassword,
                      autofillHints: [
                        _signUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _submit(),
                      suffix: IconButton(
                        tooltip: _showPassword
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: AppIcon(
                          _showPassword ? AppIcons.eyeOff : AppIcons.eye,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _Message(_error!, error: true),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 14),
                      _Message(_info!),
                    ],
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: _busy ? 0.6 : 1,
                      child: PrimaryButton(
                        label: _busy
                            ? (_signUp ? 'Creando cuenta…' : 'Entrando…')
                            : (_signUp ? 'Crear cuenta' : 'Entrar'),
                        onTap: _busy ? null : _submit,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Pressable(
                      onTap: _busy ? null : () => _setMode(!_signUp),
                      color: Colors.transparent,
                      radius: 12,
                      height: 48,
                      child: Center(
                        child: Text.rich(
                          TextSpan(
                            text: _signUp
                                ? '¿Ya tienes cuenta? '
                                : '¿No tienes cuenta? ',
                            style: AppText.body(
                              15,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              TextSpan(
                                text: _signUp ? 'Entrar' : 'Crear una',
                                style: AppText.body(
                                  15,
                                  weight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(label.toUpperCase(), style: AppText.label()),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: !obscure,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: AppText.body(18, weight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body(18, color: AppColors.textDisabled),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: border(AppColors.borderStrong),
              focusedBorder: border(AppColors.textSecondary),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aviso bajo el formulario: error (coral) o información (acento).
class _Message extends StatelessWidget {
  const _Message(this.text, {this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? AppColors.alertSoft(0.08) : AppColors.accentSoft(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: error ? const Color(0xFF5A3A32) : AppColors.accentSoft(0.35),
          ),
        ),
        child: Text(
          text,
          style: AppText.body(14, color: AppColors.textSoft, height: 1.4),
        ),
      ),
    );
  }
}
