import 'package:flutter/material.dart';

// Paleta "Factory Pro Admin"
const Color azulPrimario = Color(0xFF102A43); // Dark Navy (Elegante)
const Color azulAcento = Color(0xFF243B53); // Blue Grey (Serio)
const Color fondoGris = Color(0xFFF0F4F8); // Light Steel (Limpio)
const Color textoPrincipal = Color(0xFF102A43); // Texto oscuro legible
const Color grisBordes = Color(0xFFD9E2EC); // Para separadores
const Color verdeExito = Color(0xFF22543D); // Para dinero/stock positivo

class AppColors {
  // Paleta Profesional
  static const Color primaryBlue = Color(0xFF1A237E); // Azul Navy
  static const Color accentBlue = Color(0xFF0288D1); // Azul interactivo
  static const Color background = Color(0xFFF4F5F7); // Gris muy claro
  static const Color textDark = Color(0xFF263238); // Gris azulado oscuro
  static const Color success = Color(0xFF2E7D32); // Verde para ventas/stock ok
  static const Color warning = Color(0xFFFFA000); // Naranja para alertas
}

class AppConfig {
  static const String baseUrl = "http://100.82.170.128:3000";
  //"https://erma-contributorial-sufferingly.ngrok-free.dev";
}

String formatCurrency(dynamic valor) {
  double monto = double.tryParse(valor.toString()) ?? 0;
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String mathFunc(Match match) => '${match[1]},';
  return "\$${monto.toStringAsFixed(2).replaceAllMapped(reg, mathFunc)}";
}
