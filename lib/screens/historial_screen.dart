import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/reporte.dart';
import '../services/sync_service.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _db = DatabaseHelper();
  final _sync = SyncService();
  List<Reporte> _reportes = [];
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await _db.obtenerTodos();
    setState(() => _reportes = lista);
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    final resultado = await _sync.sincronizar();
    await _cargar();
    setState(() => _sincronizando = false);

    if (!mounted) return;

    final enviados = resultado['enviados'] ?? 0;
    final fallidos = resultado['fallidos'] ?? 0;
    final sinConexion = resultado.containsKey('sinConexion');

    String mensaje;
    Color color;

    if (sinConexion) {
      mensaje = 'Sin conexión, intenta más tarde';
      color = Colors.orange;
    } else if (enviados > 0) {
      mensaje = '$enviados reporte(s) enviado(s) correctamente';
      color = Colors.green;
    } else if (fallidos > 0) {
      mensaje = 'No se pudo enviar $fallidos reporte(s)';
      color = Colors.red;
    } else {
      mensaje = 'No hay reportes pendientes';
      color = Colors.blue;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _reportes.where((r) => r.estado == 'pendiente').length;
    final enviados = _reportes.where((r) => r.estado == 'enviado').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Reportes'),
        backgroundColor: const Color(0xFF1a6e2e),
        foregroundColor: Colors.white,
        actions: [
          // Botón sincronizar manual
          IconButton(
            onPressed: _sincronizando ? null : _sincronizar,
            icon: _sincronizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sincronizar ahora',
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen arriba
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFe8f5e9),
            child: Row(
              children: [
                Expanded(
                  child: _tarjetaResumen(
                    cantidad: pendientes,
                    label: 'Pendientes',
                    color: Colors.orange,
                    icono: Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tarjetaResumen(
                    cantidad: enviados,
                    label: 'Enviados',
                    color: const Color(0xFF1a6e2e),
                    icono: Icons.check_circle,
                  ),
                ),
              ],
            ),
          ),

          // Lista de reportes
          Expanded(
            child: _reportes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No hay reportes guardados',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _reportes.length,
                      itemBuilder: (context, index) {
                        final r = _reportes[index];
                        return _tarjetaReporte(r);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen({
    required int cantidad,
    required String label,
    required Color color,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$cantidad',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaReporte(Reporte r) {
    final enviado = r.estado == 'enviado';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: enviado
              ? const Color(0xFF1a6e2e)
              : Colors.orange,
          child: Icon(
            enviado ? Icons.cloud_done : Icons.schedule,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          r.nserie.isNotEmpty ? r.nserie : 'Sin número de serie',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              r.falla,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  r.nombreReportador,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const Spacer(),
                Text(
                  r.fechaCreacion.substring(0, 16).replaceAll('T', ' '),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            if (enviado && r.nRastreo != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFe8f5e9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Folio: ${r.nRastreo}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1a6e2e),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}