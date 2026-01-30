import '../models/business_settings.dart';
import '../services/settings_service.dart';

/// Singleton para gerenciar as regras de negócio dinâmicas
/// 
/// Esta classe fornece acesso síncrono às configurações carregadas do banco.
/// Use [initialize] no início do app para carregar as configurações.
class BookingRules {
  static final SettingsService _settingsService = SettingsService();
  static BusinessSettings? _settings;

  /// Inicializa as regras de negócio carregando do banco de dados
  /// Deve ser chamado no início do app
  static Future<void> initialize() async {
    _settings = await _settingsService.getSettings();
  }

  /// Força o reload das configurações
  static Future<void> refresh() async {
    _settings = await _settingsService.getSettings(forceRefresh: true);
  }

  /// Retorna as configurações atuais (carrega default se não inicializado)
  static BusinessSettings get settings {
    return _settings ?? BusinessSettings.defaults();
  }

  /// Horas antes da aula que o cancelamento é permitido
  static int get cancellationDeadlineHours => settings.cancellationDeadlineHours;

  /// Máximo de reservas ativas por semana
  static int get maxBookingsPerWeek => settings.maxBookingsPerWeek;

  /// Se o limite de reservas está habilitado
  static bool get bookingLimitEnabled => settings.bookingLimitEnabled;

  /// Máximo de cancelamentos por mês
  static int get maxCancellationsPerMonth => settings.maxCancellationsPerMonth;

  /// Se o limite de cancelamentos está habilitado
  static bool get cancellationLimitEnabled => settings.cancellationLimitEnabled;

  /// Antecedência mínima para reservar em horas
  static int get minBookingAdvanceHours => settings.minBookingAdvanceHours;

  /// Capacidade padrão para novas aulas
  static int get defaultClassCapacity => settings.defaultClassCapacity;

  /// Número de raias padrão
  static int get defaultLanes => settings.defaultLanes;

  /// Verifica se pode cancelar a reserva baseado no deadline
  static bool canCancelBooking(DateTime classStartTime) {
    return settings.canCancelBooking(classStartTime);
  }

  /// Verifica se pode reservar baseado na antecedência mínima
  static bool canBookClass(DateTime classStartTime) {
    return settings.canBookClass(classStartTime);
  }

  /// Retorna o tempo restante para cancelar
  static Duration? timeUntilCancellationDeadline(DateTime classStartTime) {
    return settings.timeUntilCancellationDeadline(classStartTime);
  }

  /// Formata o tempo restante para cancelar
  static String formatRemainingTime(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min';
    }
    return 'Poucos segundos';
  }

  /// Mensagem explicando o deadline de cancelamento
  static String get cancellationDeadlineMessage => settings.cancellationDeadlineMessage;

  /// Mensagem explicando o limite de reservas
  static String get bookingLimitMessage => settings.bookingLimitMessage;

  /// Mensagem explicando o limite de cancelamentos
  static String get cancellationLimitMessage => settings.cancellationLimitMessage;

  /// Mensagem explicando a antecedência mínima
  static String get minBookingAdvanceMessage => settings.minBookingAdvanceMessage;
}
