import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/auth_token_storage.dart';

/// Splash screen shown on app startup.
///
/// Minimalist entrance: a subtle fade + upward slide on the wordmark,
/// then automatically navigates to the home route.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  static const Duration _animationDuration = Duration(milliseconds: 900);
  static const Duration _navigationDelay = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      Future<void>.delayed(_navigationDelay),
      _readToken(),
    ]);
    if (!mounted) return;
    final token = results[1] as String?;
    if (token == null || token.trim().isEmpty) {
      context.go('/login');
      return;
    }

    final isValid = await _validateStoredToken();
    if (!mounted) return;
    context.go(isValid ? '/dashboard' : '/login');
  }

  Future<String?> _readToken() async {
    try {
      return await sl<AuthTokenStorage>().read();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _validateStoredToken() async {
    try {
      await sl<Dio>().get<dynamic>('users/me');
      return true;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) return false;

      // Keep a locally authenticated session during temporary network errors.
      // Normal screen-level retry states can then recover when connectivity is
      // restored without forcing the user to enter credentials again.
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value.clamp(0.0, 1.0),
              child: FractionalTranslation(
                translation: _slideAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minimal wordmark with a single accent dot — no icons/boxes.
              RichText(
                text: TextSpan(
                  style: GoogleFonts.manrope(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                  children: const [
                    TextSpan(text: 'jospar'),
                    TextSpan(
                      text: 'bee',
                      style: TextStyle(color: Color(0xFF5B5FEF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Work, organized.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9AA0A6),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
