import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'edicion_producto_screen.dart';
import '../widgets/scanner_screen.dart';

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
      cbCtrl = TextEditingController(),
      claveProCtrl = TextEditingController(),
      costoCtrl = TextEditingController(text: "0.00"),
      pzasCajaCtrl = TextEditingController(text: "1"),
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
  String cbSugeridoInicial = "";

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
      debugPrint("Error cargando datos iniciales: $e");
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
        if (descCtrl.text.isEmpty) {
          descCtrl.text = "$nuevaClave ";
        }
      });
    } catch (e) {
      debugPrint("Error al generar clave: $e");
    }
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
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final resBody = json.decode(response.body);
        if (resBody['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Producto creado con éxito"),
              backgroundColor: verdeExito,
            ),
          );

          final String claveFinal = resBody['producto'] != null
              ? resBody['producto']['Clave'].toString()
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
          throw Exception(resBody['error'] ?? "Error al guardar.");
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          "Nuevo Producto",
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
        actions: [
          if (!isSaving && !isLoadingData)
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 28),
              onPressed: _guardarNuevo,
            ),
        ],
      ),
      body: (isSaving || isLoadingData)
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("CATEGORIZACIÓN"),
                  DropdownButtonFormField<String>(
                    value: tipoSeleccionado,
                    decoration: _inputStyle(
                      "Seleccionar Tipo",
                      Icons.category_outlined,
                    ),
                    items: tiposCompletos
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['Descripcion'].toString(),
                            child: Text(t['Descripcion'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => tipoSeleccionado = val);
                      if (val != null) _actualizarClaveAuto(val);
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: claveCtrl,
                    readOnly: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: azulPrimario,
                    ),
                    decoration: _inputStyle(
                      "Clave Sugerida (Auto)",
                      Icons.vpn_key_outlined,
                    ).copyWith(fillColor: azulPrimario.withOpacity(0.05)),
                  ),
                  const SizedBox(height: 30),

                  _sectionTitle("DATOS GENERALES"),
                  TextFormField(
                    controller: descCtrl,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _inputStyle(
                      "Descripción del Producto",
                      Icons.description_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cbCtrl,
                          decoration:
                              _inputStyle(
                                "Cód. Barras",
                                Icons.qr_code_2,
                              ).copyWith(
                                prefixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.qr_code_scanner,
                                    color: azulAcento,
                                  ),
                                  onPressed: () async {
                                    final res = await showDialog<String>(
                                      context: context,
                                      builder: (context) =>
                                          const ScannerScreen(),
                                    );
                                    if (res != null)
                                      setState(() => cbCtrl.text = res);
                                  },
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: claveProCtrl,
                          decoration: _inputStyle("Clave Proveedor", Icons.tag),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _sectionTitle("FINANZAS INICIALES"),
                  Row(
                    children: [
                      _numericField(
                        costoCtrl,
                        "Costo Compra",
                        Icons.payments_outlined,
                      ),
                      const SizedBox(width: 10),
                      _numericField(
                        pzasCajaCtrl,
                        "Pzas/Caja",
                        Icons.inventory_2_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _priceRow(p1Ctrl, m1Ctrl, "Precio 1 (Menudeo)"),
                  _utilidadRow(p1Ctrl),
                  _priceRow(p2Ctrl, m2Ctrl, "Precio 2 (Mayoreo)"),
                  _utilidadRow(p2Ctrl),
                  _priceRow(p3Ctrl, m3Ctrl, "Precio 3 (Distribuidor)"),
                  _utilidadRow(p3Ctrl),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 5),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
        color: azulAcento,
        letterSpacing: 1.2,
      ),
    ),
  );

  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: azulAcento, size: 22),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: azulPrimario, width: 1),
    ),
    isDense: true,
  );

  Widget _numericField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) => Expanded(
    child: TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputStyle(label, icon),
      onTap: () {
        if (ctrl.text == "0" || ctrl.text == "0.00") ctrl.clear();
      },
    ),
  );

  Widget _priceRow(
    TextEditingController p,
    TextEditingController m,
    String label,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        _numericField(p, label, Icons.attach_money_rounded),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: m,
            keyboardType: TextInputType.number,
            decoration: _inputStyle("Mín.", Icons.shopping_basket_outlined),
            onTap: () {
              if (m.text == "0") m.clear();
            },
          ),
        ),
      ],
    ),
  );

  Widget _utilidadRow(TextEditingController pCtrl) {
    return ValueListenableBuilder(
      valueListenable: pCtrl,
      builder: (context, valP, child) {
        return ValueListenableBuilder(
          valueListenable: costoCtrl,
          builder: (context, valC, child) {
            double p = double.tryParse(pCtrl.text) ?? 0;
            double c = double.tryParse(costoCtrl.text) ?? 0;
            double ut = p - c;
            double por = (c > 0) ? (ut / c) * 100 : 0;
            return Padding(
              padding: const EdgeInsets.only(left: 15, bottom: 15),
              child: Text(
                "Utilidad: ${formatCurrency(ut)} (${por.toStringAsFixed(1)}%)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: ut >= 0 ? verdeExito : Colors.red,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
