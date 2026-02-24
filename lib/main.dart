import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/formulario_screen.dart';
import 'screens/historial_screen.dart';
import 'user_model.dart';

// VARIABLE GLOBAL
const Color colorPrincipal = Color(0xFFF52784);

// --- FUNCIÓN DE IMPRESIÓN ACTUALIZADA (PUNTO 2 CORREGIDO) ---
Future<void> funcionImprimirTicket(Map<String, dynamic> datos) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) => pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
                child: pw.Text("XSIM - REGISTRO OFICIAL",
                    style: pw.TextStyle(fontSize: 10))),
            pw.Center(
                child: pw.Text("ACTA N°: ${datos['nro_acta'] ?? 'S/N'}",
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold))),
            pw.Divider(),
            pw.Text("Patente: ${datos['patente'] ?? '---'}"),
            pw.Text(
                "Vehículo: ${datos['marca'] ?? ''} ${datos['modelo'] ?? ''}"),
            pw.Text(
                "Dirección: ${datos['calle_ruta'] ?? ''} ${datos['nro_km'] ?? ''}"),
            pw.Text("Infracción: ${datos['tipo_infraccion'] ?? 'General'}"),
            pw.Text("Fecha: ${datos['fecha_str'] ?? '---'}"),

            // --- NUEVAS LÍNEAS PARA OBSERVACIONES Y COORDENADAS ---
            pw.SizedBox(height: 5),
            pw.Text("Observaciones:",
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
            pw.Text("${datos['observaciones'] ?? 'SIN OBSERVACIONES'}",
                style: pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 5),
            pw.Text("Ubicación:",
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
            pw.Text("${datos['ubicacion'] ?? 'S/D'}",
                style: pw.TextStyle(fontSize: 7)),

            pw.Divider(),
            pw.Text("Agente: ${datos['agente_nombre'] ?? 'S/D'}"),
            pw.Text("Proyecto: ${datos['proyecto_id'] ?? '---'}"),
            pw.Divider(),
            pw.Center(
                child: pw.Text("Comprobante Digital",
                    style: pw.TextStyle(fontSize: 8))),
          ],
        ),
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Error Firebase: $e");
  }
  runApp(const XSimApp());
}

class XSimApp extends StatefulWidget {
  const XSimApp({super.key});
  @override
  State<XSimApp> createState() => _XSimAppState();
}

class _XSimAppState extends State<XSimApp> {
  bool _esModoOscuro = true;
  int _indiceActual = 0;
  DatosUsuario? _usuarioSesion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _esModoOscuro ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: colorPrincipal),
          inputDecorationTheme: const InputDecorationTheme(
              floatingLabelBehavior: FloatingLabelBehavior.always)),
      darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
              seedColor: colorPrincipal, brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF0D0D0D),
          inputDecorationTheme: const InputDecorationTheme(
              floatingLabelBehavior: FloatingLabelBehavior.always)),
      home: _usuarioSesion == null
          ? LoginScreen(
              esModoOscuro: _esModoOscuro,
              onCambiarTema: () =>
                  setState(() => _esModoOscuro = !_esModoOscuro),
              onLoginSuccess: (user) => setState(() => _usuarioSesion = user),
            )
          : Scaffold(
              appBar: AppBar(
                backgroundColor: _esModoOscuro ? Colors.black : colorPrincipal,
                foregroundColor: Colors.white,
                leading: IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => setState(() => _usuarioSesion = null)),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_usuarioSesion!.nombre.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(
                        "${_usuarioSesion!.rol} - ${_usuarioSesion!.proyectoId.toUpperCase()}",
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white70)),
                  ],
                ),
                actions: [
                  IconButton(
                      icon: Icon(
                          _esModoOscuro ? Icons.light_mode : Icons.dark_mode),
                      onPressed: () =>
                          setState(() => _esModoOscuro = !_esModoOscuro)),
                ],
              ),
              body: IndexedStack(
                index: _indiceActual,
                children: [
                  FormularioScreen(usuario: _usuarioSesion!),
                  HistorialScreen(usuario: _usuarioSesion!),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _indiceActual,
                onDestinationSelected: (i) => setState(() => _indiceActual = i),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.add_circle_outline), label: 'Registrar'),
                  NavigationDestination(
                      icon: Icon(Icons.history), label: 'Historial'),
                ],
              ),
            ),
    );
  }
}
