import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/core/input_validator.dart';

void main() {
  group('InputValidator', () {
    group('validateId', () {
      test('should return error when id is null', () {
        final result = InputValidator.validateId(null, 'ID');

        expect(result, equals('ID é obrigatório'));
      });

      test('should return error when id is empty', () {
        final result = InputValidator.validateId('', 'ID');

        expect(result, equals('ID é obrigatório'));
      });

      test('should return error when id is whitespace only', () {
        final result = InputValidator.validateId('   ', 'ID');

        expect(result, equals('ID é obrigatório'));
      });

      test('should return error when id exceeds max length', () {
        final longId = 'a' * 37;

        final result = InputValidator.validateId(longId, 'ID');

        expect(result, equals('ID inválido'));
      });

      test('should return error for invalid UUID format', () {
        final result = InputValidator.validateId('invalid-uuid', 'ID');

        expect(result, equals('ID inválido'));
      });

      test('should return null for valid UUID', () {
        const validUuid = '123e4567-e89b-12d3-a456-426614174000';

        final result = InputValidator.validateId(validUuid, 'ID');

        expect(result, isNull);
      });

      test('should return null for valid UUID with uppercase', () {
        const validUuid = '123E4567-E89B-12D3-A456-426614174000';

        final result = InputValidator.validateId(validUuid, 'ID');

        expect(result, isNull);
      });
    });

    group('validateIdList', () {
      test('should return error when list is null', () {
        final result = InputValidator.validateIdList(null, 'IDs');

        expect(result, equals('IDs é obrigatório'));
      });

      test('should return error when list is empty', () {
        final result = InputValidator.validateIdList([], 'IDs');

        expect(result, equals('IDs é obrigatório'));
      });

      test('should return error when list exceeds max items', () {
        final ids = List.generate(101, (i) => '123e4567-e89b-12d3-a456-42661417400$i');

        final result = InputValidator.validateIdList(ids, 'IDs');

        expect(result, equals('Limite de 100 itens excedido'));
      });

      test('should return error when list exceeds custom max items', () {
        final ids = List.generate(6, (i) => '123e4567-e89b-12d3-a456-42661417400$i');

        final result = InputValidator.validateIdList(ids, 'IDs', maxItems: 5);

        expect(result, equals('Limite de 5 itens excedido'));
      });

      test('should return error when any id is invalid', () {
        final ids = [
          '123e4567-e89b-12d3-a456-426614174000',
          'invalid-id',
        ];

        final result = InputValidator.validateIdList(ids, 'IDs');

        expect(result, equals('IDs inválido'));
      });

      test('should return null for valid id list', () {
        final ids = [
          '123e4567-e89b-12d3-a456-426614174000',
          '223e4567-e89b-12d3-a456-426614174001',
        ];

        final result = InputValidator.validateIdList(ids, 'IDs');

        expect(result, isNull);
      });
    });

    group('validateName', () {
      test('should return null when name is null', () {
        final result = InputValidator.validateName(null);

        expect(result, isNull);
      });

      test('should return null when name is empty', () {
        final result = InputValidator.validateName('');

        expect(result, isNull);
      });

      test('should return error when name exceeds max length', () {
        final longName = 'a' * 101;

        final result = InputValidator.validateName(longName);

        expect(result, contains('Nome muito longo'));
        expect(result, contains('100'));
      });

      test('should return error when name contains script tag', () {
        final result = InputValidator.validateName('<script>alert(1)</script>');

        expect(result, equals('Nome contém caracteres inválidos'));
      });

      test('should return error when name contains javascript:', () {
        final result = InputValidator.validateName('javascript:alert(1)');

        expect(result, equals('Nome contém caracteres inválidos'));
      });

      test('should return error when name contains SQL injection pattern', () {
        final result = InputValidator.validateName("'; DROP TABLE users;--");

        expect(result, equals('Nome contém caracteres inválidos'));
      });

      test('should return null for valid name', () {
        final result = InputValidator.validateName('João Silva');

        expect(result, isNull);
      });

      test('should return null for name with special characters', () {
        final result = InputValidator.validateName('José María García');

        expect(result, isNull);
      });
    });

    group('validateEmail', () {
      test('should return error when email is null', () {
        final result = InputValidator.validateEmail(null);

        expect(result, equals('Email é obrigatório'));
      });

      test('should return error when email is empty', () {
        final result = InputValidator.validateEmail('');

        expect(result, equals('Email é obrigatório'));
      });

      test('should return error when email exceeds max length', () {
        final longEmail = '${'a' * 250}@example.com';

        final result = InputValidator.validateEmail(longEmail);

        expect(result, equals('Email muito longo'));
      });

      test('should return error for invalid email format', () {
        final result = InputValidator.validateEmail('invalid-email');

        expect(result, equals('Email inválido'));
      });

      test('should return error for email without @', () {
        final result = InputValidator.validateEmail('emailexample.com');

        expect(result, equals('Email inválido'));
      });

      test('should return error for email without domain', () {
        final result = InputValidator.validateEmail('email@');

        expect(result, equals('Email inválido'));
      });

      test('should return null for valid email', () {
        final result = InputValidator.validateEmail('user@example.com');

        expect(result, isNull);
      });

      test('should return null for valid email with subdomain', () {
        final result = InputValidator.validateEmail('user@mail.example.com');

        expect(result, isNull);
      });

      test('should return null for valid email with plus sign', () {
        final result = InputValidator.validateEmail('user+tag@example.com');

        expect(result, isNull);
      });
    });

    group('validatePhone', () {
      test('should return null when phone is null', () {
        final result = InputValidator.validatePhone(null);

        expect(result, isNull);
      });

      test('should return null when phone is empty', () {
        final result = InputValidator.validatePhone('');

        expect(result, isNull);
      });

      test('should return error when phone exceeds max length', () {
        final longPhone = '1' * 21;

        final result = InputValidator.validatePhone(longPhone);

        expect(result, equals('Telefone muito longo'));
      });

      test('should return error when phone has too few digits', () {
        final result = InputValidator.validatePhone('123456789');

        expect(result, equals('Telefone inválido'));
      });

      test('should return error when phone has too many digits', () {
        final result = InputValidator.validatePhone('1234567890123456');

        expect(result, equals('Telefone inválido'));
      });

      test('should return null for valid 10 digit phone', () {
        final result = InputValidator.validatePhone('1199998888');

        expect(result, isNull);
      });

      test('should return null for valid 11 digit phone', () {
        final result = InputValidator.validatePhone('11999998888');

        expect(result, isNull);
      });

      test('should return null for formatted phone', () {
        final result = InputValidator.validatePhone('(11) 99999-8888');

        expect(result, isNull);
      });

      test('should return null for phone with country code', () {
        final result = InputValidator.validatePhone('+55 11 99999-8888');

        expect(result, isNull);
      });
    });

    group('validateUrl', () {
      test('should return null when url is null', () {
        final result = InputValidator.validateUrl(null);

        expect(result, isNull);
      });

      test('should return null when url is empty', () {
        final result = InputValidator.validateUrl('');

        expect(result, isNull);
      });

      test('should return error when url exceeds max length', () {
        final longUrl = 'https://example.com/${'a' * 2050}';

        final result = InputValidator.validateUrl(longUrl);

        expect(result, equals('URL muito longa'));
      });

      test('should return error for url without scheme', () {
        final result = InputValidator.validateUrl('example.com');

        expect(result, equals('URL inválida'));
      });

      test('should return error for url with invalid scheme', () {
        final result = InputValidator.validateUrl('ftp://example.com');

        expect(result, equals('URL inválida'));
      });

      test('should return null for valid http url', () {
        final result = InputValidator.validateUrl('http://example.com');

        expect(result, isNull);
      });

      test('should return null for valid https url', () {
        final result = InputValidator.validateUrl('https://example.com');

        expect(result, isNull);
      });

      test('should return null for url with path', () {
        final result = InputValidator.validateUrl('https://example.com/path/to/resource');

        expect(result, isNull);
      });

      test('should return null for url with query params', () {
        final result = InputValidator.validateUrl('https://example.com?param=value');

        expect(result, isNull);
      });
    });

    group('validateAvatarExtension', () {
      test('should return error for invalid extension', () {
        final result = InputValidator.validateAvatarExtension('file.pdf');

        expect(result, contains('Tipo de arquivo não permitido'));
      });

      test('should return error for executable file', () {
        final result = InputValidator.validateAvatarExtension('file.exe');

        expect(result, contains('Tipo de arquivo não permitido'));
      });

      test('should return null for jpg extension', () {
        final result = InputValidator.validateAvatarExtension('image.jpg');

        expect(result, isNull);
      });

      test('should return null for jpeg extension', () {
        final result = InputValidator.validateAvatarExtension('image.jpeg');

        expect(result, isNull);
      });

      test('should return null for png extension', () {
        final result = InputValidator.validateAvatarExtension('image.png');

        expect(result, isNull);
      });

      test('should return null for gif extension', () {
        final result = InputValidator.validateAvatarExtension('image.gif');

        expect(result, isNull);
      });

      test('should return null for webp extension', () {
        final result = InputValidator.validateAvatarExtension('image.webp');

        expect(result, isNull);
      });

      test('should return null for uppercase extension', () {
        final result = InputValidator.validateAvatarExtension('image.PNG');

        expect(result, isNull);
      });
    });

    group('validateFileSize', () {
      test('should return error when file exceeds max size', () {
        const fileSize = 6 * 1024 * 1024; // 6MB
        const maxSize = 5 * 1024 * 1024; // 5MB

        final result = InputValidator.validateFileSize(fileSize, maxSize);

        expect(result, contains('Arquivo muito grande'));
        expect(result, contains('5.0MB'));
      });

      test('should return null when file is within limit', () {
        const fileSize = 4 * 1024 * 1024; // 4MB
        const maxSize = 5 * 1024 * 1024; // 5MB

        final result = InputValidator.validateFileSize(fileSize, maxSize);

        expect(result, isNull);
      });

      test('should return null when file is exactly at limit', () {
        const size = 5 * 1024 * 1024; // 5MB

        final result = InputValidator.validateFileSize(size, size);

        expect(result, isNull);
      });
    });

    group('sanitizeFileName', () {
      test('should replace spaces with underscores', () {
        final result = InputValidator.sanitizeFileName('my file name.jpg');

        expect(result, equals('my_file_name.jpg'));
      });

      test('should remove path traversal characters', () {
        final result = InputValidator.sanitizeFileName('../../../etc/passwd');

        expect(result, equals('______etc_passwd'));
      });

      test('should replace backslashes', () {
        final result = InputValidator.sanitizeFileName('path\\to\\file.jpg');

        expect(result, equals('path_to_file.jpg'));
      });

      test('should keep alphanumeric characters and dots', () {
        final result = InputValidator.sanitizeFileName('image123.jpg');

        expect(result, equals('image123.jpg'));
      });

      test('should keep hyphens', () {
        final result = InputValidator.sanitizeFileName('my-image.jpg');

        expect(result, equals('my-image.jpg'));
      });

      test('should replace special characters', () {
        final result = InputValidator.sanitizeFileName('image@#\$%.jpg');

        expect(result, equals('image____.jpg'));
      });
    });

    group('validateTitle', () {
      test('should return error when title is null', () {
        final result = InputValidator.validateTitle(null);

        expect(result, equals('Título é obrigatório'));
      });

      test('should return error when title is empty', () {
        final result = InputValidator.validateTitle('');

        expect(result, equals('Título é obrigatório'));
      });

      test('should return error when title is whitespace only', () {
        final result = InputValidator.validateTitle('   ');

        expect(result, equals('Título é obrigatório'));
      });

      test('should return error when title exceeds max length', () {
        final longTitle = 'a' * 201;

        final result = InputValidator.validateTitle(longTitle);

        expect(result, contains('Título muito longo'));
        expect(result, contains('200'));
      });

      test('should return error when title contains script tag', () {
        final result = InputValidator.validateTitle('<script>alert(1)</script>');

        expect(result, equals('Título contém caracteres inválidos'));
      });

      test('should return error when title contains onclick', () {
        final result = InputValidator.validateTitle('test onclick=alert(1)');

        expect(result, equals('Título contém caracteres inválidos'));
      });

      test('should return null for valid title', () {
        final result = InputValidator.validateTitle('Aula de Natação');

        expect(result, isNull);
      });

      test('should return null for title with numbers', () {
        final result = InputValidator.validateTitle('Aula de Natação - Turma 1');

        expect(result, isNull);
      });
    });

    group('constants', () {
      test('should have correct max ID length', () {
        expect(InputValidator.maxIdLength, equals(36));
      });

      test('should have correct max name length', () {
        expect(InputValidator.maxNameLength, equals(100));
      });

      test('should have correct max email length', () {
        expect(InputValidator.maxEmailLength, equals(254));
      });

      test('should have correct max phone length', () {
        expect(InputValidator.maxPhoneLength, equals(20));
      });

      test('should have correct max URL length', () {
        expect(InputValidator.maxUrlLength, equals(2048));
      });

      test('should have correct max title length', () {
        expect(InputValidator.maxTitleLength, equals(200));
      });

      test('should have correct max avatar size', () {
        expect(InputValidator.maxAvatarSizeBytes, equals(5 * 1024 * 1024));
      });

      test('should have allowed avatar extensions', () {
        expect(InputValidator.allowedAvatarExtensions, contains('jpg'));
        expect(InputValidator.allowedAvatarExtensions, contains('jpeg'));
        expect(InputValidator.allowedAvatarExtensions, contains('png'));
        expect(InputValidator.allowedAvatarExtensions, contains('gif'));
        expect(InputValidator.allowedAvatarExtensions, contains('webp'));
      });
    });
  });
}
