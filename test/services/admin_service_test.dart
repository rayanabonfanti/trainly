import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/services/admin_service.dart';

void main() {
  group('UserProfile (AdminService)', () {
    group('fromJson', () {
      test('should create UserProfile from complete JSON', () {
        final json = {
          'id': 'user-123',
          'email': 'admin@example.com',
          'name': 'Admin User',
          'role': 'admin',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.id, equals('user-123'));
        expect(profile.email, equals('admin@example.com'));
        expect(profile.name, equals('Admin User'));
        expect(profile.role, equals('admin'));
      });

      test('should default role to student when not provided', () {
        final json = {
          'id': 'user-123',
          'email': 'user@example.com',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.role, equals('student'));
      });

      test('should handle null name', () {
        final json = {
          'id': 'user-123',
          'email': 'user@example.com',
          'name': null,
          'role': 'student',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.name, isNull);
      });
    });

    group('isAdmin', () {
      test('should return true when role is admin', () {
        final profile = UserProfile(
          id: 'user-123',
          email: 'admin@example.com',
          role: 'admin',
        );

        expect(profile.isAdmin, isTrue);
      });

      test('should return false when role is student', () {
        final profile = UserProfile(
          id: 'user-123',
          email: 'user@example.com',
          role: 'student',
        );

        expect(profile.isAdmin, isFalse);
      });

      test('should return false for any other role', () {
        final profile = UserProfile(
          id: 'user-123',
          email: 'user@example.com',
          role: 'instructor',
        );

        expect(profile.isAdmin, isFalse);
      });
    });
  });

  group('PromotionResult', () {
    group('factory constructors', () {
      test('success should create successful result with message', () {
        final profile = UserProfile(
          id: 'user-123',
          email: 'user@example.com',
          role: 'admin',
        );

        final result = PromotionResult.success(profile);

        expect(result.success, isTrue);
        expect(result.message, contains('promovido'));
        expect(result.message, contains('admin'));
        expect(result.profile, equals(profile));
      });

      test('userNotFound should create failed result', () {
        final result = PromotionResult.userNotFound('notfound@example.com');

        expect(result.success, isFalse);
        expect(result.message, contains('não encontrado'));
        expect(result.profile, isNull);
      });

      test('alreadyAdmin should create failed result', () {
        final result = PromotionResult.alreadyAdmin('admin@example.com');

        expect(result.success, isFalse);
        expect(result.message, contains('já é um administrador'));
      });

      test('permissionDenied should create failed result', () {
        final result = PromotionResult.permissionDenied();

        expect(result.success, isFalse);
        expect(result.message, contains('permissão'));
      });

      test('error should create failed result with generic message for security', () {
        final result = PromotionResult.error('Database connection failed');

        expect(result.success, isFalse);
        expect(result.message, contains('Não foi possível promover'));
      });

      test('searchError should create failed result with generic message for security', () {
        final result = PromotionResult.searchError('Query timeout');

        expect(result.success, isFalse);
        expect(result.message, contains('Erro ao buscar'));
      });

      test('invalidEmail should create failed result', () {
        final result = PromotionResult.invalidEmail();

        expect(result.success, isFalse);
        expect(result.message, contains('Email inválido'));
      });
    });
  });
}
