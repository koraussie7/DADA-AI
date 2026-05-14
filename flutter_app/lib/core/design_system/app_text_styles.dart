import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'Inter';

  static TextStyle headlineLarge() => const TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle headlineMedium({Color? color}) => TextStyle(
    fontSize: 22, fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary,
  );
  static TextStyle titleLarge() => const TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static TextStyle titleMedium({Color? color}) => TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500, color: color ?? AppColors.textPrimary,
  );
  static TextStyle bodyLarge({Color? color}) => TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400, color: color ?? AppColors.textPrimary,
  );
  static TextStyle bodyMedium({Color? color}) => TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, color: color ?? AppColors.textSecondary,
  );
  static TextStyle bodySmall({Color? color}) => TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400, color: color ?? AppColors.textMuted,
  );
  static TextStyle labelLarge({Color? color}) => TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary,
  );
  static TextStyle labelSmall({Color? color}) => TextStyle(
    fontSize: 10, fontWeight: FontWeight.w500, color: color ?? AppColors.textSecondary,
  );
}
