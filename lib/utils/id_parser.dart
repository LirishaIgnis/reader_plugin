// lib/utils/id_parser.dart
// Parser que replica la lógica y offsets del LectorBarrasAON_FS205.cs (C#)
// Este archivo se encarga de interpretar las tramas que envía el lector físico,
// extrayendo información útil (nombre, apellidos, número, fecha, etc.) según el tipo de documento.

class ColombianIDParser {
  /// Procesa la trama del lector y retorna los datos estructurados
  static Map<String, String> parse(String raw) {
    // Verificamos que el texto no esté vacío o nulo
    if (raw == null || raw.isEmpty) return _empty();

    final String s = raw; // Usamos directamente la trama original
    final int len = s.length;

    // Flags para identificar tipo de documento
    bool f_cedula = false;
    bool f_ocr = false;
    bool f_ocr_ced = false;
    bool f_ocr_pass = false;
    bool f_ocr_cedext = false;

    // ------------ Clasificación inicial ------------

    // Si la trama es larga (>200 caracteres) se asume que es una cédula antigua
    if (len > 200) {
      f_cedula = true;
    }

    // Detecta Cédula digital (OCR tipo "CC")
    if (!f_cedula && len > 2 && s[1] == 'C' && s[2] == 'C') {
      f_ocr = true;
      f_ocr_ced = true;
      f_cedula = true;
    }

    // Detecta Pasaporte (OCR empieza con "P<")
    if (!f_cedula && len > 1 && s[0] == 'P' && s[1] == '<') {
      f_ocr = true;
      f_cedula = true;
      f_ocr_pass = true;
    }

    // Detecta Cédula de extranjería (OCR empieza con "I<")
    if (!f_cedula && len > 1 && s[0] == 'I' && s[1] == '<') {
      f_ocr = true;
      f_cedula = true;
      f_ocr_cedext = true;
    }

    // ------------ Selección de parser según tipo detectado ------------

    if (f_ocr && f_ocr_pass) return _parseOCRPassport(s);
    if (f_ocr && f_ocr_ced) return _parseOCRCedulaDigital(s);
    if (f_ocr && f_ocr_cedext) return _parseOCRCedulaExtranjeria(s);

    // Tarjeta de identidad (no OCR, comienza con 'I')
    if (!f_ocr && len > 0 && s[0] == 'I') return _parseTarjetaIdentidad(s);

    // Cédula antigua (trama larga sin OCR)
    if (len > 200 && !f_ocr) return parseCedulaAntiguaAdaptativa(s);

    // Si no se identificó el tipo
    return _empty();
  }

  // ---------- OCR Pasaporte ----------
  static Map<String, String> _parseOCRPassport(String s) {
    // Toma los primeros 150 caracteres (zona MRZ)
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    // Extrae nombres y apellidos
    String nombreApellido = codigo.length >= 44 ? codigo.substring(5, 44) : '';
    String dato = codigo.length > 44 ? codigo.substring(44) : '';
    // Extrae número de pasaporte, país, nacimiento y género
    String numeroPass = _safeSubstr(dato, 0, 9).replaceAll('\x00', '').replaceAll('O', '');
    String pais = _safeSubstr(dato, 10, 3);
    String nacimiento = _safeSubstr(dato, 13, 6);
    String genero = _safeSubstr(dato, 20, 1);

    // Limpieza y separación de nombres
    List<String> parts = nombreApellido.replaceAll('<', ' ').trim().split(RegExp(r'\s+'));
    String apellidos = '', nombres = '';
    if (parts.length >= 2) {
      apellidos = parts.take(2).join(' ');
      if (parts.length > 2) nombres = parts.skip(2).join(' ');
    } else if (parts.isNotEmpty) {
      nombres = parts.join(' ');
    }

    // Convierte fecha YYMMDD a formato completo YYYY-MM-DD
    final fecha = _formatFechaFromYYMMDD(nacimiento);

    // Construye el resultado final
    final result = <String, String>{
      'tipo': 'Pasaporte',
      'numero_documento': numeroPass,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'fecha_nacimiento': fecha,
      'sexo': genero,
      'pais': pais.isNotEmpty ? pais : 'COL',
    };
    result['nombre'] = '${result['apellidos']} ${result['nombres']}'.trim();
    return result;
  }

  // ---------- OCR Cédula Digital ----------
  static Map<String, String> _parseOCRCedulaDigital(String s) {
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    String dato = _safeSubstr(codigo, 0, 63);
    // Extrae número, nacimiento y género
    String cedulaNum = _safeSubstr(dato, 48, 10).replaceAll('\x00', '').replaceAll('O', '');
    String nacimiento = _safeSubstr(dato, 30, 6);
    String genero = _safeSubstr(dato, 37, 1);
    String nombreApellido = codigo.length > 60 ? codigo.substring(60) : '';
    nombreApellido = nombreApellido.replaceAll('<', ' ').trim();

    // Tokeniza nombres y apellidos
    final tokens = nombreApellido.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    String apellidos = '', nombres = '';
    if (tokens.length >= 3) {
      apellidos = tokens.take(2).join(' ');
      nombres = tokens.skip(2).join(' ');
    } else {
      nombres = tokens.join(' ');
    }

    final fecha = _formatFechaFromYYMMDD(nacimiento);
    final result = <String, String>{
      'tipo': 'CedulaDigital',
      'numero_documento': cedulaNum,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'fecha_nacimiento': fecha,
      'sexo': genero,
      'pais': 'COL',
    };
    result['nombre'] = '${result['apellidos']} ${result['nombres']}'.trim();
    return result;
  }

  // ---------- OCR Cédula de Extranjería ----------
  static Map<String, String> _parseOCRCedulaExtranjeria(String s) {
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    final dato = _safeSubstr(codigo, 5, 55);
    final numero = _safeSubstr(dato, 0, 9).replaceAll('\x00', '').replaceAll('O', '');
    final nacimiento = _safeSubstr(dato, 25, 6);
    final genero = _safeSubstr(dato, 32, 1);
    final pais = _safeSubstr(dato, 40, 3);

    // Procesa nombres y apellidos
    String nombreApellido = codigo.length > 60 ? codigo.substring(60) : '';
    nombreApellido = nombreApellido.replaceAll('<', ' ').trim();
    final tokens = nombreApellido.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    String apellidos = '', nombres = '';
    if (tokens.length >= 3) {
      apellidos = tokens.take(2).join(' ');
      nombres = tokens.skip(2).join(' ');
    } else {
      nombres = tokens.join(' ');
    }

    final fecha = _formatFechaFromYYMMDD(nacimiento);
    final result = <String, String>{
      'tipo': 'CedulaExtranjeria',
      'numero_documento': numero,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'fecha_nacimiento': fecha,
      'sexo': genero,
      'pais': pais.isNotEmpty ? pais : 'EXT',
    };
    result['nombre'] = '${result['apellidos']} ${result['nombres']}'.trim();
    return result;
  }

  // ---------- Tarjeta de Identidad ----------
  static Map<String, String> _parseTarjetaIdentidad(String s) {
    // --- Normalización: corrige caracteres dañados, filtra símbolos y limpia ---
    String normalized = s
        .replaceAll(RegExp(r'Ã‘|Ã±', caseSensitive: false), 'Ñ')
        .replaceAll(RegExp(r'ñ', caseSensitive: false), 'Ñ')
        .replaceAllMapped(RegExp(r'(?<=[A-Z])�(?=[A-Z])'), (m) => 'Ñ')
        .replaceAll('�', ' ')
        .replaceAll(RegExp(r'[^A-Z0-9Ñ\+\s]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u00A0]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // --- Busca primer apellido ---
    final apellidoRegex = RegExp(r'\b[A-ZÑ]{3,}\b');
    final apellidoMatch = apellidoRegex.firstMatch(normalized);
    if (apellidoMatch == null) {
      return {'error': 'No se encontró el primer apellido'};
    }

    int apellidoIndex = apellidoMatch.start;
    String primerApellido = apellidoMatch.group(0)!;

    // --- Busca número de documento antes del primer apellido ---
    String anterior = normalized.substring(0, apellidoIndex).replaceAll(' ', '');
    final docRegex = RegExp(r'(\d{8,10})$');
    final docMatch = docRegex.firstMatch(anterior);

    String numeroDocumento = '';
    if (docMatch != null) {
      numeroDocumento = docMatch.group(0)!;
      if (numeroDocumento.length > 10) {
        numeroDocumento = numeroDocumento.substring(numeroDocumento.length - 10);
      }
      if (numeroDocumento.startsWith('00') && numeroDocumento.length == 10) {
        numeroDocumento = numeroDocumento.substring(2);
      }
    }

    // --- Busca segundo apellido y nombres ---
    String segundoApellido = '';
    String nombres = '';

    final tokenRegex = RegExp(r'[A-ZÑ]{2,}', caseSensitive: true);
    final tokens = <Map<String, dynamic>>[];
    for (final m in tokenRegex.allMatches(normalized)) {
      tokens.add({'text': m.group(0)!, 'start': m.start, 'end': m.end});
    }

    int tokenIdx = tokens.indexWhere((t) => t['start'] == apellidoIndex);
    if (tokenIdx == -1) {
      tokenIdx = tokens.lastIndexWhere((t) => t['text'] == primerApellido);
    }

    if (tokenIdx != -1) {
      if (tokenIdx + 1 < tokens.length && tokens[tokenIdx + 1]['text'].length >= 3) {
        segundoApellido = tokens[tokenIdx + 1]['text'];
      }

      final nombresList = <String>[];
      int startIdx = segundoApellido.isNotEmpty ? tokenIdx + 2 : tokenIdx + 1;

      for (int i = startIdx; i < tokens.length; i++) {
        final t = tokens[i]['text'] as String;

        // Filtra ruido (bloques numéricos o artefactos)
        if (RegExp(r'^[0-9]|^0[MF]').hasMatch(t)) break;
        if (t.length <= 2) break;
        if (!RegExp(r'[AEIOU]').hasMatch(t)) break;
        if (t.contains(RegExp(r'Ñ[^AEIOUÑ]$'))) break;
        nombresList.add(t);
      }

      nombres = nombresList.join(' ');
    }

    // --- Busca datos adicionales: sexo, fecha de nacimiento, RH ---
    final infoRegex = RegExp(r'0([MF])(\d{4})(\d{2})(\d{2}).*?([ABO]{1,2}\+?)');
    final infoMatch = infoRegex.firstMatch(normalized);

    String genero = infoMatch?.group(1) ?? '';
    String fechaNacimiento = '';
    if (infoMatch != null) {
      fechaNacimiento =
          '${infoMatch.group(2)}-${infoMatch.group(3)}-${infoMatch.group(4)}';
    }
    String rh = infoMatch?.group(5) ?? '';

    final apellidos = '$primerApellido $segundoApellido'.trim();
    final nombreCompleto = '$apellidos $nombres'.trim();

    // --- Limpieza y salida final ---
    Map<String, String> resultado = {
      'tipo': 'TarjetaIdentidad',
      'numero_documento': numeroDocumento,
      'nombres': nombres,
      'apellidos': apellidos,
      'fecha_nacimiento': fechaNacimiento,
      'sexo': genero,
      'pais': 'COL',
      'nombre': nombreCompleto,
      'rh': rh,
    };

    resultado.updateAll((k, v) {
      return v
          .replaceAll(RegExp(r'[^\wÑ\s\+\-]', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    });

    return resultado;
  }

  /// ---------- Algoritmo adaptativo para Cédula Antigua ----------
  static Map<String, String> parseCedulaAntiguaAdaptativa(String s) {
    // --- Detecta si la trama es reciente o antigua ---
    bool esTramaReciente(String data) {
      if (data.contains('PUBDSK') || data.contains('PubDSK_1')) return true;
      if (data.length > 800) return true;
      return false;
    }

    // --- Limpieza de la trama ---
    String limpiarTrama(String data) {
      return data
          .replaceAll(RegExp(r'Ã‘|Ã±|Ñ|ñ|�', caseSensitive: false), 'Ñ')
          .replaceAll(RegExp(r'[^A-Z0-9Ñ\+\s]', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F]', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    // --- Parser base que aplica heurísticas ---
    Map<String, String> parseCedulaBase(String data) {
      String cleaned = limpiarTrama(data);

      // Busca secuencia de apellidos y nombres
      final nameRegex = RegExp(
        r'([A-ZÑ]{2,})\s+([A-ZÑ]{2,})\s+([A-ZÑ]{2,})(?:\s+([A-ZÑ]{2,}))?(?:\s+([A-ZÑ]{2,}))?'
      );
      final nameMatch = nameRegex.firstMatch(cleaned);

      String primerApellido = nameMatch?.group(1) ?? '';
      String segundoApellido = nameMatch?.group(2) ?? '';
      List<String> nombresList = [];

      for (int i = 3; i <= 5; i++) {
        final val = nameMatch?.group(i);
        if (val != null) nombresList.add(val);
      }

      // Si no encontró nombres, intenta tokenizar el texto
      if (primerApellido.isEmpty) {
        final tokenRegex = RegExp(r'[A-ZÑ]{2,}', caseSensitive: true);
        final tokens = <String>[];
        for (final m in tokenRegex.allMatches(cleaned)) {
          final token = m.group(0)!;
          if (token.length >= 2 && RegExp(r'[AEIOUÑ]').hasMatch(token)) {
            tokens.add(token);
          }
        }
        if (tokens.length >= 2) {
          primerApellido = tokens[0];
          segundoApellido = tokens.length > 1 ? tokens[1] : '';
          if (tokens.length > 2) {
            nombresList = tokens.sublist(2);
          }
        }
      }

      // Recorre tokens para validar nombres y cortar ruido
      final tokens = cleaned.split(RegExp(r'\s+')).map((e) => {'text': e}).toList();
      int tokenIdx = tokens.indexWhere((t) => t['text'] == segundoApellido);
      if (tokenIdx != -1) {
        int startIdx = segundoApellido.isNotEmpty ? tokenIdx + 2 : tokenIdx + 1;
        for (int i = startIdx; i < tokens.length; i++) {
          final t = tokens[i]['text'] as String;
          if (RegExp(r'^[0-9]|^0[MF]').hasMatch(t)) break;
          if (t.length <= 2) break;
          if (!RegExp(r'[AEIOUÑ]').hasMatch(t)) break;
          if (!nombresList.contains(t)) {
            nombresList.add(t);
          }
        }
      }

      String nombres = nombresList.join(' ');

      // Busca número de documento antes del apellido
      String numeroDocumento = '';
      if (primerApellido.isNotEmpty) {
        int idxApellido = cleaned.indexOf(primerApellido);
        if (idxApellido > 0) {
          int from = (idxApellido - 20).clamp(0, cleaned.length);
          String antesApellido = cleaned.substring(from, idxApellido);
          final match = RegExp(r'(\d{1,10})$').firstMatch(antesApellido);
          if (match != null) {
            String rawNum = match.group(1)!;
            if (rawNum.length > 10) {
              rawNum = rawNum.substring(rawNum.length - 10);
            }
            if (rawNum.length >= 10 && rawNum.startsWith('00')) {
              rawNum = rawNum.substring(2, 10);
            }
            numeroDocumento = rawNum;
          }
        }
      }

      // Extrae género, fecha de nacimiento y RH
      final infoRegex = RegExp(r'0([MF])(\d{4})(\d{2})(\d{2}).*?([ABO]{1,2}\+?)');
      final infoMatch = infoRegex.firstMatch(cleaned);

      String genero = infoMatch?.group(1) ?? '';
      String fechaNacimiento = '';
      if (infoMatch != null) {
        fechaNacimiento =
            '${infoMatch.group(2)}-${infoMatch.group(3)}-${infoMatch.group(4)}';
      }
      String rh = infoMatch?.group(5) ?? '';

      final apellidos = '$primerApellido $segundoApellido'.trim();
      final nombreCompleto = '$apellidos $nombres'.trim();

      // Devuelve mapa con resultados
      return {
        'tipo': 'CedulaAntigua',
        'numero_documento': numeroDocumento,
        'nombres': nombres,
        'apellidos': apellidos,
        'fecha_nacimiento': fechaNacimiento,
        'sexo': genero,
        'pais': 'COL',
        'nombre': nombreCompleto,
        'rh': rh,
      };
    }

    // Determina si es reciente (no usado directamente, pero mantenido por compatibilidad)
    bool reciente = esTramaReciente(s);
    return parseCedulaBase(s);
  }

  // ---------- Utilidades ----------

  // Devuelve substring segura (evita errores de rango)
  static String _safeSubstr(String s, int start, int length) {
    if (start < 0 || start >= s.length) return '';
    final end = (start + length <= s.length) ? start + length : s.length;
    return s.substring(start, end);
  }

  // Lee una secuencia de dígitos desde una posición
  static String _readDigitsFrom(String s, int start) {
    if (start >= s.length) return '';
    final buffer = StringBuffer();
    for (int i = start; i < s.length; i++) {
      if (RegExp(r'\d').hasMatch(s[i])) buffer.write(s[i]);
      else break;
    }
    return buffer.toString();
  }

  // Convierte una fecha YYMMDD a YYYY-MM-DD considerando el siglo
  static String _formatFechaFromYYMMDD(String s) {
    if (s.length != 6) return '';
    final yy = int.tryParse(s.substring(0, 2)) ?? 0;
    final mm = s.substring(2, 4);
    final dd = s.substring(4, 6);
    final century = (yy < 25) ? 2000 : 1900;
    return '${century + yy}-$mm-$dd';
  }

  // Retorna un mapa vacío (caso desconocido)
  static Map<String, String> _empty() => {
        'tipo': 'Desconocido',
        'numero_documento': '',
        'nombres': '',
        'apellidos': '',
        'fecha_nacimiento': '',
        'sexo': '',
        'pais': '',
        'nombre': ''
      };
}
