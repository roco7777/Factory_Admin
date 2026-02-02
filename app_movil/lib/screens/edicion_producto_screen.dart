import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import '../screens/ficha_producto_helper.dart';
import '../core/security_service.dart';

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
    } finally {
      setState(() => isSaving = false);
    }
  }

  Widget _internalNumericField(
    TextEditingController ctrl,
    String label, {
    bool enabled = true,
    IconData? icon,
    bool obscureText = false,
  }) => Expanded(
    child: TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: azulAcento)
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              padding: const EdgeInsets.only(top: 5, bottom: 10, left: 5),
              child: Text(
                "Ganancia: ${formatCurrency(ut)} (${por.toStringAsFixed(1)}%)",
                style: TextStyle(
                  fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    // --- SEGURIDAD PLUS: CONSULTA DE PERMISOS ---
    final bool puedeVerCostos = SecurityService.tienePermiso('inv_ver_costos');
    final bool puedeEditarPrecios = SecurityService.tienePermiso(
      'inv_editar_precios',
    );
    final bool puedeEditarBasico = SecurityService.tienePermiso(
      'inv_editar_basico',
    );
    final bool puedeEditarStock = SecurityService.tienePermiso(
      'inv_editar_stock',
    );

    // El permiso 'can' ahora es dinámico basado en permisos o rol
    final bool esSuper = widget.userRole == 'Superusuario';
    final bool can =
        esSuper || SecurityService.tienePermiso('inv_editar_basico');

    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: Text(
          "Editar: ${widget.clave}",
          style: const TextStyle(fontWeight: FontWeight.w300),
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
        actions: [
          // Solo mostramos el botón de guardar si tiene permiso de edición
          if (can && !isLoading)
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 28),
              onPressed: _updateProduct,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECCIÓN DE FOTO (Bloqueada si no puede editar básico) ---
                      Center(
                        child: GestureDetector(
                          onTap: puedeEditarBasico
                              ? () => _mostrarMenuFoto()
                              : null,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: azulPrimario.withOpacity(0.2),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: fotoActual != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(23),
                                        child: Image.network(
                                          '${widget.baseUrl}/uploads/$fotoActual?t=${DateTime.now().millisecondsSinceEpoch}',
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 50,
                                        color: azulAcento,
                                      ),
                              ),
                              if (puedeEditarBasico)
                                CircleAvatar(
                                  backgroundColor: azulPrimario,
                                  radius: 20,
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- INFORMACIÓN BÁSICA ---
                      _sectionTitle("INFORMACIÓN BÁSICA"),
                      TextFormField(
                        controller: descCtrl,
                        enabled: puedeEditarBasico, // Bloqueo granular
                        textCapitalization: TextCapitalization.characters,
                        decoration: _inputStyle(
                          "Descripción del Producto",
                          Icons.description_outlined,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _internalNumericField(
                            cbCtrl,
                            "Código Barras",
                            enabled: puedeEditarBasico,
                            icon: Icons.qr_code_2,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: claveProCtrl,
                              enabled: puedeEditarBasico,
                              decoration: _inputStyle(
                                "Clave Proveedor",
                                Icons.tag,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // --- COSTOS Y PRECIOS ---
                      _sectionTitle("COSTOS Y RENTABILIDAD"),
                      Row(
                        children: [
                          // COSTO: Protegido con obscureText si no tiene permiso de ver
                          _internalNumericField(
                            costoCtrl,
                            puedeVerCostos
                                ? "Costo de Compra"
                                : "COSTO PROTEGIDO",
                            enabled: puedeVerCostos && puedeEditarBasico,
                            obscureText:
                                !puedeVerCostos, // <--- Muestra asteriscos si no tiene permiso
                            icon: puedeVerCostos
                                ? Icons.payments_outlined
                                : Icons.lock_outline,
                          ),
                          const SizedBox(width: 10),
                          _internalNumericField(
                            pzasCajaCtrl,
                            "Pzas por Caja",
                            enabled: puedeEditarBasico,
                            icon: Icons.inventory_2_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _priceRow(p1Ctrl, m1Ctrl, "Precio 1", puedeEditarPrecios),
                      if (puedeVerCostos) _internalUtilidad(p1Ctrl, costoCtrl),

                      _priceRow(p2Ctrl, m2Ctrl, "Precio 2", puedeEditarPrecios),
                      if (puedeVerCostos) _internalUtilidad(p2Ctrl, costoCtrl),

                      _priceRow(p3Ctrl, m3Ctrl, "Precio 3", puedeEditarPrecios),
                      if (puedeVerCostos) _internalUtilidad(p3Ctrl, costoCtrl),

                      const SizedBox(height: 30),

                      // --- EXISTENCIAS ---
                      _sectionTitle("CONTROL DE EXISTENCIAS"),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: grisBordes),
                        ),
                        child: Column(
                          children: [
                            // Solo se pueden editar si tiene el permiso inv_editar_stock
                            for (int i = 1; i <= 5; i++)
                              _buildStockRow(i, puedeEditarStock),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                if (isSaving) _loadingOverlay(),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 15, left: 5),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: azulAcento,
        letterSpacing: 1.2,
      ),
    ),
  );

  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: azulAcento),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    isDense: true,
  );

  Widget _priceRow(
    TextEditingController p,
    TextEditingController m,
    String label,
    bool can,
  ) => Row(
    children: [
      _internalNumericField(p, label, enabled: can, icon: Icons.attach_money),
      const SizedBox(width: 10),
      _internalNumericField(m, "Mínimo", enabled: can),
    ],
  );

  Widget _buildStockRow(int i, bool can) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              widget.sucursalNames[i - 1],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          _internalNumericField(vCtrls[i]!, "Pzas", enabled: can),
          const SizedBox(width: 5),
          _internalNumericField(bCtrls[i]!, "Bodega", enabled: can),
          Switch(
            value: activoStocks[i]!,
            activeColor: azulPrimario,
            onChanged: can
                ? (val) => setState(() => activoStocks[i] = val)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _loadingOverlay() => Container(
    color: azulPrimario.withOpacity(0.8),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 15),
          Text(
            "Sincronizando con el servidor...",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  void _mostrarMenuFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: fondoGris,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: azulAcento,
                ),
                title: const Text('Tomar Fotografía'),
                onTap: () {
                  Navigator.pop(c);
                  _seleccionarFoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: azulAcento,
                ),
                title: const Text('Elegir de Galería'),
                onTap: () {
                  Navigator.pop(c);
                  _seleccionarFoto(ImageSource.gallery);
                },
              ),
              if (fotoActual != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Eliminar Imagen Actual',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(c);
                    _eliminarFoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
