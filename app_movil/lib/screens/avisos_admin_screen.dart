import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AvisosAdminScreen extends StatefulWidget {
  final String baseUrl;
  const AvisosAdminScreen({super.key, required this.baseUrl});

  @override
  State<AvisosAdminScreen> createState() => _AvisosAdminScreenState();
}

class _AvisosAdminScreenState extends State<AvisosAdminScreen> {
  List<dynamic> avisos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarAvisos();
  }

  Future<void> _cargarAvisos() async {
    setState(() => cargando = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/admin/avisos'),
      );
      if (res.statusCode == 200) {
        setState(() {
          avisos = json.decode(res.body)['avisos'];
          cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando avisos: $e");
      setState(() => cargando = false);
    }
  }

  void _abrirEditor({dynamic aviso}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditorAvisoModal(
        baseUrl: widget.baseUrl,
        avisoExistente: aviso,
        onGuardar: () {
          Navigator.pop(context);
          _cargarAvisos();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestión de Avisos"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : avisos.isEmpty
          ? const Center(child: Text("No hay avisos creados"))
          : RefreshIndicator(
              onRefresh: _cargarAvisos,
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: avisos.length,
                itemBuilder: (context, index) {
                  final a = avisos[index];
                  bool estaActivo = a['activo'] == 1;
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _parseColor(a['color_fondo']),
                        child: const Icon(Icons.campaign, color: Colors.black),
                      ),
                      title: Text(
                        a['mensaje'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Vence: ${a['fecha_fin'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(a['fecha_fin'])) : 'Sin fecha'}",
                      ),
                      trailing: Switch(
                        value: estaActivo,
                        onChanged: (val) =>
                            _activarDesactivarAviso(a['id'], val),
                        activeColor: Colors.green,
                      ),
                      onTap: () => _abrirEditor(aviso: a),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEditor(),
        backgroundColor: Colors.red[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NUEVO AVISO", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _activarDesactivarAviso(int id, bool val) async {
    try {
      final res = await http.put(
        Uri.parse('${widget.baseUrl}/api/admin/avisos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'activo': val ? 1 : 0}),
      );
      if (res.statusCode == 200) _cargarAvisos();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.yellow[200]!;
    return Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));
  }
}

// --- MODAL DEL EDITOR ---
class EditorAvisoModal extends StatefulWidget {
  final String baseUrl;
  final dynamic avisoExistente;
  final VoidCallback onGuardar;

  const EditorAvisoModal({
    super.key,
    required this.baseUrl,
    this.avisoExistente,
    required this.onGuardar,
  });

  @override
  State<EditorAvisoModal> createState() => _EditorAvisoModalState();
}

class _EditorAvisoModalState extends State<EditorAvisoModal> {
  final _msgCtrl = TextEditingController();
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 1));
  String _colorSeleccionado = "#FFF176";
  bool _activo = true;
  bool _guardando = false;

  final List<Map<String, dynamic>> _colores = [
    {'nombre': 'Amarillo', 'hex': '#FFF176', 'color': const Color(0xFFFFF176)},
    {'nombre': 'Rojo', 'hex': '#FFCDD2', 'color': const Color(0xFFFFCDD2)},
    {'nombre': 'Verde', 'hex': '#C8E6C9', 'color': const Color(0xFFC8E6C9)},
    {'nombre': 'Azul', 'hex': '#BBDEFB', 'color': const Color(0xFFBBDEFB)},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.avisoExistente != null) {
      _msgCtrl.text = widget.avisoExistente['mensaje'];
      _fechaFin = DateTime.parse(widget.avisoExistente['fecha_fin']);
      _colorSeleccionado = widget.avisoExistente['color_fondo'] ?? "#FFF176";
      _activo = widget.avisoExistente['activo'] == 1;
    }
  }

  Future<void> _seleccionarFechaHora() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaFin,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_fechaFin),
      );
      if (time != null) {
        setState(() {
          _fechaFin = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _guardar() async {
    if (_msgCtrl.text.isEmpty) return;
    setState(() => _guardando = true);

    final datos = {
      'mensaje': _msgCtrl.text,
      'fecha_inicio': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'fecha_fin': DateFormat('yyyy-MM-dd HH:mm:ss').format(_fechaFin),
      'color_fondo': _colorSeleccionado,
      'activo': _activo ? 1 : 0,
    };

    try {
      final url = widget.avisoExistente == null
          ? '${widget.baseUrl}/api/admin/avisos'
          : '${widget.baseUrl}/api/admin/avisos/${widget.avisoExistente['id']}';

      final res = await (widget.avisoExistente == null
          ? http.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(datos),
            )
          : http.put(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(datos),
            ));

      if (res.statusCode == 200) widget.onGuardar();
    } catch (e) {
      debugPrint("Error guardando: $e");
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.avisoExistente == null ? "Nuevo Aviso" : "Editar Aviso",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: "Mensaje del aviso",
                border: OutlineInputBorder(),
                hintText: "Ej. 10% de descuento hoy...",
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text("Fecha y hora de finalización"),
              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(_fechaFin)),
              trailing: const Icon(Icons.edit),
              onTap: _seleccionarFechaHora,
            ),
            const SizedBox(height: 10),
            const Text(
              "Color de fondo",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _colores.map((c) {
                bool sel = _colorSeleccionado == c['hex'];
                return GestureDetector(
                  onTap: () => setState(() => _colorSeleccionado = c['hex']),
                  child: Container(
                    width: 60,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c['color'],
                      borderRadius: BorderRadius.circular(10),
                      border: sel
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: sel ? const Icon(Icons.check, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("Aviso activo"),
              value: _activo,
              onChanged: (val) => setState(() => _activo = val),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "GUARDAR AVISO",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
