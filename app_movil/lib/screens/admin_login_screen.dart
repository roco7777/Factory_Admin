import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// import 'inventario_screen.dart'; // Ya no lo necesitamos aquí
import 'dashboard_screen.dart'; // <--- Importamos el Dashboard

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
        // Guardamos las credenciales
        await prefs.setString('saved_user', userController.text);
        await prefs.setString('saved_rol', data['rol']?.toString() ?? 'Normal');

        if (!mounted) return;

        // --- CAMBIO CLAVE: Redirigimos al DASHBOARD ---
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Administrativo'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Color(0xFFD32F2F),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: userController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              isLoading
                  ? const CircularProgressIndicator(color: Color(0xFFD32F2F))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: attemptLogin,
                      child: const Text(
                        'ENTRAR AL PANEL',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
