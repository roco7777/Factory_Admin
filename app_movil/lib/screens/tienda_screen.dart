import 'package:flutter/material.dart';
import 'dart:convert'; // Solo se queda para manejar respuestas de error específicas
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'carrito_screen.dart';
import 'inventario_screen.dart';
import 'login_screen.dart';
import 'admin_login_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'detalle_producto_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/tienda_modals.dart';
import '../services/tienda_service.dart'; // NUEVO IMPORT

class TiendaScreen extends StatefulWidget {
  final String baseUrl;
  const TiendaScreen({super.key, required this.baseUrl});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  final int sessionSeed = DateTime.now().millisecondsSinceEpoch;
  List<dynamic> productos = [];
  List<dynamic> categorias = [];
  List<dynamic> sucursales = [];
  dynamic sucursalActual;
  String? nombreCliente;
  String? rolAdmin;

  String nombreSucursal = "Sucursal";
  String categoriaSeleccionada = "TODOS";
  bool cargando = false;
  int totalItemsCarrito = 0;
  int sucursalSeleccionada = 1;

  final ScrollController _scrollController = ScrollController();
  int _paginaActual = 0;
  bool _cargandoMas = false;
  bool _hayMasProductos = true;

  final TextEditingController buscadorCtrl = TextEditingController();
  final Color rojoFactory = const Color(0xFFD32F2F);
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _cargarSesion();
    _cargarSucursales();
    _actualizarContadorCarrito();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        if (!_cargandoMas && _hayMasProductos && !cargando) {
          _cargarMasProductos();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    buscadorCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE DATOS Y SESIÓN ---

  Future<void> _cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      String nombreCompleto = prefs.getString('cliente_nombre') ?? "Invitado";
      nombreCliente = nombreCompleto.split(' ')[0];
      rolAdmin = prefs.getString('saved_rol');
    });
  }

  Future<void> _cargarDatosIniciales() async {
    if (cargando || !mounted) return;
    setState(() => cargando = true);

    try {
      // Cargamos categorías si están vacías usando el Service
      if (categorias.isEmpty) {
        categorias = await TiendaService.fetchCategorias(widget.baseUrl);
      }

      String busqueda = categoriaSeleccionada == "TODOS"
          ? ""
          : categoriaSeleccionada;

      // Llamada al Service
      final data = await TiendaService.fetchInventario(
        baseUrl: widget.baseUrl,
        query: busqueda,
        page: 0,
        idSuc: sucursalSeleccionada,
        seed: sessionSeed,
      );

      setState(() {
        productos = data;
        _paginaActual = 0;
        _hayMasProductos = data.length >= 10;
      });

      for (var prod in data) {
        if (prod['Foto'] != null && prod['Foto'] != "" && mounted) {
          precacheImage(
            NetworkImage('${widget.baseUrl}/uploads/${prod['Foto']}'),
            context,
          );
        }
      }
    } catch (e) {
      debugPrint("Error cargando datos: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _cargarSucursales() async {
    try {
      final data = await TiendaService.fetchSucursales(widget.baseUrl);
      final prefs = await SharedPreferences.getInstance();
      int? savedId = prefs.getInt('saved_sucursal_id');
      String? savedNombre = prefs.getString('saved_sucursal_nombre');

      setState(() {
        sucursales = data;
        if (sucursales.isNotEmpty) {
          if (savedId != null) {
            sucursalActual = sucursales.firstWhere(
              (s) =>
                  (s['ID'] ?? s['id'] ?? s['Id']).toString() ==
                  savedId.toString(),
              orElse: () => sucursales[0],
            );
            sucursalSeleccionada = savedId;
            nombreSucursal = savedNombre ?? "Sucursal";
          } else {
            sucursalActual = sucursales[0];
            var rawId =
                sucursalActual['ID'] ??
                sucursalActual['id'] ??
                sucursalActual['Id'];
            sucursalSeleccionada = int.tryParse(rawId.toString()) ?? 1;
            nombreSucursal = sucursalActual['sucursal'] ?? "Sucursal";
          }
        }
      });
      _cargarDatosIniciales();
    } catch (e) {
      debugPrint("Error sucursales: $e");
    }
  }

  // --- MÉTODOS DE MODALES Y NAVEGACIÓN ---

  void _mostrarSelectorCantidad(dynamic item) {
    TiendaModals.mostrarSelectorCantidad(
      context: context,
      item: item,
      rojoFactory: rojoFactory,
      formatCurrency: (val) => formatCurrency(val),
      onAgregar: (qty, price) {
        _guardarEnCarrito(item['Id'], qty, price);
      },
    );
  }

  void _mostrarModalSucursales() {
    TiendaModals.mostrarModalSucursales(
      context: context,
      sucursales: sucursales,
      onSucursalClick: (suc) {
        if (mounted) Navigator.pop(context);
        _mostrarInfoSucursal(suc);
      },
    );
  }

  void _mostrarFichaProducto(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleProductoScreen(
          item: item,
          baseUrl: widget.baseUrl,
          onAgregarTap: (prod) => _mostrarSelectorCantidad(prod),
        ),
      ),
    );
  }

  // --- LÓGICA DE CARRITO Y ALERTAS ---

  Future<void> _guardarEnCarrito(dynamic pId, String qty, double price) async {
    try {
      final res = await TiendaService.agregarAlCarrito(
        baseUrl: widget.baseUrl,
        pId: pId,
        qty: qty,
        price: price,
        idSuc: sucursalSeleccionada,
      );

      if (res.statusCode == 200 && mounted) {
        _actualizarContadorCarrito();

        // --- NUEVO AVISO VISUAL PERSONALIZADO ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Expanded(
                  child: Text(
                    "El producto se agrego a tu carrito.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.blue), // Palomita azul
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior
                .floating, // Para que no lo tape la barra de Android
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else if (mounted) {
        final errorData = json.decode(res.body);
        if (errorData['error'] == "DIFERENTE_SUCURSAL") {
          _mostrarAlertaVaciarCarrito();
        } else {
          _mostrarAlerta(errorData['message'] ?? "Sin stock");
        }
      }
    } catch (e) {
      debugPrint("Error en carrito: $e");
    }
  }

  void _mostrarAlerta(String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Atención"),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ACEPTAR"),
          ),
        ],
      ),
    );
  }

  void _mostrarAlertaVaciarCarrito() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Carrito con otra sucursal"),
        content: const Text(
          "Tu carrito contiene productos de otro almacén. ¿Deseas vaciarlo?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await TiendaService.vaciarCarrito(widget.baseUrl);
              if (mounted) {
                Navigator.pop(context);
                _actualizarContadorCarrito();
              }
            },
            child: const Text("VACIAR Y CONTINUAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarContadorCarrito() async {
    try {
      int nuevoTotal = await TiendaService.getCarritoCount(widget.baseUrl);
      if (nuevoTotal != totalItemsCarrito && mounted) {
        setState(() => totalItemsCarrito = nuevoTotal);
      }
    } catch (e) {
      debugPrint("Error contador: $e");
    }
  }

  Future<void> _reproducirBip() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint("Error sonido: $e");
    }
  }

  // --- OTROS MÉTODOS DE APOYO ---

  void _mostrarInfoSucursal(dynamic suc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.local_shipping, color: rojoFactory),
            const SizedBox(width: 10),
            Expanded(child: Text(suc['sucursal'] ?? 'Información de Envío')),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            suc['InfoEnvio'] ?? "No hay descripción disponible.",
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CERRAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: rojoFactory),
            onPressed: () {
              Navigator.pop(context);
              _cambiarSucursal(suc);
            },
            child: const Text(
              "SELECCIONAR ALMACÉN",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _cambiarSucursal(dynamic suc) async {
    final prefs = await SharedPreferences.getInstance();
    var rawId = suc['ID'] ?? suc['id'] ?? suc['Id'];
    int id = int.tryParse(rawId.toString()) ?? 1;
    String nombre = suc['sucursal'] ?? "Sucursal";
    await prefs.setInt('saved_sucursal_id', id);
    await prefs.setString('saved_sucursal_nombre', nombre);

    if (mounted) {
      setState(() {
        sucursalActual = suc;
        sucursalSeleccionada = id;
        nombreSucursal = nombre;
        productos = [];
        _paginaActual = 0;
      });
      _cargarDatosIniciales();
    }
  }

  Future<void> buscarProductos(String query) async {
    if (!mounted) return;
    setState(() {
      cargando = true;
      _paginaActual = 0;
      productos = [];
    });
    try {
      final data = await TiendaService.fetchInventario(
        baseUrl: widget.baseUrl,
        query: query,
        page: 0,
        idSuc: sucursalSeleccionada,
        seed: sessionSeed,
      );
      if (mounted) {
        setState(() {
          productos = data;
          _hayMasProductos = data.length >= 10;
        });
        if (data.isNotEmpty) buscadorCtrl.clear();
      }
    } catch (e) {
      debugPrint("Error búsqueda: $e");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _cargarMasProductos() async {
    if (_cargandoMas || !_hayMasProductos || !mounted) return;
    setState(() => _cargandoMas = true);
    _paginaActual++;
    try {
      String busqueda = categoriaSeleccionada == "TODOS"
          ? ""
          : categoriaSeleccionada;
      final nuevos = await TiendaService.fetchInventario(
        baseUrl: widget.baseUrl,
        query: busqueda,
        page: _paginaActual,
        idSuc: sucursalSeleccionada,
        seed: sessionSeed,
      );
      if (mounted) {
        setState(() {
          _hayMasProductos = nuevos.length >= 10;
          productos.addAll(nuevos);
        });
      }
    } catch (e) {
      _paginaActual--;
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _mostrarDialogoCerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: Text("¿$nombreCliente, seguro que deseas salir de tu cuenta?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("NO"),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('cliente_id');
              await prefs.remove('cliente_nombre');
              if (mounted) {
                Navigator.pop(context);
                setState(() => nombreCliente = "Invitado");
                _cargarSesion();
              }
            },
            child: const Text(
              "CERRAR SESIÓN",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // El drawer se mantiene igual
      drawer: rolAdmin != null
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: rojoFactory),
                    child: const Text(
                      "Opciones de Admin",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory),
                    title: const Text("Panel de Inventario"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaInventario(
                            userRole: rolAdmin!,
                            baseUrl: widget.baseUrl,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: rojoFactory,
        foregroundColor: Colors.white,
        title: GestureDetector(
          onLongPress: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminLoginScreen(baseUrl: widget.baseUrl),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Factory Mayoreo",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              Row(
                children: [
                  const Icon(Icons.storefront, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    nombreSucursal,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
              Text(
                (nombreCliente == null || nombreCliente == "Invitado")
                    ? "Hola invitado"
                    : "Hola, $nombreCliente",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          _buildBotonCarrito(),
          if (sucursales.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.location_on, size: 22),
              onPressed: _mostrarModalSucursales,
            ),
          _buildBotonLoginOut(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(95),
          child: _buildBuscadorYCategorias(),
        ),
      ),
      // --- AQUÍ APLICAMOS EL CAMBIO PARA HACERLA UNIVERSAL ---
      body: SafeArea(
        bottom: true, // Protege contra la barra de navegación de Android
        top: false, // El AppBar ya se encarga de la parte de arriba
        child: Column(
          children: [
            Expanded(
              child: cargando && productos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : productos.isEmpty
                  ? const Center(child: Text("Sin stock en este almacén"))
                  : GridView.builder(
                      controller: _scrollController,
                      // Añadimos un poco más de padding al fondo para asegurar que el último botón respire
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        top: 8,
                        bottom: 20,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.55,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: productos.length,
                      itemBuilder: (context, index) {
                        final item = productos[index];
                        return ProductCard(
                          item: item,
                          baseUrl: widget.baseUrl,
                          onTap: () => _mostrarFichaProducto(item),
                          onAgregar: () => _mostrarSelectorCantidad(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  // --- WIDGETS DE APOYO DE UI ---

  Widget _buildBuscadorYCategorias() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: buscadorCtrl,
              textAlignVertical: TextAlignVertical
                  .center, // <-- ESTO CENTRA EL TEXTO VERTICALMENTE
              decoration: InputDecoration(
                hintText: "Buscar productos...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                fillColor: Colors.white,
                filled: true,
                // Ajustamos el padding interno para que no empuje el texto
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) => buscarProductos(val),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCatItem("TODOS"),
              ...categorias.map((c) => _buildCatItem(c['Descripcion'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatItem(String nombre) {
    bool seleccionada = categoriaSeleccionada == nombre;
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() => categoriaSeleccionada = nombre);
          buscarProductos(nombre == "TODOS" ? "" : nombre);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: seleccionada ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            nombre,
            style: TextStyle(
              color: seleccionada ? rojoFactory : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonCarrito() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CarritoScreen(baseUrl: widget.baseUrl),
              ),
            ).then((_) {
              if (mounted) _actualizarContadorCarrito();
            });
          },
        ),
        if (totalItemsCarrito > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '$totalItemsCarrito',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBotonLoginOut() {
    return IconButton(
      icon: Icon(
        nombreCliente == "Invitado"
            ? Icons.account_circle_outlined
            : Icons.exit_to_app,
        size: 26,
      ),
      onPressed: () {
        if (nombreCliente == "Invitado") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(baseUrl: widget.baseUrl),
            ),
          ).then((_) {
            if (mounted) _cargarSesion();
          });
        } else {
          _mostrarDialogoCerrarSesion();
        }
      },
    );
  }
}
