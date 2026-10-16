import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../main_navigation.dart';

/// Pantalla de bienvenida y animación inicial de "My Money".
/// Diseñada bajo principios de UI/UX Fintech modernos:
/// - Coreografía de animación escalonada (scale-up, fade-in, slide vertical).
/// - Resplandor ambiental adaptativo (Light / Dark mode).
/// - Logo 3D con efecto de elevación y borde translúcido.
/// - Posibilidad de omitir con un toque para máxima usabilidad.
/// - Adaptabilidad a pantallas compactas sin desbordamientos de RenderFlex.
class SplashScreen extends StatefulWidget {
  final Duration animationDuration;
  final bool autoNavigate;
  final VoidCallback? onFinished;
  final Widget? nextScreen;

  const SplashScreen({
    super.key,
    this.animationDuration = const Duration(milliseconds: 1600),
    this.autoNavigate = true,
    this.onFinished,
    this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _badgeFade;
  late final Animation<double> _pulseAnimation;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Controlador principal para la coreografía de entrada
    _mainController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Controlador para el resplandor pulsante continuo de fondo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    // Animación de entrada del Logo (pop suave elástico)
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );

    // Animación de tipografía y marca ("My Money")
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.30, 0.65, curve: Curves.easeIn),
    );

    // Animación de la insignia de estado inferior
    _badgeFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.55, 0.90, curve: Curves.easeIn),
    );

    // Respiración del halo de luz ambiental
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    // Al terminar la animación de entrada, navegar fluidamente si autoNavigate está activo
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.autoNavigate) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _proceedToNext();
        });
      }
    });

    _mainController.forward();
  }

  void _proceedToNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    widget.onFinished?.call();

    final destination = widget.nextScreen ?? const MainNavigation();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF131A29) : Colors.white;
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Permite al usuario tocar para omitir la animación e ingresar de inmediato
          if (widget.autoNavigate) {
            _proceedToNext();
          }
        },
        child: Stack(
          children: [
            // Resplandor ambiental de fondo (Efecto Aura Fintech)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _AmbientGlowPainter(
                      isDark: isDark,
                      pulseScale: _pulseAnimation.value,
                    ),
                  );
                },
              ),
            ),

            // Contenido central con garantía de cero desbordamientos (SingleChildScrollView)
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(flex: 3),

                              // --- SECCIÓN DEL LOGO CON HALO PULSANTE ---
                              ScaleTransition(
                                scale: _logoScale,
                                child: FadeTransition(
                                  opacity: _logoFade,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Resplandor luminoso detrás del contenedor del logo
                                      AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _pulseAnimation.value,
                                            child: Container(
                                              width: 140,
                                              height: 140,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: RadialGradient(
                                                  colors: [
                                                    AppTheme.primarySeed
                                                        .withValues(alpha: isDark ? 0.35 : 0.20),
                                                    AppTheme.accentCyan
                                                        .withValues(alpha: isDark ? 0.20 : 0.10),
                                                    Colors.transparent,
                                                  ],
                                                  stops: const [0.0, 0.55, 1.0],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      // Contenedor Squircle / Tarjeta del Logo con borde translúcido
                                      Container(
                                        width: 114,
                                        height: 114,
                                        decoration: BoxDecoration(
                                          color: cardBgColor,
                                          borderRadius:
                                              BorderRadius.circular(28),
                                          border: Border.all(
                                            color: cardBorderColor,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primarySeed
                                                  .withValues(alpha: isDark ? 0.40 : 0.18),
                                              blurRadius: 32,
                                              offset: const Offset(0, 12),
                                            ),
                                            BoxShadow(
                                              color: AppTheme.accentCyan
                                                  .withValues(alpha: isDark ? 0.25 : 0.10),
                                              blurRadius: 18,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Image.asset(
                                            'assets/icon/app_icon.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error,
                                                stackTrace) {
                                              // Respaldo elegante si el asset tardara en cargarse
                                              return Container(
                                                color: AppTheme.primarySeed,
                                                child: const Icon(
                                                  Icons.account_balance_wallet_rounded,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // --- SECCIÓN DE MARCA Y TIPOGRAFÍA ---
                              SlideTransition(
                                position: _textSlide,
                                child: FadeTransition(
                                  opacity: _textFade,
                                  child: Column(
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'My Money',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: titleColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Tu centro financiero personal',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                            color: subtitleColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const Spacer(flex: 3),

                              // --- PIE DE PÁGINA: ESTADO Y SEGURIDAD ---
                              FadeTransition(
                                opacity: _badgeFade,
                                child: Column(
                                  children: [
                                    // Píldora de estado con spinner fino
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF161F30)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        border: Border.all(
                                          color: cardBorderColor,
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: isDark ? 0.20 : 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 13,
                                              height: 13,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  AppTheme.primarySeed,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Iniciando tus finanzas...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? const Color(0xFFE2E8F0)
                                                    : const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // Distintivo de privacidad
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shield_outlined,
                                            size: 13,
                                            color: subtitleColor
                                                .withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '100% Local, Seguro y Privado',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: subtitleColor
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintor personalizado para el resplandor ambiental suave de fondo
class _AmbientGlowPainter extends CustomPainter {
  final bool isDark;
  final double pulseScale;

  _AmbientGlowPainter({
    required this.isDark,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.40);
    final radius = (size.width * 0.75) * pulseScale;

    final primaryGlowColor = isDark
        ? const Color(0xFF4F46E5).withValues(alpha: 0.16)
        : const Color(0xFF4F46E5).withValues(alpha: 0.08);

    final secondaryGlowColor = isDark
        ? const Color(0xFF06B6D4).withValues(alpha: 0.08)
        : const Color(0xFF06B6D4).withValues(alpha: 0.04);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryGlowColor,
          secondaryGlowColor,
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter oldDelegate) {
    return oldDelegate.pulseScale != pulseScale ||
        oldDelegate.isDark != isDark;
  }
}
