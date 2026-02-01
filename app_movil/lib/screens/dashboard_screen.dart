import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'inventario_screen.dart';
import 'admin_login_screen.dart';
import 'reportes_screen.dart'; // El corte en vivo
import 'historico_screen.dart'; // El histórico

class DashboardScreen extends StatefulWidget {
  final String baseUrl;

  const DashboardScreen({super.key, required this.baseUrl});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String nombreUsuario = "Admin";
  String rolUsuario = "";
  final Color rojoFactory = const Color(0xFFD32F2F);

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

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user');
    await prefs.remove('saved_rol');

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

  void _navegarA(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => pantalla));
  }

  // --- NUEVA FUNCIÓN: MENÚ DE REPORTES ---
  void _mostrarOpcionesReportes() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "REPORTES DE CAJA",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.withOpacity(0.1),
                  child: const Icon(Icons.bolt, color: Colors.amber),
                ),
                title: const Text(
                  "Corte en Vivo",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Ventas acumuladas del día de hoy"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _navegarA(PantallaReportes(baseUrl: widget.baseUrl));
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(
                    Icons.history_toggle_off,
                    color: Colors.blue,
                  ),
                ),
                title: const Text(
                  "Histórico de Ventas",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Consultar cierres de días anteriores"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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

  void _mostrarMensajeProximamente(String modulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("El módulo de $modulo estará disponible pronto."),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.grey[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: rojoFactory,
        elevation: 0,
        title: const Text("Panel de Control"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Cerrar Sesión"),
                  content: const Text(
                    "¿Deseas salir del sistema administrativo?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("NO"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cerrarSesion();
                      },
                      child: const Text(
                        "SÍ, SALIR",
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER DE BIENVENIDA ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: rojoFactory.withOpacity(0.1),
                    radius: 25,
                    child: Icon(
                      Icons.shield_rounded,
                      size: 30,
                      color: rojoFactory,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sesión Administrativa",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        nombreUsuario.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        "Nivel: $rolUsuario",
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "GESTIÓN OPERATIVA",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black54,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 15),

            // --- GRID DE MENÚ ---
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.1,
                children: [
                  // 1. INVENTARIO
                  _buildMenuCard(
                    icon: Icons.inventory_2_rounded,
                    title: "Inventario",
                    color: Colors.blue,
                    onTap: () => _navegarA(
                      PantallaInventario(
                        userRole: rolUsuario,
                        baseUrl: widget.baseUrl,
                      ),
                    ),
                  ),

                  // 2. REPORTE DE CAJAS (NUEVO & HABILITADO)
                  _buildMenuCard(
                    icon: Icons.analytics_rounded,
                    title: "Reportes de Caja",
                    color: Colors.orange,
                    onTap: _mostrarOpcionesReportes,
                  ),

                  // 3. PUNTO DE VENTA (PRÓXIMAMENTE)
                  _buildMenuCard(
                    icon: Icons.point_of_sale_rounded,
                    title: "Punto de Venta",
                    color: Colors.green,
                    isLocked: true,
                    onTap: () => _mostrarMensajeProximamente("Punto de Venta"),
                  ),

                  // 4. CLIENTES / MAYORISTAS (PRÓXIMAMENTE)
                  _buildMenuCard(
                    icon: Icons.assignment_ind_rounded,
                    title: "Clientes",
                    color: Colors.purple,
                    isLocked: true,
                    onTap: () =>
                        _mostrarMensajeProximamente("Gestión de Clientes"),
                  ),

                  // 5. CONFIGURACIÓN (PRÓXIMAMENTE)
                  _buildMenuCard(
                    icon: Icons.settings_suggest_rounded,
                    title: "Ajustes",
                    color: Colors.blueGrey,
                    isLocked: true,
                    onTap: () =>
                        _mostrarMensajeProximamente("Ajustes del Sistema"),
                  ),

                  // 6. USUARIOS (PRÓXIMAMENTE)
                  _buildMenuCard(
                    icon: Icons.manage_accounts_rounded,
                    title: "Usuarios",
                    color: Colors.indigo,
                    isLocked: true,
                    onTap: () =>
                        _mostrarMensajeProximamente("Seguridad y Usuarios"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey[200]
                          : color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 35,
                      color: isLocked ? Colors.grey : color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isLocked ? Colors.grey : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (isLocked)
              Positioned(
                right: 12,
                top: 12,
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
