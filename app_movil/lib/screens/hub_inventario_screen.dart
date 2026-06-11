import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import 'monitor_inventario_screen.dart';

class HubInventarioScreen extends StatefulWidget {
  final String baseUrl;
  const HubInventarioScreen({super.key, required this.baseUrl});

  @override
  State<HubInventarioScreen> createState() => _HubInventarioScreenState();
}

class _HubInventarioScreenState extends State<HubInventarioScreen> {
  int _sucursalSeleccionada = 1;
  final List<int> _listaSucursales = [1, 2, 3, 4, 5];

  bool _isLoading = false;
  bool _haySesionActiva = false;
  Map<String, dynamic>? _sesionActiva;

  // Controladores para crear nueva sesión
  final TextEditingController _nombreZonaController = TextEditingController();
  String _tipoSeleccionado = 'Parcial';

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/inventario/sesiones/activa?id_sucursal=$_sucursalSeleccionada',
        ),
      );
      final data = json.decode(res.body);

      if (data['success'] && data['activa']) {
        setState(() {
          _haySesionActiva = true;
          _sesionActiva = data['sesion'];
        });
      } else {
        setState(() {
          _haySesionActiva = false;
          _sesionActiva = null;
        });
      }
    } catch (e) {
      _mostrarSnack("Error al consultar el estado de la sucursal", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _crearNuevaSesion() async {
    if (_nombreZonaController.text.trim().isEmpty) {
      _mostrarSnack(
        'Asigna un nombre a la zona (Ej. Pasillo A)',
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/inventario/sesiones/nueva'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre_zona': _nombreZonaController.text.trim(),
          'id_sucursal': _sucursalSeleccionada,
          'tipo': _tipoSeleccionado,
          'id_usuario': 1, // ID del supervisor que lo crea
        }),
      );
      final data = json.decode(res.body);

      if (data['success']) {
        _mostrarSnack('¡Sesión iniciada correctamente!', verdeExito);
        _nombreZonaController.clear();
        _verificarSesion(); // Recargamos para mostrar los controles del Hub
      } else {
        _mostrarSnack(data['message'] ?? 'Error al iniciar', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _mostrarSnack('Error de conexión con el servidor', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarSesion() async {
    // Diálogo de seguridad antes de aplicar ajustes críticos
    bool confirmar =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              "⚠️ FINALIZAR INVENTARIO",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "¿Estás seguro de finalizar? Esto ejecutará el cálculo matemático y alterará las existencias de la tienda permanentemente.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCELAR"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("SÍ, APLICAR AJUSTE"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/inventario/sesiones/finalizar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_sesion': _sesionActiva!['id_sesion']}),
      );
      final data = json.decode(res.body);

      if (data['success']) {
        _mostrarSnack(
          'Ajuste de inventario aplicado a la base de datos.',
          verdeExito,
        );
        _verificarSesion(); // Recargamos para volver a la pantalla de "Crear"
      } else {
        _mostrarSnack(
          data['message'] ?? 'Error al aplicar el ajuste',
          Colors.red,
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _mostrarSnack('Error de conexión', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _mostrarSnack(String mensaje, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  // --- WIDGETS DE UI ---

  Widget _buildFormularioCreacion() {
    return Container(
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
            "Zona / Pasillo a evaluar:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nombreZonaController,
            decoration: InputDecoration(
              hintText: 'Ej. Electrónica o Toda la Tienda',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.edit_location_alt_outlined),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Tipo de Inventario:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _tipoSeleccionado,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: ['Parcial', 'General'].map((String valor) {
              return DropdownMenuItem<String>(value: valor, child: Text(valor));
            }).toList(),
            onChanged: (val) => setState(() => _tipoSeleccionado = val!),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              "ABRIR SESIÓN PARA COLABORADORES",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: verdeExito,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: _crearNuevaSesion,
          ),
        ],
      ),
    );
  }

  Widget _buildPanelControlActivo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: azulPrimario.withOpacity(0.1),
            border: Border.all(color: azulPrimario),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync, color: azulPrimario, size: 40),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Inventario en Progreso",
                      style: TextStyle(
                        color: azulPrimario,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Zona: ${_sesionActiva!['nombre_zona']}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Inició: ${_sesionActiva!['fecha_inicio']}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Botón al Monitor
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MonitorInventarioScreen(
                  baseUrl: widget.baseUrl,
                  idSesion: _sesionActiva!['id_sesion'],
                  nombreZona: _sesionActiva!['nombre_zona'],
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 25,
                  child: Icon(Icons.remove_red_eye, color: Colors.white),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Monitor en Vivo",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Revisar escaneos y mermas",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Botón Peligroso: Finalizar
        InkWell(
          onTap: _finalizarSesion,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 25,
                  child: Icon(Icons.check_circle_outline, color: Colors.white),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Finalizar y Ajustar",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        "Aplica existencias permanentemente",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          'Centro de Mando',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: azulPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // SELECTOR DE SUCURSAL GLOBAL
          Container(
            color: azulPrimario,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _sucursalSeleccionada,
                  icon: const Icon(Icons.storefront, color: azulPrimario),
                  items: _listaSucursales.map((int valor) {
                    return DropdownMenuItem<int>(
                      value: valor,
                      child: Text(
                        "Gestionar Sucursal $valor",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (int? nuevoValor) {
                    if (nuevoValor != null &&
                        nuevoValor != _sucursalSeleccionada) {
                      setState(() => _sucursalSeleccionada = nuevoValor);
                      _verificarSesion(); // Al cambiar, revisamos qué está pasando en esa sucursal
                    }
                  },
                ),
              ),
            ),
          ),

          // CONTENIDO DINÁMICO
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: azulPrimario),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(25.0),
                    child: _haySesionActiva
                        ? _buildPanelControlActivo()
                        : _buildFormularioCreacion(),
                  ),
          ),
        ],
      ),
    );
  }
}
