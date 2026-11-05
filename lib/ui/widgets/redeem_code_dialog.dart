import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/redemption_code.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

/// How the redeem dialog closed.
enum RedeemCodeDialogResult { unlocked, dismissed }

/// Code entry for an open paid challenge. Success pops [unlocked].
/// Errors stay in the dialog. The barrier and system back do not dismiss
/// while the request is in flight.
Future<RedeemCodeDialogResult> showRedeemCodeDialog({
  required BuildContext context,
  required AppStrings strings,
  required PurchaseRepository purchases,
  required String challengeId,
  VoidCallback? onAlreadyUnlocked,
}) {
  return showDialog<RedeemCodeDialogResult>(
    context: context,
    builder: (context) {
      return RedeemCodeDialog(
        strings: strings,
        purchases: purchases,
        challengeId: challengeId,
        onAlreadyUnlocked: onAlreadyUnlocked,
      );
    },
  ).then((value) => value ?? RedeemCodeDialogResult.dismissed);
}

class RedeemCodeDialog extends StatefulWidget {
  const RedeemCodeDialog({
    super.key,
    required this.strings,
    required this.purchases,
    required this.challengeId,
    this.onAlreadyUnlocked,
  });

  final AppStrings strings;
  final PurchaseRepository purchases;
  final String challengeId;
  final VoidCallback? onAlreadyUnlocked;

  static const radius = 20.0;
  static const padding = 24.0;
  static const buttonHeight = 52.0;

  @override
  State<RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends State<RedeemCodeDialog> {
  final _controller = TextEditingController();
  var _loading = false;
  RedeemCodeError? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (normalizeRedemptionCode(_controller.text) == null) {
      setState(() => _error = RedeemCodeError.invalidCode);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.purchases.redeemChallengeCode(
      challengeId: widget.challengeId,
      rawCode: _controller.text,
    );
    if (!mounted) return;
    if (result.unlocked) {
      Navigator.of(context).pop(RedeemCodeDialogResult.unlocked);
      return;
    }
    if (result.alreadyUnlocked) {
      setState(() {
        _loading = false;
        _error = RedeemCodeError.alreadyUnlocked;
      });
      widget.onAlreadyUnlocked?.call();
      return;
    }
    setState(() {
      _loading = false;
      _error = result.error ?? RedeemCodeError.network;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final error = _error;
    return PopScope(
      canPop: !_loading,
      child: Dialog(
        key: const Key('redeem-code-dialog'),
        backgroundColor: BrandColors.cream,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RedeemCodeDialog.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(RedeemCodeDialog.padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.redeemCodeTitle,
                key: const Key('redeem-code-title'),
                style: BrandTypography.display(
                  fontSize: 22,
                  height: 1.2,
                  color: BrandColors.forest,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.redeemCodeHelper,
                key: const Key('redeem-code-helper'),
                style: const TextStyle(
                  color: BrandColors.bark,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('redeem-code-field'),
                controller: _controller,
                enabled: !_loading,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: BrandColors.forest),
                cursorColor: BrandColors.forest,
                decoration: InputDecoration(
                  hintText: strings.redeemCodeHint,
                  filled: true,
                  fillColor: BrandColors.neutral,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: _fieldBorder(BrandColors.sage, 1),
                  disabledBorder: _fieldBorder(BrandColors.sage, 1),
                  focusedBorder: _fieldBorder(BrandColors.forest, 1.5),
                  border: _fieldBorder(BrandColors.sage, 1),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  strings.redeemCodeError(error),
                  key: const Key('redeem-code-error'),
                  style: const TextStyle(
                    color: BrandColors.bark,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: RedeemCodeDialog.buttonHeight,
                width: double.infinity,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          key: Key('redeem-code-loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BrandColors.forest,
                          ),
                        ),
                      )
                    : FilledButton(
                        key: const Key('redeem-code-submit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandColors.forest,
                          foregroundColor: BrandColors.cream,
                          minimumSize: const Size.fromHeight(
                            RedeemCodeDialog.buttonHeight,
                          ),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(strings.redeemCodeUnlock),
                      ),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('redeem-code-cancel'),
                onPressed: _loading
                    ? null
                    : () =>
                          Navigator.of(context)
                              .pop(RedeemCodeDialogResult.dismissed),
                style: TextButton.styleFrom(
                  foregroundColor: BrandColors.forest,
                  backgroundColor: Colors.transparent,
                  disabledForegroundColor: BrandColors.forest.withValues(
                    alpha: 0.4,
                  ),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: const RoundedRectangleBorder(),
                  side: BorderSide.none,
                  textStyle: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                child: Text(
                  strings.redeemCodeCancel,
                  style: const TextStyle(color: BrandColors.forest),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
