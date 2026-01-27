import 'package:flutter/material.dart';
import '../core/constants.dart'; // Asegúrate de que aquí esté formatCurrency

class ProductCard extends StatelessWidget {
  final dynamic item;
  final String baseUrl;
  final VoidCallback onTap;
  final VoidCallback onAgregar;

  const ProductCard({
    super.key,
    required this.item,
    required this.baseUrl,
    required this.onTap,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    double p1 = double.tryParse(item['Precio1']?.toString() ?? '0') ?? 0.0;
    double p2 = double.tryParse(item['Precio2']?.toString() ?? '0') ?? 0.0;
    double p3 = double.tryParse(item['Precio3']?.toString() ?? '0') ?? 0.0;
    int m1 = (double.tryParse(item['Min1']?.toString() ?? '1') ?? 1).toInt();
    int m2 = (double.tryParse(item['Min2']?.toString() ?? '0') ?? 0).toInt();
    int m3 = (double.tryParse(item['Min3']?.toString() ?? '0') ?? 0).toInt();

    int preciosActivos = (p1 > 0 ? 1 : 0) + (p2 > 0 ? 1 : 0) + (p3 > 0 ? 1 : 0);

    return Card(
      elevation: 4,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                child:
                    item['Foto'] != null && item['Foto'].toString().isNotEmpty
                    ? Image.network(
                        '$baseUrl/uploads/${item['Foto']}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : const Icon(Icons.image, size: 50),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['Descripcion'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "Cve: ${item['Clave']}",
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const Divider(height: 10),

                // Lógica de colores: Rojo (P1), Verde (P2), Azul (P3)
                if (preciosActivos == 1)
                  _buildFila("Precio:", p1, Colors.red)
                else ...[
                  if (p1 > 0) _buildFila("Min $m1:", p1, Colors.red),
                  if (p2 > 0) _buildFila("Min $m2:", p2, Colors.green),
                  if (p3 > 0) _buildFila("Min $m3:", p3, Colors.blue),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 35,
                  child: ElevatedButton(
                    onPressed: onAgregar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                    ),
                    child: const Text(
                      "AGREGAR",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFila(String label, double price, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        // Usamos la función de formateo de tu constants.dart
        Text(
          "\$${price.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
