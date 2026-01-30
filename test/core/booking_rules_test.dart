import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/core/booking_rules.dart';

void main() {
  group('BookingRules', () {
    group('canCancelBooking', () {
      test('should return true when class is more than 2 hours away', () {
        final classTime = DateTime.now().add(const Duration(hours: 3));
        
        final result = BookingRules.canCancelBooking(classTime);
        
        expect(result, isTrue);
      });

      test('should return true when class is exactly 2 hours and 1 minute away', () {
        final classTime = DateTime.now().add(const Duration(hours: 2, minutes: 1));
        
        final result = BookingRules.canCancelBooking(classTime);
        
        expect(result, isTrue);
      });

      test('should return false when class is less than 2 hours away', () {
        final classTime = DateTime.now().add(const Duration(hours: 1, minutes: 59));
        
        final result = BookingRules.canCancelBooking(classTime);
        
        expect(result, isFalse);
      });

      test('should return false when class is in the past', () {
        final classTime = DateTime.now().subtract(const Duration(hours: 1));
        
        final result = BookingRules.canCancelBooking(classTime);
        
        expect(result, isFalse);
      });

      test('should return false when class is exactly 2 hours away', () {
        final classTime = DateTime.now().add(const Duration(hours: 2));
        
        final result = BookingRules.canCancelBooking(classTime);
        
        expect(result, isFalse);
      });
    });

    group('timeUntilCancellationDeadline', () {
      test('should return duration when deadline has not passed', () {
        final classTime = DateTime.now().add(const Duration(hours: 5));
        
        final result = BookingRules.timeUntilCancellationDeadline(classTime);
        
        expect(result, isNotNull);
        expect(result!.inHours, greaterThanOrEqualTo(2));
      });

      test('should return null when deadline has passed', () {
        final classTime = DateTime.now().add(const Duration(hours: 1));
        
        final result = BookingRules.timeUntilCancellationDeadline(classTime);
        
        expect(result, isNull);
      });
    });

    group('formatRemainingTime', () {
      test('should format days and hours correctly', () {
        const duration = Duration(days: 2, hours: 5);
        
        final result = BookingRules.formatRemainingTime(duration);
        
        expect(result, equals('2d 5h'));
      });

      test('should format hours and minutes correctly', () {
        const duration = Duration(hours: 3, minutes: 30);
        
        final result = BookingRules.formatRemainingTime(duration);
        
        expect(result, equals('3h 30min'));
      });

      test('should format only minutes correctly', () {
        const duration = Duration(minutes: 45);
        
        final result = BookingRules.formatRemainingTime(duration);
        
        expect(result, equals('45min'));
      });

      test('should return "Poucos segundos" for very short durations', () {
        const duration = Duration(seconds: 30);
        
        final result = BookingRules.formatRemainingTime(duration);
        
        expect(result, equals('Poucos segundos'));
      });
    });

    group('constants', () {
      test('should have correct cancellation deadline hours', () {
        expect(BookingRules.cancellationDeadlineHours, equals(2));
      });

      test('should have correct max bookings per week', () {
        expect(BookingRules.maxBookingsPerWeek, equals(3));
      });

      test('should have correct max cancellations per month', () {
        expect(BookingRules.maxCancellationsPerMonth, equals(2));
      });
    });

    group('messages', () {
      test('should return non-empty cancellation deadline message', () {
        expect(BookingRules.cancellationDeadlineMessage, isNotEmpty);
        expect(
          BookingRules.cancellationDeadlineMessage,
          contains('2 horas'),
        );
      });

      test('should return non-empty booking limit message', () {
        expect(BookingRules.bookingLimitMessage, isNotEmpty);
        expect(
          BookingRules.bookingLimitMessage,
          contains('3'),
        );
      });

      test('should return non-empty cancellation limit message', () {
        expect(BookingRules.cancellationLimitMessage, isNotEmpty);
        expect(
          BookingRules.cancellationLimitMessage,
          contains('2'),
        );
      });
    });
  });
}
