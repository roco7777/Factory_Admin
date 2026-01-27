import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// --- IMPORTACIONES CORREGIDAS ---
import '../core/constants.dart';
import '../widgets/scanner_screen.dart';
import 'edicion_producto_screen.dart';
import 'nuevo_producto_screen.dart';
import 'reportes_screen.dart';
import 'historico_screen.dart';
import 'ficha_producto_helper.dart';
import 'tienda_screen.dart'; // Agregamos esta para que reconozca la Tienda
import '../main.dart'; // Para reconocer RootHandler y LoginScreen

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

  // --- FUNCIÓN PARA EL SONIDO ---
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
        // 1. Decodificamos la respuesta en una variable local llamada 'lista'
        final List<dynamic> lista = json.decode(response.body);

        setState(() {
          productos = lista;
        });
        buscadorController.clear();
        // 2. Imprimimos usando la variable correcta para debug
        if (lista.isNotEmpty) {
          buscadorController.clear(); // Limpia el buscador
          debugPrint("DEBUG PRODUCTO OK: ${lista[0]['Clave']}");
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
      // --- DRAWER PARA NAVEGACIÓN RÁPIDA ---
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
                  Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Panel Administrativo",
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
              leading: const Icon(Icons.shopping_bag, color: Colors.blue),
              title: const Text("Modo Tienda (Cliente)"),
              subtitle: const Text("Ver catálogo y existencias"),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TiendaScreen(baseUrl: widget.baseUrl),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Cerrar Sesión Admin"),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();

                // Limpiamos la sesión en el HP ProLiant
                await prefs.remove('saved_user');
                await prefs.remove('saved_rol');

                if (!mounted) return;

                // 1. ELIMINAMOS 'const' porque baseUrl es dinámica
                // 2. Pasamos widget.baseUrl para no perder la conexión
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RootHandler(baseUrl: widget.baseUrl),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text("Inventario Factory"),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.monetization_on, color: Colors.greenAccent),
            tooltip: "Reportes",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PantallaReportes(baseUrl: widget.baseUrl),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.orangeAccent),
            tooltip: "Histórico",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PantallaHistorico(baseUrl: widget.baseUrl),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
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
                hintText: "Buscar producto...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: buscarProductos,
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
                    child: Text("Busca un producto por clave o nombre"),
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
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: item['Foto'] != null && item['Foto'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${widget.baseUrl}/uploads/${item['Foto']}?t=${DateTime.now().millisecondsSinceEpoch}',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : const Icon(Icons.inventory_2, size: 35, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Clave: ${item['Clave']}",
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          List<Map<String, dynamic>> listaPrecios = [
                            {
                              'Etiqueta': 'PRECIO 1',
                              'Precio': item['Precio1'],
                              'Minimo': item['Min1'] ?? '1',
                            },
                            {
                              'Etiqueta': 'PRECIO 2',
                              'Precio': item['Precio2'],
                              'Minimo': item['Min2'] ?? '0',
                            },
                            {
                              'Etiqueta': 'PRECIO 3',
                              'Precio': item['Precio3'],
                              'Minimo': item['Min3'] ?? '0',
                            },
                          ];
                          FichaProductoHelper.compartirFicha(
                            context: context,
                            clave: item['Clave'].toString(),
                            descripcion: item['Descripcion'].toString(),
                            imagenUrl:
                                '${widget.baseUrl}/uploads/${item['Foto']}',
                            precios: listaPrecios,
                          );
                        },
                        child: const Icon(
                          Icons.share,
                          color: Color(0xFFD32F2F),
                          size: 22,
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
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Divider(height: 15),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: stock > 0 ? Colors.blue[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: stock > 0 ? Colors.blue : Colors.grey),
          ),
          child: Text(
            stock.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: stock > 0 ? Colors.blue[800] : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          nombre,
          style: const TextStyle(fontSize: 8),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
