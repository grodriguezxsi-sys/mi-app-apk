import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../user_model.dart';
import '../constantes.dart';
import '../main.dart';

class FormularioScreen extends StatefulWidget {
  final DatosUsuario usuario;
  const FormularioScreen({super.key, required this.usuario});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  // Controladores de texto
  final _patenteCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _calleCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  // Controladores y FocusNodes específicos para los Autocomplete (CORRECCIÓN DE ERROR)
  final TextEditingController _autoMarcaCtrl = TextEditingController();
  final TextEditingController _autoModeloCtrl = TextEditingController();
  final FocusNode _focusMarca = FocusNode();
  final FocusNode _focusModelo = FocusNode();

  String? _tipoInfraccionSeleccionada;
  File? _fotoPatente;
  File? _fotoContexto;

  // Variables para control de GPS Manual
  String _coordenadas = "SIN CAPTURAR";
  bool _obteniendoGPS = false;
  bool _cargando = false;

  final List<String> _opcionesInfraccion = [
    "MAL ESTACIONADO",
    "SIN DOCUMENTACIÓN",
    "SEMÁFORO EN ROJO",
    "EXCESO DE VELOCIDAD",
    "OBSTRUCCIÓN DE RAMPA",
    "GIRO PROHIBIDO",
    "OTRO"
  ];

  @override
  void dispose() {
    _patenteCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _calleCtrl.dispose();
    _alturaCtrl.dispose();
    _obsCtrl.dispose();
    _autoMarcaCtrl.dispose();
    _autoModeloCtrl.dispose();
    _focusMarca.dispose(); // Importante liberar los FocusNodes
    _focusModelo.dispose();
    super.dispose();
  }

  // Función para capturar GPS a demanda
  Future<void> _obtenerUbicacionManual() async {
    setState(() {
      _obteniendoGPS = true;
      _coordenadas = "BUSCANDO SEÑAL...";
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _coordenadas = "GPS DESACTIVADO");
        _obteniendoGPS = false;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _coordenadas = "PERMISO DENEGADO");
          _obteniendoGPS = false;
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      setState(() {
        _coordenadas = "${position.latitude}, ${position.longitude}";
        _obteniendoGPS = false;
      });
    } catch (e) {
      setState(() {
        _coordenadas = "ERROR DE SEÑAL";
        _obteniendoGPS = false;
      });
      _mostrarMensaje("ERROR: REINTENTE EN UN LUGAR ABIERTO");
    }
  }

  Future<void> _tomarFoto(bool esPatente) async {
    final pick = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (pick != null) {
      setState(() {
        if (esPatente) {
          _fotoPatente = File(pick.path);
        } else {
          _fotoContexto = File(pick.path);
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (_patenteCtrl.text.trim().length < 6) {
      _mostrarMensaje("PATENTE INVÁLIDA");
      return;
    }
    if (_coordenadas == "SIN CAPTURAR" || _coordenadas.contains("ERROR")) {
      _mostrarMensaje("DEBE CAPTURAR EL GPS PRIMERO");
      return;
    }
    if (_fotoPatente == null) {
      _mostrarMensaje("FALTA FOTO DE PATENTE");
      return;
    }

    setState(() => _cargando = true);

    try {
      final docRef =
          FirebaseFirestore.instance.collection('infracciones').doc();
      final String idActa = docRef.id;
      final String idProyecto = widget.usuario.proyectoId.toUpperCase();
      final DateTime ahora = DateTime.now().toLocal();
      final String fechaStr =
          "${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}";

      String? urlPatente, urlContexto;
      final String rutaBase =
          'proyectos/${idProyecto.toLowerCase()}/infracciones/$idActa';

      if (_fotoPatente != null) {
        final ref =
            FirebaseStorage.instance.ref().child('$rutaBase/foto_patente.jpg');
        await ref.putFile(_fotoPatente!);
        urlPatente = await ref.getDownloadURL();
      }
      if (_fotoContexto != null) {
        final ref =
            FirebaseStorage.instance.ref().child('$rutaBase/foto_contexto.jpg');
        await ref.putFile(_fotoContexto!);
        urlContexto = await ref.getDownloadURL();
      }

      final datos = {
        'nro_acta': idActa.substring(0, 6).toUpperCase(),
        'patente': _patenteCtrl.text.trim().toUpperCase(),
        'marca': _marcaCtrl.text.trim().toUpperCase(),
        'modelo': _modeloCtrl.text.trim().toUpperCase(),
        'calle_ruta': _calleCtrl.text.trim().toUpperCase(),
        'nro_km': _alturaCtrl.text.trim().toUpperCase(),
        'tipo_infraccion': _tipoInfraccionSeleccionada,
        'observaciones': _obsCtrl.text.trim().toUpperCase(),
        'ubicacion': _coordenadas,
        'agente_nombre': widget.usuario.nombre.toUpperCase(),
        'proyecto_id': idProyecto,
        'agente_uid': widget.usuario.uid,
        'fecha_str': fechaStr,
        'fecha': FieldValue.serverTimestamp(),
        'foto_patente_url': urlPatente,
        'foto_contexto_url': urlContexto,
        'estado_ftp': 'PENDIENTE',
      };

      await docRef.set(datos);

      if (mounted) {
        _mostrarDialogoExito(datos);
      }
      _limpiarFormulario();
    } catch (e) {
      _mostrarMensaje("ERROR: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoExito(Map<String, dynamic> d) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text("ACTA REGISTRADA\n¿Cómo desea entregarla?",
            textAlign: TextAlign.center),
        actions: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => funcionCompartirWhatsapp(d),
                    icon: const Icon(Icons.share),
                    label: const Text("WHATSAPP"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => funcionImprimirTicket(d),
                    icon: const Icon(Icons.print),
                    label: const Text("TICKET"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrincipal,
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CERRAR")),
            ],
          )
        ],
      ),
    );
  }

  void _limpiarFormulario() {
    _patenteCtrl.clear();
    _marcaCtrl.clear();
    _modeloCtrl.clear();
    _calleCtrl.clear();
    _alturaCtrl.clear();
    _obsCtrl.clear();
    _autoMarcaCtrl.clear();
    _autoModeloCtrl.clear();
    setState(() {
      _fotoPatente = null;
      _fotoContexto = null;
      _tipoInfraccionSeleccionada = null;
      _coordenadas = "SIN CAPTURAR";
    });
  }

  void _mostrarMensaje(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInput(_patenteCtrl, "PATENTE / DOMINIO", Icons.badge),
            const SizedBox(height: 15),
            _buildAutocomplete(_marcaCtrl, _autoMarcaCtrl, _focusMarca, "MARCA",
                Icons.directions_car, ListasAutocompletado.marcas),
            const SizedBox(height: 15),
            _buildAutocomplete(_modeloCtrl, _autoModeloCtrl, _focusModelo,
                "MODELO", Icons.model_training, ListasAutocompletado.modelos),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                    flex: 2,
                    child: _buildInput(
                        _calleCtrl, "CALLE / RUTA", Icons.add_location_alt)),
                const SizedBox(width: 10),
                Expanded(
                    flex: 1,
                    child: _buildInput(_alturaCtrl, "N° / KM", Icons.numbers)),
              ],
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _tipoInfraccionSeleccionada,
              decoration: const InputDecoration(
                  labelText: "TIPO DE INFRACCIÓN",
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.report_problem, color: colorPrincipal)),
              items: _opcionesInfraccion
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (val) =>
                  setState(() => _tipoInfraccionSeleccionada = val),
            ),
            const SizedBox(height: 15),
            _buildInput(_obsCtrl, "OBSERVACIONES", Icons.edit_note,
                maxLines: 2),
            const SizedBox(height: 15),
            _buildGPSBanner(),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                    child: _botonFoto(
                        "FOTO PATENTE", _fotoPatente, () => _tomarFoto(true))),
                const SizedBox(width: 15),
                Expanded(
                    child: _botonFoto("FOTO CONTEXTO", _fotoContexto,
                        () => _tomarFoto(false))),
              ],
            ),
            const SizedBox(height: 25),
            _cargando
                ? const CircularProgressIndicator(color: colorPrincipal)
                : ElevatedButton(
                    onPressed: _guardar,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrincipal,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    child: const Text("REGISTRAR INFRACCIÓN",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSBanner() {
    bool tieneCoordenadas = _coordenadas.contains(",");
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: tieneCoordenadas
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: tieneCoordenadas
                  ? Colors.green
                  : Colors.orange.withOpacity(0.5))),
      child: Row(children: [
        Icon(Icons.location_on,
            color: tieneCoordenadas ? Colors.green : Colors.orange),
        const SizedBox(width: 10),
        Expanded(
            child: Text("COORDENADAS: $_coordenadas",
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold))),
        _obteniendoGPS
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                icon: const Icon(Icons.refresh, color: colorPrincipal),
                onPressed: _obtenerUbicacionManual)
      ]),
    );
  }

  Widget _buildAutocomplete(
      TextEditingController mainCtrl,
      TextEditingController autoCtrl,
      FocusNode focus,
      String label,
      IconData icon,
      List<String> opciones) {
    return RawAutocomplete<String>(
      textEditingController: autoCtrl,
      focusNode: focus, // CORRECCIÓN: Vinculamos el FocusNode aquí
      optionsBuilder: (val) => val.text.isEmpty
          ? const Iterable<String>.empty()
          : opciones.where((o) => o.contains(val.text.toUpperCase())),
      onSelected: (sel) {
        autoCtrl.text = sel;
        mainCtrl.text = sel;
      },
      fieldViewBuilder: (ctx, fCtrl, fNode, onSub) => TextField(
        controller: fCtrl,
        focusNode: fNode,
        inputFormatters: [UpperCaseTextFormatter()],
        onChanged: (val) => mainCtrl.text = val,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: colorPrincipal),
            border: const OutlineInputBorder()),
      ),
      optionsViewBuilder: (ctx, onSel, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
            elevation: 4,
            child: SizedBox(
                height: 200,
                width: MediaQuery.of(context).size.width - 40,
                child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: opts.length,
                    itemBuilder: (ctx, i) => ListTile(
                        title: Text(opts.elementAt(i)),
                        onTap: () => onSel(opts.elementAt(i)))))),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      inputFormatters: [UpperCaseTextFormatter()],
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: colorPrincipal),
          border: const OutlineInputBorder()),
    );
  }

  Widget _botonFoto(String titulo, File? img, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10)),
        child: img == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.camera_alt, color: Colors.grey),
                Text(titulo, style: const TextStyle(fontSize: 10))
              ])
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(img, fit: BoxFit.cover)),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue old, TextEditingValue newVal) =>
      newVal.copyWith(text: newVal.text.toUpperCase());
}
