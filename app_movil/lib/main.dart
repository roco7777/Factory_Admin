import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'screens/inventario_screen.dart';
import 'screens/tienda_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MiNegocioApp());
}

class MiNegocioApp extends StatelessWidget {
  const MiNegocioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //showPerformanceOverlay: true, //SIRVE PARA ACTIVAR LAS BARRAS DE RENDIMIENTO EN PANTALLA
      title: 'Factory Mayoreo',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: false,
        primaryColor: const Color(0xFFD32F2F),
      ),
      // El RootHandler es el que decide si mostrar Tienda o Inventario
      home: const RootHandler(),
    );
  }
}

class RootHandler extends StatefulWidget {
  const RootHandler({super.key});

  @override
  State<RootHandler> createState() => _RootHandlerState();
}

class _RootHandlerState extends State<RootHandler> {
  @override
  void initState() {
    super.initState();
    _decidirRuta();
  }

  Future<void> _decidirRuta() async {
    final prefs = await SharedPreferences.getInstance();
    final String? adminUser = prefs.getString('saved_user');
    final String? adminRol = prefs.getString('saved_rol');

    if (!mounted) return;

    // Si ya hay sesión administrativa, vamos al inventario directamente
    if (adminUser != null && adminRol != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PantallaInventario(
            userRole: adminRol,
            baseUrl: AppConfig.baseUrl,
          ),
        ),
      );
    } else {
      // Por defecto siempre la Tienda
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TiendaScreen(baseUrl: AppConfig.baseUrl),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))),
    );
  }
}
