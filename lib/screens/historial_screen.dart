import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user_model.dart';
import '../main.dart';

class HistorialScreen extends StatelessWidget {
  final DatosUsuario usuario;
  const HistorialScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('infracciones')
          .where('localidad_id', isEqualTo: usuario.localidadId.toUpperCase())
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("ERROR: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => _buildSkeletonLoader(),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("SIN REGISTROS"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final d = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                onTap: () => _mostrarDetalle(context, d),
                leading: const Icon(Icons.description, color: colorPrincipal),
                title: Text("ACTA: ${d['nro_acta'] ?? 'S/N'}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle:
                    Text("${d['patente'] ?? 'S/D'} - ${d['localidad_id'] ?? 'S/L'} - ${d['fecha_str'] ?? ''}"),
                trailing: const Icon(Icons.chevron_right, size: 18),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.grey.withAlpha(26),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: Colors.black26, shape: BoxShape.circle)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 120, height: 12, color: Colors.black26),
              const SizedBox(height: 8),
              Container(width: 80, height: 10, color: Colors.black12),
            ],
          )
        ],
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("DETALLE DE ACTA",
                    style: TextStyle(
                        color: colorPrincipal, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: "Imprimir Ticket",
                  onPressed: () => funcionImprimirTicket(d),
                ),
              ],
            ),
            const Divider(),
            _infoRow("NRO ACTA", d['nro_acta']),
            const SizedBox(height: 10),
            // --- ORDEN CORREGIDO Y CAMPOS SEPARADOS ---
            _infoRow("FECHA", d['fecha_str']),
            _infoRow("PATENTE", d['patente']),
            _infoRow("MARCA", d['marca']),
            _infoRow("MODELO", d['modelo']),
            _infoRow("CALLE/RUTA", d['calle_ruta']),
            _infoRow("ALTURA/KM", d['nro_km']),
            _infoRow("LOCALIDAD", d['localidad_id']),
            _infoRow("INFRACCIÓN", d['tipo_infraccion']),
            _infoRow("OBSERVACIONES", d['observaciones']),
            _infoRow("UBICACIÓN", d['ubicacion']),
            _infoRow("AGENTE", d['agente_nombre']),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CERRAR"),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text("$label: ",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
          Expanded(
              child: Text(value == null || value.isEmpty ? "SIN DATOS" : value,
                  style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
