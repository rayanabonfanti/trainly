import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/core/security_helpers.dart';

void main() {
  group('SecurityHelpers', () {
    group('sanitizeErrorMessage', () {
      test('should return permission error for "permission" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('permission denied for user');

        expect(result, equals('Você não tem permissão para realizar esta ação'));
      });

      test('should return permission error for "policy" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('RLS policy violation');

        expect(result, equals('Você não tem permissão para realizar esta ação'));
      });

      test('should return permission error for "denied" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('access denied');

        expect(result, equals('Você não tem permissão para realizar esta ação'));
      });

      test('should return permission error for "rls" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('RLS check failed');

        expect(result, equals('Você não tem permissão para realizar esta ação'));
      });

      test('should return connection error for "network" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('network error occurred');

        expect(result, equals('Erro de conexão. Verifique sua internet e tente novamente'));
      });

      test('should return connection error for "connection" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('connection refused');

        expect(result, equals('Erro de conexão. Verifique sua internet e tente novamente'));
      });

      test('should return connection error for "socket" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('socket exception');

        expect(result, equals('Erro de conexão. Verifique sua internet e tente novamente'));
      });

      test('should return connection error for "timeout" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('request timeout');

        expect(result, equals('Erro de conexão. Verifique sua internet e tente novamente'));
      });

      test('should return configuration error for "relation" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('relation "users" does not exist');

        expect(result, equals('Erro de configuração do sistema. Contate o suporte'));
      });

      test('should return configuration error for "column" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('column "name" does not exist');

        expect(result, equals('Erro de configuração do sistema. Contate o suporte'));
      });

      test('should return configuration error for "table" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('table not found');

        expect(result, equals('Erro de configuração do sistema. Contate o suporte'));
      });

      test('should return configuration error for "schema" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('schema validation failed');

        expect(result, equals('Erro de configuração do sistema. Contate o suporte'));
      });

      test('should return duplicate error for "duplicate" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('duplicate key value');

        expect(result, equals('Este registro já existe'));
      });

      test('should return duplicate error for "unique" keyword', () {
        final result = SecurityHelpers.sanitizeErrorMessage('unique constraint violation');

        expect(result, equals('Este registro já existe'));
      });

      test('should return generic error for unknown errors', () {
        final result = SecurityHelpers.sanitizeErrorMessage('some random internal error xyz123');

        expect(result, equals('Ocorreu um erro. Tente novamente'));
      });

      test('should handle empty error message', () {
        final result = SecurityHelpers.sanitizeErrorMessage('');

        expect(result, equals('Ocorreu um erro. Tente novamente'));
      });

      test('should be case insensitive', () {
        final result = SecurityHelpers.sanitizeErrorMessage('PERMISSION DENIED');

        expect(result, equals('Você não tem permissão para realizar esta ação'));
      });

      test('should prioritize first matching error type', () {
        // This contains both "permission" and "network", but "permission" should match first
        final result = SecurityHelpers.sanitizeErrorMessage('permission network error');

        expect(result, equals('Você não tem permissão para realizar esta ação'));
      });
    });

    group('clearAdminCache', () {
      test('should not throw when clearing cache', () {
        expect(() => SecurityHelpers.clearAdminCache(), returnsNormally);
      });
    });
  });
}
