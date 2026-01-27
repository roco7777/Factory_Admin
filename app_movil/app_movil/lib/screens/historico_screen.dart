import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../widgets/dialogo_retiros.dart';

class PantallaHistorico extends StatefulWidget {
  final String baseUrl;
  const PantallaHistorico({super.key, required this.baseUrl});

  @override
  State<PantallaHistorico> createState() => _PantallaHistoricoState();
}

class _PantallaHistoricoState extends State<PantallaHistorico>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> datos = {};
  Map<String, List<dynamic>> sucursalesAgrupadas = {};
  bool cargando = true;
  DateTime fechaSeleccionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _cargarDatos();
    });
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => cargando = true);
    String rango = ['dia', 'semana', 'mes'][_tabController.index];
    String fStr =
        "${fechaSeleccionada.year}-${fechaSeleccionada.month.toString().padLeft(2, '0')}-${fechaSeleccionada.day.toString().padLeft(2, '0')}";

    try {
      final res = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/reportes/historico?rango=$rango&mes=${fechaSeleccionada.month}&anio=${fechaSeleccionada.year}&fecha=$fStr',
        ),
      );
      final rawData = json.decode(res.body);
      Map<String, List<dynamic>> grupos = {};
      if (rawData['detalles'] != null) {
        for (var corte in rawData['detalles']) {
          String n = corte['NombreSucursal'];
          if (!grupos.containsKey(n)) grupos[n] = [];
          grupos[n]!.add(corte);
        }
      }
      setState(() {
        datos = rawData;
        sucursalesAgrupadas = grupos;
        cargando = false;
      });
    } catch (e) {
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String fIni = fechaSeleccionada.toString().split(' ')[0];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Venta Diaria"),
        backgroundColor: Colors.blueGrey[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            onPressed: () async {
              DateTime? p = await showDatePicker(
                context: context,
                initialDate: fechaSeleccionada,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (p != null) {
                setState(() => fechaSeleccionada = p);
                _cargarDatos();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Día"),
            Tab(text: "Semana"),
            Tab(text: "Mes"),
          ],
        ),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : _UIReporteHistorico(
              datos: datos,
              sucursales: sucursalesAgrupadas,
              baseUrl: widget.baseUrl,
              fechaIni: fIni,
            ),
    );
  }
}

class _UIReporteHistorico extends StatelessWidget {
  final Map<String, dynamic> datos;
  final Map<String, List<dynamic>> sucursales;
  final String baseUrl;
  final String fechaIni;

  const _UIReporteHistorico({
    required this.datos,
    required this.sucursales,
    required this.baseUrl,
    required this.fechaIni,
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
    double tEN =
        double.tryParse(
          datos['global']?['TotalEfectivoNeto']?.toString() ?? '0',
        ) ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
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
                  Text(
                    datos['periodo'] ?? "RESUMEN",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formatCurrency(tE + tT + tB),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "GRAN TOTAL",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 9),
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Text(
                    formatCurrency(tEN),
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "EFECTIVO NETO (ENTREGAR)",
                    style: TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 25),
                  _fila("Efectivo:", tE, Colors.white),
                  _fila("Tarjeta:", tT, Colors.white),
                  _fila("Bancario:", tB, Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
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
                    .map((c) => _buildDetalleHisto(context, c))
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetalleHisto(BuildContext context, dynamic c) {
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
                    fIni: c['FechaFila'] ?? fechaIni,
                    fFin: c['FechaFila'] ?? fechaIni,
                  ),
                );
              },
            ),
            const Divider(),
            _fila(
              "EFECTIVO NETO:",
              c['EfectivoNeto'] ?? 0,
              Colors.indigo[900]!,
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
