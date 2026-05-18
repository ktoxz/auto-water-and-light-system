import 'package:flutter/material.dart';

/// Responsive utilities cho Nubia Z60S (2160 x 1440) và các devices khác
class ResponsiveUtils {
  static const double baseWidth = 360;  // Base width for scaling
  static const double baseHeight = 800; // Base height for scaling
  static const double maxScale = 1.5;   // Cap scaling factor for ultra-large screens

  /// Lấy scale factor dựa vào screen width
  static double getWidthScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / baseWidth;
    return scale.clamp(0.8, maxScale);
  }

  /// Lấy scale factor dựa vào screen height
  static double getHeightScale(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final scale = height / baseHeight;
    return scale.clamp(0.8, maxScale);
  }

  /// Lấy scale factor trung bình
  static double getScale(BuildContext context) {
    return (getWidthScale(context) + getHeightScale(context)) / 2;
  }

  /// Check nếu device là landscape
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check nếu device là portrait
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Check nếu screen size nhỏ (< 400 width)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 400;
  }

  /// Check nếu screen size vừa (400-600 width)
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 400 && width < 600;
  }

  /// Check nếu screen size lớn (>= 600 width)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  /// Get padding dựa vào screen size
  static EdgeInsets getPadding(BuildContext context) {
    final scale = getScale(context);
    if (isSmallScreen(context)) {
      return EdgeInsets.all(12 * scale);
    } else if (isMediumScreen(context)) {
      return EdgeInsets.all(14 * scale);
    } else {
      return EdgeInsets.all(16 * scale);
    }
  }

  /// Get dynamic spacing dựa vào type
  static double getSpacing(BuildContext context, {required String type}) {
    final scale = getScale(context);
    switch (type) {
      case 'xs':
        return 4 * scale;
      case 'sm':
        return 8 * scale;
      case 'md':
        return 12 * scale;
      case 'lg':
        return 16 * scale;
      case 'xl':
        return 20 * scale;
      case 'xxl':
        return 24 * scale;
      default:
        return 12 * scale;
    }
  }

  /// Get grid crossAxisCount dựa vào screen width
  /// Nubia Z60S: 2160 width → ~1 cột cho comfortable spacing
  /// Standard: ~2 cột cho 360-600 width
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) {
      return 1; // Very narrow screen
    } else if (width < 600) {
      return 2; // Normal phone
    } else if (width < 900) {
      return 2; // Tablet small
    } else {
      return 3; // Tablet large
    }
  }

  /// Get grid child aspect ratio
  static double getGridAspectRatio(BuildContext context) {
    final cols = getGridColumns(context);
    if (cols == 1) {
      return 2.0; // Wide aspect ratio for single column
    } else {
      return 1.1; // Square-ish for 2+ columns
    }
  }

  /// Get button height dựa vào screen size
  static double getButtonHeight(BuildContext context) {
    final scale = getScale(context);
    if (isSmallScreen(context)) {
      return 40 * scale;
    } else if (isMediumScreen(context)) {
      return 44 * scale;
    } else {
      return 48 * scale;
    }
  }

  /// Get headline font size
  static double getHeadlineSize(BuildContext context) {
    final scale = getWidthScale(context);
    return (28 * scale).clamp(24, 32);
  }

  /// Get title font size
  static double getTitleSize(BuildContext context) {
    final scale = getWidthScale(context);
    return (18 * scale).clamp(16, 22);
  }

  /// Get body font size
  static double getBodySize(BuildContext context) {
    final scale = getWidthScale(context);
    return (14 * scale).clamp(12, 16);
  }

  /// Get small font size
  static double getSmallSize(BuildContext context) {
    final scale = getWidthScale(context);
    return (12 * scale).clamp(10, 14);
  }

  /// Get icon size dựa vào purpose
  static double getIconSize(BuildContext context, {required String purpose}) {
    final scale = getScale(context);
    switch (purpose) {
      case 'small':
        return 16 * scale;
      case 'normal':
        return 20 * scale;
      case 'large':
        return 32 * scale;
      case 'xlarge':
        return 56 * scale;
      case 'xxlarge':
        return 112 * scale;
      default:
        return 24 * scale;
    }
  }

  /// Get horizontal padding for list items
  static EdgeInsets getListItemPadding(BuildContext context) {
    final scale = getScale(context);
    return EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale);
  }

  /// Get card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    final scale = getScale(context);
    return EdgeInsets.all(12 * scale);
  }

  /// Get border radius
  static double getBorderRadius(BuildContext context, {required String size}) {
    final scale = getScale(context);
    switch (size) {
      case 'small':
        return 4 * scale;
      case 'normal':
        return 8 * scale;
      case 'large':
        return 12 * scale;
      case 'xlarge':
        return 16 * scale;
      default:
        return 8 * scale;
    }
  }
}
