class ColombianIDParser {
  static Map<String, String> parse(String raw) {
    raw = raw.trim();

    // Caso 1: Nueva cédula (MRZ)
    if (raw.startsWith('ICCOL')) {
      final docReg = RegExp(r'COL(\d{8,11})');
      final birthReg = RegExp(r'(\d{6})[MF]');
      final nameReg = RegExp(r'([A-Z<]+)<$');

      final docMatch = docReg.firstMatch(raw);
      final birthMatch = birthReg.firstMatch(raw);

      String document = docMatch?.group(1) ?? '';
      String birth = birthMatch != null ? birthMatch.group(1)! : '';

      String formattedBirth = '';
      if (birth.isNotEmpty) {
        final year = int.parse(birth.substring(0, 2));
        final month = birth.substring(2, 4);
        final day = birth.substring(4, 6);
        // Si año menor a 25 asumimos 2000+, si no 1900+
        final fullYear = (year < 25 ? '20' : '19') + year.toString().padLeft(2, '0');
        formattedBirth = '$fullYear-$month-$day';
      }

      // Extraer nombres (después del documento, delimitado por <)
      String namesSection = raw.split('COL').last;
      if (namesSection.contains('<')) {
        final parts = namesSection.split('<');
        final letters = parts.where((e) => e.isNotEmpty && RegExp(r'[A-ZÑ]').hasMatch(e)).toList();
        if (letters.length >= 2) {
          final surnames = letters.take(2).join(' ');
          final names = letters.skip(2).join(' ');
          return {
            'nombre': names.replaceAll('<', ' ').trim(),
            'numero_documento': document,
            'fecha_nacimiento': formattedBirth,
            'apellidos': surnames,
          };
        }
      }
    }

    // Caso 2: Cédula antigua
    final docReg = RegExp(r'\b\d{8,11}\b');
    final dateReg = RegExp(r'\b(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\b');
    final wordReg = RegExp(r'[A-ZÑ]{3,}');

    final doc = docReg.firstMatch(raw)?.group(0) ?? '';
    final date = dateReg.firstMatch(raw)?.group(0) ?? '';

    String formattedDate = '';
    if (date.isNotEmpty) {
      formattedDate =
          '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
    }

    final words = wordReg.allMatches(raw).map((m) => m.group(0)!).toList();
    final possibleNames =
        words.where((w) => w.length > 3 && !w.contains(RegExp(r'\d'))).join(' ');

    return {
      'nombre': possibleNames.trim(),
      'numero_documento': doc,
      'fecha_nacimiento': formattedDate,
    };
  }
}
