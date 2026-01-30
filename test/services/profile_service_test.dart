import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/services/profile_service.dart';

void main() {
  group('ProfileResult', () {
    group('factory constructors', () {
      test('success should create successful result', () {
        final result = ProfileResult.success('Perfil atualizado!');

        expect(result.success, isTrue);
        expect(result.message, equals('Perfil atualizado!'));
        expect(result.profile, isNull);
      });

      test('error should create failed result', () {
        final result = ProfileResult.error('Erro ao salvar');

        expect(result.success, isFalse);
        expect(result.message, equals('Erro ao salvar'));
        expect(result.profile, isNull);
      });
    });

    group('properties', () {
      test('should store all properties correctly', () {
        final result = ProfileResult(
          success: true,
          message: 'OK',
          profile: null,
        );

        expect(result.success, isTrue);
        expect(result.message, equals('OK'));
      });
    });
  });
}
