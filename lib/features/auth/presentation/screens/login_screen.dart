import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_logo.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _ink = Color(0xFF16181D);
  static const Color _muted = Color(0xFF8A9099);
  static const Color _accent = Color(0xFF5B5FEF);
  static const Color _border = Color(0xFFE1E4EA);
  static const Color _fieldFill = Color(0xFFF7F8FA);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (previous, current) => current is AuthAuthenticated,
      listener: (context, state) {
        if (state is AuthAuthenticated) context.go('/dashboard');
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final error = state is AuthFailure ? state.message : null;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: AutofillGroup(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildWordmark(),
                                const SizedBox(height: 76),
                                Text(
                                  'С возвращением',
                                  style: GoogleFonts.manrope(
                                    color: _ink,
                                    fontSize: 30,
                                    height: 1.16,
                                    letterSpacing: -0.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Войдите, чтобы продолжить работу',
                                  style: GoogleFonts.manrope(
                                    color: _muted,
                                    fontSize: 15,
                                    height: 1.45,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                _buildLabel('Email'),
                                const SizedBox(height: 9),
                                _buildEmailField(isLoading),
                                const SizedBox(height: 22),
                                _buildLabel('Пароль'),
                                const SizedBox(height: 9),
                                _buildPasswordField(isLoading),
                                const SizedBox(height: 10),
                                _buildError(error),
                                const SizedBox(height: 10),
                                _buildSubmitButton(isLoading),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordmark() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: AppLogo(height: 25),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: _ink,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildEmailField(bool isLoading) {
    return TextFormField(
      key: const Key('login_email_field'),
      controller: _emailController,
      focusNode: _emailFocus,
      enabled: !isLoading,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const <String>[AutofillHints.email],
      autocorrect: false,
      enableSuggestions: false,
      style: _fieldTextStyle,
      decoration: _fieldDecoration(hintText: 'name@example.com'),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return 'Введите email';
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
          return 'Введите корректный email';
        }
        return null;
      },
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
    );
  }

  Widget _buildPasswordField(bool isLoading) {
    return TextFormField(
      key: const Key('login_password_field'),
      controller: _passwordController,
      focusNode: _passwordFocus,
      enabled: !isLoading,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const <String>[AutofillHints.password],
      style: _fieldTextStyle,
      decoration: _fieldDecoration(
        hintText: 'Введите пароль',
        suffixIcon: IconButton(
          onPressed: isLoading
              ? null
              : () => setState(() => _obscurePassword = !_obscurePassword),
          tooltip: _obscurePassword ? 'Показать пароль' : 'Скрыть пароль',
          icon: Icon(
            _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 20,
          ),
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Введите пароль' : null,
      onFieldSubmitted: (_) {
        if (!isLoading) _submit();
      },
    );
  }

  TextStyle get _fieldTextStyle => GoogleFonts.manrope(
    color: _ink,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.manrope(
        color: _muted,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      suffixIcon: suffixIcon,
      border: border(_border),
      enabledBorder: border(_border),
      disabledBorder: border(_border),
      focusedBorder: border(_accent, 1.5),
      errorBorder: border(const Color(0xFFD14B4B)),
      focusedErrorBorder: border(const Color(0xFFD14B4B), 1.5),
      errorStyle: GoogleFonts.manrope(
        color: const Color(0xFFB33A3A),
        fontSize: 12,
        height: 1.35,
      ),
    );
  }

  Widget _buildError(String? error) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: error == null
          ? const SizedBox(key: ValueKey<String>('empty'), height: 38)
          : Semantics(
              key: const ValueKey<String>('error'),
              liveRegion: true,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 38),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F4),
                  border: Border.all(color: const Color(0xFFF2D4D0)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  error,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFFA53C35),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        key: const Key('login_submit_button'),
        onPressed: isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: const Color(0xFFA7A9F5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Войти'),
      ),
    );
  }
}
