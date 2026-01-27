import 'package:flutter/material.dart';

class TiendaModals {
  // 1. Selector de Cantidad (CUADRÍCULA, MÚLTIPLOS Y VALIDACIÓN DE STOCK)
  static void mostrarSelectorCantidad({
    required BuildContext context,
    required dynamic item,
    required Color rojoFactory,
    required Function(String, double) onAgregar,
    required String Function(dynamic) formatCurrency,
  }) {
    // 1. EXTRACCIÓN DE DATOS SEGURA (Basada en tu JSON del HP ProLiant)
    int multiplo = (double.tryParse(item['Min1']?.toString() ?? '1') ?? 1)
        .toInt();
    if (multiplo <= 1) multiplo = 1;

    // Buscamos 'stock_disponible' (Carrito) o 'Stock' (Tienda)
    var rawStock = item['stock_disponible'] ?? item['Stock'] ?? '0';
    int stock = (double.tryParse(rawStock.toString()) ?? 0).toInt();

    double p1 = double.tryParse(item['Precio1']?.toString() ?? '0') ?? 0.0;
    double p2 = double.tryParse(item['Precio2']?.toString() ?? '0') ?? 0.0;
    double p3 = double.tryParse(item['Precio3']?.toString() ?? '0') ?? 0.0;
    int min2 = (double.tryParse(item['Min2']?.toString() ?? '0') ?? 0).toInt();
    int min3 = (double.tryParse(item['Min3']?.toString() ?? '0') ?? 0).toInt();

    double obtenerPrecioEscala(int cant) {
      if (p3 > 0 && min3 > 0 && cant >= min3) return p3;
      if (p2 > 0 && min2 > 0 && cant >= min2) return p2;
      return p1;
    }

    final List<int> opciones = List.generate(
      7,
      (index) => multiplo * (index + 1),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['Descripcion'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  stock > 0
                      ? "Nuevo stock disponible: $stock"
                      : "PRODUCTO AGOTADO",
                  style: TextStyle(
                    fontSize: 12,
                    color: stock > 0 ? Colors.blueGrey : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.4,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ...opciones.map((cant) {
                      // --- AQUÍ ESTÁ LA LÓGICA DE DESHABILITADO ---
                      bool habilitado = cant <= stock;
                      return _buildBotonGrid(
                        label: cant.toString(),
                        habilitado: habilitado,
                        onTap: habilitado
                            ? () {
                                Navigator.pop(context);
                                onAgregar(
                                  cant.toString(),
                                  obtenerPrecioEscala(cant),
                                );
                              }
                            : null, // Si no hay stock, el botón no hace nada
                      );
                    }),
                    _buildBotonGrid(
                      label: "Otra...",
                      isSpecial: true,
                      habilitado: stock > 0,
                      onTap: stock > 0
                          ? () {
                              Navigator.pop(context);
                              _mostrarDialogoManual(
                                context,
                                item,
                                multiplo,
                                stock,
                                obtenerPrecioEscala,
                                onAgregar,
                                rojoFactory,
                              );
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- FUNCIÓN PARA EL DIÁLOGO MANUAL ---
  static void _mostrarDialogoManual(
    BuildContext context,
    dynamic item,
    int multiplo,
    int stock,
    double Function(int) calcPrecio,
    Function(String, double) onAgregar,
    Color rojoFactory,
  ) {
    TextEditingController ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Cantidad Manual"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Stock disponible: $stock",
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Ej: 12",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: rojoFactory),
            onPressed: () {
              int? cant = int.tryParse(ctrl.text);
              if (cant == null || cant <= 0) return;

              // Validación de Múltiplo
              if (cant % multiplo != 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "❌ La cantidad debe ser múltiplo de $multiplo",
                    ),
                  ),
                );
                return;
              }

              // --- VALIDACIÓN DE STOCK ---
              if (cant > stock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("❌ No puedes agregar más de $stock unidades"),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              onAgregar(cant.toString(), calcPrecio(cant));
            },
            child: const Text("AGREGAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- WIDGET AUXILIAR PARA LOS BOTONES (ÚNICA VERSIÓN) ---
  // BOTÓN CON ESTADO DESHABILITADO (Opacidad 0.3)
  static Widget _buildBotonGrid({
    required String label,
    required VoidCallback? onTap,
    bool isSpecial = false,
    bool habilitado = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: habilitado ? 1.0 : 0.3,
        child: Container(
          decoration: BoxDecoration(
            color: !habilitado
                ? Colors.grey[200]
                : (isSpecial ? const Color(0xFFFDECEA) : Colors.grey[100]),
            border: Border.all(
              color: !habilitado
                  ? Colors.grey[300]!
                  : (isSpecial ? Colors.red[800]! : Colors.grey[300]!),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSpecial ? 12 : 14,
                color: !habilitado
                    ? Colors.grey
                    : (isSpecial ? Colors.red[800] : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 2. Modal de Selección de Almacén
  static void mostrarModalSucursales({
    required BuildContext context,
    required List<dynamic> sucursales,
    required Function(dynamic) onSucursalClick,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Selecciona un Almacén",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sucursales.length,
                  itemBuilder: (context, i) {
                    final suc = sucursales[i];
                    return ListTile(
                      leading: const Icon(
                        Icons.store,
                        color: Color(0xFFD32F2F),
                      ),
                      title: Text(
                        suc['sucursal'] ?? 'Sucursal',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => onSucursalClick(suc),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
