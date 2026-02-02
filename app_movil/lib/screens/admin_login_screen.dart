import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/security_service.dart'; // <--- IMPORTANTE: Importamos el nuevo servicio
import 'dashboard_screen.dart';
import '../core/security_service.dart';

class AdminLoginScreen extends StatefulWidget {
  final String baseUrl;
  const AdminLoginScreen({super.key, required this.baseUrl});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> attemptLogin() async {
    if (userController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': userController.text,
          'password': passwordController.text,
        }),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final prefs = await SharedPreferences.getInstance();

        // --- SEGURIDAD PLUS: GUARDADO DE DATOS Y PERMISOS ---
        await prefs.setString(
          'saved_user',
          data['user']?.toString() ?? userController.text,
        );
        await prefs.setString('saved_rol', data['rol']?.toString() ?? 'Normal');

        // Guardamos la lista de slugs que viene del servidor
        if (data['permisos'] != null) {
          List<String> listaPermisos = List<String>.from(data['permisos']);
          await prefs.setStringList('user_permissions', listaPermisos);

          // Cargamos los permisos en el servicio inmediatamente para que estén listos
          await SecurityService.cargarPermisos();
        }
        // ---------------------------------------------------

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(baseUrl: widget.baseUrl),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Acceso denegado')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión con el servidor administrativo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El resto de tu UI se mantiene igual, ya tiene el estilo Factory Pro.
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          'Acceso Administrativo',
          style: TextStyle(fontWeight: FontWeight.w300, fontSize: 18),
        ),
        backgroundColor: azulPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                size: 100,
                color: azulPrimario,
              ),
              const SizedBox(height: 10),
              Text(
                "FACTORY SUITE",
                style: TextStyle(
                  color: azulAcento.withOpacity(0.7),
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: userController,
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  labelStyle: const TextStyle(color: azulAcento),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: azulAcento,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: azulAcento),
                  prefixIcon: const Icon(Icons.lock_outline, color: azulAcento),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              isLoading
                  ? const CircularProgressIndicator(color: azulPrimario)
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulPrimario,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                      ),
                      onPressed: attemptLogin,
                      child: const Text(
                        'INGRESAR AL SISTEMA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              Text(
                "Servidor: ${widget.baseUrl}",
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
