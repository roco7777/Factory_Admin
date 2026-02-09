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
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    String hoy = DateTime.now().toString().split(' ')[0];
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          "Corte en Vivo",
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarReporte,
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : RefreshIndicator(
              color: azulPrimario,
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
    double tE =
        double.tryParse(datos['global']?['TotalEfectivo']?.toString() ?? '0') ??
        0;
    double tT =
        double.tryParse(datos['global']?['TotalTarjeta']?.toString() ?? '0') ??
        0;
    double tB =
        double.tryParse(datos['global']?['TotalBancario']?.toString() ?? '0') ??
        0;

    double totalRetirosGlobal = 0;
    sucursales.forEach((key, cajas) {
      for (var caja in cajas) {
        totalRetirosGlobal +=
            double.tryParse(caja['Retiros']?.toString() ?? '0') ?? 0;
      }
    });

    double efectivoNeto = tE - totalRetirosGlobal;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // --- PANEL DE CONTROL DE EFECTIVO (HEADLINE) ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: azulPrimario,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: azulPrimario.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "VENTA BRUTA TOTAL (HOY)",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  formatCurrency(tE + tT + tB),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(color: Colors.white12, height: 1),
                ),

                // --- CAMBIO 1: TOTAL EFECTIVO AL CENTRO (AMARILLO) ---
                Text(
                  formatCurrency(tE), // Total Efectivo Bruto
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "TOTAL EFECTIVO",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // --- CAMBIO 2: EFECTIVO NETO ABAJO (BLANCO) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniData("Efectivo neto", efectivoNeto), // Neto disponible
                    _miniData("Retiros", totalRetirosGlobal, isNegative: true),
                    _miniData("Tarjetas", tT),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // --- LISTADO DE SUCURSALES ---
          Row(
            children: [
              Container(width: 4, height: 15, color: azulAcento),
              const SizedBox(width: 10),
              const Text(
                "ESTADO POR SUCURSAL",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black54,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          ...sucursales.entries.map((entry) {
            double totalSuc = entry.value.fold(
              0,
              (sum, item) =>
                  sum +
                  (double.tryParse(item['VentaTotal']?.toString() ?? '0') ?? 0),
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: grisBordes),
              ),
              child: ExpansionTile(
                iconColor: azulAcento,
                collapsedIconColor: Colors.grey,
                leading: const CircleAvatar(
                  backgroundColor: fondoGris,
                  child: Icon(
                    Icons.storefront_rounded,
                    color: azulPrimario,
                    size: 20,
                  ),
                ),
                title: Text(
                  entry.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: azulPrimario,
                  ),
                ),
                trailing: Text(
                  formatCurrency(totalSuc),
                  style: const TextStyle(
                    color: azulAcento,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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

  Widget _miniData(String label, double valor, {bool isNegative = false}) {
    return Column(
      children: [
        Text(
          formatCurrency(valor),
          style: TextStyle(
            color: isNegative ? Colors.red[300] : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildCajaDetalle(BuildContext context, dynamic c) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fondoGris.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CAJA ${c['NumCaja']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: azulAcento,
                ),
              ),
              Text(
                formatCurrency(c['VentaTotal']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: azulPrimario,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _fila("Venta Efectivo:", c['Efectivo'], azulPrimario),
          _fila("Venta Tarjeta:", c['Tarjeta'], azulPrimario),
          _fila("Otros (Banc):", c['Bancario'], azulPrimario),
          _fila(
            "Retiros Realizados:",
            c['Retiros'] ?? 0,
            Colors.red[700]!,
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
    );
  }

  Widget _fila(String l, dynamic v, Color c, {VoidCallback? onTap}) {
    double m = double.tryParse(v.toString()) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
                color: (m > 0 && onTap != null) ? Colors.blue[700] : c,
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
