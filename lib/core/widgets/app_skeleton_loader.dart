import 'package:flutter/material.dart';

class AppSkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  @override
  State<AppSkeletonLoader> createState() => _AppSkeletonLoaderState();
}

class _AppSkeletonLoaderState extends State<AppSkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark ? const Color(0xFF151D36) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF243054) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1.0, 0.0),
              end: Alignment(_animation.value + 1.0, 0.0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class StockCardSkeleton extends StatelessWidget {
  const StockCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonLoader(width: 140, height: 18, borderRadius: 6),
              AppSkeletonLoader(width: 70, height: 22, borderRadius: 12),
            ],
          ),
          SizedBox(height: 8),
          AppSkeletonLoader(width: 100, height: 14, borderRadius: 4),
          SizedBox(height: 14),
          Divider(height: 1),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonLoader(width: 80, height: 14, borderRadius: 4),
              AppSkeletonLoader(width: 80, height: 14, borderRadius: 4),
              AppSkeletonLoader(width: 60, height: 14, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonLoader(width: 110, height: 18, borderRadius: 6),
              AppSkeletonLoader(width: 90, height: 22, borderRadius: 12),
            ],
          ),
          SizedBox(height: 10),
          AppSkeletonLoader(width: 160, height: 18, borderRadius: 6),
          SizedBox(height: 8),
          AppSkeletonLoader(width: 220, height: 14, borderRadius: 4),
          SizedBox(height: 14),
          Divider(height: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonLoader(width: 100, height: 24, borderRadius: 6),
              AppSkeletonLoader(width: 120, height: 36, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class RemittanceCardSkeleton extends StatelessWidget {
  const RemittanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          AppSkeletonLoader(width: 40, height: 40, borderRadius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLoader(width: 180, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                AppSkeletonLoader(width: 130, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppSkeletonLoader(width: 80, height: 16, borderRadius: 4),
              SizedBox(height: 6),
              AppSkeletonLoader(width: 90, height: 28, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class PayoutCardSkeleton extends StatelessWidget {
  const PayoutCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          AppSkeletonLoader(width: 40, height: 40, borderRadius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLoader(width: 190, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                AppSkeletonLoader(width: 150, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                AppSkeletonLoader(width: 110, height: 10, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppSkeletonLoader(width: 80, height: 18, borderRadius: 4),
              SizedBox(height: 6),
              AppSkeletonLoader(width: 100, height: 32, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class KpiTileSkeleton extends StatelessWidget {
  const KpiTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonLoader(width: 100, height: 12, borderRadius: 4),
          SizedBox(height: 10),
          AppSkeletonLoader(width: 140, height: 24, borderRadius: 6),
        ],
      ),
    );
  }
}
