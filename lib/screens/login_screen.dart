import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para el login seguro
import 'package:cloud_firestore/cloud_firestore.dart'; // Para traer los datos extra
import '../user_model.dart';

class LoginScreen extends StatefulWidget {
  final Function(DatosUsuario) onLoginSuccess;
  final bool esModoOscuro;
  final VoidCallback onCambiarTema;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.esModoOscuro,
    required this.onCambiarTema,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  final Color fucsiaXsim = const Color(0xFFF52784);

  Future<void> _intentarLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarError("Ingresá tu email y contraseña");
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Autenticación con Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      String uid = userCredential.user!.uid;

      // 2. Buscar datos adicionales en Firestore usando el UID
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid) // Buscamos el documento que se llama igual que el UID
          .get();

      if (userDoc.exists) {
        final datos = userDoc.data() as Map<String, dynamic>;

        final usuarioActivo = DatosUsuario(
          uid: uid,
          nombre: datos['nombre'] ?? "Agente",
          rol: datos['rol'] ?? "Inspector",
          localidadId: datos['localidad_id'] ?? "general",
        );

        widget.onLoginSuccess(usuarioActivo);
      } else {
        // Si el usuario existe en Auth pero no tiene documento en Firestore
        _mostrarError("Usuario autenticado, pero no tiene perfil asignado.");
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _mostrarError("No existe un usuario con ese email.");
      } else if (e.code == 'wrong-password') {
        _mostrarError("Contraseña incorrecta.");
      } else {
        _mostrarError("Error: ${e.message}");
      }
    } catch (e) {
      _mostrarError("Error inesperado: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msj),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.esModoOscuro ? const Color(0xFF0D0D0D) : Colors.white,
      body: Stack(
        children: [
          if (widget.esModoOscuro)
            Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)]))),
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: Icon(
                  widget.esModoOscuro ? Icons.light_mode : Icons.dark_mode,
                  color: widget.esModoOscuro ? Colors.white : Colors.black87),
              onPressed: widget.onCambiarTema,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  // Logo Shield
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.esModoOscuro ? Colors.black : Colors.white,
                      border: Border.all(color: fucsiaXsim, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: fucsiaXsim.withAlpha(102), blurRadius: 25) // Corregido
                      ],
                    ),
                    child: Icon(Icons.shield_outlined,
                        size: 60, color: fucsiaXsim),
                  ),
                  const SizedBox(height: 30),
                  Text("XSIM",
                      style: TextStyle(
                          color: widget.esModoOscuro
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 36,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 50),
                  _buildInput(_emailCtrl, "Email", Icons.email_outlined, false),
                  const SizedBox(height: 20),
                  _buildInput(
                      _passCtrl, "Contraseña", Icons.lock_outline, true),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _intentarLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fucsiaXsim,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _cargando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("INGRESAR"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
      TextEditingController ctrl, String hint, IconData icon, bool isPass) {
    return Container(
      decoration: BoxDecoration(
        color: widget.esModoOscuro
            ? Colors.white.withAlpha(13) // Corregido
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        style: TextStyle(
            color: widget.esModoOscuro ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: fucsiaXsim),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }
}
