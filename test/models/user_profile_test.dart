import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    group('fromJson', () {
      test('should create UserProfile from complete JSON', () {
        final json = {
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'email': 'user@example.com',
          'name': 'John Doe',
          'phone': '11999999999',
          'avatar_url': 'https://example.com/avatar.jpg',
          'created_at': '2024-01-15T10:00:00Z',
          'updated_at': '2024-01-16T15:30:00Z',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.id, equals('123e4567-e89b-12d3-a456-426614174000'));
        expect(profile.email, equals('user@example.com'));
        expect(profile.name, equals('John Doe'));
        expect(profile.phone, equals('11999999999'));
        expect(profile.avatarUrl, equals('https://example.com/avatar.jpg'));
        expect(profile.createdAt, isNotNull);
        expect(profile.updatedAt, isNotNull);
      });

      test('should create UserProfile with minimal JSON', () {
        final json = {
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'email': 'user@example.com',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.id, equals('123e4567-e89b-12d3-a456-426614174000'));
        expect(profile.email, equals('user@example.com'));
        expect(profile.name, isNull);
        expect(profile.phone, isNull);
        expect(profile.avatarUrl, isNull);
      });

      test('should handle null email gracefully', () {
        final json = {
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'email': null,
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.email, equals(''));
      });
    });

    group('toJson', () {
      test('should convert UserProfile to JSON correctly', () {
        final profile = UserProfile(
          id: '123',
          email: 'user@example.com',
          name: 'John Doe',
          phone: '11999999999',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        final json = profile.toJson();

        expect(json['name'], equals('John Doe'));
        expect(json['phone'], equals('11999999999'));
        expect(json['avatar_url'], equals('https://example.com/avatar.jpg'));
        // id and email should not be in toJson (they are read-only)
        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('email'), isFalse);
      });
    });

    group('copyWith', () {
      test('should create copy with updated name', () {
        final original = UserProfile(
          id: '123',
          email: 'user@example.com',
          name: 'John',
        );

        final copy = original.copyWith(name: 'Jane');

        expect(copy.name, equals('Jane'));
        expect(copy.id, equals(original.id));
        expect(copy.email, equals(original.email));
      });

      test('should keep original values when not overridden', () {
        final original = UserProfile(
          id: '123',
          email: 'user@example.com',
          name: 'John',
          phone: '11999999999',
        );

        final copy = original.copyWith(name: 'Jane');

        expect(copy.phone, equals(original.phone));
      });
    });

    group('displayName', () {
      test('should return name when available', () {
        final profile = UserProfile(
          id: '123',
          email: 'john.doe@example.com',
          name: 'John Doe',
        );

        expect(profile.displayName, equals('John Doe'));
      });

      test('should return formatted email when name is null', () {
        final profile = UserProfile(
          id: '123',
          email: 'john.doe@example.com',
        );

        expect(profile.displayName, equals('John Doe'));
      });

      test('should return formatted email when name is empty', () {
        final profile = UserProfile(
          id: '123',
          email: 'john.doe@example.com',
          name: '',
        );

        expect(profile.displayName, equals('John Doe'));
      });

      test('should handle single word email', () {
        final profile = UserProfile(
          id: '123',
          email: 'john@example.com',
        );

        expect(profile.displayName, equals('John'));
      });
    });

    group('initials', () {
      test('should return first letters of first and last name', () {
        final profile = UserProfile(
          id: '123',
          email: 'user@example.com',
          name: 'John Doe',
        );

        expect(profile.initials, equals('JD'));
      });

      test('should return single letter for single name', () {
        final profile = UserProfile(
          id: '123',
          email: 'user@example.com',
          name: 'John',
        );

        expect(profile.initials, equals('J'));
      });

      test('should return initials from email when no name', () {
        final profile = UserProfile(
          id: '123',
          email: 'john.doe@example.com',
        );

        expect(profile.initials, equals('JD'));
      });

      test('should return uppercase initials', () {
        final profile = UserProfile(
          id: '123',
          email: 'user@example.com',
          name: 'john doe',
        );

        expect(profile.initials, equals('JD'));
      });
    });
  });
}
