// lib/utils/id_parser.dart
// Parser que replica la lógica y offsets del LectorBarrasAON_FS205.cs (C#)
// Extrae campos para: Cédula digital (OCR/MRZ), Pasaporte (OCR), Cédula extranjería (OCR),
// Tarjeta ID y cédula antigua.

class ColombianIDParser {
  /// Procesa la trama del lector y retorna los datos estructurados
  static Map<String, String> parse(String raw) {
    // ⚠️ Ya no limpiamos la trama; solo verificamos longitud
    if (raw == null || raw.isEmpty) return _empty();

    final String s = raw; // usar directamente la trama original
    final int len = s.length;

    bool f_cedula = false;
    bool f_ocr = false;
    bool f_ocr_ced = false;
    bool f_ocr_pass = false;
    bool f_ocr_cedext = false;

    // ------------ Clasificación inicial ------------

    // Si la trama es larga (>200) → cédula antigua o documento nacional
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

    // ------------ Selección de parser ------------

    if (f_ocr && f_ocr_pass) return _parseOCRPassport(s);
    if (f_ocr && f_ocr_ced) return _parseOCRCedulaDigital(s);
    if (f_ocr && f_ocr_cedext) return _parseOCRCedulaExtranjeria(s);

    // Tarjeta de identidad (no OCR, empieza con I)
    if (!f_ocr && len > 0 && s[0] == 'I') return _parseTarjetaIdentidad(s);

    // Cédula antigua (trama larga sin OCR)
    if (len > 200 && !f_ocr) return parseCedulaAntiguaAdaptativa(s);

    //Fallback heurístico
    //final docMatch = RegExp(r'\b\d{9,11}\b').firstMatch(s);
    //if (docMatch != null) return _parseCedulaAntiguaHeuristica(s);

    return _empty();
  }

  // ---------- OCR Pasaporte ----------
  static Map<String, String> _parseOCRPassport(String s) {
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    String nombreApellido = codigo.length >= 44 ? codigo.substring(5, 44) : '';
    String dato = codigo.length > 44 ? codigo.substring(44) : '';
    String numeroPass = _safeSubstr(dato, 0, 9).replaceAll('\x00', '').replaceAll('O', '');
    String pais = _safeSubstr(dato, 10, 3);
    String nacimiento = _safeSubstr(dato, 13, 6);
    String genero = _safeSubstr(dato, 20, 1);

    List<String> parts = nombreApellido.replaceAll('<', ' ').trim().split(RegExp(r'\s+'));
    String apellidos = '', nombres = '';
    if (parts.length >= 2) {
      apellidos = parts.take(2).join(' ');
      if (parts.length > 2) nombres = parts.skip(2).join(' ');
    } else if (parts.isNotEmpty) {
      nombres = parts.join(' ');
    }

    final fecha = _formatFechaFromYYMMDD(nacimiento);
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
    String cedulaNum = _safeSubstr(dato, 48, 10).replaceAll('\x00', '').replaceAll('O', '');
    String nacimiento = _safeSubstr(dato, 30, 6);
    String genero = _safeSubstr(dato, 37, 1);
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

  // ---------- OCR Cédula Extranjería ----------
  static Map<String, String> _parseOCRCedulaExtranjeria(String s) {
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    final dato = _safeSubstr(codigo, 5, 55);
    final numero = _safeSubstr(dato, 0, 9).replaceAll('\x00', '').replaceAll('O', '');
    final nacimiento = _safeSubstr(dato, 25, 6);
    final genero = _safeSubstr(dato, 32, 1);
    final pais = _safeSubstr(dato, 40, 3);

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

  // ---------- Tarjeta Identidad ----------
  static Map<String, String> _parseTarjetaIdentidad(String s) {
    String clean = s.replaceAll('<', ' ');
    String cedula = '';
    if (clean.length >= 50) {
      if (clean[48] == '0' && clean[49] == '0') {
        cedula = _readDigitsFrom(clean, 50);
      } else {
        cedula = _readDigitsFrom(clean, 48);
      }
    } else {
      final m = RegExp(r'\b\d{6,11}\b').firstMatch(clean);
      cedula = m?.group(0) ?? '';
    }

    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String apellidos = '', nombres = '';
    if (words.length >= 4) {
      apellidos = '${words[0]} ${words[1]}';
      nombres = words.skip(2).take(2).join(' ');
    } else if (words.length >= 2) {
      apellidos = words[0];
      nombres = words.skip(1).join(' ');
    }

    return {
      'tipo': 'TarjetaIdentidad',
      'numero_documento': cedula,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'fecha_nacimiento': '',
      'sexo': '',
      'pais': 'COL',
      'nombre': '$apellidos $nombres'.trim()
    };
  }

  /// ---------- Nuevo algoritmo corregido para Cédula Antigua ----------
// ------------------- Parser adaptativo Cédula Antigua -------------------
static Map<String, String> parseCedulaAntiguaAdaptativa(String s) {
  // --- 1️⃣ Detectar tipo de trama ---
  bool esTramaReciente(String data) {
    if (data.contains('PUBDSK') || data.contains('PubDSK_1')) return true;
    if (data.length > 800) return true;
    return false;
  }

  // --- 2️⃣ Limpieza controlada ---
  String limpiarTrama(String data) {
    return data
        .replaceAll(RegExp(r'[^A-Z0-9Ñ\+ ]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // --- 3️⃣ Parser unificado (misma lógica de búsqueda de apellido y documento) ---
  Map<String, String> parseCedulaBase(String data) {
    String cleaned = limpiarTrama(data);

    // Buscar primer apellido (3+ letras mayúsculas)
    final apellidoRegex = RegExp(r'\b([A-ZÑ]{3,})\b');
    final apellidoMatch = apellidoRegex.firstMatch(cleaned);
    String primerApellido = '';
    if (apellidoMatch != null) {
      primerApellido = apellidoMatch.group(1)!;
    }

    // Buscar los 10 dígitos inmediatamente anteriores al apellido
    String numeroDocumento = '';
    if (apellidoMatch != null) {
      int start = apellidoMatch.start;
      int from = (start - 20).clamp(0, cleaned.length);
      String before = cleaned.substring(from, start);

      final digitsMatch = RegExp(r'(\d{8,11})').allMatches(before).toList();
      if (digitsMatch.isNotEmpty) {
        String raw = digitsMatch.last.group(1)!;
        // Aplicar regla: si los dos primeros son 00 → documento de 8 dígitos
        if (raw.length >= 10 && raw.startsWith('00')) {
          numeroDocumento = raw.substring(2, 10);
        } else {
          numeroDocumento = raw;
        }
      }
    }

    // Buscar estructura de nombres (igual algoritmo que validamos)
    final nameRegex = RegExp(
        r'([A-ZÑ]{3,})\s+([A-ZÑ]{3,})\s+([A-ZÑ]{3,})(?:\s+([A-ZÑ]{3,}))?(?:\s+([A-ZÑ]{3,}))?');
    final nameMatch = nameRegex.firstMatch(cleaned);

    String segundoApellido = nameMatch?.group(2) ?? '';
    List<String> nombresList = [];
    for (int i = 3; i <= 5; i++) {
      final val = nameMatch?.group(i);
      if (val != null) nombresList.add(val);
    }
    String nombres = nombresList.join(' ');

    // Buscar datos complementarios (género, fecha, RH)
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

  // --- 4️⃣ Determinar qué versión de trama es y procesar ---
  bool reciente = esTramaReciente(s);
  return parseCedulaBase(s);
}


  // ---------- Utilidades ----------
  static String _safeSubstr(String s, int start, int length) {
    if (start < 0 || start >= s.length) return '';
    final end = (start + length <= s.length) ? start + length : s.length;
    return s.substring(start, end);
  }

  static String _readDigitsFrom(String s, int start) {
    if (start >= s.length) return '';
    final buffer = StringBuffer();
    for (int i = start; i < s.length; i++) {
      if (RegExp(r'\d').hasMatch(s[i])) buffer.write(s[i]);
      else break;
    }
    return buffer.toString();
  }

  static String _formatFechaFromYYMMDD(String s) {
    if (s.length != 6) return '';
    final yy = int.tryParse(s.substring(0, 2)) ?? 0;
    final mm = s.substring(2, 4);
    final dd = s.substring(4, 6);
    final century = (yy < 25) ? 2000 : 1900;
    return '${century + yy}-$mm-$dd';
  }

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
