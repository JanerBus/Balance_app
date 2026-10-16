import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'concept_glossary_sheet.dart';

/// Modelo de diapositiva para el recorrido interactivo.
class TourSlide {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final List<TourBullet> bullets;
  final String badgeText;

  const TourSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.bullets,
    required this.badgeText,
  });
}

class TourBullet {
  final IconData icon;
  final String title;
  final String description;

  const TourBullet({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Modal interactivo de recorrido guiado para aprender a usar Balance y sus funciones.
class AppWalkthroughSheet extends StatefulWidget {
  const AppWalkthroughSheet({super.key});

  static const String prefKey = 'has_seen_app_tour_v1';

  /// Muestra el recorrido automáticamente solo si el usuario no lo ha completado antes.
  static Future<void> checkAndShowFirstTime(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(prefKey) ?? false;
    if (!hasSeen && context.mounted) {
      await show(context);
    }
  }

  /// Muestra el recorrido en cualquier momento (manualmente desde ajustes o menú).
  static Future<void> show(BuildContext context) async {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppWalkthroughSheet(),
    );
  }

  @override
  State<AppWalkthroughSheet> createState() => _AppWalkthroughSheetState();
}

class _AppWalkthroughSheetState extends State<AppWalkthroughSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<TourSlide> _slides = [
    TourSlide(
      badgeText: 'Paso 1 de 6 • Bienvenida',
      title: 'Bienvenido a My Money',
      subtitle: 'Tu centro financiero personal, privado, moderno y 100% bajo tu control.',
      icon: Icons.auto_awesome_rounded,
      primaryColor: Color(0xFF6366F1),
      bullets: [
        TourBullet(
          icon: Icons.shield_outlined,
          title: '100% Privado y Sin Servidores',
          description: 'Tus datos nunca salen de tu teléfono. Sin cuentas obligatorias ni rastreo externo.',
        ),
        TourBullet(
          icon: Icons.speed_rounded,
          title: 'Rápido y Dinámico',
          description: 'Lleva el control de tus finanzas en segundos con calculadoras integradas y registro ágil.',
        ),
        TourBullet(
          icon: Icons.currency_exchange_rounded,
          title: 'Multidivisa Inteligente',
          description: 'Admite pesos colombianos, dólares, euros y más de 30 monedas con conversión al instante.',
        ),
      ],
    ),
    TourSlide(
      badgeText: 'Paso 2 de 6 • Cuentas y Tarjetas',
      title: 'Cuentas y Tarjetas de Crédito',
      subtitle: 'Organiza tu dinero por bolsillos, ahorros y líneas de crédito.',
      icon: Icons.account_balance_wallet_rounded,
      primaryColor: Color(0xFF10B981),
      bullets: [
        TourBullet(
          icon: Icons.credit_card_rounded,
          title: 'Tarjetas de Crédito Pro',
          description: 'Registra tu cupo total, fecha de corte y fecha límite de pago para evitar intereses.',
        ),
        TourBullet(
          icon: Icons.swap_horiz_rounded,
          title: 'Transferencias entre Cuentas',
          description: 'Mueve fondos entre tu banco, billeteras y efectivo sin alterar tu balance neto.',
        ),
        TourBullet(
          icon: Icons.visibility_off_outlined,
          title: 'Modo Ocultar Saldos',
          description: 'Toca el ícono del ojo en el inicio para proteger la visualización de tus cifras en público.',
        ),
      ],
    ),
    TourSlide(
      badgeText: 'Paso 3 de 6 • Sincronización',
      title: 'Detección Automática de Bancos',
      subtitle: 'Registra tus gastos e ingresos sin ingresar manualmente cada compra.',
      icon: Icons.notifications_active_rounded,
      primaryColor: Color(0xFF8B5CF6),
      bullets: [
        TourBullet(
          icon: Icons.mark_email_read_outlined,
          title: 'Lectura de Notificaciones',
          description: 'My Money detecta compras de Nu, Bancolombia, Nequi, Daviplata y más al momento de pagar.',
        ),
        TourBullet(
          icon: Icons.lock_outline_rounded,
          title: 'Sin Credenciales Bancarias',
          description: 'Jamás pediremos contraseñas ni acceso a tu banco. Todo funciona vía notificaciones del sistema.',
        ),
        TourBullet(
          icon: Icons.checklist_rounded,
          title: 'Aprobación en 1 Toque',
          description: 'Revisa las transacciones pendientes en la campana del inicio y regístralas con un toque.',
        ),
      ],
    ),
    TourSlide(
      badgeText: 'Paso 4 de 6 • Motor de Aprendizaje',
      title: 'Entrena a Balance con Cualquier Banco',
      subtitle: '¿Tu banco no está en la lista o cambió su formato? Enseña al motor en segundos.',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFFEC4899),
      bullets: [
        TourBullet(
          icon: Icons.key_rounded,
          title: 'Palabras Clave Disparadoras',
          description: 'Indica palabras como "recibiste" o "compra" para que el motor identifique el mensaje.',
        ),
        TourBullet(
          icon: Icons.terminal_rounded,
          title: 'Botón "Enseñar a My Money"',
          description: 'En la Consola de Diagnóstico, toca "Enseñar" sobre cualquier mensaje recibido para crear la regla.',
        ),
        TourBullet(
          icon: Icons.replay_rounded,
          title: 'Re-procesamiento Automático',
          description: 'Al guardar la regla, la notificación se convierte inmediatamente en transacción.',
        ),
      ],
    ),
    TourSlide(
      badgeText: 'Paso 5 de 6 • Metas y Presupuestos',
      title: 'Metas de Ahorro y Presupuestos',
      subtitle: 'Alcanza tus objetivos y mantén tus gastos mensuales a raya.',
      icon: Icons.pie_chart_rounded,
      primaryColor: Color(0xFFF59E0B),
      bullets: [
        TourBullet(
          icon: Icons.savings_rounded,
          title: 'Metas con Proyección Temporal',
          description: 'Calcula cuánto debes apartar cada mes para tu viaje, fondo de emergencia o cuota inicial.',
        ),
        TourBullet(
          icon: Icons.warning_amber_rounded,
          title: 'Alertas de Topes Mensuales',
          description: 'Recibe avisos antes de sobrepasar el 80% y 100% de tu presupuesto por categoría.',
        ),
        TourBullet(
          icon: Icons.handshake_outlined,
          title: 'Deudas y Préstamos',
          description: 'Monitorea lo que te deben o debes con abonos parciales y recordatorios de vencimiento.',
        ),
      ],
    ),
    TourSlide(
      badgeText: 'Paso 6 de 6 • Glosario y Ayuda',
      title: 'Aprende Conceptos en Cualquier Momento',
      subtitle: 'Ayuda contextual integrada para resolver cualquier duda al instante.',
      icon: Icons.menu_book_rounded,
      primaryColor: Color(0xFF3B82F6),
      bullets: [
        TourBullet(
          icon: Icons.help_outline_rounded,
          title: 'Botones de Ayuda (?)',
          description: 'Toca el ícono de interrogación en cualquier pantalla para ver qué significa cada campo.',
        ),
        TourBullet(
          icon: Icons.menu_book_outlined,
          title: 'Glosario Financiero Integrado',
          description: 'Definiciones claras de fecha de corte, cupos, paquetes de apps y más en el menú superior.',
        ),
        TourBullet(
          icon: Icons.fingerprint_rounded,
          title: 'Bloqueo Seguro con PIN',
          description: 'Configura un PIN de 4 dígitos o desbloqueo biométrico en Ajustes de Seguridad.',
        ),
      ],
    ),
  ];

  Future<void> _completeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppWalkthroughSheet.prefKey, true);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTour();
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isLastPage = _currentPage == _slides.length - 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131720) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Bar con botón Saltar y Glosario
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    ConceptGlossarySheet.show(context);
                  },
                  icon: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF6366F1)),
                  label: const Text(
                    'Glosario',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: _completeTour,
                  child: Text(
                    'Saltar',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // PageView con diapositivas
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return _buildSlideContent(context, slide, isDark, colorScheme);
              },
            ),
          ),

          const Divider(height: 1),

          // Bottom Navigation Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Row(
              children: [
                // Dots Indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    _slides.length,
                    (idx) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 4),
                      width: _currentPage == idx ? 12 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _currentPage == idx
                            ? _slides[_currentPage].primaryColor
                            : colorScheme.outlineVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Botón Anterior
                if (_currentPage > 0) ...[
                  IconButton(
                    tooltip: 'Anterior',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                    ),
                    onPressed: _prevPage,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  ),
                  const SizedBox(width: 6),
                ],

                // Botón Siguiente / Comenzar
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _slides[_currentPage].primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _nextPage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLastPage ? 'Comenzar' : 'Siguiente',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Icon(isLastPage ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded, size: 14),
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

  Widget _buildSlideContent(BuildContext context, TourSlide slide, bool isDark, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        // Badge
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: slide.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: slide.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              slide.badgeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: slide.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Hero Icon & Title
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: slide.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(slide.icon, color: slide.primaryColor, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slide.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Bullets Cards
        ...slide.bullets.map((b) => _buildBulletCard(b, slide.primaryColor, isDark, colorScheme)),
      ],
    );
  }

  Widget _buildBulletCard(TourBullet bullet, Color primaryColor, bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(bullet.icon, color: primaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bullet.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  bullet.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
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
