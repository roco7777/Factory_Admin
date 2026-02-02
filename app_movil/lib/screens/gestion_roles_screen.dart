import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';

class GestionRolesScreen extends StatefulWidget {
  final String baseUrl;
  const GestionRolesScreen({super.key, required this.baseUrl});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  List<dynamic> roles = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    final res = await http.get(Uri.parse('${widget.baseUrl}/api/roles'));
    if (res.statusCode == 200) {
      setState(() {
        roles = json.decode(res.body);
        cargando = false;
      });
    }
  }

  void _verPermisosDelRol(Map<String, dynamic> rol) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditorPermisosRol(rol: rol, baseUrl: widget.baseUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text("Moldes de Perfiles (Roles)"),
        backgroundColor: azulPrimario,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: roles.length,
              itemBuilder: (context, index) {
                final r = roles[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.groups_outlined,
                      color: azulAcento,
                    ),
                    title: Text(
                      r['nombre_rol'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                    onTap: () => _verPermisosDelRol(r),
                  ),
                );
              },
            ),
    );
  }
}

// --- SUB-PANTALLA: EL CHECKLIST DE PERMISOS ---
class EditorPermisosRol extends StatefulWidget {
  final Map<String, dynamic> rol;
  final String baseUrl;
  const EditorPermisosRol({
    super.key,
    required this.rol,
    required this.baseUrl,
  });

  @override
  State<EditorPermisosRol> createState() => _EditorPermisosRolState();
}

class _EditorPermisosRolState extends State<EditorPermisosRol> {
  List<dynamic> permisos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _fetchPermisos();
  }

  Future<void> _fetchPermisos() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              '${widget.baseUrl}/api/roles/${widget.rol['id_rol']}/permisos',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        setState(() {
          permisos = json.decode(res.body);
          cargando = false;
        });
      } else {
        throw "Error ${res.statusCode}";
      }
    } catch (e) {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al cargar molde: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _togglePermiso(int idPermiso, bool asignar) async {
    await http.post(
      Uri.parse('${widget.baseUrl}/api/roles/permisos/update'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'id_rol': widget.rol['id_rol'],
        'id_permiso': idPermiso,
        'asignar': asignar,
      }),
    );
    _fetchPermisos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Permisos de: ${widget.rol['nombre_rol']}")),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: permisos.length,
              itemBuilder: (context, index) {
                final p = permisos[index];
                return CheckboxListTile(
                  title: Text(p['descripcion']),
                  subtitle: Text(p['modulo'].toString().toUpperCase()),
                  value: p['asignado'] == 1,
                  onChanged: (val) => _togglePermiso(p['id_permiso'], val!),
                );
              },
            ),
    );
  }
}
