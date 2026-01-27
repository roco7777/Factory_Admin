import 'package:flutter/material.dart';

class DetalleProductoScreen extends StatelessWidget {
  final dynamic item;
  final String baseUrl;
  final Function(dynamic) onAgregarTap;

  const DetalleProductoScreen({
    super.key,
    required this.item,
    required this.baseUrl,
    required this.onAgregarTap,
  });

  @override
  Widget build(BuildContext context) {
    String productDesc = item['product_desc']?.toString() ?? "";

    double p1 = double.tryParse(item['Precio1']?.toString() ?? '0') ?? 0;
    double p2 = double.tryParse(item['Precio2']?.toString() ?? '0') ?? 0;
    double p3 = double.tryParse(item['Precio3']?.toString() ?? '0') ?? 0;

    int m1 = (double.tryParse(item['Min1']?.toString() ?? '1') ?? 1).toInt();
    int m2 = (double.tryParse(item['Min2']?.toString() ?? '0') ?? 0).toInt();
    int m3 = (double.tryParse(item['Min3']?.toString() ?? '0') ?? 0).toInt();

    int preciosActivos = (p1 > 0 ? 1 : 0) + (p2 > 0 ? 1 : 0) + (p3 > 0 ? 1 : 0);
    String imageUrl = (item['Foto'] != null && item['Foto'] != "")
        ? '$baseUrl/uploads/${item['Foto']}'
        : "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Detalle de Producto"),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN FOTO ESTÁTICA (TOCA PARA ABRIR) ---
            GestureDetector(
              onTap: () {
                if (imageUrl.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageView(
                        imageUrl: imageUrl,
                        clave: item['Clave'],
                      ),
                    ),
                  );
                }
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: double.infinity,
                    height: 380,
                    color: Colors.white,
                    child: imageUrl.isNotEmpty
                        // Usamos Hero para una animación de transición suave
                        ? Hero(
                            tag: 'product_image_${item['Id'] ?? item['Clave']}',
                            child: Image.network(imageUrl, fit: BoxFit.contain),
                          )
                        : const Icon(
                            Icons.image,
                            size: 100,
                            color: Colors.grey,
                          ),
                  ),
                  // Indicador visual de que se puede ampliar
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del Producto (Tamaño 18)
                  Text(
                    item['Descripcion'] ?? "",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  // Clave del Producto
                  const SizedBox(height: 4),
                  Text(
                    "Clave: ${item['Clave'] ?? 'N/A'}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Información Adicional
                  if (productDesc.isNotEmpty && productDesc != "null") ...[
                    const Text(
                      "INFORMACIÓN ADICIONAL",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      productDesc,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(color: Colors.black12),
                  ),

                  // --- SECCIÓN DE PRECIOS ---
                  const Text(
                    "LISTA DE PRECIOS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (preciosActivos == 1)
                    _buildFilaPrecio("Precio:", p1, Colors.red, 22)
                  else ...[
                    if (p1 > 0)
                      _buildFilaPrecio(
                        "A partir de $m1 pzas:",
                        p1,
                        Colors.red,
                        20,
                      ),
                    if (p2 > 0)
                      _buildFilaPrecio(
                        "A partir de $m2 pzas:",
                        p2,
                        Colors.green[700]!,
                        20,
                      ),
                    if (p3 > 0)
                      _buildFilaPrecio(
                        "A partir de $m3 pzas:",
                        p3,
                        Colors.blue[700]!,
                        20,
                      ),
                  ],

                  const SizedBox(height: 30),

                  // --- BOTÓN AGREGAR AL PEDIDO ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onAgregarTap(item);
                      },
                      icon: const Icon(
                        Icons.shopping_cart_checkout,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "AGREGAR AL PEDIDO",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaPrecio(
    String label,
    double price,
    Color color,
    double size,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          Text(
            "\$${price.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// --- NUEVO WIDGET PARA PANTALLA COMPLETA ---
class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String? clave;

  const FullScreenImageView({super.key, required this.imageUrl, this.clave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SizedBox.expand(
        // <-- HACE QUE EL ÁREA DE INTERACCIÓN OCUPE TODA LA PANTALLA
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(0), // Permite libertad total
          child: Hero(
            tag: 'product_image_${clave ?? 'zoom'}',
            child: Image.network(
              imageUrl,
              fit: BoxFit
                  .contain, // Mantiene la proporción pero dentro del área expandida
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    );
  }
}
