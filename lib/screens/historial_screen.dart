import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/reporte.dart';
import '../services/sync_service.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  final _sync = SyncService();

  List<Reporte> _reportes = [];
  bool _sincronizando = false;

  late final AnimationController _spinCtrl;

  // ── Paleta (tomada del mockup) ──────────────────────────────────────────
  static const _primary          = Color(0xFF00450D);
  static const _onPrimary        = Color(0xFFFFFFFF);
  static const _background       = Color(0xFFFBF9F9);
  static const _surfaceLowest    = Color(0xFFFFFFFF);
  static const _outlineVariant   = Color(0xFFC0C9BB);
  static const _onSurface        = Color(0xFF1B1C1C);
  static const _onSurfaceVariant = Color(0xFF41493E);
  static const _naranja          = Color(0xFFF57C00);
  static const _naranjaBg        = Color(0xFFFFF3E0);
  static const _verde            = Color(0xFF2E7D32);
  static const _verdeBg          = Color(0xFFE8F5E9);
  static const _rojo             = Color(0xFFBA1A1A);
  static const _rojoBg           = Color(0xFFFFDAD6);

  static const _sombraCard = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cargar();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final lista = await _db.obtenerTodos();
    if (!mounted) return;
    setState(() => _reportes = lista);
  }

  Future<void> _sincronizar() async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);
    _spinCtrl.repeat();

    final resultado = await _sync.sincronizar();
    await _cargar();

    if (!mounted) return;
    _spinCtrl.stop();
    _spinCtrl.value = 0;
    setState(() => _sincronizando = false);

    final enviados = resultado['enviados'] ?? 0;
    final fallidos = resultado['fallidos'] ?? 0;
    final sinConexion = resultado.containsKey('sinConexion');

    String mensaje;
    Color color;

    if (sinConexion) {
      mensaje = 'Sin conexión, intenta más tarde';
      color = _naranja;
    } else if (enviados > 0) {
      mensaje = '$enviados reporte(s) enviado(s) correctamente';
      color = _verde;
    } else if (fallidos > 0) {
      mensaje = 'No se pudo enviar $fallidos reporte(s)';
      color = _rojo;
    } else {
      mensaje = 'No hay reportes pendientes';
      color = Colors.blueGrey;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pendientes = _reportes.where((r) => r.estado == 'pendiente').length;
    final enviados = _reportes.where((r) => r.estado == 'enviado').length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        elevation: 0,
        title: const Text(
          'Historial de Reportes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          RotationTransition(
            turns: _spinCtrl,
            child: IconButton(
              onPressed: _sincronizando ? null : _sincronizar,
              icon: const Icon(Icons.refresh),
              tooltip: 'Sincronizar ahora',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: _primary,
        child: CustomScrollView(
          slivers: [
            // ── Resumen ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _tarjetaResumen(
                        cantidad: pendientes,
                        label: 'PENDIENTES',
                        color: _naranja,
                        icono: Icons.schedule,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _tarjetaResumen(
                        cantidad: enviados,
                        label: 'ENVIADOS',
                        color: _verde,
                        icono: Icons.check_circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Lista / estado vacío ─────────────────────────────────────
            if (_reportes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _estadoVacio(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _tarjetaReporte(_reportes[index]),
                    ),
                    childCount: _reportes.length,
                  ),
                ),
              ),

            if (_reportes.isNotEmpty)
              SliverToBoxAdapter(child: _finDeHistorial()),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ────────────────────────────────────────────────────────────

  Widget _tarjetaResumen({
    required int cantidad,
    required String label,
    required Color color,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outlineVariant),
        boxShadow: _sombraCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icono, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                '$cantidad',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: _onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaReporte(Reporte r) {
    final estilo = _estiloEstado(r.estado);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outlineVariant),
        boxShadow: _sombraCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar de estado
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: estilo.bg, shape: BoxShape.circle),
            child: Icon(estilo.icono, color: estilo.color, size: 26),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título (n° de serie) + fecha
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (r.nserie.isNotEmpty ? r.nserie : 'SIN N° DE SERIE')
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatoFecha(r.fechaCreacion),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Descripción de la falla
                Text(
                  r.falla.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: _onSurfaceVariant),
                ),

                // Separador + reportador (+ folio si fue enviado)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _outlineVariant.withOpacity(0.4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: _onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.nombreReportador.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            color: _onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (r.estado == 'enviado' && r.nRastreo != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _verdeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Folio: ${r.nRastreo}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _verde,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _EstiloEstado _estiloEstado(String estado) {
    switch (estado) {
      case 'enviado':
        return const _EstiloEstado(
          icono: Icons.check_circle,
          color: _verde,
          bg: _verdeBg,
        );
      case 'error_datos':
        return const _EstiloEstado(
          icono: Icons.error,
          color: _rojo,
          bg: _rojoBg,
        );
      default: // pendiente
        return const _EstiloEstado(
          icono: Icons.schedule,
          color: _naranja,
          bg: _naranjaBg,
        );
    }
  }

  String _formatoFecha(String iso) {
    if (iso.length < 16) return iso;
    return iso.substring(0, 16).replaceAll('T', ' ');
  }

  Widget _estadoVacio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 64, color: _onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text(
                'No hay reportes guardados',
                style: TextStyle(color: _onSurfaceVariant),
              ),
            ],
          ),
        ),
      );

  Widget _finDeHistorial() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Opacity(
          opacity: 0.3,
          child: Column(
            children: const [
              Icon(Icons.inventory_2_outlined, size: 48),
              SizedBox(height: 8),
              Text(
                'Fin del historial',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
}

class _EstiloEstado {
  final IconData icono;
  final Color color;
  final Color bg;

  const _EstiloEstado({
    required this.icono,
    required this.color,
    required this.bg,
  });
}