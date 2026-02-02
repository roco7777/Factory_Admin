import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import 'permisos_usuario_screen.dart';

class GestionUsuariosScreen extends StatefulWidget {
  final String baseUrl;
  const GestionUsuariosScreen({super.key, required this.baseUrl});

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  List<dynamic> usuarios = [];
  List<dynamic> roles = [];
  List<dynamic> sucursales = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => cargando = true);
    try {
      final res = await Future.wait([
        http.get(Uri.parse('${widget.baseUrl}/api/usuarios/lista')),
        http.get(Uri.parse('${widget.baseUrl}/api/roles')),
        http.get(Uri.parse('${widget.baseUrl}/api/sucursales')),
      ]);

      setState(() {
        usuarios = json.decode(res[0].body);
        roles = json.decode(res[1].body);
        sucursales = json.decode(res[2].body);
        cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => cargando = false);
      debugPrint("Error cargando datos: $e");
    }
  }

  // --- LÓGICA DE ELIMINACIÓN ---
  void _confirmarEliminacion(int id, String nombre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar Usuario?"),
        content: Text(
          "Esta acción borrará a '$nombre' y todos sus permisos personalizados. No se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarUsuario(id, nombre);
            },
            child: const Text(
              "ELIMINAR",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarUsuario(int id, String nombre) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/usuarios/eliminar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id, 'nombre': nombre}),
      );

      final data = json.decode(res.body);
      if (data['success']) {
        _cargarDatos();
        _errorMsg("🗑️ Usuario eliminado", color: Colors.orange);
      } else {
        _errorMsg(data['message'] ?? "Error al eliminar");
      }
    } catch (e) {
      _errorMsg("Error de conexión");
    }
  }

  // --- FORMULARIO DE EDICIÓN / ALTA ---
  void _abrirFormulario({Map<String, dynamic>? usuario}) {
    final bool esEdicion = usuario != null;
    final TextEditingController nameCtrl = TextEditingController(
      text: esEdicion ? usuario['Nombre'] : '',
    );
    final TextEditingController longNameCtrl = TextEditingController(
      text: esEdicion ? usuario['NombreLargo'] : '',
    );
    final TextEditingController passCtrl = TextEditingController();

    int? rolSeleccionado = esEdicion ? usuario['id_rol'] : null;
    int sucursalSeleccionada = esEdicion ? (usuario['NumSuc'] ?? 0) : 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: fondoGris,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedRoleData = roles.firstWhere(
            (r) => r['id_rol'] == rolSeleccionado,
            orElse: () => null,
          );
          final bool esSuper =
              selectedRoleData != null &&
              selectedRoleData['nombre_rol'] == 'Superusuario';

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: grisBordes,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    esEdicion ? "EDITAR PERFIL" : "NUEVO PERSONAL",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: azulPrimario,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: nameCtrl,
                    decoration: _inputDecoration(
                      "Usuario (Corto)",
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: longNameCtrl,
                    decoration: _inputDecoration(
                      "Nombre Completo",
                      Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: _inputDecoration(
                      esEdicion ? "Nueva Clave (Opcional)" : "Contraseña",
                      Icons.lock_outline,
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: rolSeleccionado,
                    decoration: _inputDecoration(
                      "Rol / Rango",
                      Icons.admin_panel_settings_outlined,
                    ),
                    items: roles
                        .map<DropdownMenuItem<int>>(
                          (r) => DropdownMenuItem<int>(
                            value: r['id_rol'],
                            child: Text(r['nombre_rol']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => rolSeleccionado = val),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: esSuper ? 0 : sucursalSeleccionada,
                    decoration: _inputDecoration(
                      "Sucursal",
                      Icons.store_mall_directory_outlined,
                    ),
                    disabledHint: const Text("ACCESO GLOBAL (MASTER)"),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text("ACCESO GLOBAL (SUPER)"),
                      ),
                      ...sucursales
                          .map<DropdownMenuItem<int>>(
                            (s) => DropdownMenuItem<int>(
                              value: s['ID'],
                              child: Text(s['sucursal']),
                            ),
                          )
                          .toList(),
                    ],
                    onChanged: esSuper
                        ? null
                        : (val) =>
                              setModalState(() => sucursalSeleccionada = val!),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulPrimario,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      final roleData = roles.firstWhere(
                        (r) => r['id_rol'] == rolSeleccionado,
                        orElse: () => null,
                      );
                      if (nameCtrl.text.isEmpty || roleData == null) {
                        _errorMsg("Datos incompletos");
                        return;
                      }
                      _guardarUsuario(
                        id: esEdicion ? usuario['CveUsuario'] : null,
                        nombre: nameCtrl.text.trim(),
                        nombreLargo: longNameCtrl.text.trim(),
                        pass: passCtrl.text.trim(),
                        rol: rolSeleccionado!,
                        suc: esSuper ? 0 : sucursalSeleccionada,
                        nombreRol: roleData['nombre_rol'],
                      );
                    },
                    child: const Text(
                      "GUARDAR CAMBIOS",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- DISEÑO DE LISTA ---
  Widget _buildGrupoSucursal(
    String titulo,
    List<dynamic> lista, {
    bool inicialmenteAbierto = false,
  }) {
    if (lista.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: grisBordes),
      ),
      child: ExpansionTile(
        initiallyExpanded: inicialmenteAbierto,
        shape: const Border(),
        leading: Icon(
          titulo.contains("GLOBAL")
              ? Icons.stars_rounded
              : Icons.store_mall_directory_outlined,
          color: titulo.contains("GLOBAL") ? Colors.amber[800] : azulAcento,
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: azulPrimario,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          "${lista.length} integrantes",
          style: const TextStyle(fontSize: 11),
        ),
        children: lista
            .map(
              (u) => ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                title: Text(
                  u['Nombre'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(u['NombreLargo'] ?? 'Sin nombre registrado'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.security_rounded,
                        color: Colors.orangeAccent,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PermisosUsuarioScreen(
                            usuario: u,
                            baseUrl: widget.baseUrl,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_note_rounded,
                        color: azulAcento,
                        size: 28,
                      ),
                      onPressed: () => _abrirFormulario(usuario: u),
                    ),
                    // VALIDACIÓN VISUAL: Si es Superusuario, NO mostramos la basura
                    if (u['nombre_rol'] != 'Superusuario')
                      IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          color: Colors.redAccent,
                        ),
                        onPressed: () =>
                            _confirmarEliminacion(u['CveUsuario'], u['Nombre']),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoGris,
      appBar: AppBar(
        title: const Text(
          "Gestión de Personal",
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        backgroundColor: azulPrimario,
        elevation: 0,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: azulPrimario))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildGrupoSucursal(
                    "👑 CONTROL CORPORATIVO",
                    usuarios.where((u) => u['NumSuc'] == 0).toList(),
                    inicialmenteAbierto: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 5),
                    child: Text(
                      "SUCURSALES OPERATIVAS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  ...sucursales.map(
                    (s) => _buildGrupoSucursal(
                      "SUCURSAL: ${s['sucursal'].toString().toUpperCase()}",
                      usuarios.where((u) => u['NumSuc'] == s['ID']).toList(),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: azulPrimario,
        label: const Text(
          "NUEVO USUARIO",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        onPressed: () => _abrirFormulario(),
      ),
    );
  }

  // --- AUXILIARES ---
  Future<void> _guardarUsuario({
    int? id,
    required String nombre,
    required String nombreLargo,
    required String pass,
    required int rol,
    required int suc,
    required String nombreRol,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/usuarios/guardar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': id,
          'nombre': nombre,
          'nombreLargo': nombreLargo,
          'password': pass,
          'id_rol': rol,
          'num_suc': suc,
          'nombre_rol': nombreRol,
        }),
      );
      if (json.decode(res.body)['success']) {
        if (!mounted) return;
        Navigator.pop(context);
        _cargarDatos();
        _errorMsg("✅ Cambios guardados", color: verdeExito);
      }
    } catch (e) {
      _errorMsg("Error de red");
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: azulAcento, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  void _errorMsg(String msg, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
