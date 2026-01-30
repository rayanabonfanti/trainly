import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/core/theme_provider.dart';

void main() {
  group('AppTheme', () {
    group('lightTheme', () {
      test('should have light brightness', () {
        expect(AppTheme.lightTheme.brightness, equals(Brightness.light));
      });

      test('should use Material3', () {
        expect(AppTheme.lightTheme.useMaterial3, isTrue);
      });

      test('should have centered app bar title', () {
        expect(AppTheme.lightTheme.appBarTheme.centerTitle, isTrue);
      });

      test('should have zero app bar elevation', () {
        expect(AppTheme.lightTheme.appBarTheme.elevation, equals(0));
      });

      test('should have card elevation of 2', () {
        expect(AppTheme.lightTheme.cardTheme.elevation, equals(2));
      });

      test('should have rounded card corners', () {
        final cardTheme = AppTheme.lightTheme.cardTheme;
        expect(cardTheme.shape, isA<RoundedRectangleBorder>());
      });

      test('should have filled input decoration', () {
        expect(AppTheme.lightTheme.inputDecorationTheme.filled, isTrue);
      });
    });

    group('darkTheme', () {
      test('should have dark brightness', () {
        expect(AppTheme.darkTheme.brightness, equals(Brightness.dark));
      });

      test('should use Material3', () {
        expect(AppTheme.darkTheme.useMaterial3, isTrue);
      });

      test('should have centered app bar title', () {
        expect(AppTheme.darkTheme.appBarTheme.centerTitle, isTrue);
      });

      test('should have zero app bar elevation', () {
        expect(AppTheme.darkTheme.appBarTheme.elevation, equals(0));
      });

      test('should have card elevation of 2', () {
        expect(AppTheme.darkTheme.cardTheme.elevation, equals(2));
      });

      test('should have rounded card corners', () {
        final cardTheme = AppTheme.darkTheme.cardTheme;
        expect(cardTheme.shape, isA<RoundedRectangleBorder>());
      });

      test('should have filled input decoration', () {
        expect(AppTheme.darkTheme.inputDecorationTheme.filled, isTrue);
      });
    });

    group('theme consistency', () {
      test('both themes should have card shape', () {
        expect(AppTheme.lightTheme.cardTheme.shape, isNotNull);
        expect(AppTheme.darkTheme.cardTheme.shape, isNotNull);
      });

      test('both themes should have same card elevation', () {
        expect(
          AppTheme.lightTheme.cardTheme.elevation,
          equals(AppTheme.darkTheme.cardTheme.elevation),
        );
      });

      test('both themes should use Material3', () {
        expect(AppTheme.lightTheme.useMaterial3, isTrue);
        expect(AppTheme.darkTheme.useMaterial3, isTrue);
      });
    });
  });
}
