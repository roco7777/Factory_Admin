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
      backgroundColor: Colors.grey[100],
      // Drawer simplificado: solo para navegación interna
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFFD32F2F)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.inventory, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "Gestión de Inventario",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: Colors.blue),
              title: const Text("Volver al Panel Principal"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Inventario Factory"),
        backgroundColor: Colors.blue[900], // Un azul más oscuro para inventario
        elevation: 2,
        // SE ELIMINARON LOS ACTIONS DE REPORTES
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        elevation: 4,
        child: const Icon(Icons.add_shopping_cart),
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: buscadorController,
              decoration: InputDecoration(
                hintText: "Escribe nombre o clave...",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
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
                suffixIcon: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: buscarProductos,
                  ),
                ),
              ),
              onSubmitted: (_) => buscarProductos(),
            ),
          ),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : productos.isEmpty
                ? const Center(
                    child: Text(
                      "Busca un producto para empezar",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final item = productos[index];
                      return InkWell(
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
                        child: _buildProductoCard(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(dynamic item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: item['Foto'] != null && item['Foto'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        '${widget.baseUrl}/uploads/${item['Foto']}?t=${DateTime.now().millisecondsSinceEpoch}',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : const Icon(Icons.inventory_2, size: 30, color: Colors.grey),
            ),
            const SizedBox(width: 12),
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
                          color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        formatCurrency(item['Precio1'] ?? 0),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item['Descripcion'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStockBox(sucursalNames[0], item['stock1']),
                      _buildStockBox(sucursalNames[1], item['stock2']),
                      _buildStockBox(sucursalNames[2], item['stock3']),
                      _buildStockBox(sucursalNames[3], item['stock4']),
                      _buildStockBox(sucursalNames[4], item['stock5']),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBox(String nombre, dynamic cantidad) {
    double stock = double.tryParse(cantidad.toString()) ?? 0;
    return Column(
      children: [
        Text(
          stock.toStringAsFixed(0),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: stock > 0 ? Colors.blue[700] : Colors.red[300],
          ),
        ),
        Text(nombre, style: const TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }
}
