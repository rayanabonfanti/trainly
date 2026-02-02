import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainly/models/class_type.dart';

void main() {
  group('ClassType', () {
    group('constructor', () {
      test('should create ClassType with required properties', () {
        const classType = ClassType(id: 'test-id', name: 'Test Name');

        expect(classType.id, equals('test-id'));
        expect(classType.name, equals('Test Name'));
        expect(classType.icon, equals('school'));
      });

      test('should create ClassType with custom icon', () {
        const classType = ClassType(
          id: 'test-id',
          name: 'Test Name',
          icon: 'pool',
        );

        expect(classType.icon, equals('pool'));
      });
    });

    group('defaults', () {
      test('should have default class types', () {
        expect(ClassType.defaults, isNotEmpty);
        expect(ClassType.defaults.length, equals(2));
      });

      test('should have class type in defaults', () {
        final classType = ClassType.defaults.firstWhere((t) => t.id == 'class');

        expect(classType.name, equals('Aula'));
        expect(classType.icon, equals('school'));
      });

      test('should have free type in defaults', () {
        final freeType = ClassType.defaults.firstWhere((t) => t.id == 'free');

        expect(freeType.name, equals('Treino Livre'));
        expect(freeType.icon, equals('fitness_center'));
      });
    });

    group('fromJson', () {
      test('should create ClassType from complete JSON', () {
        final json = {
          'id': 'custom-type',
          'name': 'Custom Type',
          'icon': 'fitness_center',
        };

        final classType = ClassType.fromJson(json);

        expect(classType.id, equals('custom-type'));
        expect(classType.name, equals('Custom Type'));
        expect(classType.icon, equals('fitness_center'));
      });

      test('should use default icon when not provided', () {
        final json = {
          'id': 'custom-type',
          'name': 'Custom Type',
        };

        final classType = ClassType.fromJson(json);

        expect(classType.icon, equals('school'));
      });

      test('should handle null icon', () {
        final json = {
          'id': 'custom-type',
          'name': 'Custom Type',
          'icon': null,
        };

        final classType = ClassType.fromJson(json);

        expect(classType.icon, equals('school'));
      });
    });

    group('toJson', () {
      test('should convert ClassType to JSON correctly', () {
        const classType = ClassType(
          id: 'test-id',
          name: 'Test Name',
          icon: 'pool',
        );

        final json = classType.toJson();

        expect(json['id'], equals('test-id'));
        expect(json['name'], equals('Test Name'));
        expect(json['icon'], equals('pool'));
      });
    });

    group('fromJsonList', () {
      test('should return defaults when list is null', () {
        final result = ClassType.fromJsonList(null);

        expect(result, equals(ClassType.defaults));
      });

      test('should return defaults when list is empty', () {
        final result = ClassType.fromJsonList([]);

        expect(result, equals(ClassType.defaults));
      });

      test('should parse list of JSON objects', () {
        final jsonList = [
          {'id': 'type1', 'name': 'Type 1', 'icon': 'school'},
          {'id': 'type2', 'name': 'Type 2', 'icon': 'pool'},
        ];

        final result = ClassType.fromJsonList(jsonList);

        expect(result.length, equals(2));
        expect(result[0].id, equals('type1'));
        expect(result[1].id, equals('type2'));
      });
    });

    group('toJsonList', () {
      test('should convert list of ClassTypes to JSON', () {
        const types = [
          ClassType(id: 'type1', name: 'Type 1', icon: 'school'),
          ClassType(id: 'type2', name: 'Type 2', icon: 'pool'),
        ];

        final result = ClassType.toJsonList(types);

        expect(result.length, equals(2));
        expect(result[0]['id'], equals('type1'));
        expect(result[1]['id'], equals('type2'));
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        const type1 = ClassType(id: 'test', name: 'Name 1');
        const type2 = ClassType(id: 'test', name: 'Name 2');

        expect(type1, equals(type2));
      });

      test('should not be equal when ids differ', () {
        const type1 = ClassType(id: 'test1', name: 'Name');
        const type2 = ClassType(id: 'test2', name: 'Name');

        expect(type1, isNot(equals(type2)));
      });

      test('should have consistent hashCode', () {
        const type1 = ClassType(id: 'test', name: 'Name 1');
        const type2 = ClassType(id: 'test', name: 'Name 2');

        expect(type1.hashCode, equals(type2.hashCode));
      });
    });

    group('copyWith', () {
      test('should copy with new id', () {
        const original = ClassType(id: 'old', name: 'Name', icon: 'school');

        final copy = original.copyWith(id: 'new');

        expect(copy.id, equals('new'));
        expect(copy.name, equals('Name'));
        expect(copy.icon, equals('school'));
      });

      test('should copy with new name', () {
        const original = ClassType(id: 'id', name: 'Old Name', icon: 'school');

        final copy = original.copyWith(name: 'New Name');

        expect(copy.id, equals('id'));
        expect(copy.name, equals('New Name'));
        expect(copy.icon, equals('school'));
      });

      test('should copy with new icon', () {
        const original = ClassType(id: 'id', name: 'Name', icon: 'school');

        final copy = original.copyWith(icon: 'pool');

        expect(copy.id, equals('id'));
        expect(copy.name, equals('Name'));
        expect(copy.icon, equals('pool'));
      });

      test('should keep original values when not overridden', () {
        const original = ClassType(id: 'id', name: 'Name', icon: 'pool');

        final copy = original.copyWith();

        expect(copy.id, equals('id'));
        expect(copy.name, equals('Name'));
        expect(copy.icon, equals('pool'));
      });
    });

    group('iconData', () {
      test('should return correct IconData for school', () {
        const classType = ClassType(id: 'test', name: 'Test', icon: 'school');

        expect(classType.iconData, equals(Icons.school));
      });

      test('should return correct IconData for pool', () {
        const classType = ClassType(id: 'test', name: 'Test', icon: 'pool');

        expect(classType.iconData, equals(Icons.pool));
      });

      test('should return category icon for unknown icon name', () {
        const classType = ClassType(id: 'test', name: 'Test', icon: 'unknown');

        expect(classType.iconData, equals(Icons.category));
      });
    });
  });

  group('ClassTypeIcons', () {
    group('getIconData', () {
      test('should return school icon', () {
        expect(ClassTypeIcons.getIconData('school'), equals(Icons.school));
      });

      test('should return pool icon', () {
        expect(ClassTypeIcons.getIconData('pool'), equals(Icons.pool));
      });

      test('should return fitness_center icon', () {
        expect(ClassTypeIcons.getIconData('fitness_center'), equals(Icons.fitness_center));
      });

      test('should return sports icon', () {
        expect(ClassTypeIcons.getIconData('sports'), equals(Icons.sports));
      });

      test('should return directions_run icon', () {
        expect(ClassTypeIcons.getIconData('directions_run'), equals(Icons.directions_run));
      });

      test('should return water icon', () {
        expect(ClassTypeIcons.getIconData('water'), equals(Icons.water));
      });

      test('should return waves icon', () {
        expect(ClassTypeIcons.getIconData('waves'), equals(Icons.waves));
      });

      test('should return child_care icon', () {
        expect(ClassTypeIcons.getIconData('child_care'), equals(Icons.child_care));
      });

      test('should return elderly icon', () {
        expect(ClassTypeIcons.getIconData('elderly'), equals(Icons.elderly));
      });

      test('should return accessibility icon', () {
        expect(ClassTypeIcons.getIconData('accessibility'), equals(Icons.accessibility));
      });

      test('should return category for unknown icon name', () {
        expect(ClassTypeIcons.getIconData('unknown'), equals(Icons.category));
      });
    });

    group('availableIcons', () {
      test('should have available icons list', () {
        expect(ClassTypeIcons.availableIcons, isNotEmpty);
      });

      test('should have correct structure for each icon', () {
        for (final icon in ClassTypeIcons.availableIcons) {
          expect(icon.containsKey('name'), isTrue);
          expect(icon.containsKey('label'), isTrue);
          expect(icon['name'], isA<String>());
          expect(icon['label'], isA<String>());
        }
      });

      test('should include school icon', () {
        final schoolIcon = ClassTypeIcons.availableIcons.firstWhere(
          (i) => i['name'] == 'school',
        );

        expect(schoolIcon['label'], equals('Escola'));
      });

      test('should include pool icon', () {
        final poolIcon = ClassTypeIcons.availableIcons.firstWhere(
          (i) => i['name'] == 'pool',
        );

        expect(poolIcon['label'], equals('Piscina'));
      });
    });
  });
}
