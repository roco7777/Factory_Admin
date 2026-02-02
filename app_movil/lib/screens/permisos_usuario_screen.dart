import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';

class PermisosUsuarioScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final String baseUrl;

  const PermisosUsuarioScreen({
    super.key,
    required this.usuario,
    required this.baseUrl,
  });

  @override
  State<PermisosUsuarioScreen> createState() => _PermisosUsuarioScreenState();
}

class _PermisosUsuarioScreenState extends State<PermisosUsuarioScreen> {
  List<dynamic> permisos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _fetchPermisos();
  }

  Future<void> _fetchPermisos() async {
    try {
      final url = Uri.parse(
        '${widget.baseUrl}/api/usuarios/${widget.usuario['CveUsuario']}/permisos',
      );
      final res = await http
          .get(url)
          .timeout(const Duration(seconds: 10)); // Evita esperas infinitas

      if (res.statusCode == 200) {
        setState(() {
          permisos = json.decode(res.body);
          cargando = false;
        });
      } else {
        throw Exception("Error servidor: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No se pudieron cargar los permisos: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _togglePermiso(int idPermiso, int? valorActual) async {
    // Si es 1 lo pasamos a 0, si es 0 o null lo pasamos a 1
    int nuevoValor = (valorActual == 1) ? 0 : 1;

    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/usuarios/permisos/personalizar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_usuario': widget.usuario['CveUsuario'],
          'id_permiso': idPermiso,
          'valor': nuevoValor,
        }),
      );

      if (res.statusCode == 200) {
        _fetchPermisos(); // Recargamos para ver el cambio de color
      }
    } catch (e) {
      debugPrint("Error al actualizar permiso: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: Text(
          "Privilegios: ${widget.usuario['Nombre']}",
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: azulPrimario,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: permisos.length,
              itemBuilder: (context, index) {
                final p = permisos[index];
                bool tieneAcceso =
                    (p['valor_personalizado'] ?? p['tiene_por_rol']) == 1;
                bool esPersonalizado = p['valor_personalizado'] != null;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: esPersonalizado
                          ? Colors.orange.withOpacity(0.5)
                          : grisBordes,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      tieneAcceso ? Icons.check_circle : Icons.cancel,
                      color: tieneAcceso ? Colors.green : Colors.redAccent,
                    ),
                    title: Text(
                      p['descripcion'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "${p['modulo'].toUpperCase()} • ${esPersonalizado ? 'Personalizado' : 'Por Rol'}",
                      style: TextStyle(
                        color: esPersonalizado
                            ? Colors.orange[800]
                            : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    trailing: Switch(
                      value: tieneAcceso,
                      activeColor: esPersonalizado ? Colors.orange : azulAcento,
                      onChanged: (val) => _togglePermiso(
                        p['id_permiso'],
                        p['valor_personalizado'],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
