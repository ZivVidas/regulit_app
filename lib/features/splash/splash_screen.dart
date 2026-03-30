import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Full-screen splash shown while the app restores the auth session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  static const _grad1 = Color(0xFF0D3328);
  static const _grad2 = Color(0xFF1B4D3E);
  static const _grad3 = Color(0xFF2E7D5C);
  static const _green = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_grad1, _grad2, _grad3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative background circles ───────────────────
            Positioned(
              top: -80, right: -80,
              child: _GlowCircle(size: 300, opacity: 0.06)
                  .animate().scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1.0, 1.0),
                    duration: 1200.ms,
                    curve: Curves.easeOut,
                  ),
            ),
            Positioned(
              bottom: -60, left: -60,
              child: _GlowCircle(size: 240, opacity: 0.05)
                  .animate().scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
                    duration: 1400.ms,
                    curve: Curves.easeOut,
                  ),
            ),
            Positioned(
              top: 140, left: -30,
              child: _GlowCircle(size: 120, opacity: 0.04),
            ),

            // ── Centre content ──────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shield icon with glow
                  _LogoBadge()
                      .animate()
                      .scale(
                        begin: const Offset(0.4, 0.4),
                        end: const Offset(1.0, 1.0),
                        duration: 700.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),

                  // App name
                  const Text(
                    'Regulit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1,
                    ),
                  )
                      .animate(delay: 250.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.25, end: 0, duration: 500.ms, curve: Curves.easeOut),

                  const SizedBox(height: 10),

                  // Tagline
                  Text(
                    'Compliance that protects.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  )
                      .animate(delay: 400.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2, end: 0, duration: 400.ms),

                  const SizedBox(height: 72),

                  // Progress bar
                  _ProgressBar()
                      .animate(delay: 500.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.3, end: 0, duration: 400.ms),
                ],
              ),
            ),

            // ── Bottom version/brand line ───────────────────────
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Text(
                '© 2025 Regulit · Privacy by design',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              )
                  .animate(delay: 700.ms)
                  .fadeIn(duration: 600.ms),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo badge with layered glow ────────────────────────────────
class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4ADE80).withOpacity(0.08),
          ),
        ),
        // Middle ring
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
        ),
        // Inner badge
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D5C), Color(0xFF16A34A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withOpacity(0.45),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 2400.ms,
          curve: Curves.easeInOut,
          builder: (_, v, child) => Transform.scale(
            scale: 1.0 + v * 0.04,
            child: child,
          ),
        );
  }
}

// ── Animated progress bar ────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 2200),
            curve: Curves.easeInOut,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading…',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 800.ms, curve: Curves.easeInOut)
              .then()
              .fadeOut(duration: 800.ms, curve: Curves.easeInOut),
        ],
      ),
    );
  }
}

// ── Decorative circle ───────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _GlowCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
