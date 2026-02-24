import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/formulario_screen.dart';
import 'screens/historial_screen.dart';
import 'user_model.dart';

// VARIABLE GLOBAL
const Color colorPrincipal = Color(0xFFF52784);

// --- FUNCIÓN 1: IMPRIMIR TICKET (TÉRMICA O PDF) ---
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
                child: pw.Text("Comprobante Oficial",
                    style: pw.TextStyle(fontSize: 8))),
          ],
        ),
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

// --- FUNCIÓN 2: COMPARTIR POR WHATSAPP (PDF ADJUNTO) ---
Future<void> funcionCompartirWhatsapp(Map<String, dynamic> datos) async {
  final pdf = pw.Document();

  // Agregamos el contenido del PDF para WhatsApp
  pdf.addPage(
    pw.Page(
      pageFormat:
          PdfPageFormat.a4, // Para WhatsApp mejor A4 para que sea legible
      build: (pw.Context context) => pw.Container(
        padding: const pw.EdgeInsets.all(30),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("XSIM - COMPROBANTE DIGITAL",
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text(datos['fecha_str'] ?? '',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text("ACTA DE INFRACCIÓN",
                style:
                    pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text("N° REGISTRO: ${datos['nro_acta'] ?? 'S/N'}",
                style: pw.TextStyle(fontSize: 14, color: PdfColors.pink700)),
            pw.Divider(thickness: 2, color: PdfColors.pink),
            pw.SizedBox(height: 20),

            // Datos del Vehículo
            pw.Text("DATOS DEL VEHÍCULO",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: "DOMINIO/PATENTE: ${datos['patente']}"),
            pw.Bullet(
                text: "MARCA/MODELO: ${datos['marca']} ${datos['modelo']}"),
            pw.SizedBox(height: 15),

            // Datos de la Infracción
            pw.Text("DETALLES DEL HECHO",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: "INFRACCIÓN: ${datos['tipo_infraccion']}"),
            pw.Bullet(text: "LUGAR: ${datos['calle_ruta']} ${datos['nro_km']}"),
            pw.Bullet(text: "COORDENADAS: ${datos['ubicacion']}"),
            pw.SizedBox(height: 15),

            pw.Text("OBSERVACIONES:",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Text(
                  datos['observaciones'] ?? 'SIN OBSERVACIONES EXTRAS.',
                  style: const pw.TextStyle(fontSize: 10)),
            ),

            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                  "Este documento sirve como comprobante digital de la infracción registrada.",
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ),
          ],
        ),
      ),
    ),
  );

  try {
    // 1. Obtener directorio temporal
    final dir = await getTemporaryDirectory();
    final String nombreArchivo =
        "Acta_${datos['patente']}_${datos['nro_acta']}.pdf";
    final file = File("${dir.path}/$nombreArchivo");

    // 2. Guardar el archivo
    await file.writeAsBytes(await pdf.save());

    // 3. Compartir (Se abrirá el selector de apps, incluyendo WhatsApp)
    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          'Se adjunta comprobante de acta N° ${datos['nro_acta']} para la patente ${datos['patente']}.',
    );
  } catch (e) {
    debugPrint("Error al compartir: $e");
  }
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

  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
              body: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _indiceActual = index);
                },
                children: [
                  FormularioScreen(usuario: _usuarioSesion!),
                  HistorialScreen(usuario: _usuarioSesion!),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _indiceActual,
                onDestinationSelected: (i) {
                  setState(() => _indiceActual = i);
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
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
