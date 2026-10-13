// lib/widgets/glass_container.dart
// Glassmorphism container using BackdropFilter — premium frosted-glass effect.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bella_music/theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = 12,
    this.opacity = 0.12,
    this.border = true,
    this.padding,
    this.height,
    this.width,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final bool border;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          width: width,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border
                ? Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A gradient-bordered card — used for service tiles and feature cards.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: gradient ??
              const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
          border: Border.all(
            color: AppTheme.accentViolet.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentViolet.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
