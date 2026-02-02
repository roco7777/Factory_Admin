import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/security_service.dart';
import 'inventario_screen.dart';
import 'admin_login_screen.dart';
import 'reportes_screen.dart';
import 'historico_screen.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_roles_screen.dart'; // <--- Importante

class DashboardScreen extends StatefulWidget {
  final String baseUrl;
  const DashboardScreen({super.key, required this.baseUrl});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String nombreUsuario = "Admin";
  String rolUsuario = "";

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nombreUsuario = prefs.getString('saved_user') ?? "Admin";
      rolUsuario = prefs.getString('saved_rol') ?? "N/A";
    });
  }

  void _navegarA(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => pantalla));
  }

  void _mostrarMensajeProximamente(String modulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🚀 Módulo de $modulo en desarrollo."),
        duration: const Duration(seconds: 2),
        backgroundColor: azulPrimario,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarDialogoCambioPass() {
    final TextEditingController passCtrl = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Mi Contraseña",
            style: TextStyle(color: azulPrimario),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Escribe tu nueva clave de acceso:",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: "Nueva contraseña",
                  prefixIcon: const Icon(Icons.lock_reset, color: azulAcento),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCELAR"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: azulPrimario,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (passCtrl.text.isEmpty) return;
                final res = await http.post(
                  Uri.parse('${widget.baseUrl}/api/usuarios/cambiar-pass'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'nombre': nombreUsuario,
                    'nueva_pass': passCtrl.text.trim(),
                  }),
                );
                if (json.decode(res.body)['success']) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Contraseña actualizada"),
                      backgroundColor: verdeExito,
                    ),
                  );
                }
              },
              child: const Text("ACTUALIZAR"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    SecurityService.limpiarPermisos();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => AdminLoginScreen(baseUrl: widget.baseUrl),
        ),
        (route) => false,
      );
    }
  }

  void _mostrarOpcionesReportes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: fondoGris,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
              const SizedBox(height: 25),
              const Text(
                "REPORTES OPERATIVOS",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: azulPrimario,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildReportTile(
                icon: Icons.bolt_rounded,
                color: Colors.amber[700]!,
                title: "Corte en Vivo",
                subtitle: "Ventas registradas el día de hoy",
                onTap: () {
                  Navigator.pop(context);
                  _navegarA(PantallaReportes(baseUrl: widget.baseUrl));
                },
              ),
              const Divider(color: grisBordes),
              _buildReportTile(
                icon: Icons.history_rounded,
                color: azulAcento,
                title: "Histórico de Ventas",
                subtitle: "Consulta cierres de fechas pasadas",
                onTap: () {
                  Navigator.pop(context);
                  _navegarA(PantallaHistorico(baseUrl: widget.baseUrl));
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: grisBordes),
      onTap: onTap,
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: grisBordes, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey[100] : color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isLocked ? Colors.grey[400] : color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isLocked ? Colors.grey[400] : azulPrimario,
              ),
            ),
            if (isLocked)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.lock_outline, size: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esSuperUser = rolUsuario == 'Superusuario';
    final bool puedeGestionarUsuarios =
        SecurityService.tienePermiso('admin_usuarios') || esSuperUser;

    return Scaffold(
      backgroundColor: fondoGris,
      // EL APPBAR estándar garantiza que el botón del Drawer aparezca correctamente
      appBar: AppBar(
        backgroundColor: azulPrimario,
        elevation: 0,
        centerTitle: true,
        title: Text(
          esSuperUser ? "PANEL MASTER" : "PANEL DE CONTROL",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text("Cerrar Sesión"),
                  content: const Text(
                    "¿Seguro que desea salir del panel administrativo?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("CANCELAR"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cerrarSesion();
                      },
                      child: const Text(
                        "SALIR",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // EL DRAWER ahora se maneja correctamente por el Scaffold
      drawer: Drawer(
        elevation: 20,
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: azulPrimario,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(40),
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: esSuperUser ? Colors.amber : azulAcento,
                  child: Icon(
                    esSuperUser ? Icons.stars : Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                accountName: Text(
                  nombreUsuario,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                accountEmail: Text(
                  "Nivel: $rolUsuario",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined, color: azulAcento),
                title: const Text(
                  "Mi Contraseña",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarDialogoCambioPass();
                },
              ),
              if (puedeGestionarUsuarios)
                ListTile(
                  leading: const Icon(Icons.people_outline, color: azulAcento),
                  title: const Text(
                    "Gestión de Personal",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navegarA(GestionUsuariosScreen(baseUrl: widget.baseUrl));
                  },
                ),
              if (esSuperUser)
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text(
                    "Configurar Perfiles (Roles)",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navegarA(GestionRolesScreen(baseUrl: widget.baseUrl));
                  },
                ),
              const Divider(),
              const Spacer(),
              const Text(
                "Versión 1.0.5 - Factory Admin",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
            decoration: const BoxDecoration(
              color: azulPrimario,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: esSuperUser ? Colors.amber : azulAcento,
                  child: Icon(
                    esSuperUser
                        ? Icons.verified_user
                        : Icons.admin_panel_settings,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esSuperUser ? "Modo Master activo," : "Operando como,",
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      nombreUsuario.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              children: [
                _buildMenuCard(
                  icon: Icons.inventory_2_outlined,
                  title: "Inventario",
                  color: azulAcento,
                  onTap: () => _navegarA(
                    PantallaInventario(
                      userRole: rolUsuario,
                      baseUrl: widget.baseUrl,
                    ),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.analytics_outlined,
                  title: "Reportes",
                  color: Colors.orange[800]!,
                  onTap: _mostrarOpcionesReportes,
                ),
                if (puedeGestionarUsuarios)
                  _buildMenuCard(
                    icon: Icons.manage_accounts_outlined,
                    title: "Usuarios",
                    color: Colors.teal,
                    onTap: () => _navegarA(
                      GestionUsuariosScreen(baseUrl: widget.baseUrl),
                    ),
                  ),
                _buildMenuCard(
                  icon: Icons.point_of_sale_rounded,
                  title: "Ventas",
                  color: Colors.grey,
                  isLocked: true,
                  onTap: () => _mostrarMensajeProximamente("Punto de Venta"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
