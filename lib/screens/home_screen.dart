import 'package:flutter/material.dart';
import 'formulario_screen.dart';
import 'historial_screen.dart';

/// Pantalla raíz post-login.
/// Contiene un BottomNavigationBar con dos pestañas:
///   0 → Nuevo reporte (FormularioScreen)
///   1 → Historial    (HistorialScreen)
class HomeScreen extends StatefulWidget {
  final String matricula;
  final String nombreTecnico;

  const HomeScreen({
    super.key,
    required this.matricula,
    required this.nombreTecnico,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabActual = 0;

  static const _verde = Color(0xFF1a6e2e);

  // Las pestañas se mantienen vivas con IndexedStack para que el formulario
  // no se resetee al cambiar a Historial y volver.
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      FormularioScreen(
        matricula:     widget.matricula,
        nombreTecnico: widget.nombreTecnico,
      ),
      const HistorialScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabActual,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabActual,
        onDestinationSelected: (i) => setState(() => _tabActual = i),
        backgroundColor: Colors.white,
        indicatorColor: _verde.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon:          Icon(Icons.add_circle_outline),
            selectedIcon:  Icon(Icons.add_circle, color: _verde),
            label:         'Nuevo reporte',
          ),
          NavigationDestination(
            icon:          Icon(Icons.history_outlined),
            selectedIcon:  Icon(Icons.history, color: _verde),
            label:         'Historial',
          ),
        ],
      ),
    );
  }
}