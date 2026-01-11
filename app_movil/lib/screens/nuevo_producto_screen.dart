import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart'; // Para formatCurrency
import 'edicion_producto_screen.dart'; // IMPORTACIÓN NECESARIA
import '../widgets/scanner_screen.dart'; // IMPORTACIÓN PARA EL SCANNER

class NuevoProductoScreen extends StatefulWidget {
  final String baseUrl;
  final String userRole;
  final List<String> sucursalNames;
  const NuevoProductoScreen({
    super.key,
    required this.baseUrl,
    required this.userRole,
    required this.sucursalNames,
  });

  @override
  State<NuevoProductoScreen> createState() => _NuevoProductoScreenState();
}

class _NuevoProductoScreenState extends State<NuevoProductoScreen> {
  final TextEditingController claveCtrl = TextEditingController(),
      descCtrl = TextEditingController(),
      cbCtrl =
          TextEditingController(), // NUEVO: Código de Barras
      claveProCtrl =
          TextEditingController(), // NUEVO: Clave Proveedor
      costoCtrl = TextEditingController(text: "0.00"),
      pzasCajaCtrl = TextEditingController(text: "1"),
      tipoCtrl = TextEditingController(),
      p1Ctrl = TextEditingController(text: "0.00"),
      p2Ctrl = TextEditingController(text: "0.00"),
      p3Ctrl = TextEditingController(text: "0.00"),
      m1Ctrl = TextEditingController(text: "0"),
      m2Ctrl = TextEditingController(text: "0"),
      m3Ctrl = TextEditingController(text: "0");

  bool isSaving = false;
  bool isLoadingData = true;
  List<Map<String, dynamic>> tiposCompletos = [];
  String? tipoSeleccionado;
  String cbSugeridoInicial = ""; // Para comparar al guardar

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${widget.baseUrl}/api/tipos')),
        http.get(Uri.parse('${widget.baseUrl}/api/siguiente-cb')),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        final List<dynamic> tiposJson = json.decode(results[0].body);
        final cbData = json.decode(results[1].body);

        setState(() {
          tiposCompletos = List<Map<String, dynamic>>.from(tiposJson);
          cbSugeridoInicial = cbData['siguienteCB']?.toString() ?? "";
          cbCtrl.text = cbSugeridoInicial;
          isLoadingData = false;
        });
      }
    } catch (e) {
      print("Error cargando datos iniciales: $e");
      setState(() => isLoadingData = false);
    }
  }

  void _actualizarClaveAuto(String nombreTipo) {
    try {
      final tipoData = tiposCompletos.firstWhere(
        (t) => t['Descripcion'] == nombreTipo,
      );
      String letra = tipoData['Letra'] ?? 'X';
      int consecutivo = int.tryParse(tipoData['Consecutivo'].toString()) ?? 1;
      String nuevaClave = "$letra${consecutivo.toString().padLeft(3, '0')}";

      setState(() {
        claveCtrl.text = nuevaClave;
        tipoCtrl.text = nombreTipo;
        if (descCtrl.text.isEmpty) {
          descCtrl.text = "$nuevaClave ";
        }
      });
    } catch (e) {
      print("Error al generar clave: $e");
    }
  }

  Widget _buildUtilidadVisual(TextEditingController pCtrl) {
    return ValueListenableBuilder(
      valueListenable: pCtrl,
      builder: (context, valP, child) {
        return ValueListenableBuilder(
          valueListenable: costoCtrl,
          builder: (context, valC, child) {
            double p = double.tryParse(pCtrl.text) ?? 0;
            double c = double.tryParse(costoCtrl.text) ?? 0;
            double ut = 0;
            double por = 0;

            if (p > 0) {
              ut = p - c;
              por = (c > 0) ? (ut / c) * 100 : 0;
            }

            return Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 10, top: 2),
              child: Text(
                "Ganancia: ${formatCurrency(ut)} (${por.toStringAsFixed(1)}%)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: p == 0
                      ? Colors.grey
                      : (ut >= 0 ? Colors.green[700] : Colors.red),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _guardarNuevo() async {
    if (claveCtrl.text.isEmpty ||
        descCtrl.text.isEmpty ||
        tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tipo, Clave y Descripción son obligatorios"),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    final payload = {
      'Clave': claveCtrl.text.trim(),
      'Descripcion': descCtrl.text.trim().toUpperCase(),
      'CB': cbCtrl.text.trim(),
      'ClavePro': claveProCtrl.text.trim(),
      'PCosto': costoCtrl.text,
      'PzasxCaja': pzasCajaCtrl.text,
      'Tipo': tipoSeleccionado,
      'Precio1': p1Ctrl.text,
      'Precio2': p2Ctrl.text,
      'Precio3': p3Ctrl.text,
      'Min1': m1Ctrl.text,
      'Min2': m2Ctrl.text,
      'Min3': m3Ctrl.text,
    };

    try {
      final response = await http
          .post(
            Uri.parse('${widget.baseUrl}/api/abmc/producto/nuevo'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final resBody = json.decode(response.body);
        if (resBody['success'] == true) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ ÉXITO: Guardado en Base de Datos"),
              backgroundColor: Colors.green,
            ),
          );

          final productoData = resBody['producto'];
          final String claveFinal = productoData != null
              ? productoData['Clave'].toString()
              : resBody['clave'].toString();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EdicionProductoScreen(
                clave: claveFinal,
                baseUrl: widget.baseUrl,
                userRole: widget.userRole,
                sucursalNames: widget.sucursalNames,
              ),
            ),
          );
        } else {
          throw Exception(resBody['error'] ?? "Error desconocido al guardar.");
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['error'] ?? "Error del servidor: ${response.statusCode}",
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _numericField(TextEditingController ctrl, String label) => Expanded(
    child: TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onTap: () {
        if (ctrl.text == "0" || ctrl.text == "0.00" || ctrl.text == "0.0") {
          ctrl.clear();
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo Producto"),
        backgroundColor: const Color(0xFFD32F2F), // Rojo Factory
        actions: [
          if (!isSaving && !isLoadingData)
            IconButton(icon: const Icon(Icons.check), onPressed: _guardarNuevo),
        ],
      ),
      body: (isSaving || isLoadingData)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tipoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: "Tipo / Categoría",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: tiposCompletos.map((t) {
                      return DropdownMenuItem<String>(
                        value: t['Descripcion'].toString(),
                        child: Text(t['Descripcion'].toString()),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() => tipoSeleccionado = newValue);
                      if (newValue != null) _actualizarClaveAuto(newValue);
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: claveCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Clave del Producto (Auto)",
                      border: OutlineInputBorder(),
                      fillColor: Color(0xFFFFF9C4),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: descCtrl,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cbCtrl,
                          decoration: InputDecoration(
                            labelText: "Cód. Barras",
                            border: const OutlineInputBorder(),
                            isDense: true,
                            // SE AÑADE LA LÓGICA DE ESCANEO AQUÍ
                            prefixIcon: IconButton(
                              icon: const Icon(
                                Icons.qr_code_scanner,
                                size: 20,
                                color: Color(0xFFD32F2F),
                              ),
                              onPressed: () async {
                                final res = await showDialog<String>(
                                  context: context,
                                  builder: (context) => const ScannerScreen(),
                                );
                                if (res != null) {
                                  setState(() {
                                    cbCtrl.text = res;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: claveProCtrl,
                          decoration: const InputDecoration(
                            labelText: "Clave Proveedor",
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: Icon(Icons.inventory_2, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _numericField(costoCtrl, "Costo"),
                      const SizedBox(width: 8),
                      _numericField(pzasCajaCtrl, "Pzas/Caja"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "PRECIOS Y UTILIDADES",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      _numericField(p1Ctrl, "Precio 1"),
                      const SizedBox(width: 8),
                      _numericField(m1Ctrl, "Min 1"),
                    ],
                  ),
                  _buildUtilidadVisual(p1Ctrl),
                  Row(
                    children: [
                      _numericField(p2Ctrl, "Precio 2"),
                      const SizedBox(width: 8),
                      _numericField(m2Ctrl, "Min 2"),
                    ],
                  ),
                  _buildUtilidadVisual(p2Ctrl),
                  Row(
                    children: [
                      _numericField(p3Ctrl, "Precio 3"),
                      const SizedBox(width: 8),
                      _numericField(m3Ctrl, "Min 3"),
                    ],
                  ),
                  _buildUtilidadVisual(p3Ctrl),
                ],
              ),
            ),
    );
  }
}
