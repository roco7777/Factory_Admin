import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'screens/inventario_screen.dart';
import 'screens/admin_login_screen.dart'; // <--- CORREGIDO: Importamos el login correcto
import 'package:factory_admin/services/tienda_service.dart';
import 'screens/dashboard_screen.dart';
import '../core/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  await SecurityService.cargarPermisos();

  String? savedUrl = prefs.getString('custom_api_url');
  String finalUrl = savedUrl ?? AppConfig.baseUrl;

  runApp(MiNegocioApp(baseUrl: finalUrl));
}

class MiNegocioApp extends StatelessWidget {
  final String baseUrl;

  const MiNegocioApp({super.key, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Factory POS Admin',
      // En MiNegocioApp dentro de main.dart
      theme: ThemeData(
        primaryColor: AppColors.primaryBlue,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textDark),
        ),
        useMaterial3: true, // Esto le dará un look mucho más moderno
      ),
      home: RootHandler(baseUrl: baseUrl),
    );
  }
}

class RootHandler extends StatefulWidget {
  final String baseUrl;
  const RootHandler({super.key, required this.baseUrl});

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

    // 1. Lógica de URL Dinámica
    String? urlNueva = await TiendaService.obtenerUrlRemota(widget.baseUrl);
    String urlFinal = widget.baseUrl;

    if (urlNueva != null && urlNueva != widget.baseUrl) {
      await prefs.setString('custom_api_url', urlNueva);
      urlFinal = urlNueva;
    }

    final String? adminUser = prefs.getString('saved_user');
    final String? adminRol = prefs.getString('saved_rol');

    if (!mounted) return;

    // 2. Lógica de Ruteo
    if (adminUser != null && adminRol != null) {
      // Si ya tiene sesión --> Va al Inventario/Panel
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(baseUrl: urlFinal),
          //PantallaInventario(userRole: adminRol, baseUrl: urlFinal),
        ),
      );
    } else {
      // Si NO tiene sesión --> Va al Login de ADMINISTRADOR
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AdminLoginScreen(baseUrl: urlFinal), // <--- USO CORRECTO
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
