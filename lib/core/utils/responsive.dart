import 'package:flutter/material.dart';

extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  
  // scaleFactor = screenWidth / 375 (standard phone width)
  // Clamp scaleFactor between 0.7 and 1.4 to prevent layout distortion on tablet/large screen or extremely tiny screen
  double get scaleFactor {
    final double factor = screenWidth / 375.0;
    return factor.clamp(0.7, 1.4);
  }

  // Responsive font size calculation
  double rFont(double baseFontSize) => baseFontSize * scaleFactor;

  // Responsive size (for padding, margins, sizing widgets)
  double rSize(double baseSize) => baseSize * scaleFactor;

  // Percentage based sizing
  double rWidth(double percentage) => screenWidth * percentage;
  double rHeight(double percentage) => screenHeight * percentage;
}
