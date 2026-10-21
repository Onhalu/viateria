import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Manrope display type (SIL OFL 1.1). Body text stays on Material Roboto.
///
/// The bundled variable font's default master is ExtraLight, so every display
/// style sets an explicit weight. Playfair Display 600 maps to Manrope 700;
/// Playfair 700 stays 700.
abstract final class BrandTypography {
  static const family = 'Manrope';

  /// Uppercase Czech carons (Ž, Ř, Ů, Ď, Ť) need at least this line height.
  static const minLineHeight = 1.2;

  static const licenseAsset = 'assets/licenses/OFL.txt';

  /// −1% from 24 sp up, 0 below.
  static double letterSpacingFor(double fontSize) =>
      fontSize >= 24 ? fontSize * -0.01 : 0;

  /// Former Playfair Display weight. 600 becomes 700; 700 stays 700.
  static FontWeight mapPlayfairWeight(FontWeight weight) =>
      weight == FontWeight.w600 ? FontWeight.w700 : weight;

  static TextStyle display({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double height = minLineHeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height < minLineHeight ? minLineHeight : height,
      letterSpacing: letterSpacing ?? letterSpacingFor(fontSize),
      color: color,
    );
  }
}

bool _manropeLicenseRegistered = false;

/// Registers the Manrope OFL with [LicenseRegistry]. Safe to call once.
void registerManropeLicense() {
  if (_manropeLicenseRegistered) return;
  _manropeLicenseRegistered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(BrandTypography.licenseAsset);
    yield LicenseEntryWithLineBreaks(const ['Manrope'], text);
  });
}
