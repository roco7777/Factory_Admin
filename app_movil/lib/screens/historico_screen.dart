import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          "Ventas e Histórico",
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              DateTime? p = await showDatePicker(
                context: context,
                initialDate: fechaSeleccionada,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: azulPrimario,
                      ),
                    ),
                    child: child!,
                  );
                },
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
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Día"),
            Tab(text: "Semana"),
            Tab(text: "Mes"),
          ],
        ),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // --- CARD RESUMEN GLOBAL (ESTILO PROFESIONAL) ---
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
                Text(
                  datos['periodo']?.toString().toUpperCase() ??
                      "RESUMEN DE OPERACIONES",
                  style: const TextStyle(
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
                const Text(
                  "VENTA BRUTA TOTAL",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(color: Colors.white12),
                ),
                Text(
                  formatCurrency(tEN),
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "EFECTIVO NETO A ENTREGAR",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _itemHeader("Efectivo", tE),
                    _itemHeader("Tarjeta", tT),
                    _itemHeader("Bancario", tB),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // --- DESGLOSE POR SUCURSAL ---
          Row(
            children: [
              Container(width: 4, height: 15, color: azulAcento),
              const SizedBox(width: 10),
              const Text(
                "DESGLOSE POR SUCURSAL",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black54,
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
                    color: verdeExito,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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

  Widget _itemHeader(String label, double valor) {
    return Column(
      children: [
        Text(
          formatCurrency(valor),
          style: const TextStyle(
            color: Colors.white,
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

  Widget _buildDetalleHisto(BuildContext context, dynamic c) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondoGris.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
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
          _fila("Efectivo:", c['Efectivo'], azulPrimario),
          _fila("Tarjetas:", c['Tarjeta'], azulPrimario),
          _fila("Depósitos:", c['Bancario'], azulPrimario),
          _fila(
            "Retiros de Caja:",
            c['Retiros'] ?? 0,
            Colors.red[700]!,
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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: azulPrimario.withOpacity(0.05),
              borderRadius: BorderRadius.circular(5),
            ),
            child: _fila(
              "EFECTIVO NETO:",
              c['EfectivoNeto'] ?? 0,
              azulPrimario,
              bold: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(
    String l,
    dynamic v,
    Color c, {
    VoidCallback? onTap,
    bool bold = false,
  }) {
    double m = double.tryParse(v.toString()) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: TextStyle(
              fontSize: 13,
              color: c,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
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
