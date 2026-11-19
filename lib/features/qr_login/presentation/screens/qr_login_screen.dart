import '../../../../core/widgets/app_snack_bar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../cubit/qr_login_cubit.dart';
import '../cubit/qr_login_state.dart';
import '../qr_login_strings.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({
    super.key,
    required this.accountName,
    required this.email,
  });
  final String accountName;
  final String email;

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _scanner = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final qrState = context.read<QrLoginCubit>().state;
    if (state == AppLifecycleState.resumed && qrState is QrLoginReady) {
      unawaited(_scanner.start());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(_scanner.stop());
    }
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handling = true;
    await _scanner.stop();
    if (mounted) await context.read<QrLoginCubit>().scan(raw);
  }

  Future<void> _leave() async {
    if (context.read<QrLoginCubit>().state is QrLoginApproving) return;
    unawaited(context.read<QrLoginCubit>().reject());
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = QrLoginStrings.of(context);
    return PopScope(
      canPop: context.watch<QrLoginCubit>().state is! QrLoginApproving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(context.read<QrLoginCubit>().reject());
      },
      child: BlocConsumer<QrLoginCubit, QrLoginState>(
        listener: (context, state) {
          if (state is QrLoginReady) {
            _handling = false;
            unawaited(_scanner.start());
          }
          if (state is QrLoginSessionExpired) context.go('/login');
          if (state is QrLoginApproved) {
            ScaffoldMessenger.of(context).showSnackBar(
              appSnackBar(
                context: context,
                tone: AppSnackBarTone.success,
                content: Text(strings.approved),
              ),
            );
            Future<void>.delayed(const Duration(milliseconds: 700), () {
              if (mounted) this.context.pop();
            });
          }
        },
        builder: (context, state) => Scaffold(
          backgroundColor: const Color(0xFFF7F7FB),
          appBar: AppBar(
            title: Text(strings.title),
            leading: IconButton(
              onPressed: _leave,
              icon: const Icon(LucideIcons.arrowLeft),
            ),
          ),
          body: switch (state) {
            QrLoginConfirmation confirmation => _confirmation(
              context,
              strings,
              confirmation,
              false,
            ),
            QrLoginApproving approving => _confirmation(
              context,
              strings,
              QrLoginConfirmation(
                details: approving.details,
                remaining: approving.details.expiresAt.difference(
                  DateTime.now(),
                ),
              ),
              true,
            ),
            QrLoginApproved() => _success(strings),
            QrLoginSessionExpired() => const Center(
              child: CircularProgressIndicator(),
            ),
            _ => _scannerView(context, strings, state),
          },
        ),
      ),
    );
  }

  Widget _scannerView(
    BuildContext context,
    QrLoginStrings strings,
    QrLoginState state,
  ) {
    final errorMessage = state is QrLoginReady ? state.message : null;

    return ColoredBox(
      color: const Color(0xFF15151A),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = (constraints.maxWidth - 64).clamp(220.0, 304.0);
          final frameTop = (constraints.maxHeight * .22).clamp(72.0, 170.0);
          final frame = Rect.fromLTWH(
            (constraints.maxWidth - frameSize) / 2,
            frameTop,
            frameSize,
            frameSize,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _scanner,
                onDetect: _detected,
                errorBuilder: (context, error) {
                  final denied =
                      error.errorCode ==
                      MobileScannerErrorCode.permissionDenied;
                  return _CameraError(
                    message: denied
                        ? strings.cameraDenied
                        : strings.cameraUnavailable,
                  );
                },
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(frame: frame),
                ),
              ),
              Positioned(
                top: frame.bottom + 28,
                left: 32,
                right: 32,
                child: Column(
                  children: [
                    Text(
                      errorMessage == null
                          ? strings.scanHint
                          : strings.error(errorMessage),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: context.read<QrLoginCubit>().retryScanning,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1D1B24),
                        ),
                        child: Text(strings.retry),
                      ),
                    ],
                  ],
                ),
              ),
              if (state is QrLoginScanning)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _confirmation(
    BuildContext context,
    QrLoginStrings strings,
    QrLoginConfirmation state,
    bool busy,
  ) {
    final seconds = state.remaining.inSeconds.clamp(0, 120);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          LucideIcons.monitorCheck,
          size: 56,
          color: Color(0xFF6D5FE0),
        ),
        const SizedBox(height: 18),
        Text(
          strings.allowTitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 28),
        _info(strings.account, '${widget.accountName}\n${widget.email}'),
        _info(strings.device, state.details.deviceInfo),
        _info(strings.ip, state.details.ipAddress),
        _info(strings.expires, '$seconds сек.'),
        if (state.message != null) ...[
          const SizedBox(height: 4),
          Text(
            strings.error(state.message!),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC44E58)),
          ),
        ],
        if (state.expired) ...[
          const SizedBox(height: 12),
          Text(
            strings.expired,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC44E58)),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('qr_login_approve_button'),
          onPressed: busy || state.expired
              ? null
              : context.read<QrLoginCubit>().approve,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.allow),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : _leave,
          child: Text(strings.cancel),
        ),
      ],
    );
  }

  Widget _info(String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF858297), fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _success(QrLoginStrings strings) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.circleCheck, size: 72, color: Color(0xFF3A9B68)),
        const SizedBox(height: 18),
        Text(
          strings.approved,
          style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF222229),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cameraOff, color: Colors.white70, size: 34),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(28)));
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      framePath,
    );
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: .58),
    );

    const cornerLength = 34.0;
    const radius = 28.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final cornerPath = Path()
      ..moveTo(frame.left, frame.top + cornerLength)
      ..lineTo(frame.left, frame.top + radius)
      ..quadraticBezierTo(frame.left, frame.top, frame.left + radius, frame.top)
      ..lineTo(frame.left + cornerLength, frame.top)
      ..moveTo(frame.right - cornerLength, frame.top)
      ..lineTo(frame.right - radius, frame.top)
      ..quadraticBezierTo(
        frame.right,
        frame.top,
        frame.right,
        frame.top + radius,
      )
      ..lineTo(frame.right, frame.top + cornerLength)
      ..moveTo(frame.right, frame.bottom - cornerLength)
      ..lineTo(frame.right, frame.bottom - radius)
      ..quadraticBezierTo(
        frame.right,
        frame.bottom,
        frame.right - radius,
        frame.bottom,
      )
      ..lineTo(frame.right - cornerLength, frame.bottom)
      ..moveTo(frame.left + cornerLength, frame.bottom)
      ..lineTo(frame.left + radius, frame.bottom)
      ..quadraticBezierTo(
        frame.left,
        frame.bottom,
        frame.left,
        frame.bottom - radius,
      )
      ..lineTo(frame.left, frame.bottom - cornerLength);
    canvas.drawPath(cornerPath, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
