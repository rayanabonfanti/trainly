import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/widgets/skeleton_loading.dart';

void main() {
  group('SkeletonContainer', () {
    testWidgets('should render with correct dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonContainer(width: 100, height: 50),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(container.constraints?.maxWidth, equals(100));
      expect(container.constraints?.maxHeight, equals(50));
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('should use custom border radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkeletonContainer(
              width: 100,
              height: 50,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.borderRadius, equals(BorderRadius.circular(20)));
    });

    testWidgets('should adapt color to light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: SkeletonContainer(width: 100, height: 50),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(Colors.grey[300]));
    });

    testWidgets('should adapt color to dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SkeletonContainer(width: 100, height: 50),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(Colors.grey[800]));
    });
  });

  group('ClassCardSkeleton', () {
    testWidgets('should render without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClassCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(ClassCardSkeleton), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('should contain skeleton containers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClassCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(SkeletonContainer), findsWidgets);
    });
  });

  group('ClassesListSkeleton', () {
    testWidgets('should render default 5 items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClassesListSkeleton(),
          ),
        ),
      );

      expect(find.byType(ClassCardSkeleton), findsNWidgets(5));
    });

    testWidgets('should render custom item count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClassesListSkeleton(itemCount: 3),
          ),
        ),
      );

      expect(find.byType(ClassCardSkeleton), findsNWidgets(3));
    });
  });

  group('SectionHeaderSkeleton', () {
    testWidgets('should render without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeaderSkeleton(),
          ),
        ),
      );

      expect(find.byType(SectionHeaderSkeleton), findsOneWidget);
    });

    testWidgets('should contain skeleton containers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeaderSkeleton(),
          ),
        ),
      );

      expect(find.byType(SkeletonContainer), findsWidgets);
    });
  });

  group('BookingCardSkeleton', () {
    testWidgets('should render without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(BookingCardSkeleton), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('StatCardSkeleton', () {
    testWidgets('should render without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(StatCardSkeleton), findsOneWidget);
    });

    testWidgets('should contain skeleton containers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(SkeletonContainer), findsWidgets);
    });
  });
}
