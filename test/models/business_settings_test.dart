import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/business_settings.dart';

void main() {
  group('BusinessSettings', () {
    group('constructor', () {
      test('should create with default values', () {
        final settings = BusinessSettings();

        expect(settings.cancellationDeadlineHours, 2);
        expect(settings.maxCancellationsPerMonth, 2);
        expect(settings.cancellationLimitEnabled, true);
        expect(settings.maxBookingsPerWeek, 3);
        expect(settings.bookingLimitEnabled, true);
        expect(settings.minBookingAdvanceHours, 24);
        expect(settings.defaultClassCapacity, 10);
        expect(settings.defaultLanes, 4);
      });

      test('should create with custom values', () {
        final settings = BusinessSettings(
          cancellationDeadlineHours: 4,
          maxCancellationsPerMonth: 5,
          cancellationLimitEnabled: false,
          maxBookingsPerWeek: 7,
          bookingLimitEnabled: false,
          minBookingAdvanceHours: 48,
          defaultClassCapacity: 15,
          defaultLanes: 6,
        );

        expect(settings.cancellationDeadlineHours, 4);
        expect(settings.maxCancellationsPerMonth, 5);
        expect(settings.cancellationLimitEnabled, false);
        expect(settings.maxBookingsPerWeek, 7);
        expect(settings.bookingLimitEnabled, false);
        expect(settings.minBookingAdvanceHours, 48);
        expect(settings.defaultClassCapacity, 15);
        expect(settings.defaultLanes, 6);
      });
    });

    group('defaults factory', () {
      test('should create settings with default values', () {
        final settings = BusinessSettings.defaults();

        expect(settings.cancellationDeadlineHours, 2);
        expect(settings.maxCancellationsPerMonth, 2);
        expect(settings.cancellationLimitEnabled, true);
        expect(settings.maxBookingsPerWeek, 3);
        expect(settings.bookingLimitEnabled, true);
        expect(settings.minBookingAdvanceHours, 24);
        expect(settings.defaultClassCapacity, 10);
        expect(settings.defaultLanes, 4);
      });
    });

    group('fromJson', () {
      test('should parse all fields from JSON', () {
        final json = {
          'cancellation_deadline_hours': 6,
          'max_cancellations_per_month': 3,
          'cancellation_limit_enabled': false,
          'max_bookings_per_week': 5,
          'booking_limit_enabled': false,
          'min_booking_advance_hours': 12,
          'default_class_capacity': 20,
          'default_lanes': 8,
          'updated_at': '2025-01-15T10:30:00Z',
          'updated_by': 'user-123',
        };

        final settings = BusinessSettings.fromJson(json);

        expect(settings.cancellationDeadlineHours, 6);
        expect(settings.maxCancellationsPerMonth, 3);
        expect(settings.cancellationLimitEnabled, false);
        expect(settings.maxBookingsPerWeek, 5);
        expect(settings.bookingLimitEnabled, false);
        expect(settings.minBookingAdvanceHours, 12);
        expect(settings.defaultClassCapacity, 20);
        expect(settings.defaultLanes, 8);
        expect(settings.updatedAt, isNotNull);
        expect(settings.updatedBy, 'user-123');
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final settings = BusinessSettings.fromJson(json);

        expect(settings.cancellationDeadlineHours, 2);
        expect(settings.maxCancellationsPerMonth, 2);
        expect(settings.cancellationLimitEnabled, true);
        expect(settings.maxBookingsPerWeek, 3);
        expect(settings.bookingLimitEnabled, true);
        expect(settings.minBookingAdvanceHours, 24);
        expect(settings.defaultClassCapacity, 10);
        expect(settings.defaultLanes, 4);
      });
    });

    group('toJson', () {
      test('should convert to JSON correctly', () {
        final settings = BusinessSettings(
          cancellationDeadlineHours: 4,
          maxCancellationsPerMonth: 5,
          cancellationLimitEnabled: false,
          maxBookingsPerWeek: 7,
          bookingLimitEnabled: false,
          minBookingAdvanceHours: 48,
          defaultClassCapacity: 15,
          defaultLanes: 6,
        );

        final json = settings.toJson();

        expect(json['cancellation_deadline_hours'], 4);
        expect(json['max_cancellations_per_month'], 5);
        expect(json['cancellation_limit_enabled'], false);
        expect(json['max_bookings_per_week'], 7);
        expect(json['booking_limit_enabled'], false);
        expect(json['min_booking_advance_hours'], 48);
        expect(json['default_class_capacity'], 15);
        expect(json['default_lanes'], 6);
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = BusinessSettings.defaults();
        final copied = original.copyWith(
          cancellationDeadlineHours: 10,
          maxBookingsPerWeek: 5,
        );

        expect(copied.cancellationDeadlineHours, 10);
        expect(copied.maxBookingsPerWeek, 5);
        expect(copied.maxCancellationsPerMonth, 2);
        expect(copied.bookingLimitEnabled, true);
      });

      test('should keep original values when not specified', () {
        final original = BusinessSettings(
          cancellationDeadlineHours: 8,
          maxCancellationsPerMonth: 10,
        );
        final copied = original.copyWith();

        expect(copied.cancellationDeadlineHours, 8);
        expect(copied.maxCancellationsPerMonth, 10);
      });
    });

    group('messages', () {
      test('should return correct cancellation deadline message for 0 hours', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 0);
        expect(
          settings.cancellationDeadlineMessage,
          'Cancelamentos são permitidos a qualquer momento',
        );
      });

      test('should return correct cancellation deadline message for 1 hour', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 1);
        expect(
          settings.cancellationDeadlineMessage,
          'Cancelamentos só são permitidos até 1 hora antes da aula',
        );
      });

      test('should return correct cancellation deadline message for multiple hours', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 4);
        expect(
          settings.cancellationDeadlineMessage,
          'Cancelamentos só são permitidos até 4 horas antes da aula',
        );
      });

      test('should return correct booking limit message when disabled', () {
        final settings = BusinessSettings(bookingLimitEnabled: false);
        expect(settings.bookingLimitMessage, 'Sem limite de reservas por semana');
      });

      test('should return correct booking limit message for 1 booking', () {
        final settings = BusinessSettings(
          bookingLimitEnabled: true,
          maxBookingsPerWeek: 1,
        );
        expect(
          settings.bookingLimitMessage,
          'Você pode ter no máximo 1 reserva ativa por semana',
        );
      });

      test('should return correct booking limit message for multiple bookings', () {
        final settings = BusinessSettings(
          bookingLimitEnabled: true,
          maxBookingsPerWeek: 5,
        );
        expect(
          settings.bookingLimitMessage,
          'Você pode ter no máximo 5 reservas ativas por semana',
        );
      });

      test('should return correct cancellation limit message when disabled', () {
        final settings = BusinessSettings(cancellationLimitEnabled: false);
        expect(settings.cancellationLimitMessage, 'Sem limite de cancelamentos por mês');
      });

      test('should return correct cancellation limit message for 1 cancellation', () {
        final settings = BusinessSettings(
          cancellationLimitEnabled: true,
          maxCancellationsPerMonth: 1,
        );
        expect(
          settings.cancellationLimitMessage,
          'Você pode cancelar no máximo 1 vez por mês',
        );
      });

      test('should return correct min booking advance message for 0 hours', () {
        final settings = BusinessSettings(minBookingAdvanceHours: 0);
        expect(
          settings.minBookingAdvanceMessage,
          'Reservas podem ser feitas até o horário da aula',
        );
      });

      test('should return correct min booking advance message for hours less than 24', () {
        final settings = BusinessSettings(minBookingAdvanceHours: 12);
        expect(
          settings.minBookingAdvanceMessage,
          'Reservas devem ser feitas com 12 horas de antecedência',
        );
      });

      test('should return correct min booking advance message for 1 day', () {
        final settings = BusinessSettings(minBookingAdvanceHours: 24);
        expect(
          settings.minBookingAdvanceMessage,
          'Reservas devem ser feitas com 1 dia de antecedência',
        );
      });

      test('should return correct min booking advance message for multiple days', () {
        final settings = BusinessSettings(minBookingAdvanceHours: 72);
        expect(
          settings.minBookingAdvanceMessage,
          'Reservas devem ser feitas com 3 dias de antecedência',
        );
      });
    });

    group('canCancelBooking', () {
      test('should return true when deadline is 0', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 0);
        final classTime = DateTime.now().add(const Duration(minutes: 30));

        expect(settings.canCancelBooking(classTime), true);
      });

      test('should return true when within deadline', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 2);
        final classTime = DateTime.now().add(const Duration(hours: 3));

        expect(settings.canCancelBooking(classTime), true);
      });

      test('should return false when past deadline', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 2);
        final classTime = DateTime.now().add(const Duration(hours: 1));

        expect(settings.canCancelBooking(classTime), false);
      });
    });

    group('canBookClass', () {
      test('should return true when min advance is 0', () {
        final settings = BusinessSettings(minBookingAdvanceHours: 0);
        final classTime = DateTime.now().add(const Duration(minutes: 30));

        expect(settings.canBookClass(classTime), true);
      });

      test('should return true when within min advance', () {
        final settings = BusinessSettings(minBookingAdvanceHours: 24);
        final classTime = DateTime.now().add(const Duration(hours: 48));

        expect(settings.canBookClass(classTime), true);
      });

      test('should return false when past min advance', () {
        final settings = BusinessSettings(minBookingAdvanceHours: 24);
        final classTime = DateTime.now().add(const Duration(hours: 12));

        expect(settings.canBookClass(classTime), false);
      });
    });

    group('timeUntilCancellationDeadline', () {
      test('should return null when deadline is 0', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 0);
        final classTime = DateTime.now().add(const Duration(hours: 3));

        expect(settings.timeUntilCancellationDeadline(classTime), null);
      });

      test('should return remaining time when within deadline', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 2);
        final classTime = DateTime.now().add(const Duration(hours: 5));

        final remaining = settings.timeUntilCancellationDeadline(classTime);

        expect(remaining, isNotNull);
        expect(remaining!.inHours, greaterThanOrEqualTo(2));
      });

      test('should return null when past deadline', () {
        final settings = BusinessSettings(cancellationDeadlineHours: 2);
        final classTime = DateTime.now().add(const Duration(hours: 1));

        expect(settings.timeUntilCancellationDeadline(classTime), null);
      });
    });
  });
}
