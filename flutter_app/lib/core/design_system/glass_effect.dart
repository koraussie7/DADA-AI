import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class GlassStyle {
  final Color? color;
  final double opacity;
  final double blur;
  final double borderRadius;
  final BorderSide? border;
  final List<BoxShadow>? shadows;

  const GlassStyle({
    this.color,
    this.opacity = 0.1,
    this.blur = 12,
    this.borderRadius = 16,
    this.border,
    this.shadows,
  });

  BoxDecoration decoration() => BoxDecoration(
    color: (color ?? AppColors.surfaceLight).withOpacity(opacity),
    borderRadius: BorderRadius.circular(borderRadius),
    border: border ?? Border.all(color: Colors.white.withOpacity(0.08)),
  );

  static const card = GlassStyle();
  static const cardElevated = GlassStyle(
    opacity: 0.15, blur: 20, borderRadius: 20,
    shadows: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
  );
  static const bubble = GlassStyle(
    opacity: 0.08, blur: 8, borderRadius: 12,
  );
  static const hero = GlassStyle(
    opacity: 0.12, blur: 24, borderRadius: 24,
  );
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final GlassStyle style;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key, required this.child,
    this.style = const GlassStyle(),
    this.padding, this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: style.decoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(style.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: style.blur, sigmaY: style.blur),
          child: child,
        ),
      ),
    );
  }
}
