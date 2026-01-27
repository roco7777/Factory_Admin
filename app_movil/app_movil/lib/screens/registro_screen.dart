import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistroScreen extends StatefulWidget {
  final String baseUrl;
  const RegistroScreen({super.key, required this.baseUrl});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores existentes
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _telController = TextEditingController();

  // NUEVOS Controladores para dirección
  final TextEditingController _calleController = TextEditingController();
  final TextEditingController _barrioController = TextEditingController();
  final TextEditingController _cpController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _estadoController = TextEditingController();

  bool _cargando = false;

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/cliente/registrar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombreCompleto': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passController.text.trim(),
          'telefono': _telController.text.trim(),
          'direccion': _calleController.text.trim(),
          'colonia': _barrioController.text.trim(),
          'cp': _cpController.text.trim(),
          'ciudad': _ciudadController.text.trim(),
          'estado': _estadoController.text.trim(),
        }),
      );

      final data = json.decode(res.body);
      if (data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Registro exitoso! Ya puedes iniciar sesión."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        _mostrarAlerta(data['message'] ?? "Error en el registro");
      }
    } catch (e) {
      _mostrarAlerta("Error de conexión con el servidor");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarAlerta(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Cuenta"),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- SECCIÓN DATOS PERSONALES ---
              // --- Dentro del Column de tu Form en registro_screen.dart ---
              const Text(
                "Datos Personales",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v!.isEmpty ? "El nombre es obligatorio" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _telController,
                decoration: const InputDecoration(
                  labelText: "Teléfono / WhatsApp",
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                  helperText: "Se usará para iniciar sesión",
                ),
                keyboardType: TextInputType.phone,
                // Validamos que sean al menos 10 dígitos para que la clave de 5 funcione
                validator: (v) =>
                    v!.length < 10 ? "Ingresa un número de 10 dígitos" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Correo Electrónico (Opcional)",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                // Solo valida si hay texto; si está vacío, es válido
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  return v.contains("@") ? null : "Formato de correo inválido";
                },
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _passController,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => v!.length < 4 ? "Mínimo 4 caracteres" : null,
              ),
              const SizedBox(height: 20),
              // --- SECCIÓN DIRECCIÓN ---
              const Text(
                "Dirección de Envío",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextFormField(
                controller: _calleController,
                decoration: const InputDecoration(labelText: "Calle y Número"),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              TextFormField(
                controller: _barrioController,
                decoration: const InputDecoration(
                  labelText: "Colonia / Barrio",
                ),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ciudadController,
                      decoration: const InputDecoration(labelText: "Ciudad"),
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _cpController,
                      decoration: const InputDecoration(labelText: "C.P."),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _estadoController,
                decoration: const InputDecoration(labelText: "Estado"),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),

              const SizedBox(height: 40),

              _cargando
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _registrar,
                        child: const Text(
                          "REGISTRARME",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
