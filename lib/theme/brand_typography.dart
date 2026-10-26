import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Onest display type (SIL OFL 1.1).
///
/// Body text and catalog card titles stay on Material Roboto.
///
/// The bundled variable font's default instance is Regular (wght 400),
/// so every display style sets an explicit weight. Onest has a `wght`
/// axis (100–900) and no `opsz` axis. Former Playfair Display 600 and
/// 700 both map to Onest 700.
abstract final class BrandTypography {
  static const family = 'Onest';

  /// Variable font bundled from google/fonts `ofl/onest`.
  static const fontAsset = 'assets/fonts/Onest[wght].ttf';

  /// Uppercase Czech carons (Ž, Ř, Ů, Ď, Ť) need at least this line height.
  static const minLineHeight = 1.2;

  static const licenseAsset = 'assets/licenses/OFL.txt';

  /// −1% from 24 sp up, 0 below.
  static double letterSpacingFor(double fontSize) =>
      fontSize >= 24 ? fontSize * -0.01 : 0;

  /// Former Playfair Display weight. 600 and 700 both become Onest 700.
  static FontWeight mapPlayfairWeight(FontWeight weight) =>
      weight == FontWeight.w600 || weight == FontWeight.w700
      ? FontWeight.w700
      : weight;

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
      fontVariations: [FontVariation('wght', fontWeight.value.toDouble())],
      height: height < minLineHeight ? minLineHeight : height,
      letterSpacing: letterSpacing ?? letterSpacingFor(fontSize),
      color: color,
    );
  }
}

bool _onestLicenseRegistered = false;

/// Registers the Onest OFL with [LicenseRegistry].
/// Safe to call once.
void registerOnestLicense() {
  if (_onestLicenseRegistered) return;
  _onestLicenseRegistered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(BrandTypography.licenseAsset);
    yield LicenseEntryWithLineBreaks(const ['Onest'], text);
  });
}
