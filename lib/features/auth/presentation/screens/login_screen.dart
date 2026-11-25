import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  static Color _ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.of(context).ink
      : const Color(0xFF20212B);
  static Color _muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.of(context).muted
      : const Color(0xFF737587);
  static const Color _accent = AppColors.accent;
  static Color _fieldFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.of(context).subtleSurface
      : const Color(0xFFFAFAFC);
  static Color _canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.of(context).canvas
      : Colors.white;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  static const String _googleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M21.6 12.23c0-.71-.06-1.4-.18-2.06H12v3.9h5.38a4.6 4.6 0 0 1-2 3.02v2.53h3.24c1.9-1.75 2.98-4.33 2.98-7.39Z"/>
  <path fill="#34A853" d="M12 22c2.7 0 4.97-.9 6.62-2.38l-3.24-2.53c-.9.6-2.05.96-3.38.96-2.61 0-4.82-1.76-5.61-4.13H3.04v2.61A10 10 0 0 0 12 22Z"/>
  <path fill="#FBBC05" d="M6.39 13.92A6.01 6.01 0 0 1 6.08 12c0-.67.12-1.32.31-1.92V7.47H3.04A10 10 0 0 0 2 12c0 1.63.39 3.17 1.04 4.53l3.35-2.61Z"/>
  <path fill="#EA4335" d="M12 5.95c1.47 0 2.79.5 3.83 1.5l2.87-2.87A9.62 9.62 0 0 0 12 2a10 10 0 0 0-8.96 5.47l3.35 2.61C7.18 7.71 9.39 5.95 12 5.95Z"/>
</svg>
''';

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

  Future<void> _signInWithGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await context.read<AuthCubit>().loginWithGoogle();
  }

  Future<void> _signInWithApple() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await context.read<AuthCubit>().loginWithApple();
  }

  bool get _supportsNativeAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

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

        return FTheme(
          data: FThemeData(
            touch: true,
            colors:
                (Theme.of(context).brightness == Brightness.dark
                        ? FTheme.neutral.dark.touch.colors
                        : FTheme.neutral.light.touch.colors)
                    .copyWith(
                      primary: AppColors.accent,
                      primaryForeground: Colors.white,
                    ),
          ),
          child: Scaffold(
            backgroundColor: _canvas(context),
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
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLogo) ...[
              const AppLogo(height: 24),
              const SizedBox(height: AppSpacing.lg * 2),
            ],
            Text(
              tr(context, 'Войти в JosparBee'),
              style: GoogleFonts.inter(
                color: _ink(context),
                fontSize: 26,
                height: 1.15,
                letterSpacing: -0.9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr(context, 'Ваши задачи, проекты и команда — рядом.'),
              style: GoogleFonts.inter(
                color: _muted(context),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            _buildGoogleButton(isLoading),
            if (_supportsNativeAppleSignIn) ...[
              const SizedBox(height: 12),
              _buildAppleButton(isLoading),
            ],
            const SizedBox(height: 22),
            const _LoginDivider(),
            const SizedBox(height: 22),
            _buildLabel(tr(context, 'Рабочая почта')),
            const SizedBox(height: 8),
            _buildEmailField(isLoading),
            const SizedBox(height: 20),
            _buildLabel(tr(context, 'Пароль')),
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
                Icon(
                  LucideIcons.lockKeyhole,
                  size: AppIconSizes.standard,
                  color: _muted(context),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    tr(context, 'Ваши данные защищены'),
                    style: GoogleFonts.inter(
                      color: _muted(context),
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
    style: GoogleFonts.inter(
      color: _ink(context),
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _buildGoogleButton(bool isLoading) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: FButton(
        key: const Key('google_login_button'),
        variant: FButtonVariant.outline,
        onPress: isLoading ? null : _signInWithGoogle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
              _googleLogo,
              width: 20,
              height: 20,
              semanticsLabel: 'Google',
            ),
            const SizedBox(width: 11),
            Text(tr(context, 'Войти через Google')),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleButton(bool isLoading) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: FButton(
        key: const Key('apple_login_button'),
        variant: FButtonVariant.outline,
        onPress: isLoading ? null : _signInWithApple,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apple, size: 22, color: Colors.black),
            SizedBox(width: 11),
            Text(tr(context, 'Войти через Apple')),
          ],
        ),
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
      decoration: _fieldDecoration(
        hintText: 'name@company.com',
        prefixIcon: LucideIcons.mail,
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return tr(context, 'Введите email');
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
          return tr(context, 'Введите корректный email');
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
          tooltip: _obscurePassword
              ? tr(context, 'Показать пароль')
              : tr(context, 'Скрыть пароль'),
          icon: Icon(
            _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
            size: AppIconSizes.standard,
          ),
        ),
      ),
      validator: (value) => (value == null || value.isEmpty)
          ? tr(context, 'Введите пароль')
          : null,
      onFieldSubmitted: (_) {
        if (!isLoading) _submit();
      },
    );
  }

  TextStyle get _fieldTextStyle => GoogleFonts.inter(
    color: _ink(context),
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
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF9A9CAB),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, size: AppIconSizes.standard),
      prefixIconColor: const Color(0xFF77798B),
      suffixIcon: suffixIcon,
      suffixIconColor: const Color(0xFF686A78),
      filled: true,
      fillColor: _fieldFill(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.of(context).border),
      enabledBorder: border(AppColors.of(context).border),
      disabledBorder: border(Colors.transparent),
      focusedBorder: border(_accent),
      errorBorder: border(const Color(0xFFD14B4B)),
      focusedErrorBorder: border(const Color(0xFFD14B4B)),
      errorStyle: GoogleFonts.inter(
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
          ? const SizedBox.shrink(key: ValueKey<String>('empty'))
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
                  style: GoogleFonts.inter(
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
      child: FButton(
        key: const Key('login_submit_button'),
        onPress: isLoading ? null : _submit,
        child: isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr(context, 'Войти')),
                  SizedBox(width: 9),
                  Icon(LucideIcons.arrowRight, size: AppIconSizes.standard),
                ],
              ),
      ),
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(child: Divider(color: Color(0xFFE8E9EF), height: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            tr(context, 'или по рабочей почте'),
            style: GoogleFonts.inter(
              color: _LoginScreenState._muted(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        line,
      ],
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
              tr(context, 'ВСЯ РАБОТА — В ОДНОМ МЕСТЕ'),
              style: GoogleFonts.inter(
                color: AppColors.accent,
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            tr(context, 'Планы становятся\nрезультатами.'),
            style: GoogleFonts.inter(
              color: _LoginScreenState._ink(context),
              fontSize: 48,
              height: 1.08,
              letterSpacing: -2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            tr(
              context,
              'Управляйте задачами, командой и проектами\nв едином рабочем пространстве JosparBee.',
            ),
            style: GoogleFonts.inter(
              color: _LoginScreenState._muted(context),
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
        Icon(icon, size: AppIconSizes.standard, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            color: _LoginScreenState._ink(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
