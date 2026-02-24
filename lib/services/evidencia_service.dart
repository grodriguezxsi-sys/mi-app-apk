import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class EvidenciaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, String>> subirEvidencias(
      String idMulta, File patenteFile, File contextoFile) async {
    try {
      // 1. Definir las rutas (Aquí es donde se crean las "carpetas" automáticamente)
      Reference refPatente =
          _storage.ref().child('infracciones/$idMulta/foto_patente.jpg');
      Reference refContexto =
          _storage.ref().child('infracciones/$idMulta/foto_contexto.jpg');

      // 2. Subir archivos
      UploadTask uploadPatente = refPatente.putFile(patenteFile);
      UploadTask uploadContexto = refContexto.putFile(contextoFile);

      // 3. Esperar a que terminen y obtener las URLs de descarga
      TaskSnapshot snapshotPatente = await uploadPatente;
      TaskSnapshot snapshotContexto = await uploadContexto;

      String urlPatente = await snapshotPatente.ref.getDownloadURL();
      String urlContexto = await snapshotContexto.ref.getDownloadURL();

      // Devolvemos un mapa con los links para guardarlos luego en Firestore
      return {
        'foto_patente': urlPatente,
        'foto_contexto': urlContexto,
      };
    } catch (e) {
      print('Error al subir evidencias: $e');
      rethrow;
    }
  }
}
