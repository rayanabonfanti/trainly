import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/services/booking_service.dart';

void main() {
  group('BookingResult', () {
    group('factory constructors', () {
      test('success should create successful result', () {
        final result = BookingResult.success('Reserva realizada!');

        expect(result.success, isTrue);
        expect(result.message, equals('Reserva realizada!'));
        expect(result.booking, isNull);
      });

      test('error should create failed result', () {
        final result = BookingResult.error('Aula lotada');

        expect(result.success, isFalse);
        expect(result.message, equals('Aula lotada'));
        expect(result.booking, isNull);
      });
    });

    group('properties', () {
      test('should store all properties correctly', () {
        final result = BookingResult(
          success: true,
          message: 'Test message',
          booking: null,
        );

        expect(result.success, isTrue);
        expect(result.message, equals('Test message'));
      });
    });
  });

  group('UserBookingLimits', () {
    test('should store all properties correctly', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 2,
        cancellationsThisMonth: 1,
        canBookMore: true,
        canCancelMore: true,
      );

      expect(limits.activeBookingsThisWeek, equals(2));
      expect(limits.cancellationsThisMonth, equals(1));
      expect(limits.canBookMore, isTrue);
      expect(limits.canCancelMore, isTrue);
    });

    test('should indicate cannot book when limit reached', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 3,
        cancellationsThisMonth: 0,
        canBookMore: false,
        canCancelMore: true,
      );

      expect(limits.canBookMore, isFalse);
    });

    test('should indicate cannot cancel when limit reached', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 1,
        cancellationsThisMonth: 2,
        canBookMore: true,
        canCancelMore: false,
      );

      expect(limits.canCancelMore, isFalse);
    });

    test('should handle zero values', () {
      final limits = UserBookingLimits(
        activeBookingsThisWeek: 0,
        cancellationsThisMonth: 0,
        canBookMore: true,
        canCancelMore: true,
      );

      expect(limits.activeBookingsThisWeek, equals(0));
      expect(limits.cancellationsThisMonth, equals(0));
      expect(limits.canBookMore, isTrue);
      expect(limits.canCancelMore, isTrue);
    });
  });
}
