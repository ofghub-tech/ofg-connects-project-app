import 'package:flutter/material.dart';

class OfgUi {
  static const Color bg = Color(0xFF080A0F);
  static const Color bg2 = Color(0xFF0D1018);
  static const Color surface = Color(0xFF111520);
  static const Color surface2 = Color(0xFF161B28);
  static const Color border = Color(0xFF1E2535);
  static const Color accent = Color(0xFF2D5AA0);
  static const Color accentHover = Color(0xFF3A6FC0);
  static const Color accentWarm = Color(0xFFD9522A);
  static const Color gold = Color(0xFFC4973E);
  static const Color text = Color(0xFFE2E6F0);
  static const Color muted = Color(0xFF5A6478);
  static const Color muted2 = Color(0xFF8A94A8);

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(12));

  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, bg2],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050F20),
      Color(0xFF0D2040),
      Color(0xFF04100A),
    ],
  );

  static const TextStyle cinzelTitle = TextStyle(
    fontFamily: 'Cinzel',
    fontWeight: FontWeight.w700,
    color: text,
    letterSpacing: 0.4,
  );

  static BoxDecoration cardDecoration({
    bool elevated = false,
    BorderRadius? radius,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: radius ?? cardRadius,
      border: Border.all(color: border),
      boxShadow: elevated
          ? const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  static Widget sectionHeader({
    required String title,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Cinzel',
            color: gold,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        if (actionText != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionText,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

