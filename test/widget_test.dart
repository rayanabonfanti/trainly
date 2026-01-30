import 'package:flutter_test/flutter_test.dart';

import 'package:trainly/models/training_type.dart';
import 'package:trainly/models/time_slot.dart';

void main() {
  group('TrainingType', () {
    test('fromJson creates instance correctly', () {
      final json = {
        'id': '123',
        'name': 'CrossFit',
      };

      final trainingType = TrainingType.fromJson(json);

      expect(trainingType.id, '123');
      expect(trainingType.name, 'CrossFit');
    });
  });

  group('TimeSlot', () {
    test('formattedTime returns correct format', () {
      final timeSlot = TimeSlot(
        id: '1',
        startTime: '06:00:00',
        endTime: '07:00:00',
      );

      expect(timeSlot.formattedTime, '06:00 - 07:00');
    });
  });
}
