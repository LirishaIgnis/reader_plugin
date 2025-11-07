import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reader_plugin/reader_plugin.dart';
import 'package:reader_plugin/utils/id_parser.dart';

void main() {
  runApp(const ReaderExampleApp());
}

class ReaderExampleApp extends StatefulWidget {
  const ReaderExampleApp({Key? key}) : super(key: key);

  @override
  State<ReaderExampleApp> createState() => _ReaderExampleAppState();
}

class _ReaderExampleAppState extends State<ReaderExampleApp> {
  String _lastScan = "Esperando lectura...";

  @override
  void initState() {
    super.initState();

    // Escucha las lecturas del lector
    ReaderPlugin.onScanData.listen((rawData) async {
      final parsed = ColombianIDParser.parse(rawData);

      final tipo = parsed['tipo'] ?? '';
      final numero = parsed['numero_documento'] ?? '';
      final apellidos = parsed['apellidos'] ?? '';
      final nombres = parsed['nombres'] ?? '';
      final fecha = parsed['fecha_nacimiento'] ?? '';

      // Texto formateado en el orden solicitado
      final textoCopiar = '''
Tipo de documento: $tipo
Número de documento: $numero
Apellidos: $apellidos
Nombres: $nombres
Fecha de nacimiento: $fecha
'''.trim();

      // Copiar al portapapeles
      await Clipboard.setData(ClipboardData(text: textoCopiar));

      // Mostrar en pantalla lo que se copió
      setState(() {
        _lastScan = "Copiado al portapapeles:\n\n$textoCopiar";
      });
    });
  }

  void _startScan() async {
    await ReaderPlugin.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Lector cédulas Colombia')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _lastScan,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _startScan,
                child: const Text("Iniciar escaneo"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
