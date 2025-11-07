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
    ReaderPlugin.onScanData.listen((rawData) async {
      final parsed = ColombianIDParser.parse(rawData);
      final csv =
          "${parsed['nombre']},${parsed['numero_documento']},${parsed['fecha_nacimiento']}";
      await Clipboard.setData(ClipboardData(text: csv));
      setState(() {
        _lastScan = "Copiado al portapapeles:\n$csv";
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
                textAlign: TextAlign.center,
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
