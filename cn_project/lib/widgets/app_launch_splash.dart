import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLaunchSplash extends StatefulWidget {
  final Widget destination;

  const AppLaunchSplash({super.key, required this.destination});

  @override
  State<AppLaunchSplash> createState() => _AppLaunchSplashState();
}

class _AppLaunchSplashState extends State<AppLaunchSplash>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _linesController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    _linesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 1650), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, __, ___) => widget.destination,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _linesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _linesController,
            builder: (context, child) {
              return CustomPaint(
                painter: _MovingLinesPainter(progress: _linesController.value),
              );
            },
          ),
          Center(
            child: FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.0).animate(_logoScale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'app-logo-hero',
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.nfc_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'NFC Shuttle Pay',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovingLinesPainter extends CustomPainter {
  final double progress;

  _MovingLinesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final lines = [
      _LineDef(0.18, 140, 0.07, 0.55, phase: 0.00),
      _LineDef(0.32, 180, -0.06, 0.48, phase: 0.22),
      _LineDef(0.46, 120, 0.08, 0.50, phase: 0.41),
      _LineDef(0.64, 160, -0.05, 0.43, phase: 0.63),
      _LineDef(0.78, 130, 0.07, 0.4, phase: 0.81),
    ];

    for (final line in lines) {
      final y = size.height * line.yFactor;
      final travel = size.width * (0.16 + line.speed.abs());
      final phase = ((progress + line.phase) % 1.0);
      final xBase = size.width * 0.5 + (phase - 0.5) * travel * line.speed.sign;

      final paint = Paint()
        ..color = AppColors.border.withValues(alpha: line.opacity)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2;

      final x1 = (xBase - line.length).clamp(0.0, size.width);
      final x2 = (xBase + line.length).clamp(0.0, size.width);
      canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);

      final pulse = 0.4 + 0.6 * math.sin((phase * math.pi * 2));
      final dotPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.12 * pulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(xBase.clamp(0.0, size.width), y), 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MovingLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LineDef {
  final double yFactor;
  final double length;
  final double speed;
  final double opacity;
  final double phase;

  const _LineDef(
    this.yFactor,
    this.length,
    this.speed,
    this.opacity, {
    this.phase = 0,
  });
}
