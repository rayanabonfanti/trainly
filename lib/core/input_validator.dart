/// Utilitário para validação de inputs
/// Centraliza validações de segurança para evitar ataques
class InputValidator {
  /// Tamanho máximo para IDs (UUIDs têm 36 caracteres)
  static const int maxIdLength = 36;

  /// Tamanho máximo para nomes
  static const int maxNameLength = 100;

  /// Tamanho máximo para emails
  static const int maxEmailLength = 254;

  /// Tamanho máximo para telefones
  static const int maxPhoneLength = 20;

  /// Tamanho máximo para URLs
  static const int maxUrlLength = 2048;

  /// Tamanho máximo para títulos
  static const int maxTitleLength = 200;

  /// Tamanho máximo de arquivo de avatar (5MB)
  static const int maxAvatarSizeBytes = 5 * 1024 * 1024;

  /// Extensões permitidas para avatar
  static const List<String> allowedAvatarExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];

  /// Valida um ID (UUID)
  /// Retorna null se válido, mensagem de erro se inválido
  static String? validateId(String? id, String fieldName) {
    if (id == null || id.trim().isEmpty) {
      return '$fieldName é obrigatório';
    }

    final trimmedId = id.trim();

    if (trimmedId.length > maxIdLength) {
      return '$fieldName inválido';
    }

    // UUID regex pattern
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!uuidRegex.hasMatch(trimmedId)) {
      return '$fieldName inválido';
    }

    return null;
  }

  /// Valida uma lista de IDs
  static String? validateIdList(
    List<String>? ids,
    String fieldName, {
    int maxItems = 100,
  }) {
    if (ids == null || ids.isEmpty) {
      return '$fieldName é obrigatório';
    }

    if (ids.length > maxItems) {
      return 'Limite de $maxItems itens excedido';
    }

    for (final id in ids) {
      final error = validateId(id, fieldName);
      if (error != null) {
        return error;
      }
    }

    return null;
  }

  /// Valida um nome
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return null; // Nome é opcional
    }

    final trimmedName = name.trim();

    if (trimmedName.length > maxNameLength) {
      return 'Nome muito longo (máximo $maxNameLength caracteres)';
    }

    // Verifica caracteres suspeitos (SQL injection, XSS)
    if (_containsDangerousChars(trimmedName)) {
      return 'Nome contém caracteres inválidos';
    }

    return null;
  }

  /// Valida um email
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email é obrigatório';
    }

    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedEmail.length > maxEmailLength) {
      return 'Email muito longo';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmedEmail)) {
      return 'Email inválido';
    }

    return null;
  }

  /// Valida um telefone
  static String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null; // Telefone é opcional
    }

    final trimmedPhone = phone.trim();

    if (trimmedPhone.length > maxPhoneLength) {
      return 'Telefone muito longo';
    }

    // Remove caracteres de formatação para validar
    final digitsOnly = trimmedPhone.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Telefone inválido';
    }

    return null;
  }

  /// Valida uma URL
  static String? validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null; // URL é opcional
    }

    final trimmedUrl = url.trim();

    if (trimmedUrl.length > maxUrlLength) {
      return 'URL muito longa';
    }

    try {
      final uri = Uri.parse(trimmedUrl);
      if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return 'URL inválida';
      }
    } catch (e) {
      return 'URL inválida';
    }

    return null;
  }

  /// Valida extensão de arquivo para avatar
  static String? validateAvatarExtension(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();

    if (!allowedAvatarExtensions.contains(extension)) {
      return 'Tipo de arquivo não permitido. Use: ${allowedAvatarExtensions.join(", ")}';
    }

    return null;
  }

  /// Valida tamanho de arquivo
  static String? validateFileSize(int sizeBytes, int maxSizeBytes) {
    if (sizeBytes > maxSizeBytes) {
      final maxMB = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return 'Arquivo muito grande. Máximo: ${maxMB}MB';
    }

    return null;
  }

  /// Sanitiza um nome de arquivo para evitar path traversal
  static String sanitizeFileName(String fileName) {
    // Remove caracteres perigosos e path traversal
    return fileName
        .replaceAll(RegExp(r'[^\w\.\-]'), '_')
        .replaceAll('..', '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_');
  }

  /// Verifica se contém caracteres perigosos (SQL injection, XSS)
  static bool _containsDangerousChars(String input) {
    final dangerousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false), // onclick, onload, etc.
      RegExp(r'''['"];'''), // SQL injection patterns
      RegExp(r'--'), // SQL comment
      RegExp(r'/\*'), // SQL block comment
    ];

    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }

    return false;
  }

  /// Valida um título
  static String? validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return 'Título é obrigatório';
    }

    final trimmedTitle = title.trim();

    if (trimmedTitle.length > maxTitleLength) {
      return 'Título muito longo (máximo $maxTitleLength caracteres)';
    }

    if (_containsDangerousChars(trimmedTitle)) {
      return 'Título contém caracteres inválidos';
    }

    return null;
  }
}
