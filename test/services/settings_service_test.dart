import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/services/settings_service.dart';

void main() {
  group('SettingsResult', () {
    group('success factory', () {
      test('should create success result', () {
        final result = SettingsResult.success('Operação realizada');

        expect(result.success, true);
        expect(result.message, 'Operação realizada');
      });
    });

    group('error factory', () {
      test('should create error result', () {
        final result = SettingsResult.error('Erro na operação');

        expect(result.success, false);
        expect(result.message, 'Erro na operação');
      });
    });

    group('constructor', () {
      test('should create result with custom values', () {
        final result = SettingsResult(
          success: true,
          message: 'Mensagem personalizada',
        );

        expect(result.success, true);
        expect(result.message, 'Mensagem personalizada');
      });
    });
  });

  group('SettingsService', () {
    test('should create instance', () {
      final service = SettingsService();
      expect(service, isNotNull);
    });

    test('cachedSettings should return defaults when no cache', () {
      final service = SettingsService();
      service.clearCache();
      
      final settings = service.cachedSettings;

      expect(settings.cancellationDeadlineHours, 2);
      expect(settings.maxBookingsPerWeek, 3);
      expect(settings.maxCancellationsPerMonth, 2);
    });
  });
}
