import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static List<String> _permisos = [];

  // NUEVA FUNCIÓN: Guarda los permisos en disco y en memoria RAM al hacer login
  static Future<void> setPermisos(List<String> nuevosPermisos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_permissions', nuevosPermisos);
    _permisos = nuevosPermisos;
  }

  // Carga los permisos desde el almacenamiento local
  static Future<void> cargarPermisos() async {
    final prefs = await SharedPreferences.getInstance();
    _permisos = prefs.getStringList('user_permissions') ?? [];
  }

  // Verifica si el usuario tiene el permiso
  static bool tienePermiso(String slug) {
    return _permisos.contains(slug);
  }

  static void limpiarPermisos() {
    _permisos = [];
  }
}
