// Importaciones necesarias
import 'package:flutter/material.dart';              // Para construir la interfaz de usuario
import 'package:flutter/services.dart';              // Para usar el portapapeles (Clipboard)
import 'package:reader_plugin/reader_plugin.dart';   // Plugin nativo que controla el lector físico
import 'package:reader_plugin/utils/id_parser.dart'; // Utilidad que procesa el texto leído (parseo de cédulas)

void main() {
  // Punto de entrada principal de la app Flutter
  runApp(const ReaderExampleApp());
}

// --------------------------------------------------------------------------
// Widget principal de la aplicación
// --------------------------------------------------------------------------
class ReaderExampleApp extends StatefulWidget {
  const ReaderExampleApp({Key? key}) : super(key: key);

  @override
  State<ReaderExampleApp> createState() => _ReaderExampleAppState();
}

// --------------------------------------------------------------------------
//  Estado de la aplicación (donde se maneja la lógica principal)
// --------------------------------------------------------------------------
class _ReaderExampleAppState extends State<ReaderExampleApp> {
  // Variable que almacena el último texto leído y mostrado en pantalla
  String _lastScan = "Esperando lectura...";

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------------------
    // Se establece la escucha del flujo de datos del lector (eventos nativos)
    // ----------------------------------------------------------------------
    ReaderPlugin.onScanData.listen((rawData) async {
      // 1. Mostrar en consola el texto crudo tal como lo envía la tablet
      print("=== DATO CRUDO DEL LECTOR ===");
      print(rawData);
      print("=== FIN DATO CRUDO ===\n");

      // 2. Procesar los datos con el parser colombiano (ColombianIDParser)
      // Este parser interpreta el texto y separa los campos: tipo, número, nombres, etc.
      final parsed = ColombianIDParser.parse(rawData);

      // 3. Mostrar en consola el resultado del procesamiento
      print("=== RESULTADO PARSEADO ===");
      parsed.forEach((key, value) {
        print("$key: $value");
      });
      print("=== FIN PARSEADO ===\n");

      // 4. Extraer los datos específicos del mapa resultante
      final tipo = parsed['tipo'] ?? '';
      final numero = parsed['numero_documento'] ?? '';
      final apellidos = parsed['apellidos'] ?? '';
      final nombres = parsed['nombres'] ?? '';
      final fecha = parsed['fecha_nacimiento'] ?? '';

      // 5. Construir un texto formateado con los datos en el orden solicitado
      final textoCopiar = '''
Tipo de documento: $tipo
Número de documento: $numero
Apellidos: $apellidos
Nombres: $nombres
Fecha de nacimiento: $fecha
'''.trim();

      // 6. Copiar el texto final al portapapeles del dispositivo
      await Clipboard.setData(ClipboardData(text: textoCopiar));

      // 7. Actualizar la interfaz para mostrar que se copió correctamente
      setState(() {
        _lastScan = "Copiado al portapapeles:\n\n$textoCopiar";
      });
    });
  }

  // --------------------------------------------------------------------------
  //  Método que solicita al plugin iniciar el proceso de escaneo
  // --------------------------------------------------------------------------
  void _startScan() async {
    await ReaderPlugin.startScan(); // Llama al método nativo Android "startScan"
  }

  // --------------------------------------------------------------------------
  // Construcción de la interfaz gráfica de la app
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        // Barra superior con el título de la aplicación
        appBar: AppBar(title: const Text('Lector cédulas Colombia')),

        // Cuerpo principal de la pantalla
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Muestra el resultado del último escaneo o el mensaje inicial
              Text(
                _lastScan,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30), // Espacio entre texto y botón

              // Botón que al presionarse inicia el escaneo
              ElevatedButton(
                onPressed: _startScan,                 // Acción al presionar
                child: const Text("Iniciar escaneo"), // Texto del botón
              ),
            ],
          ),
        ),
      ),
    );
  }
}
