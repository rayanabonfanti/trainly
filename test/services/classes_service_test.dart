import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/services/classes_service.dart';

void main() {
  group('ClassOperationResult', () {
    group('factory constructors', () {
      test('success should create successful result', () {
        final result = ClassOperationResult.success('Aula criada!');

        expect(result.success, isTrue);
        expect(result.message, equals('Aula criada!'));
        expect(result.swimClass, isNull);
      });

      test('error should create failed result', () {
        final result = ClassOperationResult.error('Erro de validação');

        expect(result.success, isFalse);
        expect(result.message, equals('Erro de validação'));
        expect(result.swimClass, isNull);
      });
    });

    group('properties', () {
      test('should store all properties correctly', () {
        final result = ClassOperationResult(
          success: true,
          message: 'Operação concluída',
          swimClass: null,
        );

        expect(result.success, isTrue);
        expect(result.message, equals('Operação concluída'));
      });
    });
  });
}
