import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class PanelInventariosAdminScreen extends StatefulWidget {
  final String baseUrl;

  const PanelInventariosAdminScreen({super.key, required this.baseUrl});

  @override
  State<PanelInventariosAdminScreen> createState() =>
      _PanelInventariosAdminScreenState();
}

class _PanelInventariosAdminScreenState
    extends State<PanelInventariosAdminScreen> {
  final TextEditingController _nombreZonaController = TextEditingController();

  int _sucursalSeleccionada = 1;
  String _tipoSeleccionado = 'Parcial';
  bool _isLoading = false;

  final List<int> _listaSucursales = [1, 2, 3, 4, 5];
  final List<String> _tiposInventario = ['Parcial', 'General'];

  Future<void> _crearSesion() async {
    if (_nombreZonaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un nombre para la zona o evento.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      // Asumimos que guardaste el ID del usuario al loguearse, si no, puedes usar 1 como fallback temporal
      final String? usuarioActivo = prefs.getString('saved_user');

      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/inventario/sesiones/nueva'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre_zona': _nombreZonaController.text.trim(),
          'id_sucursal': _sucursalSeleccionada,
          'tipo': _tipoSeleccionado,
          'id_usuario':
              1, // <--- Aquí debes pasar el ID real del supervisor logueado
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '¡Sesión de inventario creada!'),
            backgroundColor: verdeExito,
          ),
        );
        _nombreZonaController.clear();
        // Opcional: Navegar a una pantalla de "Monitoreo" de esta sesión
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Error al crear la sesión.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión con el servidor.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          'Apertura de Inventario',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: azulPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.inventory_rounded, size: 80, color: azulPrimario),
            const SizedBox(height: 20),
            const Text(
              "CONFIGURAR NUEVA SESIÓN",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: azulAcento,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sucursal a inventariar:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _sucursalSeleccionada,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                    ),
                    items: _listaSucursales.map((int valor) {
                      return DropdownMenuItem<int>(
                        value: valor,
                        child: Text("Sucursal $valor"),
                      );
                    }).toList(),
                    onChanged: (int? nuevoValor) {
                      if (nuevoValor != null) {
                        setState(() => _sucursalSeleccionada = nuevoValor);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Nombre de la Zona/Evento:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nombreZonaController,
                    decoration: InputDecoration(
                      hintText: 'Ej. Pasillo A - Abarrotes',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Tipo de Conteo:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _tipoSeleccionado,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                    ),
                    items: _tiposInventario.map((String valor) {
                      return DropdownMenuItem<String>(
                        value: valor,
                        child: Text(valor),
                      );
                    }).toList(),
                    onChanged: (String? nuevoValor) {
                      if (nuevoValor != null) {
                        setState(() => _tipoSeleccionado = nuevoValor);
                      }
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "* Parcial: Solo ajusta lo escaneado.\n* General: Asume en 0 todo lo que no se cuente.",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: azulPrimario),
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      "INICIAR INVENTARIO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          verdeExito, // Usa un color verde de tus constantes o Colors.green
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _crearSesion,
                  ),
          ],
        ),
      ),
    );
  }
}
