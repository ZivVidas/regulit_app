import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Full-screen splash shown while the app restores the auth session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  // Deep navy palette — matches the blue logo tones
  static const _bg      = Color(0xFF04091A);
  static const _grad1   = Color(0xFF06102A);
  static const _grad2   = Color(0xFF0A1840);
  static const _accent  = Color(0xFF0078D4); // Azure Blue (Kinetic Corporate)
  static const _accentL = Color(0xFF58C2F0); // Light blue

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bg, _grad1, _grad2],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative glow circles ─────────────────────────
            Positioned(
              top: -100, right: -100,
              child: _GlowCircle(size: 320, color: _accent, opacity: 0.07)
                  .animate().scale(
                    begin: const Offset(0.5, 0.5),
                    end:   const Offset(1.0, 1.0),
                    duration: 1400.ms,
                    curve: Curves.easeOut,
                  ),
            ),
            Positioned(
              bottom: -80, left: -80,
              child: _GlowCircle(size: 260, color: _accentL, opacity: 0.05)
                  .animate().scale(
                    begin: const Offset(0.4, 0.4),
                    end:   const Offset(1.0, 1.0),
                    duration: 1600.ms,
                    curve: Curves.easeOut,
                  ),
            ),
            Positioned(
              top: 160, left: -40,
              child: _GlowCircle(size: 140, color: _accent, opacity: 0.04),
            ),

            // ── Centre content ──────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // GIF logo with outer glow ring
                  _GifLogo()
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end:   const Offset(1.0, 1.0),
                        duration: 700.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: 500.ms),

                  const SizedBox(height: 36),

                  // Tagline
                  Text(
                    'Compliance that protects.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.4,
                    ),
                  )
                      .animate(delay: 450.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2, end: 0, duration: 400.ms),

                  const SizedBox(height: 72),

                  // Progress bar
                  _ProgressBar()
                      .animate(delay: 600.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.3, end: 0, duration: 400.ms),
                ],
              ),
            ),

            // ── Bottom brand line ───────────────────────────────
            Positioned(
              bottom: 36, left: 0, right: 0,
              child: Text(
                '© 2025 Regulit · Privacy by design',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              )
                  .animate(delay: 800.ms)
                  .fadeIn(duration: 600.ms),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GIF logo with soft blue glow ────────────────────────────────
class _GifLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow halo
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF0078D4).withOpacity(0.18),
                const Color(0xFF0078D4).withOpacity(0.0),
              ],
            ),
          ),
        ),
        // Subtle ring border
        Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF58C2F0).withOpacity(0.14),
              width: 1.5,
            ),
          ),
        ),
        // GIF
        Image.asset(
          'assets/images/regulit_shine.gif',
          width: 148,
          height: 148,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 2800.ms,
          curve: Curves.easeInOut,
          builder: (_, v, child) => Transform.scale(
            scale: 1.0 + v * 0.03,
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
            duration: const Duration(milliseconds: 2400),
            curve: Curves.easeInOut,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF0078D4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading…',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
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

// ── Decorative glow circle ──────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _GlowCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}
