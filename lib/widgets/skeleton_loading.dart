import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Widget base para skeleton loading
class SkeletonContainer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonContainer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

/// Skeleton para um card de aula
class ClassCardSkeleton extends StatelessWidget {
  const ClassCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonContainer(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonContainer(
                          width: 150,
                          height: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        SkeletonContainer(
                          width: 100,
                          height: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                  SkeletonContainer(
                    width: 70,
                    height: 32,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SkeletonContainer(
                    width: 80,
                    height: 24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 8),
                  SkeletonContainer(
                    width: 60,
                    height: 24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton para lista de aulas
class ClassesListSkeleton extends StatelessWidget {
  final int itemCount;

  const ClassesListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ClassCardSkeleton(),
    );
  }
}

/// Skeleton para header de seção
class SectionHeaderSkeleton extends StatelessWidget {
  const SectionHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SkeletonContainer(
              width: 20,
              height: 20,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(width: 8),
            SkeletonContainer(
              width: 100,
              height: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton para card de reserva
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonContainer(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonContainer(
                          width: 120,
                          height: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SkeletonContainer(
                              width: 80,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(width: 12),
                            SkeletonContainer(
                              width: 70,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonContainer(
                    width: 60,
                    height: 28,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  SkeletonContainer(
                    width: 100,
                    height: 36,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton para estatísticas do dashboard
class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SkeletonContainer(
              width: 32,
              height: 32,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            SkeletonContainer(
              width: 50,
              height: 28,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            SkeletonContainer(
              width: 40,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
