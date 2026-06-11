import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // <--- LIBRERÍA ACTUALIZADA
import '../core/constants.dart';

class EscanerInventarioScreen extends StatefulWidget {
  final String baseUrl;

  const EscanerInventarioScreen({super.key, required this.baseUrl});

  @override
  State<EscanerInventarioScreen> createState() =>
      _EscanerInventarioScreenState();
}

class _EscanerInventarioScreenState extends State<EscanerInventarioScreen> {
  bool _isLoading = true;
  bool _haySesionActiva = false;
  int? _idSesion;
  String _nombreZona = "";
  int _idUsuario = 1;
  int _idSucursal = 1;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _resultadosBusqueda = [];
  Map<String, dynamic>? _productoSeleccionado;
  String _cantidadIngresada = "";

  @override
  void initState() {
    super.initState();
    _iniciarPantalla();
  }

  Future<void> _iniciarPantalla() async {
    final prefs = await SharedPreferences.getInstance();
    _idUsuario = 1; // Ajustar a tu lógica de ID de usuario real
    _idSucursal = prefs.getInt('saved_sucursal') ?? 1;

    await _verificarSesionActiva();
  }

  Future<void> _verificarSesionActiva() async {
    try {
      final res = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/inventario/sesiones/activa?id_sucursal=$_idSucursal',
        ),
      );
      final data = json.decode(res.body);

      if (data['success'] && data['activa']) {
        setState(() {
          _haySesionActiva = true;
          _idSesion = data['sesion']['id_sesion'];
          _nombreZona = data['sesion']['nombre_zona'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _haySesionActiva = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarSnack("Error de conexión al verificar sesión", Colors.red);
    }
  }

  Future<void> _buscarProducto(String query) async {
    if (query.isEmpty) {
      setState(() => _resultadosBusqueda = []);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/admin/inventario?q=${Uri.encodeComponent(query)}',
        ),
      );
      if (res.statusCode == 200) {
        setState(() {
          _resultadosBusqueda = json.decode(res.body);
          if (_resultadosBusqueda.length == 1 &&
              query == _resultadosBusqueda[0]['Clave']) {
            _seleccionarProducto(_resultadosBusqueda[0]);
          }
        });
      }
    } catch (e) {
      _mostrarSnack("Error al buscar producto", Colors.red);
    }
  }

  // --- NUEVA LÓGICA CON MOBILE_SCANNER ---
  Future<void> _abrirEscanerCamara() async {
    final String? barcodeScanRes = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PantallaLectorCamara()),
    );

    if (barcodeScanRes != null && barcodeScanRes.isNotEmpty) {
      _searchController.text = barcodeScanRes;
      _buscarProducto(barcodeScanRes);
    }
  }

  void _seleccionarProducto(Map<String, dynamic> producto) {
    setState(() {
      _productoSeleccionado = producto;
      _resultadosBusqueda = [];
      _searchController.clear();
      _cantidadIngresada = "";
    });
  }

  void _teclaPresionada(String valor) {
    setState(() {
      if (valor == "C") {
        _cantidadIngresada = "";
      } else if (valor == "DEL") {
        if (_cantidadIngresada.isNotEmpty) {
          _cantidadIngresada = _cantidadIngresada.substring(
            0,
            _cantidadIngresada.length - 1,
          );
        }
      } else if (valor == ".") {
        if (!_cantidadIngresada.contains(".")) {
          _cantidadIngresada += _cantidadIngresada.isEmpty ? "0." : ".";
        }
      } else {
        _cantidadIngresada += valor;
      }
    });
  }

  Future<void> _enviarEscaneo() async {
    if (_productoSeleccionado == null || _cantidadIngresada.isEmpty) return;

    double? cant = double.tryParse(_cantidadIngresada);
    if (cant == null || cant <= 0) {
      _mostrarSnack("Ingresa una cantidad válida mayor a 0", Colors.orange);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: azulPrimario)),
    );

    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/inventario/escanear'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_sesion': _idSesion,
          'clave': _productoSeleccionado!['Clave'],
          'cantidad': cant,
          'id_usuario': _idUsuario,
        }),
      );

      Navigator.pop(context);

      final data = json.decode(res.body);

      if (data['success']) {
        _mostrarSnack(
          "✅ ¡Guardado! Total contado: ${data['total_contado_sesion']} pzas",
          verdeExito,
        );
        setState(() {
          _productoSeleccionado = null;
          _cantidadIngresada = "";
        });
      } else {
        _mostrarSnack(data['message'] ?? "Error al guardar", Colors.red);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarSnack("Error de conexión con el servidor", Colors.red);
    }
  }

  void _mostrarSnack(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildNumpadButton(String label, {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _teclaPresionada(label),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == "C" || label == "DEL" ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: color != null ? Colors.white : azulPrimario,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: fondoGris,
        body: Center(child: CircularProgressIndicator(color: azulPrimario)),
      );
    }

    if (!_haySesionActiva) {
      return Scaffold(
        backgroundColor: fondoGris,
        appBar: AppBar(
          backgroundColor: azulPrimario,
          title: const Text("Conteo Físico"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 100,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 20),
                const Text(
                  "No hay ningún inventario activo para tu sucursal en este momento.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        backgroundColor: azulPrimario,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Conteo de Inventario", style: TextStyle(fontSize: 16)),
            Text(
              "Zona: $_nombreZona",
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // BUSCADOR Y ESCÁNER
          Container(
            color: azulPrimario,
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _buscarProducto,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Clave, Descripción o Prov...",
                      fillColor: Colors.white,
                      filled: true,
                      prefixIcon: const Icon(Icons.search, color: azulAcento),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _abrirEscanerCamara,
                  child: const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.amber,
                    child: Icon(
                      Icons.qr_code_scanner,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // RESULTADOS DE BÚSQUEDA
          if (_resultadosBusqueda.isNotEmpty && _productoSeleccionado == null)
            Expanded(
              child: ListView.builder(
                itemCount: _resultadosBusqueda.length,
                itemBuilder: (context, index) {
                  final prod = _resultadosBusqueda[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(
                        prod['Descripcion'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Clave: ${prod['Clave']} | Ref: ${prod['ClavePro'] ?? '-'}",
                      ),
                      trailing: const Icon(Icons.touch_app, color: azulAcento),
                      onTap: () => _seleccionarProducto(prod),
                    ),
                  );
                },
              ),
            ),

          // PRODUCTO SELECCIONADO Y TECLADO NUMÉRICO
          if (_productoSeleccionado != null) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: azulPrimario.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _productoSeleccionado!['Descripcion'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: azulPrimario,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Clave: ${_productoSeleccionado!['Clave']}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _cantidadIngresada.isEmpty ? "0" : _cantidadIngresada,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 1.4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildNumpadButton("1"),
                          _buildNumpadButton("2"),
                          _buildNumpadButton("3"),
                          _buildNumpadButton("4"),
                          _buildNumpadButton("5"),
                          _buildNumpadButton("6"),
                          _buildNumpadButton("7"),
                          _buildNumpadButton("8"),
                          _buildNumpadButton("9"),
                          _buildNumpadButton("C", color: Colors.redAccent),
                          _buildNumpadButton("0"),
                          _buildNumpadButton(
                            "DEL",
                            onTap: () => _teclaPresionada("DEL"),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verdeExito,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _cantidadIngresada.isNotEmpty
                          ? _enviarEscaneo
                          : null,
                      child: const Text(
                        "GUARDAR CANTIDAD",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_resultadosBusqueda.isEmpty) ...[
            const Expanded(
              child: Center(
                child: Text(
                  "Busca un producto o escanea\nsu código de barras.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- WIDGET EXCLUSIVO DE MOBILE_SCANNER ---
class PantallaLectorCamara extends StatefulWidget {
  const PantallaLectorCamara({super.key});

  @override
  State<PantallaLectorCamara> createState() => _PantallaLectorCamaraState();
}

class _PantallaLectorCamaraState extends State<PantallaLectorCamara> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _fueDetectado = false; // Bloqueo rápido para evitar lecturas dobles.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: azulPrimario,
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.amber);
                  case TorchState.auto:
                    return const Icon(
                      Icons.flash_auto,
                      color: Colors.amberAccent,
                    );
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _cameraController,
        onDetect: (BarcodeCapture capture) {
          if (_fueDetectado) return; // Evita que lea 100 veces en 1 segundo

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            _fueDetectado = true;
            final String code = barcodes.first.rawValue!;

            // Apaga la cámara y regresa el código a la pantalla anterior
            _cameraController.dispose();
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}
