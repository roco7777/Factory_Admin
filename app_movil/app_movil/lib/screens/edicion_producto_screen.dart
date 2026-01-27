import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import '../screens/ficha_producto_helper.dart'; // Importante: que la ruta sea correcta

class EdicionProductoScreen extends StatefulWidget {
  final String clave;
  final String baseUrl;
  final String userRole;
  final List<String> sucursalNames;

  const EdicionProductoScreen({
    super.key,
    required this.clave,
    required this.baseUrl,
    required this.userRole,
    required this.sucursalNames,
  });

  @override
  State<EdicionProductoScreen> createState() => _EdicionProductoScreenState();
}

class _EdicionProductoScreenState extends State<EdicionProductoScreen> {
  bool isLoading = true, isSaving = false;
  String? fotoActual;

  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController cbCtrl = TextEditingController();
  final TextEditingController claveProCtrl = TextEditingController();
  final TextEditingController costoCtrl = TextEditingController();
  final TextEditingController pzasCajaCtrl = TextEditingController();
  final TextEditingController tipoCtrl = TextEditingController();
  final TextEditingController p1Ctrl = TextEditingController();
  final TextEditingController p2Ctrl = TextEditingController();
  final TextEditingController p3Ctrl = TextEditingController();
  final TextEditingController m1Ctrl = TextEditingController();
  final TextEditingController m2Ctrl = TextEditingController();
  final TextEditingController m3Ctrl = TextEditingController();

  final Map<int, TextEditingController> vCtrls = {}, bCtrls = {};
  final Map<int, bool> activoStocks = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    for (int i = 1; i <= 5; i++) {
      vCtrls[i] = TextEditingController();
      bCtrls[i] = TextEditingController();
      activoStocks[i] = true;
    }
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/producto/${widget.clave}'),
      );
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        setState(() {
          fotoActual = d['Foto'];
          descCtrl.text = d['Descripcion']?.toString() ?? '';
          cbCtrl.text = d['CB']?.toString() ?? '';
          claveProCtrl.text = d['ClavePro']?.toString() ?? '';
          costoCtrl.text =
              (double.tryParse(d['PCosto']?.toString() ?? '0') ?? 0)
                  .toStringAsFixed(2);
          p1Ctrl.text = (double.tryParse(d['Precio1']?.toString() ?? '0') ?? 0)
              .toStringAsFixed(2);
          p2Ctrl.text = (double.tryParse(d['Precio2']?.toString() ?? '0') ?? 0)
              .toStringAsFixed(2);
          p3Ctrl.text = (double.tryParse(d['Precio3']?.toString() ?? '0') ?? 0)
              .toStringAsFixed(2);
          pzasCajaCtrl.text = d['PzasxCaja']?.toString() ?? '1';
          m1Ctrl.text = (double.tryParse(d['Min1']?.toString() ?? '0') ?? 0)
              .toStringAsFixed(0);
          m2Ctrl.text = (double.tryParse(d['Min2']?.toString() ?? '0') ?? 0)
              .toStringAsFixed(0);
          m3Ctrl.text = (double.tryParse(d['Min3']?.toString() ?? '0') ?? 0)
              .toStringAsFixed(0);
          tipoCtrl.text = d['Tipo']?.toString() ?? '';

          for (int i = 1; i <= 5; i++) {
            vCtrls[i]!.text =
                (double.tryParse(d['alm${i}_pventas']?.toString() ?? '0') ?? 0)
                    .toStringAsFixed(0);
            bCtrls[i]!.text =
                (double.tryParse(d['alm${i}_bodega']?.toString() ?? '0') ?? 0)
                    .toStringAsFixed(0);
            activoStocks[i] =
                (d['alm${i}_activo'] == 1 || d['alm${i}_activo'] == true);
          }
        });
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _eliminarFoto() async {
    setState(() => isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/producto/delete-foto'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'clave': widget.clave}),
      );
      if (response.statusCode == 200) {
        setState(() => fotoActual = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("🗑️ Foto eliminada")));
      }
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 40,
      maxWidth: 800,
    );
    if (image == null) return;
    setState(() => isSaving = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${widget.baseUrl}/api/producto/upload-foto'),
      );
      request.fields['clave'] = widget.clave;
      request.files.add(await http.MultipartFile.fromPath('foto', image.path));
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var result = json.decode(responseData);
      if (response.statusCode == 200 && result['success']) {
        setState(() => fotoActual = result['foto']);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Foto actualizada")));
      }
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> _updateProduct() async {
    if (widget.userRole != 'Administrador') return;
    setState(() => isSaving = true);
    try {
      final stocksMap = <String, dynamic>{};
      for (int i = 1; i <= 5; i++) {
        stocksMap['alm$i'] = {
          'ExisPVentas': vCtrls[i]!.text,
          'ExisBodega': bCtrls[i]!.text,
          'ACTIVO': activoStocks[i]! ? 1 : 0,
        };
      }
      final payload = {
        'Clave': widget.clave,
        'Descripcion': descCtrl.text.toUpperCase(),
        'CB': cbCtrl.text.trim(),
        'ClavePro': claveProCtrl.text.trim(),
        'PCosto': costoCtrl.text,
        'PzasxCaja': pzasCajaCtrl.text,
        'Tipo': tipoCtrl.text,
        'Precio1': p1Ctrl.text,
        'Precio2': p2Ctrl.text,
        'Precio3': p3Ctrl.text,
        'Min1': m1Ctrl.text,
        'Min2': m2Ctrl.text,
        'Min3': m3Ctrl.text,
        'stocks': stocksMap,
      };
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/abmc/producto/${widget.clave}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (response.statusCode == 200) Navigator.pop(context, true);
    } catch (e) {
      print("Error al actualizar producto: $e");
    } finally {
      setState(() => isSaving = false);
    }
  }

  Widget _internalNumericField(
    TextEditingController ctrl,
    String label, {
    bool enabled = true,
  }) => Expanded(
    child: TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onTap: () {
        if (ctrl.text == "0" || ctrl.text == "0.0" || ctrl.text == "0.00")
          ctrl.clear();
      },
    ),
  );

  Widget _internalUtilidad(
    TextEditingController pCtrl,
    TextEditingController cCtrl,
  ) {
    return ValueListenableBuilder(
      valueListenable: pCtrl,
      builder: (context, val, child) {
        return ValueListenableBuilder(
          valueListenable: cCtrl,
          builder: (context, valC, child) {
            double p = double.tryParse(pCtrl.text) ?? 0,
                c = double.tryParse(cCtrl.text) ?? 0;
            double ut = p - c;
            double por = c > 0 ? (ut / c) * 100 : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "Ganancia: ${formatCurrency(ut)} (${por.toStringAsFixed(1)}%)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: ut >= 0 ? Colors.green : Colors.red,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final can = widget.userRole == 'Administrador';
    return Scaffold(
      appBar: AppBar(
        title: Text("Editar: ${widget.clave}"),
        backgroundColor: const Color(0xFFD32F2F),
        actions: [
          if (can && !isLoading)
            IconButton(icon: const Icon(Icons.save), onPressed: _updateProduct),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            GestureDetector(
                              onTap: can ? () => _mostrarMenuFoto() : null,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.blue,
                                        width: 2,
                                      ),
                                    ),
                                    child: fotoActual != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.network(
                                              '${widget.baseUrl}/uploads/$fotoActual?t=${DateTime.now().millisecondsSinceEpoch}',
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.add_a_photo,
                                            size: 50,
                                            color: Colors.blue,
                                          ),
                                  ),
                                  if (can)
                                    const CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      radius: 18,
                                      child: Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (fotoActual != null)
                              Positioned(
                                top: -5,
                                right: -5,
                                child: IconButton(
                                  icon: const CircleAvatar(
                                    backgroundColor: Colors.green,
                                    radius: 16,
                                    child: Icon(
                                      Icons.share,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    List<Map<String, dynamic>> listaPrecios = [
                                      {
                                        'Etiqueta': 'PRECIO 1',
                                        'Precio': p1Ctrl.text,
                                        'Minimo': m1Ctrl.text,
                                      },
                                      {
                                        'Etiqueta': 'PRECIO 2',
                                        'Precio': p2Ctrl.text,
                                        'Minimo': m2Ctrl.text,
                                      },
                                      {
                                        'Etiqueta': 'PRECIO 3',
                                        'Precio': p3Ctrl.text,
                                        'Minimo': m3Ctrl.text,
                                      },
                                    ];
                                    FichaProductoHelper.compartirFicha(
                                      context: context,
                                      clave: widget.clave,
                                      descripcion: descCtrl.text,
                                      imagenUrl:
                                          '${widget.baseUrl}/uploads/$fotoActual',
                                      precios: listaPrecios,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: descCtrl,
                        enabled: can,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: "Descripción",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        initialValue: widget.clave,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "Clave Sistema",
                          border: OutlineInputBorder(),
                          fillColor: Color(0xFFFFF9C4),
                          filled: true,
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _internalNumericField(
                            cbCtrl,
                            "Cód. Barras",
                            enabled: can,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: claveProCtrl,
                              enabled: can,
                              decoration: const InputDecoration(
                                labelText: "Clave Proveedor",
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.inventory_2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _internalNumericField(
                            costoCtrl,
                            "Costo",
                            enabled: can,
                          ),
                          const SizedBox(width: 10),
                          _internalNumericField(
                            pzasCajaCtrl,
                            "Pzas/Caja",
                            enabled: can,
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      Row(
                        children: [
                          _internalNumericField(
                            p1Ctrl,
                            "Precio 1",
                            enabled: can,
                          ),
                          const SizedBox(width: 8),
                          _internalNumericField(m1Ctrl, "Min 1", enabled: can),
                        ],
                      ),
                      _internalUtilidad(p1Ctrl, costoCtrl),
                      Row(
                        children: [
                          _internalNumericField(
                            p2Ctrl,
                            "Precio 2",
                            enabled: can,
                          ),
                          const SizedBox(width: 8),
                          _internalNumericField(m2Ctrl, "Min 2", enabled: can),
                        ],
                      ),
                      _internalUtilidad(p2Ctrl, costoCtrl),
                      Row(
                        children: [
                          _internalNumericField(
                            p3Ctrl,
                            "Precio 3",
                            enabled: can,
                          ),
                          const SizedBox(width: 8),
                          _internalNumericField(m3Ctrl, "Min 3", enabled: can),
                        ],
                      ),
                      _internalUtilidad(p3Ctrl, costoCtrl),
                      const Divider(height: 30),
                      const Text(
                        "Existencias por Almacén",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      for (int i = 1; i <= 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  widget.sucursalNames[i - 1],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _internalNumericField(
                                vCtrls[i]!,
                                "Pzas",
                                enabled: can,
                              ),
                              const SizedBox(width: 5),
                              _internalNumericField(
                                bCtrls[i]!,
                                "Bodega",
                                enabled: can,
                              ),
                              Switch(
                                value: activoStocks[i]!,
                                onChanged: can
                                    ? (val) =>
                                          setState(() => activoStocks[i] = val)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSaving)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            "Guardando cambios...",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _mostrarMenuFoto() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(c);
                _seleccionarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(c);
                _seleccionarFoto(ImageSource.gallery);
              },
            ),
            if (fotoActual != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar Foto'),
                onTap: () {
                  Navigator.pop(c);
                  _eliminarFoto();
                },
              ),
          ],
        ),
      ),
    );
  }
}
