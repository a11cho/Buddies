import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class BuddiesStyleScope extends StatelessWidget {
  const BuddiesStyleScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme.copyWith(
      primary: AppColors.primaryBlue,
      primaryContainer: AppColors.softBlue,
      secondary: AppColors.primaryBlue,
    );

    return Theme(
      data: theme.copyWith(
        colorScheme: colorScheme,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
            disabledForegroundColor: colorScheme.outline,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            side: const BorderSide(color: AppColors.inputBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: AppColors.inputFill,
          prefixIconColor: AppColors.primaryBlue,
          suffixIconColor: AppColors.primaryBlue,
          suffixStyle: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w700,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.inputBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: AppColors.primaryBlue,
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.inputBorder),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      child: child,
    );
  }
}

class BuddiesScreenBody extends StatelessWidget {
  const BuddiesScreenBody({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BuddiesStyleScope(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: child,
      ),
    );
  }
}

class BuddiesCard extends StatelessWidget {
  const BuddiesCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
