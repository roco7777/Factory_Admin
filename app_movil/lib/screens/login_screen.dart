import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'registro_screen.dart';
import 'tienda_screen.dart'; // <--- CORRECCIÓN 1: Importamos la tienda

class LoginScreen extends StatefulWidget {
  final String baseUrl;
  const LoginScreen({super.key, required this.baseUrl});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  final Color rojoFactory = const Color(0xFFD32F2F);

  Future<void> _login() async {
    // Validación básica de campos vacíos
    if (_telController.text.trim().isEmpty ||
        _passController.text.trim().isEmpty) {
      _mostrarError("Por favor, llena todos los campos");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/cliente/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'telefono': _telController.text.trim(),
          'password': _passController.text.trim(),
        }),
      );
      debugPrint("Código de estado: ${response.statusCode}");
      debugPrint(
        "Cuerpo enviado: ${json.encode({'telefono': _telController.text.trim(), 'password': _passController.text.trim()})}",
      );
      debugPrint("Respuesta del servidor: ${response.body}");
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();

        // Guardamos los datos del cliente
        await prefs.setString('cliente_id', data['cliente']['Id'].toString());
        await prefs.setString(
          'cliente_nombre',
          data['cliente']['Nombre2'] ?? "Cliente",
        );

        // Manejamos el teléfono por si viene nulo
        await prefs.setString(
          'cliente_telefono',
          data['cliente']['Telefono'] ?? _telController.text.trim(),
        );

        if (!mounted) return;

        // Navegamos a la tienda y borramos el historial para que no puedan regresar al login con el botón atrás
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TiendaScreen(baseUrl: widget.baseUrl),
          ),
          (route) => false,
        );
      } else {
        _mostrarError(data['message'] ?? "Datos incorrectos");
      }
    } catch (e) {
      _mostrarError("Error de conexión con el servidor");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // CORRECCIÓN 2: Unificamos el nombre de la función de error
  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[900],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Iniciar Sesión"),
        backgroundColor: rojoFactory,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.account_circle, size: 100, color: rojoFactory),
            const SizedBox(height: 30),
            TextFormField(
              controller: _telController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Teléfono de 10 dígitos",
                prefixIcon: Icon(Icons.phone_android, color: rojoFactory),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Contraseña",
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login, // Llamamos a la función _login
                      style: ElevatedButton.styleFrom(
                        backgroundColor: rojoFactory,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "INGRESAR",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RegistroScreen(baseUrl: widget.baseUrl),
                  ),
                );
              },
              child: Text(
                "¿No tienes cuenta? Regístrate aquí",
                style: TextStyle(
                  color: rojoFactory,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
