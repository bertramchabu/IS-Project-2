import 'package:flutter/material.dart';

import 'web_safe_backdrop_blur.dart';

class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.9),
          radius: 1.45,
          colors: [Color(0xFF14233B), Color(0xFF090E18), Color(0xFF060A12)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -130,
            top: -150,
            child: _AmbientGlow(
              size: 360,
              color: const Color(0xFF00D9FF).withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            right: -180,
            bottom: -210,
            child: _AmbientGlow(
              size: 440,
              color: const Color(0xFF8257FF).withValues(alpha: 0.07),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final Color? borderColor;
  final double blurSigma;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 16,
    this.tint,
    this.borderColor,
    this.blurSigma = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: WebSafeBackdropBlur(
        sigma: blurSigma,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? const Color(0xFF152033)).withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x1200D9FF),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
