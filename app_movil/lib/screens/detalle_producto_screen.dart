import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../services/tienda_service.dart';
import 'edicion_producto_screen.dart';

class DetalleProductoScreen extends StatefulWidget {
  final dynamic item;
  final String baseUrl;

  const DetalleProductoScreen({
    super.key,
    required this.item,
    required this.baseUrl,
  });

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  List<String> nombresSucursales = [];
  bool isLoadingSucursales = true;

  Map<String, dynamic>? fullItem;
  bool isLoadingFullItem = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    // 1. Cargar las sucursales
    try {
      final resSuc = await http.get(
        Uri.parse('${widget.baseUrl}/api/sucursales'),
      );
      if (resSuc.statusCode == 200) {
        final List data = json.decode(resSuc.body);
        if (mounted) {
          setState(() {
            nombresSucursales = data
                .map((s) => s['sucursal'].toString())
                .toList();
            isLoadingSucursales = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error sucursales: $e");
    }

    // 2. Cargar el detalle COMPLETO del producto
    try {
      final String clave = widget.item['Clave'].toString().trim();
      final resProd = await http.get(
        Uri.parse('${widget.baseUrl}/api/producto/$clave'),
      );
      if (resProd.statusCode == 200) {
        if (mounted) {
          setState(() {
            fullItem = json.decode(resProd.body);
            isLoadingFullItem = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error producto: $e");
      if (mounted) setState(() => isLoadingFullItem = false);
    }
  }

  String formatPrecio(dynamic valor) {
    if (valor == null ||
        valor.toString() == 'null' ||
        valor.toString().isEmpty) {
      return "0.00";
    }
    double monto = double.tryParse(valor.toString()) ?? 0;
    return monto.toStringAsFixed(2);
  }

  Future<void> _exportarFicha() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final data = fullItem ?? widget.item;
    String descripcion = data['Descripcion']?.toString().toUpperCase() ?? '';
    String clave = data['Clave']?.toString() ?? '';

    final String imageUrl = TiendaService.getImagenUrl(
      data['drive_id']?.toString(),
      data['Foto']?.toString(),
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
          _filaPrecioFicha("Precio Público:", data['Precio1']),
          _filaPrecioFicha("Precio Mayoreo:", data['Precio2']),
          _filaPrecioFicha("Precio Especial:", data['Precio3']),
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

  @override
  Widget build(BuildContext context) {
    final data = fullItem ?? widget.item;

    final String imageUrl = TiendaService.getImagenUrl(
      data['drive_id']?.toString(),
      data['Foto']?.toString(),
      widget.baseUrl,
    );

    double costoBase = double.tryParse(data['PCosto']?.toString() ?? '0') ?? 0;

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
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () => _irAEditar(context),
          ),
        ],
      ),
      body: isLoadingFullItem
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _abrirZoom(imageUrl, data['Clave']),
                    child: Hero(
                      tag: 'product_image_${data['Clave']}',
                      child: Container(
                        height: 320,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(30),
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
                          data['Descripcion'] ?? "SIN NOMBRE",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "CB: ${data['CB'] ?? 'N/A'}  |  Tipo: ${data['Tipo'] ?? 'N/A'}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Presentación: ${data['Presentacion'] ?? 'Ninguna'}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "Clave: ${data['Clave']}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Text(
                              "ClavePro: ${data['ClavePro'] ?? 'N/A'}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                              "PRECIOS Y MÁRGENES DE UTILIDAD",
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
                                "Costo Base:",
                                double.tryParse(
                                      data['PCosto']?.toString() ?? '0',
                                    ) ??
                                    0,
                                costoBase,
                                Colors.blueGrey,
                                null,
                                esCosto: true,
                              ),
                              const Divider(height: 20),
                              _filaPrecioUtilidad(
                                "Precio 1:",
                                double.tryParse(
                                      data['Precio1']?.toString() ?? '0',
                                    ) ??
                                    0,
                                costoBase,
                                Colors.black87,
                                data['Min1'],
                              ),
                              _filaPrecioUtilidad(
                                "Precio 2:",
                                double.tryParse(
                                      data['Precio2']?.toString() ?? '0',
                                    ) ??
                                    0,
                                costoBase,
                                Colors.black87,
                                data['Min2'],
                              ),
                              _filaPrecioUtilidad(
                                "Precio 3:",
                                double.tryParse(
                                      data['Precio3']?.toString() ?? '0',
                                    ) ??
                                    0,
                                costoBase,
                                Colors.black87,
                                data['Min3'],
                              ),
                              _filaPrecioUtilidad(
                                "Precio 4:",
                                double.tryParse(
                                      data['Precio4']?.toString() ?? '0',
                                    ) ??
                                    0,
                                costoBase,
                                Colors.black87,
                                data['Min4'],
                              ),
                              _filaPrecioUtilidad(
                                "Precio 5:",
                                double.tryParse(
                                      data['Precio5']?.toString() ?? '0',
                                    ) ??
                                    0,
                                costoBase,
                                Colors.black87,
                                data['Min5'],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Color(0xFF1A237E),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "INFORMACIÓN LOGÍSTICA",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInformacionAdicional(data),

                        const SizedBox(height: 25),

                        const Row(
                          children: [
                            Icon(
                              Icons.warehouse_outlined,
                              size: 18,
                              color: Color(0xFF1A237E),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "STOCKS POR SUCURSAL",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildStockCompleto(data),

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

  Widget _buildInformacionAdicional(Map<String, dynamic> data) {
    int pzasCaja = (double.tryParse(data['PzasxCaja']?.toString() ?? '1') ?? 1)
        .toInt();
    if (pzasCaja <= 0) pzasCaja = 1;

    double pedidos =
        double.tryParse(data['en_pedidos']?.toString() ?? '0') ?? 0;

    double totalPiezas = 0;
    for (int i = 1; i <= 5; i++) {
      double pzas =
          double.tryParse(data['alm${i}_pventas']?.toString() ?? '0') ?? 0;
      double cajas =
          double.tryParse(data['alm${i}_bodega']?.toString() ?? '0') ?? 0;
      totalPiezas += pzas + (cajas * pzasCaja);
    }

    String fechaIngreso = data['FIngreso']?.toString().split(' ')[0] ?? 'N/A';
    String fechaSalida =
        data['LotePend']?.toString().split(' ')[0] ?? 'Ninguna';

    // Formateo seguro para "UltimaVez"
    String ultimaVezRaw = data['UltimaVez']?.toString() ?? '';
    String ultimaVez = (ultimaVezRaw.isEmpty || ultimaVezRaw.startsWith('0000'))
        ? 'Nunca'
        : ultimaVezRaw.split(' ')[0];

    bool activo =
        data['Activo'] == 1 || data['Activo'] == true || data['Activo'] == '1';
    bool visibleApp =
        data['status'] == 1 || data['status'] == true || data['status'] == '1';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _filaInfoBasica("Piezas por Caja:", "$pzasCaja pzas", Colors.black87),
          _filaInfoBasica(
            "Total Gral. Almacenes:",
            "${totalPiezas.toStringAsFixed(0)} pzas",
            Colors.blue[800]!,
          ),
          _filaInfoBasica(
            "En Pedidos (Cotdet):",
            "${pedidos.toStringAsFixed(0)} pzas",
            Colors.orange[800]!,
          ),
          const Divider(),
          _filaInfoBasica(
            "Estatus Sistema:",
            activo ? "ACTIVO" : "INACTIVO",
            activo ? Colors.green : Colors.red,
          ),
          _filaInfoBasica(
            "Visible en Tienda App:",
            visibleApp ? "SÍ" : "NO",
            visibleApp ? Colors.green : Colors.red,
          ),
          const Divider(),
          _filaInfoBasica("Fecha de Alta:", fechaIngreso, Colors.black54),
          _filaInfoBasica(
            "Lanzamiento Programado:",
            fechaSalida,
            Colors.black54,
          ),
          _filaInfoBasica(
            "Última Venta:",
            ultimaVez,
            Colors.black87,
          ), // NUEVO CAMPO AÑADIDO
        ],
      ),
    );
  }

  Widget _filaInfoBasica(String label, String valor, Color colorValor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorValor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCompleto(Map<String, dynamic> data) {
    if (isLoadingSucursales)
      return const Center(child: CircularProgressIndicator());
    if (nombresSucursales.isEmpty)
      return const Text(
        "Error al cargar sucursales",
        style: TextStyle(color: Colors.red),
      );

    return Column(
      children: List.generate(nombresSucursales.length, (index) {
        String sucursal = nombresSucursales[index];
        double pzas =
            double.tryParse(
              data['alm${index + 1}_pventas']?.toString() ?? '0',
            ) ??
            0;
        double cajas =
            double.tryParse(
              data['alm${index + 1}_bodega']?.toString() ?? '0',
            ) ??
            0;

        bool tieneStock = (pzas > 0 || cajas > 0);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tieneStock ? Colors.blue[100]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sucursal.length > 15 ? sucursal.substring(0, 15) : sucursal,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              Row(
                children: [
                  _bloqueStock("Piso", pzas.toStringAsFixed(0), tieneStock),
                  const SizedBox(width: 15),
                  _bloqueStock("Bodega", cajas.toStringAsFixed(0), tieneStock),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _bloqueStock(String label, String qty, bool destacado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          qty,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: qty == '0'
                ? Colors.grey[400]
                : (destacado ? Colors.green[700] : Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _filaPrecioUtilidad(
    String label,
    double precioActual,
    double costoBase,
    Color color,
    dynamic minQty, {
    bool esCosto = false,
  }) {
    // 1. Calculamos la utilidad (Real y Porcentaje)
    String utilidadTxt = "COSTO";
    if (!esCosto && costoBase > 0 && precioActual > 0) {
      double ganancia = precioActual - costoBase;
      double pct = (ganancia / costoBase) * 100;
      utilidadTxt =
          "\$${ganancia.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)";
    } else if (!esCosto) {
      utilidadTxt = "0%";
    }

    // 2. Formateamos el "Mínimo" para que NUNCA tenga decimales (ej. Min: 6)
    int minPzas = (double.tryParse(minQty?.toString() ?? '0') ?? 0).toInt();
    String minStr = (minPzas > 0) ? " (Mín: $minPzas)" : " Min: 0";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3, // Ajustado para dar más espacio a la utilidad
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 3,
            child: RichText(
              text: TextSpan(
                text: "\$${precioActual.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
                children: [
                  TextSpan(
                    text: minStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4, // Caja más grande para que quepa "$15.00 (30.0%)"
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: esCosto
                    ? Colors.grey[200]
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                utilidadTxt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
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
          sucursalNames: nombresSucursales,
        ),
      ),
    ).then((_) => _cargarDatosCompletos());
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
