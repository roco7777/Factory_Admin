import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'login_screen.dart';

class CarritoScreen extends StatefulWidget {
  final String baseUrl;
  const CarritoScreen({super.key, required this.baseUrl});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  List<dynamic> items = [];
  bool cargando = true;
  String nombreSucursal = "Cargando...";

  @override
  void initState() {
    super.initState();
    _obtenerCarrito();
  }

  Future<void> _obtenerCarrito() async {
    setState(() => cargando = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/api/carrito?ip_add=APP_USER'),
      );
      if (res.statusCode == 200) {
        setState(() {
          items = json.decode(res.body);
          if (items.isNotEmpty) {
            nombreSucursal =
                items[0]['NombreSucursal'] ?? "Sucursal Seleccionada";
          }
        });
      }
    } catch (e) {
      debugPrint("Error obteniendo carrito: $e");
    } finally {
      setState(() => cargando = false);
    }
  }

  Future<void> _actualizarCantidad(dynamic item, int nuevaCantidad) async {
    if (nuevaCantidad < 1) return;

    double p1 =
        double.tryParse(
          item['Precio1']?.toString() ?? item['p_price'].toString(),
        ) ??
        0;
    double p2 = double.tryParse(item['Precio2']?.toString() ?? '0') ?? 0;
    double p3 = double.tryParse(item['Precio3']?.toString() ?? '0') ?? 0;
    int min2 = int.tryParse(item['Min2']?.toString() ?? '0') ?? 0;
    int min3 = int.tryParse(item['Min3']?.toString() ?? '0') ?? 0;

    double nuevoPrecio = p1;
    if (nuevaCantidad >= min3 && min3 > 0) {
      nuevoPrecio = p3;
    } else if (nuevaCantidad >= min2 && min2 > 0) {
      nuevoPrecio = p2;
    }

    try {
      await http.post(
        Uri.parse('${widget.baseUrl}/api/agregar_carrito'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'p_id': item['p_id'],
          'qty': nuevaCantidad,
          'p_price': nuevoPrecio,
          'ip_add': 'APP_USER',
          'num_suc': item['num_suc'],
        }),
      );
      _obtenerCarrito();
    } catch (e) {
      debugPrint("Error al actualizar: $e");
    }
  }

  Future<void> _eliminarItem(dynamic pId) async {
    final res = await http.post(
      Uri.parse('${widget.baseUrl}/api/carrito/eliminar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'p_id': pId, 'ip_add': 'APP_USER'}),
    );
    if (res.statusCode == 200) _obtenerCarrito();
  }

  double _calcularTotal() {
    double total = 0;
    for (var item in items) {
      double precio = double.tryParse(item['p_price'].toString()) ?? 0;
      int cantidad = int.tryParse(item['qty'].toString()) ?? 0;
      total += (precio * cantidad);
    }
    return total;
  }

  // 1. PRIMERO VERIFICAMOS SI ESTÁ LOGUEADO
  Future<void> _verificarLoginYConfirmar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Cambiamos a String porque así lo guardamos en el login nuevo
    String? clienteId = prefs.getString('cliente_id');

    if (clienteId == null) {
      // Si no hay sesión, mandamos a loguearse
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(baseUrl: widget.baseUrl),
        ),
      );
      _obtenerCarrito(); // Refrescamos al volver
    } else {
      // Si ya tiene sesión, preguntamos si está seguro de enviar
      _confirmarEnvioPedido();
    }
  }

  // 2. DIÁLOGO DE SEGURIDAD PARA EVITAR ENVÍOS POR ERROR
  void _confirmarEnvioPedido() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("¿Confirmar Pedido?"),
        content: const Text(
          "Se generará tu cotización y se abrirá WhatsApp para enviarla a Factory Mayoreo.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("REVISAR MÁS"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _finalizarPedido(); // Llamamos a la función real de envío
            },
            child: const Text(
              "SÍ, ENVIAR",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 3. PROCESO FINAL: API + WHATSAPP
  Future<void> _finalizarPedido() async {
    setState(() => cargando = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String clienteId = prefs.getString('cliente_id') ?? "0";
    String nombreCliente = prefs.getString('cliente_nombre') ?? "Cliente";
    int sucId = items.isNotEmpty
        ? int.parse(items[0]['num_suc'].toString())
        : 1;

    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/finalizar_pedido'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ip_add': 'APP_USER',
          'customer_id': clienteId,
          'num_suc': sucId,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        String invoiceNo = data['invoice_no'].toString();

        // CONSTRUIMOS UN MENSAJE DETALLADO PARA WHATSAPP
        String listaProductos = "";
        for (var i in items) {
          listaProductos += "• ${i['qty']} pz - ${i['Descripcion']}\n";
        }

        String mensaje =
            "📦 *NUEVO PEDIDO: #$invoiceNo*\n"
            "👤 *Cliente:* $nombreCliente\n"
            "🏢 *Almacén:* $nombreSucursal\n"
            "----------------------------------\n"
            "$listaProductos"
            "----------------------------------\n"
            "💰 *TOTAL ESTIMADO:* ${formatCurrency(_calcularTotal())}\n\n"
            "Favor de confirmar existencias.";

        // REEMPLAZA CON EL NÚMERO REAL (incluye código de país sin el +)
        await _abrirWhatsApp("521XXXXXXXXXX", mensaje);

        setState(() => items = []);
        _mostrarExito();
      }
    } catch (e) {
      debugPrint("Error al finalizar: $e");
    } finally {
      setState(() => cargando = false);
    }
  }

  Future<void> _abrirWhatsApp(String telefono, String mensaje) async {
    final telLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappUri = Uri.parse(
      "https://wa.me/$telLimpio?text=${Uri.encodeComponent(mensaje)}",
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(whatsappUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint("Error WhatsApp: $e");
    }
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: const Text(
          "¡Pedido procesado!\nSe ha enviado el resumen a la tienda.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Regresar a la tienda
            },
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  Widget _botonCant(IconData icono, VoidCallback accion) {
    return GestureDetector(
      onTap: accion,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icono, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Mi Carrito"),
        backgroundColor: const Color(0xFFD32F2F),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text("Tu carrito está vacío"))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.amber[50],
                  child: Row(
                    children: [
                      const Icon(Icons.store, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Almacén: $nombreSucursal",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      int qty = int.tryParse(item['qty'].toString()) ?? 1;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: Image.network(
                            '${widget.baseUrl}/uploads/${item['Foto']}',
                            width: 50,
                            errorBuilder: (c, e, s) => const Icon(Icons.image),
                          ),
                          title: Text(
                            item['Descripcion'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Unit: ${formatCurrency(item['p_price'])}"),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  _botonCant(
                                    Icons.remove,
                                    () => _actualizarCantidad(item, qty - 1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      "$qty",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _botonCant(
                                    Icons.add,
                                    () => _actualizarCantidad(item, qty + 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _eliminarItem(item['p_id']),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "TOTAL ESTIMADO:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatCurrency(_calcularTotal()),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                          ),
                          onPressed: _verificarLoginYConfirmar,
                          child: const Text(
                            "CONFIRMAR PEDIDO",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
}
