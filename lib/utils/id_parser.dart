// lib/utils/id_parser.dart
// Parser que replica la lógica y offsets del LectorBarrasAON_FS205.cs (C#)
// Extrae campos para: Cédula digital (OCR/MRZ), Pasaporte (OCR), Cédula extranjería (OCR), Tarjeta ID y cédula antigua.

class ColombianIDParser {
  /// Parse raw text (trama) and return map with fields:
  /// 'tipo','numero_documento','nombres','apellidos','fecha_nacimiento','sexo','pais','nombre'
  static Map<String, String> parse(String raw) {
    if (raw == null) raw = '';
    // Normalizar: quitar NULs y retornos
    String s = raw.replaceAll('\x00', '').replaceAll('\r', '').replaceAll('\n', '');
    s = s.replaceAll('�', ''); // quitar caracteres basura visibles
    s = s.trim();

    if (s.isEmpty) return _empty();

    // Convertir a "array" lógico similar al Rx[] del C#
    // Para indexación por offset, sólo usaremos la String s (caracteres).
    int len = s.length;

    bool f_cedula = false;
    bool f_ocr = false;
    bool f_ocr_ced = false;
    bool f_ocr_pass = false;
    bool f_ocr_cedext = false;

    // ------------
    // Detección (replica el orden del C#)
    // ------------

    // Si longitud grande (>200) el C# marca f_cedula = true (trama extensa)
    if (len > 200) {
      f_cedula = true;
    }

    // Detecta CC en Rx[1] Rx[2] -> en string s eso corresponde a s[1], s[2] (si existen)
    if (!f_cedula && len > 2) {
      if (s[1] == 'C' && s[2] == 'C') {
        f_ocr = true;
        f_ocr_ced = true;
        f_cedula = true;
      }
    }

    // Detecta P< -> pasaporte OCR
    if (!f_cedula && len > 1) {
      if (s[0] == 'P' && s[1] == '<') {
        f_ocr = true;
        f_cedula = true;
        f_ocr_pass = true;
      }
    }

    // Detecta I< -> cedula extranjeria OCR
    if (!f_cedula && len > 1) {
      if (s[0] == 'I' && s[1] == '<') {
        f_ocr = true;
        f_cedula = true;
        f_ocr_cedext = true;
      }
    }

    // ------------
    // Ramas de procesamiento (replico subrutinas y offsets)
    // ------------

    // Si es OCR de pasaporte
    if (f_ocr && f_ocr_pass) {
      return _parseOCRPassport(s);
    }

    // Si es OCR cedula digital (CC)
    if (f_ocr && f_ocr_ced) {
      return _parseOCRCedulaDigital(s);
    }

    // Si es OCR cedula extranjeria
    if (f_ocr && f_ocr_cedext) {
      return _parseOCRCedulaExtranjeria(s);
    }

    // Si no es OCR pero empieza con 'I' -> tarjeta identidad (branch similar al C#)
    if (!f_ocr && len > 0 && s[0] == 'I') {
      return _parseTarjetaIdentidad(s);
    }

    // Si s tiene suficiente longitud para ser cedula con offsets fijos (branch "else" largo en C#)
    if (len > 150) {
      // intentar parseo basado en offsets para cédula normal (copia de offsets usados en C#)
      return _parseCedulaConOffsets(s);
    }

    // Fallback: intentar detectar cédula antigua por regex (número 9-11 dígitos)
    final docMatch = RegExp(r'\b\d{9,11}\b').firstMatch(s);
    if (docMatch != null) {
      return _parseCedulaAntiguaHeuristica(s);
    }

    // Si nada, devolver vacío
    return _empty();
  }

  // ---------- OCR Pasaporte (f_ocr_pass) ----------
  static Map<String, String> _parseOCRPassport(String s) {
    // Según C#:
    // datos = 150; ocr = first 150 bytes -> codigo_ocr
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    // nombreApellido = codigo_ocr.Substring(5,39)
    String nombreApellido = '';
    if (codigo.length >= 5 + 39) nombreApellido = codigo.substring(5, 5 + 39);
    else if (codigo.length > 5) nombreApellido = codigo.substring(5);

    // dato = codigo_ocr.Substring(44)
    String dato = codigo.length > 44 ? codigo.substring(44) : '';

    // numeroPass = dato.Substring(0,9)
    String numeroPass = _safeSubstr(dato, 0, 9);
    numeroPass = numeroPass.replaceAll('\x00', '').replaceAll('O', ''); // similar a C#

    // pais = dato.Substring(10,3)
    String pais = _safeSubstr(dato, 10, 3);

    // nacimiento = dato.Substring(13,6)
    String nacimiento = _safeSubstr(dato, 13, 6);

    // genero = dato.Substring(20,1)
    String genero = _safeSubstr(dato, 20, 1);

    // Separación nombres/apellidos (C# hace split y separa por primer espacio vacío — heurística)
    List<String> parts = nombreApellido.replaceAll('<', ' ').trim().split(RegExp(r'\s+'));
    String apellidos = '', nombres = '';
    if (parts.length >= 2) {
      // el C# asume apellidos primero en MRZ
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
    result['nombre'] = (result['apellidos']! + ' ' + result['nombres']!).trim();
    return result;
  }

  // ---------- OCR Cedula Digital (f_ocr_ced) ----------
  static Map<String, String> _parseOCRCedulaDigital(String s) {
    // C#:
    // datos1 = 150; ocr = first 150 => codigo1_ocr
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    // dato = codigo1_ocr.Substring(0,63)
    String dato = _safeSubstr(codigo, 0, 63);

    // cedula = dato.Substring(48,10)  <-- IMPORTANT: seguimos exactamente este offset (evita error COL0)
    String cedulaNum = _safeSubstr(dato, 48, 10).replaceAll('\x00', '');
    cedulaNum = cedulaNum.replaceAll('O', ''); // C# reemplaza 'O' en algunos casos

    // nacimiento = dato.Substring(30,6)
    String nacimiento = _safeSubstr(dato, 30, 6);

    // genero = dato.Substring(37,1)
    String genero = _safeSubstr(dato, 37, 1);

    // nombreApellido = codigo1_ocr.Substring(60)
    String nombreApellido = codigo.length > 60 ? codigo.substring(60) : '';
    nombreApellido = nombreApellido.replaceAll('<', ' ').trim();

    // Separar apellidos y nombres tal como lo hace C#
    final tokens = nombreApellido.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    String apellidos = '', nombres = '';
    bool separar = false;
    final apList = <String>[];
    final nmList = <String>[];

    for (var t in tokens) {
      if (!separar) {
        // en C# acumula apellidos hasta encontrar token igual a "" — aquí usamos una heurística:
        // si el token contiene un patrón de nombre (no todo mayúsculas?) es complejo; para mantener la lógica:
        // asumimos que los dos primeros tokens son apellidos (como en C# cuando hay suficientes)
        apList.add(t);
        if (apList.length >= 2) separar = true;
      } else {
        nmList.add(t);
      }
    }
    if (apList.isNotEmpty) apellidos = apList.join(' ');
    if (nmList.isNotEmpty) nombres = nmList.join(' ');
    // si no hay separación por heurística, hacemos fallback simple:
    if (apellidos.isEmpty && tokens.length >= 3) {
      apellidos = tokens.take(2).join(' ');
      nombres = tokens.skip(2).join(' ');
    } else if (apellidos.isEmpty) {
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
    result['nombre'] = (result['apellidos']! + ' ' + result['nombres']!).trim();
    return result;
  }

  // ---------- OCR Cedula Extranjeria (f_ocr_cedext) ----------
  static Map<String, String> _parseOCRCedulaExtranjeria(String s) {
    // C#:
    final codigo = s.length >= 150 ? s.substring(0, 150) : s;
    // dato = codigo_ocr.Substring(5,55)
    final dato = _safeSubstr(codigo, 5, 55);

    final numero = _safeSubstr(dato, 0, 9).replaceAll('\x00', '').replaceAll('O', '');
    final nacimiento = _safeSubstr(dato, 25, 6);
    final genero = _safeSubstr(dato, 32, 1);
    final pais = _safeSubstr(dato, 40, 3);

    // nombres: codigo.substring(60) similar al C#
    String nombreApellido = codigo.length > 60 ? codigo.substring(60) : '';
    nombreApellido = nombreApellido.replaceAll('<', ' ').trim();
    final tokens = nombreApellido.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    String apellidos = '', nombres = '';
    if (tokens.length >= 3) {
      apellidos = tokens.take(2).join(' ');
      nombres = tokens.skip(2).join(' ');
    } else if (tokens.length == 2) {
      apellidos = tokens[0];
      nombres = tokens[1];
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
    result['nombre'] = (result['apellidos']! + ' ' + result['nombres']!).trim();
    return result;
  }

  // ---------- Tarjeta Identidad (branch Rx[0]=='I' && !f_ocr) ----------
  static Map<String, String> _parseTarjetaIdentidad(String s) {
    // Implementamos offsets que el C# usa para 'I' (tarjeta identidad)
    // Busca el número de cédula en Rx[48] o Rx[50] según condiciones.
    // Como no tenemos bytes exactos, intentamos reproducir:
    String clean = s.replaceAll('<', ' ');
    String cedula = '';

    // Intento detectar patrón "00" en posiciones 48-49 (índices basados en string)
    if (clean.length >= 50) {
      if (clean[48] == '0' && clean[49] == '0') {
        // extraer desde 50 hasta dígitos
        cedula = _readDigitsFrom(clean, 50);
      } else {
        cedula = _readDigitsFrom(clean, 48);
      }
    } else {
      final m = RegExp(r'\b\d{6,11}\b').firstMatch(clean);
      cedula = m?.group(0) ?? '';
    }

    // Apellidos y nombres: replicar offsets del C# (ej.: primer_apellido desde +tempOffset o +some)
    // Fallback heurístico:
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String apellidos = '', nombres = '';
    if (words.length >= 4) {
      apellidos = words[0] + ' ' + words[1];
      nombres = words.skip(2).take(2).join(' ');
    } else if (words.length >= 2) {
      nombres = words.skip(1).join(' ');
      apellidos = words[0];
    }

    return {
      'tipo': 'TarjetaIdentidad',
      'numero_documento': cedula,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'fecha_nacimiento': '',
      'sexo': '',
      'pais': 'COL',
      'nombre': (apellidos + ' ' + nombres).trim()
    };
  }

  // ---------- Cedula con Offsets largos (branch grande del C# para cedula normal) ----------
  // ---------- Cedula con Offsets largos (branch grande del C# para cedula normal) ----------
static Map<String, String> _parseCedulaConOffsets(String s) {
  //  NO limpiar ni reemplazar '�' antes de indexar: cada carácter ocupa posición como byte.
  final int len = s.length;

  // --- Número de documento ---
  String numero = '';
  if (len > 50) {
    final c48 = len > 48 ? s[48] : '';
    final c49 = len > 49 ? s[49] : '';
    if (c48 == '0' && c49 == '0') {
      numero = _readDigitsFrom(s, 50);
    } else {
      numero = _readDigitsFrom(s, 48);
    }
  } else {
    // Fallback si no cumple longitud
    final m = RegExp(r'\b\d{9,11}\b').firstMatch(s);
    numero = m?.group(0) ?? '';
  }

  // --- Campos por offsets fijos (idénticos al C#) ---
  String primerApellidoRaw = _safeSubstr(s, 52, 30);
  String segundoApellidoRaw = _safeSubstr(s, 82, 30);
  String primerNombreRaw = _safeSubstr(s, 112, 23);
  String segundoNombreRaw = _safeSubstr(s, 135, 23);
  String nacimientoRaw = _safeSubstr(s, 192, 8);
  String sexoRaw = _safeSubstr(s, 200, 1);

  // --- Limpieza de subcadenas ---
  String _clean(String t) => t
      .replaceAll('\x00', '')
      .replaceAll('\uFFFD', '') // '�'
      .replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑáéíóúñ \+\-]'), '')
      .trim();

  final primerApellido = _clean(primerApellidoRaw);
  final segundoApellido = _clean(segundoApellidoRaw).replaceAll('PEA', 'PEÑA');
  final primerNombre = _clean(primerNombreRaw);
  final segundoNombre = _clean(segundoNombreRaw);

  final apellidos = ([primerApellido, segundoApellido].where((x) => x.isNotEmpty).join(' ')).trim();
  final nombres = ([primerNombre, segundoNombre].where((x) => x.isNotEmpty).join(' ')).trim();

  // --- Fecha ---
  String fecha = '';
  final na = nacimientoRaw.replaceAll(RegExp(r'[^0-9]'), '');
  if (na.length == 8) {
    fecha = '${na.substring(0, 4)}-${na.substring(4, 6)}-${na.substring(6, 8)}';
  } else {
    final mdate = RegExp(r'\b(19|20)\d{6}\b').firstMatch(s);
    if (mdate != null) {
      final d = mdate.group(0)!;
      fecha = '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)}';
    }
  }

  final sexo = sexoRaw.replaceAll(RegExp(r'[^MF]'), '');

  return {
    'tipo': 'CedulaAntigua',
    'numero_documento': numero,
    'nombres': nombres,
    'apellidos': apellidos,
    'fecha_nacimiento': fecha,
    'sexo': sexo,
    'pais': 'COL',
    'nombre': (apellidos + ' ' + nombres).trim(),
  };
}

  // ---------- Heurística Cedula Antigua ----------
  static Map<String, String> _parseCedulaAntiguaHeuristica(String s) {
    String clean = s.replaceAll(RegExp(r'[^A-Z0-9Ñ\+ ]'), ' ').trim();
    final docMatch = RegExp(r'\b\d{9,11}\b').firstMatch(clean);
    String doc = docMatch?.group(0) ?? '';

    // buscar fecha formato YYYYMMDD
    final dateMatch = RegExp(r'\b(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\b').firstMatch(clean);
    String fecha = '';
    if (dateMatch != null) {
      final d = dateMatch.group(0)!;
      fecha = '${d.substring(0,4)}-${d.substring(4,6)}-${d.substring(6,8)}';
    } else {
      // fallback: buscar 8 dígitos
      final m2 = RegExp(r'\b\d{8}\b').firstMatch(clean);
      if (m2 != null) {
        final d = m2.group(0)!;
        fecha = '${d.substring(0,4)}-${d.substring(4,6)}-${d.substring(6,8)}';
      }
    }

    // nombres/apellidos heurísticos: tomar palabras en mayúscula
    final words = RegExp(r'[A-ZÑ]{2,}').allMatches(clean).map((m) => m.group(0)!).toList();
    String nombres = '', apellidos = '';
    if (words.length >= 3) {
      apellidos = words.take(2).join(' ');
      nombres = words.skip(2).join(' ');
    } else {
      nombres = words.join(' ');
    }

    final result = <String, String>{
      'tipo': 'CedulaAntigua',
      'numero_documento': doc,
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'fecha_nacimiento': fecha,
      'sexo': '',
      'pais': 'COL',
    };
    result['nombre'] = (result['apellidos']! + ' ' + result['nombres']!).trim();
    return result;
  }

  // ---------- Utilities ----------
  static String _safeSubstr(String s, int start, int length) {
    if (s == null) return '';
    if (start < 0) start = 0;
    if (start >= s.length) return '';
    final end = (start + length) <= s.length ? (start + length) : s.length;
    return s.substring(start, end);
  }

  // Lee dígitos consecutivos a partir de offset (como hace el C# con do..while Rx[b] < 0x3A && Rx[b] > 0x2F)
  static String _readDigitsFrom(String s, int start) {
    if (start >= s.length) return '';
    final buffer = StringBuffer();
    for (int i = start; i < s.length; i++) {
      final ch = s[i];
      if (RegExp(r'\d').hasMatch(ch)) buffer.write(ch);
      else break;
    }
    return buffer.toString();
  }

  static String _formatFechaFromYYMMDD(String s) {
    if (s == null) return '';
    s = s.trim();
    if (s.length != 6) return '';
    final yy = int.tryParse(s.substring(0, 2)) ?? 0;
    final mm = s.substring(2, 4);
    final dd = s.substring(4, 6);
    final century = (yy < 25) ? 2000 : 1900;
    final year = (century + yy).toString().padLeft(4, '0');
    return '$year-$mm-$dd';
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


