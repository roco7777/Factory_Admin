import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

// --- COMPARTIR ---
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// --- NÚCLEO Y SERVICIOS ---
import '../core/constants.dart';
import '../services/tienda_service.dart';

// --- PANTALLAS Y WIDGETS ---
import '../widgets/scanner_screen.dart';
import 'edicion_producto_screen.dart';
import 'nuevo_producto_screen.dart';
import 'detalle_producto_screen.dart';
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

  final ScreenshotController screenshotController = ScreenshotController();

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

    FocusScope.of(context).unfocus();
    setState(() => cargando = true);

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/admin/inventario?q=${Uri.encodeComponent(query)}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> lista = json.decode(response.body);
        setState(() {
          productos = lista;
        });
      }
    } catch (e) {
      debugPrint("Error en búsqueda: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  // ========================================================
  // FUNCIONALIDAD: GENERAR Y COMPARTIR FICHA VISUAL
  // ========================================================
  Future<void> _compartirFichaProducto(dynamic item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: azulPrimario)),
    );

    String descripcion =
        item['Descripcion']?.toString().toUpperCase() ?? 'SIN DESCRIPCIÓN';
    String clave = item['Clave']?.toString() ?? '';
    String fotoUrl =
        (item['Foto'] != null && item['Foto'].toString().isNotEmpty)
        ? '${widget.baseUrl}/uploads/${item['Foto']}'
        : '';

    Widget fichaVisual = Container(
      width: 500,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 350,
            width: double.infinity,
            alignment: Alignment.center,
            child: fotoUrl.isNotEmpty
                ? Image.network(fotoUrl, fit: BoxFit.contain)
                : const Icon(
                    Icons.inventory_2_outlined,
                    size: 120,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildPreciosFicha(item, clave),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              descripcion,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0000CC),
              ),
            ),
          ),
        ],
      ),
    );

    try {
      final uint8list = await screenshotController.captureFromWidget(
        Material(child: fichaVisual),
        delay: const Duration(milliseconds: 300),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        path.join(directory.path, '${clave}_cotizacion.png'),
      ).create();
      await imagePath.writeAsBytes(uint8list);

      if (!mounted) return;
      Navigator.pop(context);

      final XFile file = XFile(imagePath.path);
      await Share.shareXFiles([file], text: 'Cotización: $descripcion');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error al compartir: $e");
    }
  }

  Widget _buildPreciosFicha(dynamic item, String clave) {
    List<Widget> preciosList = [];

    void revisarPrecio(String keyP, String keyM) {
      double p = double.tryParse(item[keyP]?.toString() ?? '0') ?? 0;
      double m = double.tryParse(item[keyM]?.toString() ?? '1') ?? 1;
      if (p > 0) {
        String formattedP = "\$${p.toStringAsFixed(2)}";
        preciosList.add(
          Text(
            "${formattedP}x${m.toStringAsFixed(0)}pzas",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0000CC),
            ),
          ),
        );
      }
    }

    revisarPrecio('Precio3', 'Min3');
    revisarPrecio('Precio2', 'Min2');
    revisarPrecio('Precio1', 'Min1');

    if (preciosList.length > 1) {
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12.0,
        runSpacing: 8.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            clave,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0000CC),
            ),
          ),
          ...preciosList,
        ],
      );
    } else if (preciosList.isNotEmpty) {
      double p1 = double.tryParse(item['Precio1']?.toString() ?? '0') ?? 0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            clave,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0000CC),
            ),
          ),
          Text(
            "\$${p1.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0000CC),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
  // ========================================================

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
          // --- SECCIÓN BUSCADOR ---
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
                prefixIcon: IconButton(
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: azulPrimario),
                  onPressed: () => buscarProductos(),
                ),
              ),
              onSubmitted: (_) => buscarProductos(),
            ),
          ),

          if (!cargando && buscadorController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: 12.0,
                left: 20.0,
                right: 20.0,
                bottom: 4.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${productos.length} producto(s) encontrado(s)",
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                    // --- AQUI GUARDAMOS LA POSICIÓN DEL SCROLL DE LA BÚSQUEDA ---
                    key: const PageStorageKey('scroll_busqueda_inventario'),
                    padding: const EdgeInsets.only(top: 10, bottom: 80),
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final item = productos[index];
                      // Lógica de producto activo/inactivo (asume activo si es nulo)
                      bool isActivo = item['Activo']?.toString() != '0';

                      return Dismissible(
                        key: Key(item['Id'].toString()),
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: azulAcento,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EdicionProductoScreen(
                                clave: item['Clave'].toString().trim(),
                                baseUrl: widget.baseUrl,
                                userRole: widget.userRole,
                                sucursalNames: sucursalNames,
                              ),
                            ),
                          ).then((_) => buscarProductos());
                          return false;
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: isActivo
                              ? Colors.white
                              : const Color(0xFFFFF0F0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: isActivo
                                ? BorderSide.none
                                : BorderSide(
                                    color: Colors.red.shade300,
                                    width: 1.5,
                                  ),
                          ),
                          elevation: 2,
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: Image.network(
                                      TiendaService.getImagenUrl(
                                        item['drive_id']?.toString(),
                                        item['Foto']?.toString(),
                                        widget.baseUrl,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.inventory_2,
                                                color: Colors.grey,
                                              ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['Descripcion'] ?? "Sin descripción",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActivo
                                        ? azulPrimario
                                        : Colors.blueGrey,
                                    fontSize: 14,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "Clave: ${item['Clave']}  |  Prov: ${item['ClavePro'] ?? 'N/A'}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          "\$${(double.tryParse(item['Precio1']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isActivo
                                                ? verdeExito
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(
                                        sucursalNames.length,
                                        (i) {
                                          String stockRaw =
                                              item['stock${i + 1}']
                                                  ?.toString() ??
                                              '0';
                                          double stockDouble =
                                              double.tryParse(stockRaw) ?? 0;
                                          String stockValue = stockDouble
                                              .toStringAsFixed(0);
                                          bool hasStock = stockDouble > 0;

                                          return Column(
                                            children: [
                                              Text(
                                                stockValue,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: hasStock
                                                      ? (isActivo
                                                            ? verdeExito
                                                            : Colors.red)
                                                      : Colors.red[300],
                                                ),
                                              ),
                                              Text(
                                                sucursalNames[i].length > 10
                                                    ? sucursalNames[i]
                                                          .substring(0, 10)
                                                    : sucursalNames[i],
                                                style: const TextStyle(
                                                  fontSize: 7.5,
                                                  color: Colors.blueGrey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: grisBordes,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetalleProductoScreen(
                                        item: item,
                                        baseUrl: widget.baseUrl,
                                      ),
                                    ),
                                  ).then((_) => buscarProductos());
                                },
                              ),

                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActivo
                                        ? azulAcento
                                        : Colors.grey[600],
                                    borderRadius: const BorderRadius.only(
                                      bottomRight: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    "#${index + 1}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(dynamic item) {
    return Container();
  }

  Widget _buildStockItem(String nombre, dynamic cantidad) {
    return Container();
  }
}
