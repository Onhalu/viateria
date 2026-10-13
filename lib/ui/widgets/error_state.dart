import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Beige skeleton block. Shimmer period is capped at 1.2s.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final base = BrandColors.beige.withValues(alpha: 0.4);
    if (reduce) {
      return _box(base);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final alpha = 0.28 + (t * 0.22);
        return _box(BrandColors.beige.withValues(alpha: alpha));
      },
    );
  }

  Widget _box(Color color) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
  }
}

/// Three catalog-shaped placeholders used in place of a full-screen spinner.
class CatalogLoadingSkeleton extends StatelessWidget {
  const CatalogLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: const [
        AppSkeleton(height: 180, radius: 12),
        SizedBox(height: 16),
        AppSkeleton(height: 120, radius: 12),
        SizedBox(height: 12),
        AppSkeleton(height: 120, radius: 12),
      ],
    );
  }
}

/// Shared failure surface: bark icon, error title, forest hint, retry pill.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.retryLabel,
    required this.onRetry,
    this.hint,
    this.titleKey,
    this.icon = Icons.error_outline,
  });

  final String title;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? hint;
  final Key? titleKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 40, color: BrandColors.bark),
        const SizedBox(height: 12),
        Text(
          title,
          key: titleKey,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: BrandColors.error,
            fontSize: AppTheme.bodySize,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.forest,
              fontSize: AppTheme.labelSize,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ),
      ],
    );
  }
}
