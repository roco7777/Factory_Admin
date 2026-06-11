import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Necesario para el Timer
import '../core/constants.dart';

class MonitorInventarioScreen extends StatefulWidget {
  final String baseUrl;
  final int idSesion;
  final String nombreZona;

  const MonitorInventarioScreen({
    super.key,
    required this.baseUrl,
    required this.idSesion,
    required this.nombreZona,
  });

  @override
  State<MonitorInventarioScreen> createState() =>
      _MonitorInventarioScreenState();
}

class _MonitorInventarioScreenState extends State<MonitorInventarioScreen> {
  Timer? _timer;
  bool _isLoading = true;

  Map<String, dynamic>? _finanzas;
  Map<String, dynamic>? _progreso;
  List<dynamic> _feed = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosMonitor();
    // Configurar el "Latido" cada 5 segundos para actualizar en tiempo real
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _cargarDatosMonitor(fondo: true);
    });
  }

  @override
  void dispose() {
    _timer
        ?.cancel(); // ¡MUY IMPORTANTE! Apagar el timer al salir de la pantalla
    super.dispose();
  }

  Future<void> _cargarDatosMonitor({bool fondo = false}) async {
    try {
      final res = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/inventario/sesiones/${widget.idSesion}/monitor',
        ),
      );
      final data = json.decode(res.body);

      if (data['success']) {
        setState(() {
          _finanzas = data['finanzas'];
          _progreso = data['progreso'];
          _feed = data['feed'];
          _isLoading = false;
        });
      }
    } catch (e) {
      // Si es una carga de fondo, no mostramos error para no interrumpir al usuario,
      // solo lo mostramos si es la carga inicial.
      if (!fondo && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al conectar con el monitor")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- WIDGETS DE UI ---

  Widget _buildTarjetaFinanciera(
    String titulo,
    double monto,
    int piezas,
    Color color,
    IconData icono,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border(bottom: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "\$${monto.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "$piezas pzas",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgresoGeneral() {
    int totalMeta =
        int.tryParse(_progreso!['total_productos_meta'].toString()) ?? 0;
    int contados =
        int.tryParse(_progreso!['productos_contados'].toString()) ?? 0;

    if (totalMeta == 0)
      return const SizedBox.shrink(); // Es un inventario parcial, no hay meta fija

    double porcentaje = (contados / totalMeta);

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: azulPrimario,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Avance General",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${(porcentaje * 100).toStringAsFixed(1)}%",
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: porcentaje,
            backgroundColor: Colors.white24,
            color: Colors.amber,
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          Text(
            "$contados de $totalMeta productos contados",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: fondoGris,
        appBar: AppBar(
          title: const Text("Monitor en Vivo"),
          backgroundColor: azulPrimario,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: azulPrimario),
        ),
      );
    }

    double faltanteDinero =
        double.tryParse(_finanzas!['dinero_faltante']?.toString() ?? '0') ?? 0;
    int faltantePzas =
        int.tryParse(_finanzas!['pzas_faltantes']?.toString() ?? '0') ?? 0;

    double sobranteDinero =
        double.tryParse(_finanzas!['dinero_sobrante']?.toString() ?? '0') ?? 0;
    int sobrantePzas =
        int.tryParse(_finanzas!['pzas_sobrantes']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Monitor Administrativo",
              style: TextStyle(fontSize: 16),
            ),
            Text(
              "Zona: ${widget.nombreZona}",
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
        actions: [
          // Un pequeño indicador visual de que está "En Vivo"
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 5),
                  Text(
                    "EN VIVO",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BARRA DE PROGRESO (Aparece solo si es inventario General)
            if (_progreso != null &&
                int.parse(_progreso!['total_productos_meta'].toString()) > 0)
              _buildProgresoGeneral(),

            // TARJETAS DE IMPACTO FINANCIERO
            Row(
              children: [
                _buildTarjetaFinanciera(
                  "SOBRANTES",
                  sobranteDinero,
                  sobrantePzas,
                  verdeExito,
                  Icons.trending_up_rounded,
                ),
                const SizedBox(width: 15),
                _buildTarjetaFinanciera(
                  "FALTANTES",
                  faltanteDinero,
                  faltantePzas,
                  Colors.red,
                  Icons.trending_down_rounded,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // TÍTULO DEL FEED
            Row(
              children: [
                const Icon(Icons.history, color: azulPrimario),
                const SizedBox(width: 10),
                const Text(
                  "Últimos Escaneos",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: azulPrimario,
                  ),
                ),
                const Spacer(),
                Text(
                  "${_feed.length} registros",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // LISTA DE ESCANEOS EN TIEMPO REAL
            Expanded(
              child: _feed.isEmpty
                  ? const Center(
                      child: Text(
                        "Esperando escaneos...\nLos registros aparecerán aquí automáticamente.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _feed.length,
                      itemBuilder: (context, index) {
                        final item = _feed[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: azulAcento.withOpacity(0.2),
                              child: const Icon(
                                Icons.qr_code,
                                color: azulAcento,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item['producto'] ?? 'Desconocido',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              "Por: ${item['usuario']} a las ${item['hora']}",
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: verdeExito.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "+${item['cantidad_agregada']}",
                                style: const TextStyle(
                                  color: verdeExito,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
