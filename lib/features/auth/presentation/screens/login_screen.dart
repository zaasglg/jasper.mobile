import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _ink = Color(0xFF20212B);
  static const Color _muted = Color(0xFF737587);
  static const Color _accent = AppColors.accent;
  static const Color _border = Color(0xFFE1E2EA);
  static const Color _fieldFill = Color(0xFFFAFAFC);
  static const Color _canvas = Color(0xFFF7F7FC);

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
          backgroundColor: _canvas,
          body: SafeArea(
            child: AutofillGroup(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 48 : 20,
                      vertical: isWide ? 40 : 20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - (isWide ? 80 : 40),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: isWide
                              ? Row(
                                  children: [
                                    const Expanded(child: _BrandStory()),
                                    const SizedBox(width: 72),
                                    SizedBox(
                                      width: 440,
                                      child: _buildLoginCard(
                                        isLoading: isLoading,
                                        error: error,
                                        showLogo: false,
                                      ),
                                    ),
                                  ],
                                )
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  child: _buildLoginCard(
                                    isLoading: isLoading,
                                    error: error,
                                    showLogo: true,
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

  Widget _buildLoginCard({
    required bool isLoading,
    required String? error,
    required bool showLogo,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F102A),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x0A0F102A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLogo) ...[
              const AppLogo(height: 27),
              const SizedBox(height: 42),
            ],
            Text(
              'С возвращением',
              style: GoogleFonts.manrope(
                color: _ink,
                fontSize: 30,
                height: 1.15,
                letterSpacing: -0.9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Войдите в рабочее пространство JosparBee',
              style: GoogleFonts.manrope(
                color: _muted,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            _buildLabel('Рабочая почта'),
            const SizedBox(height: 8),
            _buildEmailField(isLoading),
            const SizedBox(height: 20),
            _buildLabel('Пароль'),
            const SizedBox(height: 8),
            _buildPasswordField(isLoading),
            const SizedBox(height: 8),
            _buildError(error),
            const SizedBox(height: 8),
            _buildSubmitButton(isLoading),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.lockKeyhole, size: 14, color: _muted),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Ваши данные защищены',
                    style: GoogleFonts.manrope(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: GoogleFonts.manrope(
      color: _ink,
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
  );

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
      decoration: _fieldDecoration(
        hintText: 'name@company.com',
        prefixIcon: LucideIcons.mail,
      ),
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
        prefixIcon: LucideIcons.lock,
        suffixIcon: IconButton(
          onPressed: isLoading
              ? null
              : () => setState(() => _obscurePassword = !_obscurePassword),
          tooltip: _obscurePassword ? 'Показать пароль' : 'Скрыть пароль',
          icon: Icon(
            _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 19,
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
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
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
        color: const Color(0xFF9A9CAB),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, size: 19),
      prefixIconColor: const Color(0xFF77798B),
      suffixIcon: suffixIcon,
      suffixIconColor: const Color(0xFF686A78),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(_border),
      enabledBorder: border(_border),
      disabledBorder: border(_border),
      focusedBorder: border(_accent, 1.6),
      errorBorder: border(const Color(0xFFD14B4B)),
      focusedErrorBorder: border(const Color(0xFFD14B4B), 1.6),
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
          ? const SizedBox(key: ValueKey<String>('empty'), height: 36)
          : Semantics(
              key: const ValueKey<String>('error'),
              liveRegion: true,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 36),
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
            fontWeight: FontWeight.w800,
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Войти'),
                  SizedBox(width: 9),
                  Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
      ),
    );
  }
}

class _BrandStory extends StatelessWidget {
  const _BrandStory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(height: 32),
          const SizedBox(height: 72),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFECEBFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'ВСЯ РАБОТА — В ОДНОМ МЕСТЕ',
              style: GoogleFonts.manrope(
                color: AppColors.accent,
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Планы становятся\nрезультатами.',
            style: GoogleFonts.manrope(
              color: _LoginScreenState._ink,
              fontSize: 48,
              height: 1.08,
              letterSpacing: -2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Управляйте задачами, командой и проектами\nв едином рабочем пространстве JosparBee.',
            style: GoogleFonts.manrope(
              color: _LoginScreenState._muted,
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 36),
          const Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _Feature(icon: LucideIcons.circleCheck, text: 'Задачи'),
              _Feature(icon: LucideIcons.layoutDashboard, text: 'Проекты'),
              _Feature(icon: LucideIcons.users, text: 'Команда'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.manrope(
            color: _LoginScreenState._ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
