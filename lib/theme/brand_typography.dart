import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bricolage Grotesque display type (SIL OFL 1.1).
///
/// Body text and catalog card titles stay on Material Roboto.
///
/// The bundled variable font's default master is 96pt ExtraBold
/// (opsz 96, wght 800, wdth 100), so every display style sets an explicit
/// weight. Optical size follows the font size, clamped to the axis
/// (12–96). Width stays on the axis default. Former Playfair Display
/// 600 and 700 both map to Bricolage 700.
abstract final class BrandTypography {
  static const family = 'Bricolage Grotesque';

  /// Uppercase Czech carons (Ž, Ř, Ů, Ď, Ť) need at least this line height.
  static const minLineHeight = 1.2;

  /// `opsz` axis of `BricolageGrotesque[opsz,wdth,wght].ttf`.
  static const opszMin = 12.0;
  static const opszMax = 96.0;

  static const licenseAsset = 'assets/licenses/OFL.txt';

  /// −1% from 24 sp up, 0 below.
  static double letterSpacingFor(double fontSize) =>
      fontSize >= 24 ? fontSize * -0.01 : 0;

  /// Optical size for [fontSize], clamped to the font's `opsz` axis.
  static double opszFor(double fontSize) =>
      fontSize.clamp(opszMin, opszMax).toDouble();

  /// Former Playfair Display weight. 600 and 700 both become 700.
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
      fontVariations: [FontVariation('opsz', opszFor(fontSize))],
      height: height < minLineHeight ? minLineHeight : height,
      letterSpacing: letterSpacing ?? letterSpacingFor(fontSize),
      color: color,
    );
  }
}

bool _bricolageLicenseRegistered = false;

/// Registers the Bricolage Grotesque OFL with [LicenseRegistry].
/// Safe to call once.
void registerBricolageLicense() {
  if (_bricolageLicenseRegistered) return;
  _bricolageLicenseRegistered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(BrandTypography.licenseAsset);
    yield LicenseEntryWithLineBreaks(const ['Bricolage Grotesque'], text);
  });
}
