import '../core/booking_rules.dart';
import '../core/supabase_client.dart';
import '../models/booking.dart';
import '../models/swim_class.dart';

/// Resultado de uma operação de booking
class BookingResult {
  final bool success;
  final String message;
  final Booking? booking;

  BookingResult({
    required this.success,
    required this.message,
    this.booking,
  });

  factory BookingResult.success(String message, [Booking? booking]) {
    return BookingResult(success: true, message: message, booking: booking);
  }

  factory BookingResult.error(String message) {
    return BookingResult(success: false, message: message);
  }
}

/// Status de limites do usuário
class UserBookingLimits {
  final int activeBookingsThisWeek;
  final int cancellationsThisMonth;
  final bool canBookMore;
  final bool canCancelMore;

  UserBookingLimits({
    required this.activeBookingsThisWeek,
    required this.cancellationsThisMonth,
    required this.canBookMore,
    required this.canCancelMore,
  });
}

/// Informações de reserva com dados do aluno (para visualização admin)
class StudentBookingInfo {
  final String bookingId;
  final String classId;
  final String classTitle;
  final String classType;
  final DateTime classStartTime;
  final DateTime classEndTime;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final int bookingsThisWeek;
  final int remainingBookings; // -1 = sem limite

  StudentBookingInfo({
    required this.bookingId,
    required this.classId,
    required this.classTitle,
    required this.classType,
    required this.classStartTime,
    required this.classEndTime,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.bookingsThisWeek,
    required this.remainingBookings,
  });

  String get formattedDate {
    final day = classStartTime.day.toString().padLeft(2, '0');
    final month = classStartTime.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String get formattedTime {
    final startHour = classStartTime.hour.toString().padLeft(2, '0');
    final startMin = classStartTime.minute.toString().padLeft(2, '0');
    final endHour = classEndTime.hour.toString().padLeft(2, '0');
    final endMin = classEndTime.minute.toString().padLeft(2, '0');
    return '$startHour:$startMin - $endHour:$endMin';
  }

  String get remainingText {
    if (remainingBookings < 0) return 'Sem limite';
    if (remainingBookings == 0) return 'Limite atingido';
    if (remainingBookings == 1) return '1 restante';
    return '$remainingBookings restantes';
  }
}

/// Serviço para gerenciamento de reservas
class BookingService {
  /// Busca aulas disponíveis para agendamento (a partir de amanhã)
  /// Retorna aulas com informação de vagas e se o usuário já reservou
  Future<List<SwimClassWithAvailability>> fetchAvailableClasses() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startOfTomorrow = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    // Busca aulas
    final classesResponse = await supabase
        .from('classes')
        .select()
        .gte('start_time', startOfTomorrow.toIso8601String())
        .order('start_time', ascending: true);

    // Busca todas as reservas para calcular vagas (ignora erro se tabela não existe)
    var bookingCounts = <String, int>{};
    var userBookedClassIds = <String>{};

    try {
      final allBookingsResponse = await supabase
          .from('bookings')
          .select('class_id');

      final userBookingsResponse = await supabase
          .from('bookings')
          .select('class_id')
          .eq('user_id', userId);

      // Conta reservas por aula
      for (final booking in allBookingsResponse as List) {
        final classId = booking['class_id'] as String;
        bookingCounts[classId] = (bookingCounts[classId] ?? 0) + 1;
      }

      userBookedClassIds = (userBookingsResponse as List)
          .map((b) => b['class_id'] as String)
          .toSet();
    } catch (e) {
      // Tabela bookings não existe ainda - continua com listas vazias
    }

    return (classesResponse as List).map((json) {
      final classId = json['id'] as String;
      final capacity = json['capacity'] as int;
      final bookedCount = bookingCounts[classId] ?? 0;
      final availableSpots = capacity - bookedCount;

      return SwimClassWithAvailability(
        swimClass: SwimClass.fromJson(json),
        availableSpots: availableSpots > 0 ? availableSpots : 0,
        bookedCount: bookedCount,
        isBookedByCurrentUser: userBookedClassIds.contains(classId),
      );
    }).toList();
  }

  /// Busca aulas de uma data específica com disponibilidade
  Future<List<SwimClassWithAvailability>> fetchClassesByDateWithAvailability(
    DateTime date,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Busca aulas da data
    final classesResponse = await supabase
        .from('classes')
        .select()
        .gte('start_time', startOfDay.toIso8601String())
        .lt('start_time', endOfDay.toIso8601String())
        .order('start_time', ascending: true);

    if ((classesResponse as List).isEmpty) {
      return [];
    }

    // Pega os IDs das aulas
    final classIds = classesResponse.map((c) => c['id'] as String).toList();

    // Busca reservas (ignora erro se tabela não existe)
    var bookingCounts = <String, int>{};
    var userBookedClassIds = <String>{};

    try {
      final bookingsResponse = await supabase
          .from('bookings')
          .select('class_id')
          .inFilter('class_id', classIds);

      final userBookingsResponse = await supabase
          .from('bookings')
          .select('class_id')
          .eq('user_id', userId)
          .inFilter('class_id', classIds);

      // Conta reservas por aula
      for (final booking in bookingsResponse as List) {
        final classId = booking['class_id'] as String;
        bookingCounts[classId] = (bookingCounts[classId] ?? 0) + 1;
      }

      userBookedClassIds = (userBookingsResponse as List)
          .map((b) => b['class_id'] as String)
          .toSet();
    } catch (e) {
      // Tabela bookings não existe ainda - continua com listas vazias
    }

    return classesResponse.map((json) {
      final classId = json['id'] as String;
      final capacity = json['capacity'] as int;
      final bookedCount = bookingCounts[classId] ?? 0;
      final availableSpots = capacity - bookedCount;

      return SwimClassWithAvailability(
        swimClass: SwimClass.fromJson(json),
        availableSpots: availableSpots > 0 ? availableSpots : 0,
        bookedCount: bookedCount,
        isBookedByCurrentUser: userBookedClassIds.contains(classId),
      );
    }).toList();
  }

  /// Cria uma reserva para uma aula
  Future<BookingResult> createBooking(String classId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return BookingResult.error('Usuário não autenticado');
    }

    try {
      // Verifica limite de reservas da semana (se habilitado)
      if (BookingRules.bookingLimitEnabled) {
        final limits = await getUserBookingLimits();
        if (!limits.canBookMore) {
          return BookingResult.error(
            'Limite semanal atingido. ${BookingRules.bookingLimitMessage}',
          );
        }
      }

      // Validações client-side
      final validationResult = await _validateBooking(classId, userId);
      if (!validationResult.success) {
        return validationResult;
      }

      // Tenta criar a reserva (sem join para evitar erro se tabela não existe)
      await supabase.from('bookings').insert({
        'user_id': userId,
        'class_id': classId,
      });

      // Recarrega as configurações após operação bem-sucedida
      await BookingRules.refresh();

      return BookingResult.success('Reserva realizada com sucesso!');
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      
      // Se tabela não existe
      if (errorMessage.contains('relation') && 
          errorMessage.contains('does not exist')) {
        return BookingResult.error(
          'Sistema de reservas ainda não configurado. Entre em contato com o administrador.',
        );
      }
      
      // Se não encontrou relacionamento (tabela existe mas sem dados ainda)
      if (errorMessage.contains('could not find a relationship')) {
        return BookingResult.error(
          'Sistema de reservas ainda não configurado. Execute o SQL de bookings no Supabase.',
        );
      }
      
      return _handleError(e);
    }
  }

  /// Busca reservas do usuário atual
  Future<List<Booking>> fetchMyBookings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('bookings')
          .select('''
            *,
            classes (*)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Booking.fromJson(json)).toList();
    } catch (e) {
      // Se tabela não existe ou outro erro, retorna lista vazia
      return [];
    }
  }

  /// Busca reservas futuras do usuário (para cancelamento)
  Future<List<Booking>> fetchMyFutureBookings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final now = DateTime.now();

      final response = await supabase
          .from('bookings')
          .select('''
            *,
            classes!inner (*)
          ''')
          .eq('user_id', userId)
          .gte('classes.start_time', now.toIso8601String())
          .order('classes(start_time)', ascending: true);

      return (response as List).map((json) => Booking.fromJson(json)).toList();
    } catch (e) {
      // Se tabela não existe ou outro erro, retorna lista vazia
      return [];
    }
  }

  /// Cancela uma reserva
  /// Verifica deadline de cancelamento e limite de cancelamentos
  Future<BookingResult> cancelBooking(String bookingId, {bool forceCancel = false}) async {
    try {
      // Busca a reserva para verificar a aula
      final bookingResponse = await supabase
          .from('bookings')
          .select('*, classes(*)')
          .eq('id', bookingId)
          .single();

      final classData = bookingResponse['classes'];
      if (classData != null && !forceCancel) {
        final startTime = DateTime.parse(classData['start_time'] as String);
        
        // Verifica deadline de cancelamento
        if (!BookingRules.canCancelBooking(startTime)) {
          return BookingResult.error(
            'Não é possível cancelar. ${BookingRules.cancellationDeadlineMessage}',
          );
        }

        // Verifica limite de cancelamentos (se habilitado)
        if (BookingRules.cancellationLimitEnabled) {
          final limits = await getUserBookingLimits();
          if (!limits.canCancelMore) {
            return BookingResult.error(
              'Limite de cancelamentos atingido. ${BookingRules.cancellationLimitMessage}',
            );
          }
        }
      }

      // Registra o cancelamento para controle de limite
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        try {
          await supabase.from('cancellations').insert({
            'user_id': userId,
            'booking_id': bookingId,
            'cancelled_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          // Tabela de cancelamentos pode não existir
        }
      }

      await supabase.from('bookings').delete().eq('id', bookingId);

      return BookingResult.success('Reserva cancelada com sucesso!');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Verifica os limites de reservas e cancelamentos do usuário
  Future<UserBookingLimits> getUserBookingLimits() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return UserBookingLimits(
        activeBookingsThisWeek: 0,
        cancellationsThisMonth: 0,
        canBookMore: true,
        canCancelMore: true,
      );
    }

    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Conta reservas ativas desta semana
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id, classes!inner(start_time)')
          .eq('user_id', userId)
          .gte('classes.start_time', startOfWeek.toIso8601String())
          .gte('classes.start_time', now.toIso8601String());

      final activeBookings = (bookingsResponse as List).length;

      // Conta cancelamentos deste mês
      int cancellations = 0;
      try {
        final cancellationsResponse = await supabase
            .from('cancellations')
            .select('id')
            .eq('user_id', userId)
            .gte('cancelled_at', startOfMonth.toIso8601String());
        
        cancellations = (cancellationsResponse as List).length;
      } catch (e) {
        // Tabela de cancelamentos pode não existir
      }

      // Verifica se os limites estão habilitados
      final canBookMore = !BookingRules.bookingLimitEnabled || 
          activeBookings < BookingRules.maxBookingsPerWeek;
      final canCancelMore = !BookingRules.cancellationLimitEnabled || 
          cancellations < BookingRules.maxCancellationsPerMonth;

      return UserBookingLimits(
        activeBookingsThisWeek: activeBookings,
        cancellationsThisMonth: cancellations,
        canBookMore: canBookMore,
        canCancelMore: canCancelMore,
      );
    } catch (e) {
      return UserBookingLimits(
        activeBookingsThisWeek: 0,
        cancellationsThisMonth: 0,
        canBookMore: true,
        canCancelMore: true,
      );
    }
  }

  /// Busca reservas de uma aula específica (para admin ver quem reservou)
  Future<List<Map<String, dynamic>>> fetchBookingsForClass(String classId) async {
    try {
      final response = await supabase
          .from('bookings')
          .select('''
            id,
            user_id,
            created_at,
            profiles:user_id (
              email,
              name
            )
          ''')
          .eq('class_id', classId);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Busca todas as reservas de múltiplas aulas (para admin)
  Future<Map<String, List<Map<String, dynamic>>>> fetchAllBookingsByClass(
    List<String> classIds,
  ) async {
    if (classIds.isEmpty) return {};

    try {
      final response = await supabase
          .from('bookings')
          .select('''
            id,
            class_id,
            user_id,
            created_at,
            profiles:user_id (
              email,
              name
            )
          ''')
          .inFilter('class_id', classIds);

      final result = <String, List<Map<String, dynamic>>>{};
      for (final booking in response as List) {
        final classId = booking['class_id'] as String;
        result.putIfAbsent(classId, () => []);
        result[classId]!.add(booking);
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  /// Verifica se o usuário tem reserva para uma aula específica
  Future<bool> hasBookingForClass(String classId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await supabase
          .from('bookings')
          .select('id')
          .eq('user_id', userId)
          .eq('class_id', classId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Validação client-side antes de criar reserva
  Future<BookingResult> _validateBooking(String classId, String userId) async {
    try {
      // Busca informações da aula
      final classResponse = await supabase
          .from('classes')
          .select()
          .eq('id', classId)
          .single();

      final startTime = DateTime.parse(classResponse['start_time'] as String);
      final endTime = DateTime.parse(classResponse['end_time'] as String);
      final capacity = classResponse['capacity'] as int;

      // Verifica antecedência mínima para reservar
      if (!BookingRules.canBookClass(startTime)) {
        return BookingResult.error(
          'Não é possível reservar. ${BookingRules.minBookingAdvanceMessage}',
        );
      }

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final startOfTomorrow = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

      // Verifica se é aula futura (a partir de amanhã)
      if (startTime.isBefore(startOfTomorrow)) {
        return BookingResult.error(
          'Reservas só podem ser feitas para aulas a partir de amanhã',
        );
      }

      // Tenta validar reservas (pode falhar se tabela não existe)
      try {
        // Conta reservas existentes
        final bookingsCount = await supabase
            .from('bookings')
            .select('id')
            .eq('class_id', classId);

        final bookedCount = (bookingsCount as List).length;
        final availableSpots = capacity - bookedCount;

        // Verifica vagas
        if (availableSpots <= 0) {
          return BookingResult.error('Esta aula está lotada');
        }

        // Verifica se já reservou essa aula
        final existingBooking = await supabase
            .from('bookings')
            .select('id')
            .eq('user_id', userId)
            .eq('class_id', classId)
            .maybeSingle();

        if (existingBooking != null) {
          return BookingResult.error('Você já reservou esta aula');
        }

        // Verifica conflito de horário
        final userBookings = await supabase
            .from('bookings')
            .select('id, class_id')
            .eq('user_id', userId);

        for (final booking in userBookings as List) {
          final bookingClassId = booking['class_id'] as String;
          
          // Busca horários da aula reservada
          final bookedClass = await supabase
              .from('classes')
              .select('start_time, end_time')
              .eq('id', bookingClassId)
              .single();
          
          final existingStart = DateTime.parse(bookedClass['start_time'] as String);
          final existingEnd = DateTime.parse(bookedClass['end_time'] as String);

          // Verifica sobreposição de horários
          final hasOverlap = startTime.isBefore(existingEnd) && endTime.isAfter(existingStart);
          
          if (hasOverlap) {
            return BookingResult.error(
              'Você já possui uma reserva neste horário',
            );
          }
        }
      } catch (e) {
        // Se não conseguir validar reservas, deixa o servidor fazer
      }

      return BookingResult.success('Validação OK');
    } catch (e) {
      // Se falhar validação, tenta criar e deixa o servidor validar
      return BookingResult.success('Validação OK');
    }
  }

  /// Busca todas as reservas futuras com informações do aluno (para admin)
  /// Retorna lista de reservas agrupadas por aluno com contagem de reservas restantes
  Future<List<StudentBookingInfo>> fetchAllBookingsWithStudentInfo() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      // Busca todas as reservas futuras com informações do aluno e da aula
      final response = await supabase
          .from('bookings')
          .select('''
            id,
            user_id,
            created_at,
            classes!inner (
              id,
              title,
              type,
              start_time,
              end_time,
              capacity,
              lanes
            ),
            profiles:user_id (
              id,
              email,
              name
            )
          ''')
          .gte('classes.start_time', now.toIso8601String())
          .order('classes(start_time)', ascending: true);

      // Agrupa reservas por usuário para calcular o total
      final userBookingsCount = <String, int>{};
      for (final booking in response as List) {
        final userId = booking['user_id'] as String;
        final classData = booking['classes'];
        if (classData != null) {
          final startTime = DateTime.parse(classData['start_time'] as String);
          // Conta apenas reservas desta semana
          if (startTime.isAfter(startOfWeek)) {
            userBookingsCount[userId] = (userBookingsCount[userId] ?? 0) + 1;
          }
        }
      }

      // Converte para lista de StudentBookingInfo
      final maxBookings = BookingRules.bookingLimitEnabled 
          ? BookingRules.maxBookingsPerWeek 
          : 999;

      return response.map((json) {
        final userId = json['user_id'] as String;
        final profile = json['profiles'];
        final classData = json['classes'];
        
        final studentName = profile?['name'] as String? ?? 
            _extractNameFromEmail(profile?['email'] as String? ?? 'Aluno');
        final studentEmail = profile?['email'] as String? ?? '';
        
        final bookingsThisWeek = userBookingsCount[userId] ?? 0;
        final remainingBookings = BookingRules.bookingLimitEnabled 
            ? (maxBookings - bookingsThisWeek).clamp(0, maxBookings)
            : -1; // -1 indica sem limite

        return StudentBookingInfo(
          bookingId: json['id'] as String,
          classId: classData['id'] as String,
          classTitle: classData['title'] as String,
          classType: classData['type'] as String,
          classStartTime: DateTime.parse(classData['start_time'] as String),
          classEndTime: DateTime.parse(classData['end_time'] as String),
          studentId: userId,
          studentName: studentName,
          studentEmail: studentEmail,
          bookingsThisWeek: bookingsThisWeek,
          remainingBookings: remainingBookings,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  String _extractNameFromEmail(String email) {
    final parts = email.split('@');
    if (parts.isNotEmpty) {
      final name = parts[0].replaceAll('.', ' ');
      return name.split(' ').map((s) {
        if (s.isEmpty) return s;
        return s[0].toUpperCase() + s.substring(1).toLowerCase();
      }).join(' ');
    }
    return email;
  }

  /// Trata erros e retorna mensagem apropriada
  BookingResult _handleError(Object e) {
    final errorMessage = e.toString().toLowerCase();

    if (errorMessage.contains('unique_user_class') ||
        errorMessage.contains('duplicate')) {
      return BookingResult.error('Você já reservou esta aula');
    }

    if (errorMessage.contains('is_future_class')) {
      return BookingResult.error(
        'Reservas só podem ser feitas para aulas a partir de amanhã',
      );
    }

    if (errorMessage.contains('has_available_spots')) {
      return BookingResult.error('Esta aula está lotada');
    }

    if (errorMessage.contains('has_time_conflict')) {
      return BookingResult.error('Você já possui uma reserva neste horário');
    }

    if (errorMessage.contains('permission') ||
        errorMessage.contains('policy') ||
        errorMessage.contains('denied') ||
        errorMessage.contains('rls')) {
      return BookingResult.error(
        'Não foi possível realizar a reserva. Verifique as regras.',
      );
    }

    return BookingResult.error('Erro ao processar reserva: $e');
  }
}
