import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../widgets/dialogo_retiros.dart';

class PantallaReportes extends StatefulWidget {
  final String baseUrl;
  const PantallaReportes({super.key, required this.baseUrl});

  @override
  State<PantallaReportes> createState() => _PantallaReportesState();
}

class _PantallaReportesState extends State<PantallaReportes> {
  Map<String, dynamic> datos = {};
  Map<String, List<dynamic>> sucursalesAgrupadas = {};
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarReporte();
  }

  Future<void> _cargarReporte() async {
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/reportes/cajas'),
      );
      if (res.statusCode == 200) {
        final rawData = json.decode(res.body);
        Map<String, List<dynamic>> grupos = {};
        for (var caja in rawData['detalles']) {
          String n = caja['NombreSucursal'];
          if (!grupos.containsKey(n)) grupos[n] = [];
          grupos[n]!.add(caja);
        }
        setState(() {
          datos = rawData;
          sucursalesAgrupadas = grupos;
          cargando = false;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    String hoy = DateTime.now().toString().split(' ')[0];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Corte en Vivo"),
        backgroundColor: Colors.indigo[800],
      ),
      backgroundColor: Colors.grey[200],
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarReporte,
              child: _UIReporteVivo(
                datos: datos,
                sucursales: sucursalesAgrupadas,
                baseUrl: widget.baseUrl,
                fechaHoy: hoy,
              ),
            ),
    );
  }
}

class _UIReporteVivo extends StatelessWidget {
  final Map<String, dynamic> datos;
  final Map<String, List<dynamic>> sucursales;
  final String baseUrl;
  final String fechaHoy;

  const _UIReporteVivo({
    required this.datos,
    required this.sucursales,
    required this.baseUrl,
    required this.fechaHoy,
  });
  @override
  Widget build(BuildContext context) {
    // 1. Extraemos los valores del mapa global
    double tE =
        double.tryParse(datos['global']?['TotalEfectivo']?.toString() ?? '0') ??
        0;
    double tT =
        double.tryParse(datos['global']?['TotalTarjeta']?.toString() ?? '0') ??
        0;
    double tB =
        double.tryParse(datos['global']?['TotalBancario']?.toString() ?? '0') ??
        0;

    // 2. Calculamos los Retiros Globales (sumando los retiros de todas las cajas)
    double totalRetirosGlobal = 0;
    sucursales.forEach((key, cajas) {
      for (var caja in cajas) {
        totalRetirosGlobal +=
            double.tryParse(caja['Retiros']?.toString() ?? '0') ?? 0;
      }
    });

    // 3. Calculamos el Efectivo Neto (Lo que queda en físico)
    double efectivoNeto = tE - totalRetirosGlobal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Card de Total Empresa
          Card(
            color: Colors.indigo[900],
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "TOTAL EMPRESA ACTUAL (BRUTO)",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    formatCurrency(tE + tT + tB),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 20),

                  // --- NUEVA SECCIÓN DE EFECTIVO NETO ---
                  _fila("Efectivo Total:", tE, Colors.white70),
                  _fila(
                    "Retiros Totales:",
                    totalRetirosGlobal,
                    Colors.redAccent,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _fila(
                      "EFECTIVO NETO:",
                      efectivoNeto,
                      Colors.greenAccent,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 20),

                  // ---------------------------------------
                  _fila("Tarjeta:", tT, Colors.white),
                  _fila("Bancario:", tB, Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Listado de Sucursales
          ...sucursales.entries.map((entry) {
            double totalSuc = entry.value.fold(
              0,
              (sum, item) =>
                  sum +
                  (double.tryParse(item['VentaTotal']?.toString() ?? '0') ?? 0),
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.store, color: Colors.indigo),
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  formatCurrency(totalSuc),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: entry.value
                    .map((c) => _buildCajaDetalle(context, c))
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCajaDetalle(BuildContext context, dynamic c) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Caja ${c['NumCaja']}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  formatCurrency(c['VentaTotal']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            _fila("Efec:", c['Efectivo'], Colors.black87),
            _fila("Tarj:", c['Tarjeta'], Colors.black87),
            _fila("Banc:", c['Bancario'], Colors.black87),
            _fila(
              "Retiros:",
              c['Retiros'] ?? 0,
              Colors.red,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => DialogoRetiros(
                    baseUrl: baseUrl,
                    numSuc: c['NumSuc'],
                    numCaja: c['NumCaja'],
                    fIni: fechaHoy,
                    fFin: fechaHoy,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String l, dynamic v, Color c, {VoidCallback? onTap}) {
    double m = double.tryParse(v.toString()) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: TextStyle(fontSize: 13, color: c)),
          GestureDetector(
            onTap: (m > 0) ? onTap : null,
            child: Text(
              formatCurrency(v),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: (m > 0 && onTap != null) ? Colors.blue : c,
                decoration: (m > 0 && onTap != null)
                    ? TextDecoration.underline
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
