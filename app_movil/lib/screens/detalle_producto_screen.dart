import 'package:flutter/material.dart';
import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../services/tienda_service.dart';
import 'edicion_producto_screen.dart';

class DetalleProductoScreen extends StatefulWidget {
  final dynamic item;
  final String baseUrl;
  final List<String> sucursalNames;

  const DetalleProductoScreen({
    super.key,
    required this.item,
    required this.baseUrl,
    required this.sucursalNames,
  });

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  // --- 1. FUNCIONES DE APOYO (Solo una declaración de cada una) ---

  String formatPrecio(dynamic valor) {
    if (valor == null ||
        valor.toString() == 'null' ||
        valor.toString().isEmpty) {
      return "0.00";
    }
    double monto = double.tryParse(valor.toString()) ?? 0;
    return monto.toStringAsFixed(2);
  }

  String calcularUtilidad(dynamic precio, double costoBase) {
    double p = double.tryParse(precio?.toString() ?? '0') ?? 0;
    if (costoBase <= 0 || p <= 0) return "0%";
    double utilidad = ((p - costoBase) / costoBase) * 100;
    return "${utilidad.toStringAsFixed(1)}%";
  }

  // --- 2. LÓGICA DE EXPORTACIÓN ---

  Future<void> _exportarFicha() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final item = widget.item;
    String descripcion = item['Descripcion']?.toString().toUpperCase() ?? '';
    String clave = item['Clave']?.toString() ?? '';

    final String imageUrl = TiendaService.getImagenUrl(
      item['drive_id']?.toString(),
      item['Foto']?.toString(),
      widget.baseUrl,
    );

    Widget fichaVisual = Container(
      width: 450,
      color: Colors.white,
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(imageUrl, height: 300, fit: BoxFit.contain)
          else
            const Icon(
              Icons.image_not_supported,
              size: 150,
              color: Colors.grey,
            ),
          const SizedBox(height: 20),
          Text(
            descripcion,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "CLAVE: $clave",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const Divider(height: 30, thickness: 2),
          _filaPrecioFicha("Precio Público:", item['Precio1']),
          _filaPrecioFicha("Precio Mayoreo:", item['Precio2']),
          _filaPrecioFicha("Precio Especial:", item['Precio3']),
        ],
      ),
    );

    try {
      final uint8list = await screenshotController.captureFromWidget(
        Material(child: fichaVisual),
        delay: const Duration(milliseconds: 250),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        path.join(directory.path, '${clave}_ficha.png'),
      ).create();
      await imagePath.writeAsBytes(uint8list);

      if (!mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: 'Cotización Factory: $descripcion');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error exportando: $e");
    }
  }

  Widget _filaPrecioFicha(String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            "\$${formatPrecio(valor)}",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. DISEÑO DE LA PANTALLA ---

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final String imageUrl = TiendaService.getImagenUrl(
      item['drive_id']?.toString(),
      item['Foto']?.toString(),
      widget.baseUrl,
    );

    double costoBase = double.tryParse(item['PCosto']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text("Análisis de Producto"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _exportarFicha,
            tooltip: "Compartir Ficha",
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () => _irAEditar(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _abrirZoom(imageUrl, item['Clave']),
              child: Hero(
                tag: 'product_image_${item['Clave']}',
                child: Container(
                  height: 320,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.contain)
                      : const Icon(
                          Icons.image_not_supported,
                          size: 100,
                          color: Colors.grey,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['Descripcion'] ?? "SIN NOMBRE",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF263238),
                    ),
                  ),
                  Text(
                    "Clave: ${item['Clave']}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 18,
                        color: Color(0xFF1A237E),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "MÁRGENES DE UTILIDAD",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _filaPrecioUtilidad(
                          "Costo Base (P.Costo):",
                          "\$${costoBase.toStringAsFixed(2)}",
                          "COSTO",
                          Colors.blueGrey,
                        ),
                        const Divider(height: 20),
                        _filaPrecioUtilidad(
                          "Precio 1 (Público):",
                          "\$${formatPrecio(item['Precio1'])}",
                          calcularUtilidad(item['Precio1'], costoBase),
                          Colors.black87,
                        ),
                        _filaPrecioUtilidad(
                          "Precio 2:",
                          "\$${formatPrecio(item['Precio2'])}",
                          calcularUtilidad(item['Precio2'], costoBase),
                          Colors.black87,
                        ),
                        _filaPrecioUtilidad(
                          "Precio 3:",
                          "\$${formatPrecio(item['Precio3'])}",
                          calcularUtilidad(item['Precio3'], costoBase),
                          Colors.black87,
                        ),
                        _filaPrecioUtilidad(
                          "Precio 4:",
                          "\$${formatPrecio(item['Precio4'])}",
                          calcularUtilidad(item['Precio4'], costoBase),
                          Colors.black87,
                        ),
                        _filaPrecioUtilidad(
                          "Precio 5:",
                          "\$${formatPrecio(item['Precio5'])}",
                          calcularUtilidad(item['Precio5'], costoBase),
                          Colors.black87,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "STOCKS POR SUCURSAL",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildStockHorizontal(item),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => _irAEditar(context),
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      "MODIFICAR ESTE PRODUCTO",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. WIDGETS DE COMPONENTES ---

  Widget _buildStockHorizontal(dynamic item) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(widget.sucursalNames.length, (index) {
          String stockKey = 'stock${index + 1}';
          return Expanded(
            child: Column(
              children: [
                Text(
                  item[stockKey]?.toString() ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.sucursalNames[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _filaPrecioUtilidad(
    String label,
    String precio,
    String utilidad,
    Color color,
  ) {
    bool esCosto = utilidad == "COSTO";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              precio,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: esCosto
                    ? Colors.grey[200]
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                utilidad,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: esCosto ? Colors.grey : Colors.blue[800],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirZoom(String url, String clave) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(imageUrl: url, clave: clave),
      ),
    );
  }

  void _irAEditar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EdicionProductoScreen(
          clave: widget.item['Clave'].toString().trim(),
          baseUrl: widget.baseUrl,
          userRole: "admin",
          sucursalNames: widget.sucursalNames,
        ),
      ),
    );
  }
}

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String clave;
  const FullScreenImageView({
    super.key,
    required this.imageUrl,
    required this.clave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Hero(
            tag: 'product_image_$clave',
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }
}
