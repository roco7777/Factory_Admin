import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class DialogoRetiros extends StatelessWidget {
  final String baseUrl;
  final dynamic numSuc;
  final dynamic numCaja;
  final String fIni, fFin;

  const DialogoRetiros({
    super.key,
    required this.baseUrl,
    required this.numSuc,
    required this.numCaja,
    required this.fIni,
    required this.fFin,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Retiros - Suc $numSuc Caja $numCaja"),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<http.Response>(
          future: http.get(
            Uri.parse(
              '$baseUrl/api/reportes/retiros-detalle?numSuc=$numSuc&numCaja=$numCaja&fechaInicio=$fIni&fechaFin=$fFin',
            ),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData && snapshot.data!.statusCode == 200) {
              final decoded = json.decode(snapshot.data!.body);
              if (decoded is List) {
                if (decoded.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Sin retiros hoy."),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: decoded.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final r = decoded[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        "${r['Motivo']} - ${formatCurrency(r['Monto'])}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Vendedor: ${r['NombreVendedor'] ?? 'N/A'}",
                      ),
                    );
                  },
                );
              }
            }
            return const Text("⚠️ No se pudieron cargar los datos.");
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CERRAR"),
        ),
      ],
    );
  }
}
