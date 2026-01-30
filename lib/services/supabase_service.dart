import '../core/supabase_client.dart';
import '../models/class_item.dart';
import '../models/time_slot.dart';
import '../models/training_type.dart';

/// Serviço para comunicação com o Supabase
class SupabaseService {
  /// Busca todos os tipos de treino
  Future<List<TrainingType>> getTrainingTypes() async {
    final response = await supabase
        .from('training_types')
        .select()
        .order('name');

    return (response as List)
        .map((json) => TrainingType.fromJson(json))
        .toList();
  }

  /// Busca todos os horários disponíveis
  Future<List<TimeSlot>> getTimeSlots() async {
    final response = await supabase
        .from('time_slots')
        .select()
        .order('start_time');

    return (response as List)
        .map((json) => TimeSlot.fromJson(json))
        .toList();
  }

  /// Busca aulas de uma data específica com dados relacionados
  Future<List<ClassItem>> getClassesByDate(DateTime date) async {
    final dateString = _formatDate(date);

    final response = await supabase
        .from('classes')
        .select('''
          id,
          date,
          capacity,
          training_types (
            id,
            name
          ),
          time_slots (
            id,
            start_time,
            end_time
          )
        ''')
        .eq('date', dateString)
        .order('time_slot_id');

    return (response as List)
        .map((json) => ClassItem.fromJson(json))
        .toList();
  }

  /// Formata data para o padrão do Supabase (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
