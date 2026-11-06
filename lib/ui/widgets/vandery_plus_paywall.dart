import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/vandery_plus_session.dart';
import '../../domain/vandery_plus.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../theme/app_button.dart';
import '../../theme/brand_colors.dart';
import '../../theme/brand_typography.dart';
import '../layout/breakpoints.dart';
import 'vandery_plus_icons.dart';

const vanderyPlusSheetFraction = 0.82;
const vanderyPlusDialogMaxWidth = 480.0;

/// One content widget. Mobile uses a bottom sheet, web ≥600 a dialog.
Future<void> showVanderyPlusPaywall(
  BuildContext context, {
  int initialSlide = 0,
}) {
  final services = context.read<AppServices>();
  final session = services.vanderyPlus;
  final localeStrings = context.read<LocaleController>().strings;
  final host = context;
  final viewport = MediaQuery.sizeOf(context);
  final wide = viewport.width >= Breakpoints.compactMax;
  if (wide) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (dialogContext) {
        return _PaywallShell(
          session: session,
          strings: localeStrings,
          initialSlide: initialSlide,
          showHandle: false,
          hostContext: host,
          dialog: true,
          openUrl: services.openUrl,
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    enableDrag: true,
    backgroundColor: BrandColors.cream,
    barrierColor: const Color(0x99000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final height = viewport.height * vanderyPlusSheetFraction;
      return SizedBox(
        key: const Key('vandery-plus-sheet'),
        height: height,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: BrandColors.cream,
          body: SafeArea(
            top: false,
            child: _PaywallShell(
              session: session,
              strings: localeStrings,
              initialSlide: initialSlide,
              showHandle: true,
              hostContext: host,
              dialog: false,
              openUrl: services.openUrl,
            ),
          ),
        ),
      );
    },
  );
}

class _PaywallShell extends StatefulWidget {
  const _PaywallShell({
    required this.session,
    required this.strings,
    required this.initialSlide,
    required this.showHandle,
    required this.hostContext,
    required this.dialog,
    required this.openUrl,
  });

  final VanderyPlusSession session;
  final AppStrings strings;
  final int initialSlide;
  final bool showHandle;
  final BuildContext hostContext;
  final bool dialog;
  final Future<void> Function(Uri url) openUrl;

  @override
  State<_PaywallShell> createState() => _PaywallShellState();
}

class _PaywallShellState extends State<_PaywallShell> {
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    if (widget.session.message == VanderyPlusMessage.active) {
      final host = widget.hostContext;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(
          content: Text(
            widget.strings.vanderyPlusActiveToast,
            key: const Key('vandery-plus-toast'),
          ),
        ),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final body = VanderyPlusPaywallContent(
      session: widget.session,
      strings: widget.strings,
      initialSlide: widget.initialSlide,
      showHandle: widget.showHandle,
      onClose: () => Navigator.of(context).maybePop(),
      openUrl: widget.openUrl,
    );
    if (!widget.dialog) return body;
    final view = MediaQuery.sizeOf(context);
    final width = math.min(vanderyPlusDialogMaxWidth, view.width - 48);
    final height = math.min(640.0, view.height - 48);
    return Dialog(
      backgroundColor: BrandColors.cream,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        key: const Key('vandery-plus-dialog'),
        width: width,
        height: height,
        child: body,
      ),
    );
  }
}

class VanderyPlusPaywallContent extends StatefulWidget {
  const VanderyPlusPaywallContent({
    super.key,
    required this.session,
    required this.strings,
    required this.onClose,
    required this.openUrl,
    this.initialSlide = 0,
    this.showHandle = false,
  });

  final VanderyPlusSession session;
  final AppStrings strings;
  final VoidCallback onClose;
  final Future<void> Function(Uri url) openUrl;
  final int initialSlide;
  final bool showHandle;

  @override
  State<VanderyPlusPaywallContent> createState() =>
      _VanderyPlusPaywallContentState();
}

class _VanderyPlusPaywallContentState extends State<VanderyPlusPaywallContent> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialSlide.clamp(0, 3);
    _pages = PageController(initialPage: _index);
    widget.session.addListener(_changed);
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    _pages.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _reduce {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  void _go(int next) {
    final target = next.clamp(0, 3);
    if (_reduce) {
      setState(() => _index = target);
      return;
    }
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final session = widget.session;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.showHandle)
                      const Center(
                        child: SizedBox(
                          key: Key('vandery-plus-handle'),
                          width: 36,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: BrandColors.beige,
                              borderRadius: BorderRadius.all(
                                Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: Semantics(
                          button: true,
                          label: strings.vanderyPlusClose,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              key: const Key('vandery-plus-close'),
                              onPressed: session.lockDismiss
                                  ? null
                                  : widget.onClose,
                              icon: const Icon(
                                Icons.close,
                                color: BrandColors.forest,
                              ),
                              tooltip: strings.vanderyPlusClose,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      strings.vanderyPlusTitle,
                      style: BrandTypography.display(
                        fontSize: 28,
                        color: BrandColors.forest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.vanderyPlusSubtitle,
                      style: const TextStyle(
                        color: BrandColors.bark,
                        fontSize: 15,
                        height: 22 / 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: _reduce
                          ? _BenefitList(strings: strings)
                          : SizedBox(
                              height: 240,
                              child: PageView.builder(
                                key: const Key('vandery-plus-pages'),
                                controller: _pages,
                                itemCount: 4,
                                onPageChanged: (value) =>
                                    setState(() => _index = value),
                                itemBuilder: (context, index) {
                                  return _BenefitCard(
                                    index: index,
                                    strings: strings,
                                  );
                                },
                              ),
                            ),
                    ),
                    if (!_reduce) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _NavButton(
                            key: const Key('vandery-plus-prev'),
                            order: 3,
                            tooltip: strings.vanderyPlusPrev,
                            icon: Icons.chevron_left,
                            onPressed: _index == 0
                                ? null
                                : () => _go(_index - 1),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < 4; i++)
                                  _Dot(
                                    index: i,
                                    selected: i == _index,
                                    strings: strings,
                                    onPressed: () => _go(i),
                                  ),
                              ],
                            ),
                          ),
                          _NavButton(
                            key: const Key('vandery-plus-next'),
                            order: 4,
                            tooltip: strings.vanderyPlusNext,
                            icon: Icons.chevron_right,
                            onPressed: _index == 3
                                ? null
                                : () => _go(_index + 1),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      session.displayPrice,
                      key: const Key('vandery-plus-price'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.forest,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      strings.vanderyPlusMonthly,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.bark,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.vanderyPlusDraftNote,
                      key: const Key('vandery-plus-draft'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.bark,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(16),
                          child: TextButton(
                            key: const Key('vandery-plus-terms'),
                            onPressed: () =>
                                widget.openUrl(VanderyPlusLegal.terms),
                            child: Text(strings.vanderyPlusTerms),
                          ),
                        ),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(17),
                          child: TextButton(
                            key: const Key('vandery-plus-privacy'),
                            onPressed: () =>
                                widget.openUrl(VanderyPlusLegal.privacy),
                            child: Text(strings.vanderyPlusPrivacy),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      strings.vanderyPlusLegalGate,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BrandColors.bark,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                    if (session.phase == VanderyPlusPhase.verifying)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          strings.vanderyPlusVerifying,
                          key: const Key('vandery-plus-verifying'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: BrandColors.forest),
                        ),
                      ),
                    if (session.message == VanderyPlusMessage.stillInactive ||
                        session.message == VanderyPlusMessage.payFailed ||
                        session.message == VanderyPlusMessage.cancelled)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          session.message == VanderyPlusMessage.stillInactive
                              ? strings.vanderyPlusRetryHint
                              : session.message == VanderyPlusMessage.cancelled
                              ? strings.vanderyPlusCancelled
                              : strings.vanderyPlusPayFailed,
                          key: const Key('vandery-plus-error'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: BrandColors.error),
                        ),
                      ),
                    if (session.message == VanderyPlusMessage.stillInactive)
                      TextButton(
                        key: const Key('vandery-plus-retry'),
                        onPressed: () => widget.session.verifyAgain(),
                        child: Text(strings.vanderyPlusRetryVerify),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.vanderyPlusCancelNote,
              key: const Key('vandery-plus-cancel-note'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.bark,
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
            const SizedBox(height: 8),
            FocusTraversalOrder(
              order: const NumericFocusOrder(20),
              child: SizedBox(
                key: const Key('vandery-plus-pay-slot'),
                width: double.infinity,
                height: 52,
                child: AbsorbPointer(
                  absorbing: session.lockDismiss,
                  child: AppButton(
                    key: const Key('vandery-plus-pay'),
                    label: strings.vanderyPlusPayCta(session.displayPrice),
                    size: AppButtonSize.l,
                    loading: session.phase == VanderyPlusPhase.submitting,
                    onPressed: session.lockDismiss ? null : () => session.pay(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  const _BenefitList({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('vandery-plus-benefit-list'),
      children: [
        for (var index = 0; index < 4; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _BenefitCard(index: index, strings: strings),
        ],
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.index, required this.strings});

  final int index;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final title = switch (index) {
      0 => strings.vanderyPlusSlide1Title,
      1 => strings.vanderyPlusSlide2Title,
      2 => strings.vanderyPlusSlide3Title,
      _ => strings.vanderyPlusSlide4Title,
    };
    final body = switch (index) {
      0 => strings.vanderyPlusSlide1Body,
      1 => strings.vanderyPlusSlide2Body,
      2 => strings.vanderyPlusSlide3Body,
      _ => strings.vanderyPlusSlide4Body,
    };
    return Semantics(
      label: strings.vanderyPlusBenefit(index + 1, 4),
      child: DecoratedBox(
        key: Key('vandery-plus-slide-$index'),
        decoration: BoxDecoration(
          color: BrandColors.beige,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    VanderyPlusBenefitIcon(index: index),
                    if (index == 1) ...[
                      const SizedBox(width: 12),
                      const HiddenDiplomaSilhouette(),
                      const SizedBox(width: 12),
                      const HiddenDiplomaSilhouette(),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: BrandColors.forest,
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  maxLines: 3,
                  style: const TextStyle(
                    color: BrandColors.bark,
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.order,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final double order;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: BrandColors.forest),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.index,
    required this.selected,
    required this.strings,
    required this.onPressed,
  });

  final int index;
  final bool selected;
  final AppStrings strings;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(5 + index.toDouble()),
      child: Semantics(
        button: true,
        selected: selected,
        label: strings.vanderyPlusBenefit(index + 1, 4),
        child: SizedBox(
          key: Key('vandery-plus-dot-$index'),
          width: 48,
          height: 48,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 8 : 6,
                height: selected ? 8 : 6,
                decoration: BoxDecoration(
                  color: selected
                      ? BrandColors.sage
                      : BrandColors.bark.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
