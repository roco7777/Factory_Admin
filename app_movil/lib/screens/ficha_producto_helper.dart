import 'dart:io';
import 'dart:async'; // Añadido para el manejo de tiempos
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class FichaProductoHelper {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  static Future<void> compartirFicha({
    required BuildContext context,
    required String clave,
    required String descripcion,
    required String imagenUrl,
    required List<Map<String, dynamic>> precios,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. PRE-CARGA DE IMAGEN: Forzamos a Flutter a descargar la imagen antes de seguir
      final ImageProvider imgProvider = NetworkImage(imagenUrl);
      final Completer<void> completer = Completer<void>();
      final ImageStream stream = imgProvider.resolve(
        const ImageConfiguration(),
      );

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (!completer.isCompleted) completer.complete();
          stream.removeListener(listener);
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          if (!completer.isCompleted) completer.complete();
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);

      // Esperamos a que la imagen cargue o que pasen máximo 5 segundos (timeout)
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      // 2. Filtrar precios mayores a 0
      List<Map<String, dynamic>> preciosValidos = precios.where((p) {
        double val = double.tryParse(p['Precio'].toString()) ?? 0;
        return val > 0;
      }).toList();

      // 3. Captura con un pequeño respiro extra para el renderizado
      final imageBytes = await _screenshotController.captureFromWidget(
        _disenoFicha(clave, descripcion, imagenUrl, preciosValidos),
        delay: const Duration(milliseconds: 300),
        context: context,
      );

      if (Navigator.canPop(context)) Navigator.pop(context);

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/ficha_$clave.png',
      ).create();
      await imagePath.writeAsBytes(imageBytes);

      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: 'Producto: $clave');
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al generar ficha: $e")));
    }
  }

  static Widget _disenoFicha(
    String clave,
    String desc,
    String url,
    List<Map<String, dynamic>> precios,
  ) {
    return Container(
      width: 450,
      padding: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.network(url, height: 400, width: 450, fit: BoxFit.contain),
          Container(height: 4, color: const Color(0xFFD32F2F)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clave,
                  style: const TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                Text(
                  desc.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 15),
                const Divider(),
                ...precios
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['Etiqueta'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Mínimo: ${p['Minimo']} pzas",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "\$${p['Precio']}",
                              style: const TextStyle(
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.bold,
                                fontSize: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
