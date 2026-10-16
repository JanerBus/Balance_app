import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modelo de un concepto educativo en la aplicación.
class ConceptItem {
  final String title;
  final String category;
  final IconData icon;
  final Color color;
  final String shortDescription;
  final String fullExplanation;
  final String? example;
  final String? tip;

  const ConceptItem({
    required this.title,
    required this.category,
    required this.icon,
    required this.color,
    required this.shortDescription,
    required this.fullExplanation,
    this.example,
    this.tip,
  });
}

/// Hoja interactiva con el glosario de conceptos y guía educativa de Balance.
class ConceptGlossarySheet extends StatefulWidget {
  final String? initialCategory;

  const ConceptGlossarySheet({super.key, this.initialCategory});

  static Future<void> show(BuildContext context, {String? initialCategory}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConceptGlossarySheet(initialCategory: initialCategory),
    );
  }

  @override
  State<ConceptGlossarySheet> createState() => _ConceptGlossarySheetState();
}

class _ConceptGlossarySheetState extends State<ConceptGlossarySheet> {
  late String _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _categories = [
    'Todos',
    'Motor de Reglas',
    'Cuentas y Tarjetas',
    'Presupuestos',
    'Metas y Deudas',
  ];

  static const List<ConceptItem> _allConcepts = [
    // --- MOTOR DE REGLAS Y NOTIFICACIONES ---
    ConceptItem(
      title: 'Palabras Clave (Trigger Keywords)',
      category: 'Motor de Reglas',
      icon: Icons.key_rounded,
      color: Color(0xFF6366F1),
      shortDescription: 'Términos obligatorios que deben estar en la notificación para que se active la regla.',
      fullExplanation:
          'Son las palabras identificadoras que el motor de Balance busca dentro del mensaje de notificación. '
          'Si la notificación entrante no contiene TODAS las palabras clave definidas en la regla, el motor la ignora, evitando que mensajes irrelevantes o no financieros se registren por error.',
      example: 'Para compras en Falabella: "compra aprobada". Para nómina en Nu: "recibiste" y "nómina".',
      tip: 'Usa palabras distintivas del banco. Evita palabras muy cortas o genéricas como "el", "de" o "tu".',
    ),
    ConceptItem(
      title: 'Paquete de la App (Package Name)',
      category: 'Motor de Reglas',
      icon: Icons.android_rounded,
      color: Color(0xFF10B981),
      shortDescription: 'El identificador técnico único de la aplicación bancaria en Android.',
      fullExplanation:
          'En Android, cada app bancaria tiene una dirección única en el sistema (por ejemplo, "com.nu.production" para Nu o "com.bancolombia.personas" para Bancolombia). '
          'Al indicarlo en la regla, aseguras que solo las notificaciones emitidas por esa app específica activen la detección. Si lo dejas vacío, la regla buscará en cualquier app instalada.',
      example: 'com.nu.production (Nu), com.nequi.MobileApp (Nequi), com.bancolombia.personas (Bancolombia).',
      tip: 'Puedes dejarlo vacío si quieres que la regla aplique sin importar qué aplicación envíe el mensaje.',
    ),
    ConceptItem(
      title: 'Entidad Bancaria',
      category: 'Motor de Reglas',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF3B82F6),
      shortDescription: 'El nombre del banco, cooperativa o billetera digital de la transacción.',
      fullExplanation:
          'Es el nombre con el que se etiquetará la entidad de la transacción en tus movimientos y en el registro diagnóstico. '
          'Permite a Balance clasificar de dónde proviene o hacia dónde va el dinero.',
      example: 'Nu, Banco Falabella, Lulo Bank, Nequi, Scotiabank Colpatria, Dale!.',
    ),
    ConceptItem(
      title: 'Comercio o Concepto Fijo',
      category: 'Motor de Reglas',
      icon: Icons.storefront_rounded,
      color: Color(0xFFF59E0B),
      shortDescription: 'Nombre predeterminado del comercio o beneficiario cuando la notificación no lo especifica.',
      fullExplanation:
          'Algunas notificaciones bancarias no incluyen el nombre del almacén o remitente (por ejemplo, dicen únicamente "Compra aprobada por \$50.000"). '
          'Con este campo opcional, puedes forzar a que siempre se registre como "Supermercado", "Netflix", "Pago de Alquiler", etc.',
      example: 'Si creas una regla para tu suscripción de Spotify, puedes fijar "Spotify Premium" como comercio.',
    ),
    ConceptItem(
      title: 'Asociar a Cuenta Bancaria',
      category: 'Motor de Reglas',
      icon: Icons.wallet_rounded,
      color: Color(0xFF8B5CF6),
      shortDescription: 'La cuenta de Balance donde se debitará o acreditará el dinero automáticamente.',
      fullExplanation:
          'Cuando la regla detecte la notificación, aplicará el movimiento directamente en el saldo de la cuenta que elijas (por ejemplo, tu "Cuenta Nu Ahorros" o "Tarjeta de Crédito Falabella"). '
          'Si seleccionas "Preguntar siempre", la app te notificará para que tú decidas qué cuenta afectar.',
      example: 'Vincular las compras de Nu a tu cuenta "Tarjeta Nu" para llevar el saldo al centavo.',
    ),
    ConceptItem(
      title: 'Consola de Diagnóstico Bancario',
      category: 'Motor de Reglas',
      icon: Icons.terminal_rounded,
      color: Color(0xFF64748B),
      shortDescription: 'Registro en vivo de todas las notificaciones recibidas y su resultado de procesamiento.',
      fullExplanation:
          'Muestra el historial en tiempo real de los mensajes capturados por el sistema Android. '
          'Te permite auditar qué detectó My Money, por qué se aprobó o ignoró una notificación, y ofrece el botón directo "Enseñar a My Money" para entrenar nuevas reglas con 1 solo toque.',
      tip: 'Si un banco cambió el formato de sus mensajes, consulta la consola para ver el texto exacto recibido y crear la regla en segundos.',
    ),

    // --- CUENTAS Y TARJETAS ---
    ConceptItem(
      title: 'Cupo Total de Tarjeta de Crédito',
      category: 'Cuentas y Tarjetas',
      icon: Icons.credit_card_rounded,
      color: Color(0xFFF43F5E),
      shortDescription: 'Límite máximo de crédito asignado por el banco para esa tarjeta.',
      fullExplanation:
          'Es el monto total que la entidad financiera te permite utilizar en tu tarjeta de crédito. '
          'Balance lo utiliza para calcular en tiempo real tu cupo disponible y tu porcentaje de endeudamiento.',
      example: 'Si el banco te otorgó un cupo de \$5.000.000, ese es tu Cupo Total.',
    ),
    ConceptItem(
      title: 'Fecha de Corte (Billing Cutoff)',
      category: 'Cuentas y Tarjetas',
      icon: Icons.event_repeat_rounded,
      color: Color(0xFFEC4899),
      shortDescription: 'Día del mes en que el banco cierra el periodo de compras y genera tu extracto.',
      fullExplanation:
          'Todas las compras que realices hasta este día entrarán en la factura del mes actual. '
          'Las compras realizadas al día siguiente de la fecha de corte se facturan hasta el siguiente mes, dándote hasta 45 días de financiación sin intereses.',
      example: 'Si tu corte es el día 15, una compra hecha el 16 de octubre la pagarás en diciembre.',
      tip: 'Balance te avisa cuándo está próximo tu corte para que aproveches las mejores ventanas de compra.',
    ),
    ConceptItem(
      title: 'Fecha Límite de Pago',
      category: 'Cuentas y Tarjetas',
      icon: Icons.event_available_rounded,
      color: Color(0xFFF97316),
      shortDescription: 'Último día para abonar o pagar el extracto de tu tarjeta sin incurrir en intereses de mora.',
      fullExplanation:
          'Es el plazo máximo otorgado por el banco después del corte (habitualmente entre 15 y 20 días después). '
          'Pagar antes de esta fecha protege tu historial crediticio y evita comisiones por mora.',
      tip: 'Activa las alertas inteligentes en Ajustes para recibir un recordatorio automático 2 días antes de vencer.',
    ),
    ConceptItem(
      title: 'Modo Privacidad (Discreto)',
      category: 'Cuentas y Tarjetas',
      icon: Icons.visibility_off_rounded,
      color: Color(0xFF14B8A6),
      shortDescription: 'Oculta tus saldos y montos con asteriscos (••••••) con un solo toque.',
      fullExplanation:
          'Diseñado para cuando estás en la calle, transporte público o con personas cerca. '
          'Toca el ícono del ojo en la esquina superior derecha del inicio para enmascarar todos los saldos de tus cuentas.',
    ),

    // --- PRESUPUESTOS Y GASTOS ---
    ConceptItem(
      title: 'Presupuesto por Categoría',
      category: 'Presupuestos',
      icon: Icons.pie_chart_outline_rounded,
      color: Color(0xFF10B981),
      shortDescription: 'Tope máximo mensual asignado a un grupo de gastos (Alimentación, Transporte, Ocio, etc.).',
      fullExplanation:
          'Te ayuda a no gastar más de lo planeado en un periodo. Balance suma automáticamente tus gastos de esa categoría '
          'y te muestra barras de progreso con código de color: verde (óptimo), amarillo (cerca al 80%) y rojo (sobrepasado).',
      example: 'Presupuesto de Alimentación: \$600.000 mensuales.',
    ),
    ConceptItem(
      title: 'Gastos Recurrentes / Suscripciones',
      category: 'Presupuestos',
      icon: Icons.sync_rounded,
      color: Color(0xFF06B6D4),
      shortDescription: 'Cobros periódicos automáticos como Netflix, internet, arriendo o membresías.',
      fullExplanation:
          'Transacciones con una periodicidad fija (semanal, quincenal, mensual, anual). '
          'Balance proyecta su costo normalizado mensual y te alerta un día antes del cobro para que tengas fondos disponibles.',
    ),

    // --- METAS Y DEUDAS ---
    ConceptItem(
      title: 'Metas de Ahorro con Proyección',
      category: 'Metas y Deudas',
      icon: Icons.savings_rounded,
      color: Color(0xFF6366F1),
      shortDescription: 'Objetivos financieros con monto meta y fecha límite de cumplimiento.',
      fullExplanation:
          'Te permite ahorrar con propósito (Fondo de emergencia, vacaciones, cuota inicial). '
          'Balance calcula automáticamente cuánto debes ahorrar cada mes o semana para llegar a tiempo a tu objetivo.',
    ),
    ConceptItem(
      title: 'Deudas (Por Cobrar vs. Por Pagar)',
      category: 'Metas y Deudas',
      icon: Icons.handshake_rounded,
      color: Color(0xFFE11D48),
      shortDescription: 'Control de préstamos a amigos/familiares o compromisos adquiridos.',
      fullExplanation:
          'Registra tanto "Me deben" (activos por cobrar) como "Debo" (pasivos por pagar). '
          'Admite pagos parciales con historial detallado, cálculo del saldo pendiente y recordatorios antes de su vencimiento.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'Todos';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ConceptItem> get _filteredConcepts {
    return _allConcepts.where((c) {
      final matchesCategory = _selectedCategory == 'Todos' || c.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return c.title.toLowerCase().contains(query) ||
          c.shortDescription.toLowerCase().contains(query) ||
          c.fullExplanation.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Glosario y Guía de Conceptos',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      Text(
                        'Aprende qué significa cada función en My Money',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar concepto (ej. palabras clave, cupo, corte)...',
                hintStyle: TextStyle(fontSize: 13, color: colorScheme.outline),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Chips de Categoría
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Lista de conceptos
          Expanded(
            child: _filteredConcepts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: colorScheme.outline),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron conceptos',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Intenta con otra palabra de búsqueda o cambia de categoría.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                    itemCount: _filteredConcepts.length,
                    itemBuilder: (context, index) {
                      final item = _filteredConcepts[index];
                      return _buildConceptCard(context, item, isDark, colorScheme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptCard(BuildContext context, ConceptItem item, bool isDark, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: isDark ? const Color(0xFF1E2638).withValues(alpha: 0.6) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.shortDescription,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, height: 1.3),
            ),
          ),
          children: [
            const Divider(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.fullExplanation,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (item.example != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ejemplo Práctico:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.example!,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.tip != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consejo Balance:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.tip!,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
