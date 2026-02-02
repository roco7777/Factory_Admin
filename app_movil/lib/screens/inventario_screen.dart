import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// --- IMPORTACIONES LIMPIAS ---
import '../core/constants.dart';
import '../widgets/scanner_screen.dart';
import 'edicion_producto_screen.dart';
import 'nuevo_producto_screen.dart';
import 'ficha_producto_helper.dart';
import 'admin_login_screen.dart';

class PantallaInventario extends StatefulWidget {
  final String userRole;
  final String baseUrl;
  const PantallaInventario({
    super.key,
    required this.userRole,
    required this.baseUrl,
  });

  @override
  State<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends State<PantallaInventario> {
  List<dynamic> productos = [];
  bool cargando = false;
  final TextEditingController buscadorController = TextEditingController();
  List<String> sucursalNames = ["Alm 1", "Alm 2", "Alm 3", "Alm 4", "Alm 5"];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    fetchSucursalNames();
  }

  @override
  void dispose() {
    buscadorController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _reproducirBip() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint("Error al reproducir sonido: $e");
    }
  }

  Future<void> fetchSucursalNames() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/sucursales'),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          List<String> tempNames = data
              .map((item) => item['sucursal'].toString().trim())
              .toList();
          for (int i = 0; i < tempNames.length && i < 5; i++) {
            sucursalNames[i] = tempNames[i];
          }
        });
      }
    } catch (e) {
      debugPrint("Error cargando nombres sucursales: $e");
    }
  }

  Future<void> buscarProductos() async {
    String query = buscadorController.text.trim();
    if (query.isEmpty) return;
    setState(() => cargando = true);

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/admin/inventario?q=$query'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> lista = json.decode(response.body);
        setState(() {
          productos = lista;
        });
        if (lista.isNotEmpty) {
          _reproducirBip();
        }
      }
    } catch (e) {
      debugPrint("Error en búsqueda: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          "Gestión de Inventario",
          style: TextStyle(fontWeight: FontWeight.w300, fontSize: 18),
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: azulAcento,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NuevoProductoScreen(
              baseUrl: widget.baseUrl,
              userRole: widget.userRole,
              sucursalNames: sucursalNames,
            ),
          ),
        ).then((_) => buscarProductos()),
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ESTILO PRO ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: const BoxDecoration(
              color: azulPrimario,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: TextField(
              controller: buscadorController,
              style: const TextStyle(color: azulPrimario),
              decoration: InputDecoration(
                hintText: "Nombre del producto o clave...",
                hintStyle: TextStyle(color: azulAcento.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: azulAcento.withOpacity(0.7),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: azulPrimario,
                  ),
                  onPressed: () async {
                    final res = await showDialog<String>(
                      context: context,
                      builder: (context) => const ScannerScreen(),
                    );
                    if (res != null) {
                      buscadorController.text = res;
                      buscarProductos();
                    }
                  },
                ),
              ),
              onSubmitted: (_) => buscarProductos(),
            ),
          ),

          // --- LISTADO DE RESULTADOS ---
          Expanded(
            child: cargando
                ? const Center(
                    child: CircularProgressIndicator(color: azulPrimario),
                  )
                : productos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: grisBordes,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Inicia una búsqueda de mercancía",
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 80),
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final item = productos[index];
                      return _buildProductoCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: grisBordes, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EdicionProductoScreen(
              clave: item['Clave'].toString().trim(),
              baseUrl: widget.baseUrl,
              userRole: widget.userRole,
              sucursalNames: sucursalNames,
            ),
          ),
        ).then((_) => buscarProductos()),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniatura del Producto
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  color: fondoGris,
                  borderRadius: BorderRadius.circular(15),
                ),
                child:
                    item['Foto'] != null && item['Foto'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          '${widget.baseUrl}/uploads/${item['Foto']}?t=${DateTime.now().millisecondsSinceEpoch}',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Icon(
                            Icons.image_not_supported_rounded,
                            color: grisBordes,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.inventory_2_rounded,
                        size: 30,
                        color: grisBordes,
                      ),
              ),
              const SizedBox(width: 15),
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['Clave'].toString(),
                          style: const TextStyle(
                            color: azulAcento,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          formatCurrency(item['Precio1'] ?? 0),
                          style: const TextStyle(
                            color: verdeExito,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['Descripcion'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: azulPrimario,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1, color: grisBordes),
                    ),
                    // Stocks por sucursal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStockItem(sucursalNames[0], item['stock1']),
                        _buildStockItem(sucursalNames[1], item['stock2']),
                        _buildStockItem(sucursalNames[2], item['stock3']),
                        _buildStockItem(sucursalNames[3], item['stock4']),
                        _buildStockItem(sucursalNames[4], item['stock5']),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockItem(String nombre, dynamic cantidad) {
    double stock = double.tryParse(cantidad.toString()) ?? 0;
    bool tieneStock = stock > 0;
    return Column(
      children: [
        Text(
          stock.toStringAsFixed(0),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: tieneStock ? azulAcento : Colors.red[300],
          ),
        ),
        Text(
          nombre,
          style: const TextStyle(
            fontSize: 8,
            color: Colors.blueGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
