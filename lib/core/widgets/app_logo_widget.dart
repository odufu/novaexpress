import 'package:flutter/material.dart';

enum AppLogoVariant {
  landscape,
  square,
}

class AppLogoWidget extends StatelessWidget {
  final AppLogoVariant variant;
  final bool? isDarkMode;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLogoWidget({
    super.key,
    this.variant = AppLogoVariant.landscape,
    this.isDarkMode,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);

    String assetPath;
    if (variant == AppLogoVariant.square) {
      assetPath = dark
          ? 'assets/images/logo/square_logo_dark.png'
          : 'assets/images/logo/square_logo.png';
    } else {
      assetPath = dark
          ? 'assets/images/logo/long_logo_dark.png'
          : 'assets/images/logo/long_logo.png';
    }

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
