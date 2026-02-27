import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants.dart';
import 'edicion_producto_screen.dart'; // Asegúrate de tener esta importación correcta

class LanzamientosScreen extends StatefulWidget {
  final String baseUrl;
  final String userRole; // Necesario para pasarlo a la edición

  const LanzamientosScreen({
    super.key,
    required this.baseUrl,
    required this.userRole,
  });

  @override
  State<LanzamientosScreen> createState() => _LanzamientosScreenState();
}

class _LanzamientosScreenState extends State<LanzamientosScreen> {
  bool isLoading = true;
  List<dynamic> lotes = [];

  @override
  void initState() {
    super.initState();
    _cargarLotes();
  }

  Future<void> _cargarLotes() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/abmc/lotes-resumen'),
      );
      if (res.statusCode == 200) {
        setState(() {
          lotes = json.decode(res.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando lotes: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _procesarLote(String fechaLote, String accion) async {
    bool confirmar = await _mostrarDialogoConfirmacion(fechaLote, accion);
    if (!confirmar) return;

    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/abmc/lotes/accion'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fechaLote': fechaLote, 'accion': accion}),
      );

      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ ${data['actualizados']} productos actualizados"),
            ),
          );
        }
        _cargarLotes();
      } else {
        throw Exception(data['error']);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
      setState(() => isLoading = false);
    }
  }

  Future<bool> _mostrarDialogoConfirmacion(String fecha, String accion) async {
    String titulo = accion == 'publicar'
        ? '🚀 Publicar Lote'
        : '⏪ Revertir Publicación';
    String mensaje = accion == 'publicar'
        ? '¿Estás seguro de hacer VISIBLES en la tienda todos los productos programados para el $fecha?'
        : '¿Estás seguro de OCULTAR de la tienda los productos del lote $fecha?';

    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(titulo, style: const TextStyle(color: azulPrimario)),
            content: Text(mensaje),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accion == 'publicar'
                      ? verdeExito
                      : Colors.orange,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirmar"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          "Lanzamientos Programados",
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarLotes),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : lotes.isEmpty
          ? const Center(
              child: Text(
                "No hay lotes programados",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: lotes.length,
              itemBuilder: (context, index) {
                final lote = lotes[index];
                final String fecha = lote['FechaLote'];
                final int total =
                    int.tryParse(lote['TotalProductos'].toString()) ?? 0;
                final int pendientes =
                    int.tryParse(lote['TotalPendientes'].toString()) ?? 0;
                final bool yaPublicado = pendientes == 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: yaPublicado
                                      ? verdeExito
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  fecha,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: azulPrimario,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: yaPublicado
                                    ? verdeExito.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                yaPublicado ? "PUBLICADO" : "PENDIENTE",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: yaPublicado
                                      ? verdeExito
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        Text(
                          "Productos en este lote: $total",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .spaceBetween, // Separamos el botón de Ver de los de acción
                          children: [
                            // BOTÓN PARA VER EL DETALLE
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetalleLoteScreen(
                                      fecha: fecha,
                                      baseUrl: widget.baseUrl,
                                      userRole: widget.userRole,
                                      yaPublicado: yaPublicado,
                                    ),
                                  ),
                                ).then(
                                  (_) => _cargarLotes(),
                                ); // Recargar al volver por si editó algo
                              },
                              icon: const Icon(
                                Icons.list_alt,
                                color: azulAcento,
                              ),
                              label: const Text(
                                "Ver Productos",
                                style: TextStyle(
                                  color: azulAcento,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                if (yaPublicado)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                    ),
                                    icon: const Icon(Icons.undo, size: 18),
                                    label: const Text("Revertir"),
                                    onPressed: () =>
                                        _procesarLote(fecha, 'revertir'),
                                  ),
                                if (!yaPublicado)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: verdeExito,
                                    ),
                                    icon: const Icon(
                                      Icons.rocket_launch,
                                      size: 18,
                                    ),
                                    label: const Text("Publicar"),
                                    onPressed: () =>
                                        _procesarLote(fecha, 'publicar'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// =========================================================================
// SUB-PANTALLA: DETALLE DEL LOTE (Listado de productos y exportación a PDF)
// =========================================================================
class DetalleLoteScreen extends StatefulWidget {
  final String fecha;
  final String baseUrl;
  final String userRole;
  final bool yaPublicado;

  const DetalleLoteScreen({
    super.key,
    required this.fecha,
    required this.baseUrl,
    required this.userRole,
    required this.yaPublicado,
  });

  @override
  State<DetalleLoteScreen> createState() => _DetalleLoteScreenState();
}

class _DetalleLoteScreenState extends State<DetalleLoteScreen> {
  bool isLoading = true;
  List<dynamic> productos = [];

  // Nombres de tus sucursales para el módulo de edición
  final List<String> nombresSucursales = const [
    'Tuxtla Gutiérrez',
    'Comitán',
    'San Cristóbal',
    'Alm 4',
    'Alm 5',
  ];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/abmc/lotes/${widget.fecha}/productos'),
      );
      if (res.statusCode == 200) {
        setState(() {
          productos = json.decode(res.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _generarYCompartirPDF() async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Lanzamientos Factory',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Lote: ${widget.fecha}',
                    style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              widget.yaPublicado
                  ? 'Estado: PUBLICADO EN TIENDA'
                  : 'Estado: PENDIENTE DE PUBLICACIÓN',
              style: pw.TextStyle(
                color: widget.yaPublicado
                    ? PdfColors.green700
                    : PdfColors.orange700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Clave', 'Prov.', 'Descripción', 'Precio'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              data: productos
                  .map(
                    (p) => [
                      p['Clave'].toString(),
                      p['ClavePro']?.toString() ?? '',
                      p['Descripcion'].toString(),
                      '\$${p['Precio1']}',
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Lanzamiento_${widget.fecha}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: Text(
          "Productos del Lote: ${widget.fecha}",
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: azulPrimario,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Exportar a PDF",
            onPressed: productos.isEmpty ? null : _generarYCompartirPDF,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: productos.length,
              itemBuilder: (context, index) =>
                  _buildProductoCard(productos[index]),
            ),
    );
  }

  // Ficha de producto idéntica a la del inventario
  Widget _buildProductoCard(dynamic item) {
    bool activo = item['Activo'] == 1 || item['Activo'] == true;
    String fotoUrl = item['Foto'] != null && item['Foto'].toString().isNotEmpty
        ? '${widget.baseUrl}/uploads/${item['Foto']}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EdicionProductoScreen(
                clave: item['Clave'],
                baseUrl: widget.baseUrl,
                userRole: widget.userRole,
                sucursalNames: nombresSucursales,
              ),
            ),
          ).then((_) => _cargarProductos()); // Recargar por si se editó
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: fotoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey,
                      ),
              ),
              const SizedBox(width: 15),
              // Datos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['Descripcion'] ?? 'Sin descripción',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: activo ? null : TextDecoration.lineThrough,
                        color: activo ? Colors.black87 : Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "${item['Clave']}  |  Prov: ${item['ClavePro'] ?? 'N/A'}",
                            style: const TextStyle(
                              color: azulAcento,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatCurrency(item['Precio1'] ?? 0),
                          style: const TextStyle(
                            color: verdeExito,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
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
}
