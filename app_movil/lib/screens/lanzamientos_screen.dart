import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants.dart';
import 'edicion_producto_screen.dart';
import 'detalle_producto_screen.dart';

class LanzamientosScreen extends StatefulWidget {
  final String baseUrl;
  final String userRole;

  const LanzamientosScreen({
    super.key,
    required this.baseUrl,
    required this.userRole,
  });

  @override
  State<LanzamientosScreen> createState() => _LanzamientosScreenState();
}

class _LanzamientosScreenState extends State<LanzamientosScreen> {
  bool isLoading = false;
  List<dynamic> lotes = [];

  @override
  void initState() {
    super.initState();
    _cargarLotes();
  }

  // --- NUEVA FUNCIÓN: SINCRONIZAR FOTOS DRIVE ---
  Future<void> _sincronizarFotosManual() async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("🔄 Sincronizar Google Drive"),
            content: const Text(
              "¿Deseas ejecutar la búsqueda de nuevas fotos en Drive ahora mismo? \n\nEsto actualizará los productos modificados hoy.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Ahora no"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Ejecutar"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/admin/sincronizar-fotos'),
      );
      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['success']) {
        _mostrarResumenSync(data['output']);
      } else {
        throw Exception(data['error'] ?? "Error desconocido");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error de servidor: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _mostrarResumenSync(String output) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("✅ Sincronización Exitosa"),
        content: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            output,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 Lote procesado con éxito")),
        );
        _cargarLotes();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
      setState(() => isLoading = false);
    }
  }

  Future<bool> _mostrarDialogoConfirmacion(String fecha, String accion) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              accion == 'publicar' ? '🚀 Publicar Lote' : '⏪ Revertir',
            ),
            content: Text("¿Confirmas la acción para el lote del $fecha?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: azulPrimario),
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
          "Lanzamientos HIATECH",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: azulPrimario,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.cloud_sync_rounded,
              color: Colors.white,
              size: 28,
            ),
            tooltip: "Sincronizar Drive",
            onPressed: isLoading ? null : _sincronizarFotosManual,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarLotes),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : lotes.isEmpty
          ? const Center(child: Text("No hay lotes programados"))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: lotes.length,
              itemBuilder: (context, index) {
                final lote = lotes[index];
                final String fecha = lote['FechaLote'];
                final bool yaPublicado =
                    (int.tryParse(lote['TotalPendientes'].toString()) ?? 0) ==
                    0;
                final String totalProd =
                    (lote['total_productos'] ??
                            lote['TotalProductos'] ??
                            lote['Total'] ??
                            '0')
                        .toString();

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fecha,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: azulPrimario,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: azulAcento.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "$totalProd productos",
                                    style: const TextStyle(
                                      color: azulAcento,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Badge(
                              label: Text(
                                yaPublicado ? "PUBLICADO" : "PROGRAMADO",
                              ),
                              backgroundColor: yaPublicado
                                  ? azulPrimario
                                  : Colors.orange,
                            ),
                          ],
                        ),
                        const Divider(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetalleLoteScreen(
                                    fecha: fecha,
                                    baseUrl: widget.baseUrl,
                                    userRole: widget.userRole,
                                    yaPublicado: yaPublicado,
                                  ),
                                ),
                              ).then((_) => _cargarLotes()),
                              icon: const Icon(
                                Icons.inventory_2,
                                color: azulAcento,
                              ),
                              label: const Text(
                                "Gestionar Lote",
                                style: TextStyle(
                                  color: azulAcento,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: yaPublicado
                                    ? Colors.blueGrey
                                    : azulPrimario,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                              ),
                              onPressed: () => _procesarLote(
                                fecha,
                                yaPublicado ? 'revertir' : 'publicar',
                              ),
                              child: Text(
                                yaPublicado ? "REVERTIR" : "PUBLICAR",
                              ),
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

// --- SUB-PANTALLA: DETALLE DEL LOTE ACTUALIZADA ---
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
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: Text("Lote ${widget.fecha}"),
        backgroundColor: azulPrimario,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              key: const PageStorageKey('scroll_productos_lote'),
              padding: const EdgeInsets.all(12),
              itemCount: productos.length,
              itemBuilder: (context, index) =>
                  _buildProductoCard(productos[index], index),
            ),
    );
  }

  Widget _buildProductoCard(dynamic item, int index) {
    String driveId = item['drive_id']?.toString() ?? '';
    String fotoUrl = driveId.isNotEmpty && driveId != 'null'
        ? "https://drive.google.com/uc?id=$driveId"
        : '${widget.baseUrl}/uploads/${item['Foto']}';

    bool isActivo = item['Activo']?.toString() != '0';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      color: isActivo ? Colors.white : const Color(0xFFFFF0F0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActivo
            ? BorderSide.none
            : BorderSide(color: Colors.red.shade300, width: 1.5),
      ),
      child: Stack(
        children: [
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                fotoUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image),
              ),
            ),
            title: Text(
              item['Descripcion'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActivo ? Colors.black : Colors.blueGrey,
              ),
              maxLines:
                  2, // Le puse 2 líneas para que aproveche aún más el espacio
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              "${item['Clave']} | \$${(double.tryParse(item['Precio1']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}",
              style: TextStyle(
                color: isActivo ? azulAcento : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleProductoScreen(
                    item: item,
                    baseUrl: widget.baseUrl,
                  ),
                ),
              ).then((_) => _cargarProductos());
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActivo ? azulAcento : Colors.grey[600],
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
    );
  }
}
