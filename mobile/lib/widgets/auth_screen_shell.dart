import 'package:flutter/material.dart';

const Color authPrimaryColor = Color(0xFF0054FF);
const Color authBackgroundColor = Color(0xFFF5F5FA);
const Color authSoftBlueColor = Color(0xFFEAF1FF);
const Color authInputFillColor = Color(0xFFF0F3FA);
const Color authInputBorderColor = Color(0xFFD9E4FF);

class AuthLogoTitle extends StatelessWidget {
  const AuthLogoTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/buddies_logo_name.png',
      height: 34,
      fit: BoxFit.contain,
    );
  }
}

class AuthScreenBody extends StatelessWidget {
  const AuthScreenBody({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme.copyWith(
      primary: authPrimaryColor,
      primaryContainer: authSoftBlueColor,
      secondary: authPrimaryColor,
    );

    return Theme(
      data: theme.copyWith(
        colorScheme: colorScheme,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: authPrimaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
            disabledForegroundColor: colorScheme.outline,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: authPrimaryColor,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: authPrimaryColor,
            side: const BorderSide(color: authInputBorderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: authInputFillColor,
          prefixIconColor: authPrimaryColor,
          suffixStyle: theme.textTheme.bodyMedium?.copyWith(
            color: authPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: authInputBorderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: authPrimaryColor,
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: authInputBorderColor),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: authBackgroundColor),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: children,
        ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: authInputBorderColor.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: authPrimaryColor.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class AuthInfoPill extends StatelessWidget {
  const AuthInfoPill({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: authSoftBlueColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: authInputBorderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: authPrimaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
