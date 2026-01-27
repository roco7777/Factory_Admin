// lib/screens/confirmacion_pedido_screen.dart
import 'package:flutter/material.dart';
import '../services/tienda_service.dart';

class ConfirmacionPedidoScreen extends StatelessWidget {
  final String baseUrl;
  final VoidCallback onConfirmar;

  const ConfirmacionPedidoScreen({
    super.key,
    required this.baseUrl,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Compromiso de Pedido"),
        backgroundColor: Colors.orange[900],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        // Usamos el 'slug' dinámico para traer el mensaje
        future: TiendaService.fetchMensaje(baseUrl, 'compromiso_pago'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final msg =
              snapshot.data ??
              {
                'encabezado': 'Atención',
                'descripcion': 'Por favor confirme su compromiso de pago.',
              };

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 30),
                Text(
                  msg['encabezado'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  msg['descripcion'],
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Regresamos
                      onConfirmar(); // Ejecutamos el guardado
                    },
                    child: const Text(
                      "ACEPTO, FINALIZAR MI PEDIDO",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
