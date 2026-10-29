import 'package:flutter/material.dart';
import '../theme.dart';

/// Skeleton loading: grey placeholder shapes in the layout of the content
/// that is loading, gently pulsing. Used instead of a spinner so the screen
/// keeps its shape while data arrives. Every [Bone] inside pulses together.
class Shimmer extends StatefulWidget {
  final Widget child;

  /// Lighter shapes for dark backgrounds (e.g. the green sales card).
  final bool onDark;
  const Shimmer({super.key, required this.child, this.onDark = false});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: _ShimmerScope(
        animation: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        onDark: widget.onDark,
        child: widget.child,
      ),
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  final Animation<double> animation;
  final bool onDark;
  const _ShimmerScope(
      {required this.animation, required this.onDark, required super.child});

  @override
  bool updateShouldNotify(_ShimmerScope old) =>
      old.animation != animation || old.onDark != onDark;
}

const _base = Color(0xFFE3E8E2);
const _highlight = Color(0xFFF1F4F0);

/// One grey placeholder shape. Pulses when inside a [Shimmer].
class Bone extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const Bone({super.key, this.width, this.height = 12, this.radius = 6});

  const Bone.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 999;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();
    final base = scope?.onDark == true
        ? Colors.white.withValues(alpha: 0.18)
        : _base;
    final highlight = scope?.onDark == true
        ? Colors.white.withValues(alpha: 0.34)
        : _highlight;
    Widget box(Color color) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    if (scope == null) return box(base);
    return AnimatedBuilder(
      animation: scope.animation,
      builder: (_, _) =>
          box(Color.lerp(base, highlight, scope.animation.value)!),
    );
  }
}

/// The kinds of list the app loads, each with its own placeholder card.
enum SkeletonKind { product, listing, order, request, notification, farm, offer }

/// A scrollable list of placeholder cards. Scrollable so pull-to-refresh
/// still works while it shows.
class SkeletonList extends StatelessWidget {
  final SkeletonKind kind;
  final int count;
  final EdgeInsetsGeometry padding;
  const SkeletonList({
    super.key,
    required this.kind,
    this.count = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => SkeletonCard(kind: kind),
      ),
    );
  }
}

/// One placeholder card shaped like the real card of that [kind].
class SkeletonCard extends StatelessWidget {
  final SkeletonKind kind;
  const SkeletonCard({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TamuColors.line),
      ),
      child: switch (kind) {
        SkeletonKind.product || SkeletonKind.listing => _photoRow(),
        SkeletonKind.order => _order(),
        SkeletonKind.request => _request(),
        SkeletonKind.notification => _notification(),
        SkeletonKind.farm => _farm(),
        SkeletonKind.offer => _offer(),
      },
    );
  }

  // Crop photo on the left, name / price / stock on the right.
  Widget _photoRow() => const Row(
        children: [
          Bone(width: 64, height: 64, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 120, height: 15),
                SizedBox(height: 8),
                Bone(width: 90, height: 13),
                SizedBox(height: 8),
                Bone(width: 150, height: 11),
              ],
            ),
          ),
          SizedBox(width: 8),
          Bone(width: 52, height: 20, radius: 10),
        ],
      );

  Widget _order() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone(width: 140, height: 11),
              Spacer(),
              Bone(width: 70, height: 20, radius: 10),
            ],
          ),
          SizedBox(height: 10),
          Bone(width: 160, height: 17),
          SizedBox(height: 8),
          Bone(width: 110, height: 11),
          SizedBox(height: 14),
          Bone(height: 11),
          SizedBox(height: 6),
          Bone(width: 180, height: 11),
        ],
      );

  Widget _request() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone(width: 110, height: 18),
              Spacer(),
              Bone(width: 56, height: 20, radius: 10),
            ],
          ),
          SizedBox(height: 8),
          Bone(width: 90, height: 14),
          SizedBox(height: 10),
          Bone(width: 130, height: 11),
          SizedBox(height: 14),
          Bone(height: 42, radius: 12),
        ],
      );

  Widget _notification() => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Bone(width: 36, height: 36, radius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 150, height: 14),
                SizedBox(height: 8),
                Bone(height: 11),
                SizedBox(height: 6),
                Bone(width: 170, height: 11),
                SizedBox(height: 10),
                Bone(width: 70, height: 10),
              ],
            ),
          ),
        ],
      );

  Widget _farm() => const Row(
        children: [
          Bone.circle(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 130, height: 15),
                SizedBox(height: 8),
                Bone(width: 180, height: 11),
              ],
            ),
          ),
          Bone(width: 48, height: 14),
        ],
      );

  Widget _offer() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone(width: 110, height: 16),
              Spacer(),
              Bone(width: 70, height: 16),
            ],
          ),
          SizedBox(height: 8),
          Bone(width: 150, height: 11),
          SizedBox(height: 12),
          Bone(height: 40, radius: 12),
        ],
      );
}

/// Placeholder for the sales report: total card, small stat tiles, chart
/// and the top crops list.
class SalesReportSkeleton extends StatelessWidget {
  const SalesReportSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile() => Expanded(
          child: Container(
            height: 70,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TamuColors.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 70, height: 10),
                SizedBox(height: 10),
                Bone(width: 50, height: 16),
              ],
            ),
          ),
        );
    return Shimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Bone(height: 120, radius: 18),
          const SizedBox(height: 12),
          Row(children: [tile(), const SizedBox(width: 10), tile()]),
          const SizedBox(height: 10),
          Row(children: [tile(), const SizedBox(width: 10), tile()]),
          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Bone(width: 140, height: 16)),
          const SizedBox(height: 12),
          const Bone(height: 160, radius: 14),
          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Bone(width: 140, height: 16)),
          const SizedBox(height: 12),
          const SkeletonCard(kind: SkeletonKind.farm),
          const SizedBox(height: 10),
          const SkeletonCard(kind: SkeletonKind.farm),
        ],
      ),
    );
  }
}
