import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static List<String> _permisos = [];

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
