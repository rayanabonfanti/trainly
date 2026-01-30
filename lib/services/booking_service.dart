import '../core/booking_rules.dart';
import '../core/input_validator.dart';
import '../core/security_helpers.dart';
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
    // Validação de input
    final idError = InputValidator.validateId(classId, 'ID da aula');
    if (idError != null) {
      return BookingResult.error(idError);
    }

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
          'Sistema de reservas ainda não configurado. Entre em contato com o administrador.',
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
      // Busca as reservas do usuário
      final bookingsResponse = await supabase
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final bookings = bookingsResponse as List;
      if (bookings.isEmpty) return [];

      // Busca os IDs das aulas
      final classIds = bookings
          .map((b) => b['class_id'] as String)
          .toSet()
          .toList();

      // Busca as aulas separadamente
      final classesResponse = await supabase
          .from('classes')
          .select()
          .inFilter('id', classIds);

      // Cria um mapa de aulas por ID
      final classesMap = <String, Map<String, dynamic>>{};
      for (final classData in classesResponse as List) {
        classesMap[classData['id'] as String] = classData;
      }

      // Combina os dados
      return bookings.map((bookingJson) {
        final classId = bookingJson['class_id'] as String;
        final classData = classesMap[classId];
        
        // Adiciona os dados da aula ao booking
        final combinedJson = Map<String, dynamic>.from(bookingJson);
        combinedJson['classes'] = classData;
        
        return Booking.fromJson(combinedJson);
      }).toList();
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

      // Busca as reservas do usuário
      final bookingsResponse = await supabase
          .from('bookings')
          .select()
          .eq('user_id', userId);

      final bookings = bookingsResponse as List;
      if (bookings.isEmpty) return [];

      // Busca os IDs das aulas
      final classIds = bookings
          .map((b) => b['class_id'] as String)
          .toSet()
          .toList();

      // Busca as aulas futuras
      final classesResponse = await supabase
          .from('classes')
          .select()
          .inFilter('id', classIds)
          .gte('start_time', now.toIso8601String())
          .order('start_time', ascending: true);

      // Cria um mapa de aulas por ID
      final classesMap = <String, Map<String, dynamic>>{};
      for (final classData in classesResponse as List) {
        classesMap[classData['id'] as String] = classData;
      }

      // Combina os dados (apenas reservas com aulas futuras)
      final result = <Booking>[];
      for (final bookingJson in bookings) {
        final classId = bookingJson['class_id'] as String;
        final classData = classesMap[classId];
        
        // Só inclui se a aula existe e é futura
        if (classData != null) {
          final combinedJson = Map<String, dynamic>.from(bookingJson);
          combinedJson['classes'] = classData;
          result.add(Booking.fromJson(combinedJson));
        }
      }

      // Ordena por horário de início da aula
      result.sort((a, b) {
        final aTime = a.swimClass?.startTime ?? DateTime.now();
        final bTime = b.swimClass?.startTime ?? DateTime.now();
        return aTime.compareTo(bTime);
      });

      return result;
    } catch (e) {
      // Se tabela não existe ou outro erro, retorna lista vazia
      return [];
    }
  }

  /// Cancela uma reserva
  /// Verifica ownership, deadline de cancelamento e limite de cancelamentos
  Future<BookingResult> cancelBooking(String bookingId, {bool forceCancel = false}) async {
    // Validação de input
    final idError = InputValidator.validateId(bookingId, 'ID da reserva');
    if (idError != null) {
      return BookingResult.error(idError);
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return BookingResult.error('Usuário não autenticado');
    }

    try {
      // Busca a reserva primeiro (sem join)
      final bookingResponse = await supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .maybeSingle();

      if (bookingResponse == null) {
        return BookingResult.error('Reserva não encontrada');
      }

      // SEGURANÇA: Verifica se o usuário é o dono da reserva
      final bookingUserId = bookingResponse['user_id'] as String;
      final isOwner = bookingUserId == userId;
      final isAdmin = await SecurityHelpers.isCurrentUserAdmin();

      if (!isOwner && !isAdmin) {
        return BookingResult.error('Você não tem permissão para cancelar esta reserva');
      }

      final classId = bookingResponse['class_id'] as String;

      // Busca os dados da aula separadamente
      Map<String, dynamic>? classData;
      try {
        final classResponse = await supabase
            .from('classes')
            .select()
            .eq('id', classId)
            .single();
        classData = classResponse;
      } catch (e) {
        // Aula pode não existir mais
      }

      // Regras de cancelamento só se aplicam ao dono (não admin forçando)
      if (classData != null && !forceCancel && isOwner && !isAdmin) {
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

      // Registra o cancelamento para controle de limite (apenas para o dono)
      if (isOwner) {
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

      // Busca reservas do usuário
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id, class_id')
          .eq('user_id', userId);

      final bookings = bookingsResponse as List;
      int activeBookings = 0;

      if (bookings.isNotEmpty) {
        // Busca os IDs das aulas
        final classIds = bookings
            .map((b) => b['class_id'] as String)
            .toSet()
            .toList();

        // Busca aulas futuras desta semana
        final classesResponse = await supabase
            .from('classes')
            .select('id')
            .inFilter('id', classIds)
            .gte('start_time', startOfWeek.toIso8601String())
            .gte('start_time', now.toIso8601String());

        final futureClassIds = (classesResponse as List)
            .map((c) => c['id'] as String)
            .toSet();

        // Conta quantas reservas são para aulas futuras desta semana
        activeBookings = bookings
            .where((b) => futureClassIds.contains(b['class_id'] as String))
            .length;
      }

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
  /// REQUER: Usuário autenticado como admin
  Future<List<Map<String, dynamic>>> fetchBookingsForClass(String classId) async {
    // Validação de input
    final idError = InputValidator.validateId(classId, 'ID da aula');
    if (idError != null) {
      return [];
    }

    // SEGURANÇA: Verifica se é admin antes de expor dados de usuários
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return [];
    }

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
  /// REQUER: Usuário autenticado como admin
  Future<Map<String, List<Map<String, dynamic>>>> fetchAllBookingsByClass(
    List<String> classIds,
  ) async {
    if (classIds.isEmpty) return {};

    // Validação de input
    final idsError = InputValidator.validateIdList(classIds, 'IDs das aulas');
    if (idsError != null) {
      return {};
    }

    // SEGURANÇA: Verifica se é admin antes de expor dados de usuários
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return {};
    }

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
    // Validação de input
    final idError = InputValidator.validateId(classId, 'ID da aula');
    if (idError != null) {
      return false;
    }

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
  /// REQUER: Usuário autenticado como admin
  Future<List<StudentBookingInfo>> fetchAllBookingsWithStudentInfo() async {
    // SEGURANÇA: Verifica se é admin antes de expor dados de usuários
    final isAdmin = await SecurityHelpers.isCurrentUserAdmin();
    if (!isAdmin) {
      return [];
    }

    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      // Busca todas as reservas
      final bookingsResponse = await supabase
          .from('bookings')
          .select('id, user_id, class_id, created_at');

      final bookings = bookingsResponse as List;
      if (bookings.isEmpty) return [];

      // Busca os IDs das aulas e usuários
      final classIds = bookings
          .map((b) => b['class_id'] as String)
          .toSet()
          .toList();
      final userIds = bookings
          .map((b) => b['user_id'] as String)
          .toSet()
          .toList();

      // Busca as aulas futuras
      final classesResponse = await supabase
          .from('classes')
          .select()
          .inFilter('id', classIds)
          .gte('start_time', now.toIso8601String())
          .order('start_time', ascending: true);

      // Cria mapa de aulas por ID
      final classesMap = <String, Map<String, dynamic>>{};
      for (final classData in classesResponse as List) {
        classesMap[classData['id'] as String] = classData;
      }

      // Busca perfis dos usuários
      final profilesMap = <String, Map<String, dynamic>>{};
      try {
        final profilesResponse = await supabase
            .from('profiles')
            .select('id, email, name')
            .inFilter('id', userIds);

        for (final profile in profilesResponse as List) {
          profilesMap[profile['id'] as String] = profile;
        }
      } catch (e) {
        // Tabela profiles pode não ter todos os dados
      }

      // Filtra reservas para aulas futuras
      final futureBookings = bookings.where((b) {
        final classId = b['class_id'] as String;
        return classesMap.containsKey(classId);
      }).toList();

      // Agrupa reservas por usuário para calcular o total
      final userBookingsCount = <String, int>{};
      for (final booking in futureBookings) {
        final userId = booking['user_id'] as String;
        final classId = booking['class_id'] as String;
        final classData = classesMap[classId];
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

      final result = <StudentBookingInfo>[];
      for (final booking in futureBookings) {
        final userId = booking['user_id'] as String;
        final classId = booking['class_id'] as String;
        final classData = classesMap[classId];
        final profile = profilesMap[userId];

        if (classData == null) continue;

        final studentName = profile?['name'] as String? ?? 
            _extractNameFromEmail(profile?['email'] as String? ?? 'Aluno');
        final studentEmail = profile?['email'] as String? ?? '';
        
        final bookingsThisWeek = userBookingsCount[userId] ?? 0;
        final remainingBookings = BookingRules.bookingLimitEnabled 
            ? (maxBookings - bookingsThisWeek).clamp(0, maxBookings)
            : -1; // -1 indica sem limite

        result.add(StudentBookingInfo(
          bookingId: booking['id'] as String,
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
        ));
      }

      // Ordena por horário de início
      result.sort((a, b) => a.classStartTime.compareTo(b.classStartTime));

      return result;
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
  /// SEGURANÇA: Não expõe detalhes técnicos do erro
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
        'Você não tem permissão para realizar esta ação',
      );
    }

    // SEGURANÇA: Retorna mensagem genérica sem expor detalhes técnicos
    return BookingResult.error('Não foi possível processar a reserva. Tente novamente');
  }
}
