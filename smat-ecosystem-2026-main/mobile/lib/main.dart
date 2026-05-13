import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'models/estacion.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'services/auth_service.dart';

void main() => runApp(const SMATApp());

class SMATApp extends StatelessWidget {
  const SMATApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SMAT Mobile',
      // El home ahora depende de la verificación del token
      home: FutureBuilder(
        future: AuthService().getToken(),
        builder: (context, snapshot) {
          // Mientras verifica, muestra un indicador de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Si el token existe, va al Home, si no, al Login
          if (snapshot.hasData && snapshot.data != null) {
            return const HomePage();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Estacion>> futureEstaciones;

  @override
  void initState() {
    super.initState();
    futureEstaciones = ApiService().fetchEstaciones();
  }

  void _mostrarDialogoEdicion(Estacion estacion) {
    final nombreCtrl = TextEditingController(text: estacion.nombre);
    final ubicacionCtrl = TextEditingController(text: estacion.ubicacion);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Estación"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: ubicacionCtrl, decoration: const InputDecoration(labelText: "Ubicación")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),

          ElevatedButton(
            onPressed: () async {
              bool ok = await ApiService().editarEstacion(estacion.id, nombreCtrl.text, ubicacionCtrl.text);

              if (ok) {
                Navigator.pop(context);

                setState(() {
                  futureEstaciones = ApiService().fetchEstaciones();
                });
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMAT - Monitoreo Móvil')),

      body: FutureBuilder<List<Estacion>>(
        future: futureEstaciones,

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('❌ Error de conexión'));
          } else {
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  // Volvemos a disparar el Future para traer datos frescos
                  futureEstaciones = ApiService().fetchEstaciones();
                });
              },

              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,

                itemBuilder: (context, index) {
                  final estacion = snapshot.data![index];

                  return Dismissible(
                    key: Key(estacion.id.toString()),
                    direction: DismissDirection.endToStart,

                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),

                    onDismissed: (direction) async {
                      bool ok = await ApiService().eliminarEstacion(estacion.id);

                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${estacion.nombre} eliminada")),
                        );

                        setState(() {
                          futureEstaciones = ApiService().fetchEstaciones();
                        });
                      }
                    },

                    child: ListTile(
                      leading: Icon(
                        Icons.satellite_alt,
                        color: Colors.green,
                      ),

                      title: Text(estacion.nombre),

                      subtitle: Text(estacion.ubicacion),

                      onTap: () => _mostrarDialogoEdicion(estacion),
                    ),
                  );
                },
              ),
            );
          }
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => futureEstaciones = ApiService().fetchEstaciones()),
        tooltip: 'Actualizar datos',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}