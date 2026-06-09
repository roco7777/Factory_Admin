import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class FichaProductoHelper {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  static Future<XFile?> generarFichaXFile({
    required String clave,
    required String descripcion,
    required String imagenUrl,
    required List<Map<String, dynamic>> precios,
  }) async {
    try {
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

      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      List<Map<String, dynamic>> preciosValidos = precios.where((p) {
        double val = double.tryParse(p['Precio'].toString()) ?? 0;
        return val > 0;
      }).toList();

      final imageBytes = await _screenshotController.captureFromWidget(
        _disenoFichaOptimizada(clave, descripcion, imagenUrl, preciosValidos),
        delay: const Duration(milliseconds: 300),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/ficha_$clave.png',
      ).create();
      await imagePath.writeAsBytes(imageBytes);

      return XFile(imagePath.path);
    } catch (e) {
      debugPrint("Error generando XFile para $clave: $e");
      return null;
    }
  }

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

      XFile? ficha = await generarFichaXFile(
        clave: clave,
        descripcion: descripcion,
        imagenUrl: imagenUrl,
        precios: precios,
      );

      if (Navigator.canPop(context)) Navigator.pop(context);

      if (ficha != null) {
        await Share.shareXFiles([ficha], text: 'Cotización: $clave');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error interno al generar imagen")),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al generar ficha: $e")));
    }
  }

  static Widget _disenoFichaOptimizada(
    String clave,
    String desc,
    String url,
    List<Map<String, dynamic>> precios,
  ) {
    List<Widget> listaPreciosWidgets = [];

    for (int i = 0; i < precios.length; i++) {
      var p = precios[i];
      double precioVal = double.tryParse(p['Precio'].toString()) ?? 0;
      String precioFormat = precioVal.toStringAsFixed(2);
      int minVal = (double.tryParse(p['Minimo'].toString()) ?? 0).toInt();
      double totalGasto = precioVal * minVal;

      String etiquetaNombre = precios.length == 1
          ? "Precio"
          : "Precio ${i + 1}";

      listaPreciosWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 4,
          ), // Un poco más de espacio vertical ya que hay holgura
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiquetaNombre,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  if (precios.length > 1)
                    Text(
                      "Mínimo: $minVal pzas",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "\$$precioFormat",
                    style: const TextStyle(
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      height: 1.0,
                    ),
                  ),
                  if (precios.length > 1) ...[
                    const SizedBox(width: 8),
                    Text(
                      "(\$${totalGasto.toStringAsFixed(0)})",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 450,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. IMAGEN PRINCIPAL
          Container(
            color: Colors.white,
            height: 480,
            child: Image.network(url, fit: BoxFit.contain),
          ),

          // 2. BLOQUE DE IDENTIFICACIÓN (Clave arriba, Descripción abajo)
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clave.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w900,
                    fontSize: 26, // Tamaño ideal y llamativo en su propia fila
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          // 3. LÍNEA ROJA DIVISORIA
          Container(height: 4, color: const Color(0xFFD32F2F)),

          // 4. FOOTER DE PRECIOS (Aprovechando el 100% del ancho de la tarjeta)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: listaPreciosWidgets,
            ),
          ),
        ],
      ),
    );
  }
}
