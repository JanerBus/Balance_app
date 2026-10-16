import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/currency_provider.dart';
import '../../utils/calculator_evaluator.dart';
import '../../utils/formatters.dart';
import '../../widgets/financial_calculator_sheet.dart';

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DebtType _type = DebtType.theyOweMe;
  DateTime? _dueDate;

  final List<String> _quickReasons = [
    'Préstamo personal',
    'Almuerzo / Cena',
    'Servicios / Factura',
    'Viaje compartido',
    'Compra conjunta',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color get _accentColor =>
      _type == DebtType.theyOweMe ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

  Future<void> _openCalculator() async {
    HapticFeedback.selectionClick();
    final current = double.tryParse(_amountController.text.replaceAll(',', '.'));
    final calc = await FinancialCalculatorSheet.show(
      context,
      initialValue: current,
      title: 'Monto de la deuda',
    );
    if (calc != null && mounted) {
      setState(() {
        _amountController.text = CalculatorEvaluator.formatResult(calc);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Obtener nombres de personas existentes para sugerencias
    final existingPersons = debtProvider.debts
        .map((d) => d.personName.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Nueva Deuda',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _submit();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _type == DebtType.theyOweMe ? 'Guardar Deuda por Cobrar' : 'Guardar Deuda por Pagar',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          children: [
            // 1. Selector de Tipo Segmentado Cápsula
            _buildTypeSwitcher(isDark),

            const SizedBox(height: 18),

            // 2. Hero Card de Monto con Calculadora
            _buildAmountHero(currencyProvider, isDark),

            const SizedBox(height: 20),

            // 3. Card de Persona y Contactos Frecuentes
            _buildPersonCard(existingPersons, isDark),

            const SizedBox(height: 16),

            // 4. Card de Motivo / Concepto
            _buildReasonCard(isDark),

            const SizedBox(height: 16),

            // 5. Card de Fecha Límite
            _buildDueDateCard(isDark),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Switcher segmentado: Me deben vs Yo debo
  Widget _buildTypeSwitcher(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          _buildTypeTab(
            type: DebtType.theyOweMe,
            label: 'Me deben',
            icon: Icons.call_received_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          _buildTypeTab(
            type: DebtType.iOwe,
            label: 'Yo debo',
            icon: Icons.call_made_rounded,
            color: const Color(0xFFF43F5E),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required DebtType type,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _type = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF222B3E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de entrada Hero de monto con calculadora
  Widget _buildAmountHero(CurrencyProvider currencyProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _type == DebtType.theyOweMe ? 'MONTO QUE TE DEBEN' : 'MONTO QUE DEBES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '${currencyProvider.currency.symbol} ',
              prefixStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: _accentColor,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa un monto';
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) return 'Monto inválido';
              return null;
            },
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _openCalculator,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calculate_rounded, size: 16, color: _accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Calculadora',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Persona / Contacto
  Widget _buildPersonCard(List<String> existingPersons, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERSONA O ENTIDAD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Ej. Carlos Méndez, Mamá, Banco...',
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline_rounded, size: 18, color: _accentColor),
              ),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _nameController.clear()),
                    )
                  : null,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
            onChanged: (_) => setState(() {}),
          ),
          if (existingPersons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Personas registradas:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: existingPersons.map((name) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(name),
                      avatar: CircleAvatar(
                        radius: 9,
                        backgroundColor: _accentColor.withValues(alpha: 0.2),
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _accentColor),
                        ),
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                      backgroundColor: isDark ? const Color(0xFF1E2738) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _nameController.text = name);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tarjeta de Motivo / Concepto
  Widget _buildReasonCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOTIVO O CONCEPTO (OPCIONAL)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Ej. Prestado para compras de fin de semana...',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickReasons.map((reason) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(reason),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                    backgroundColor: isDark ? const Color(0xFF1E2738) : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _descriptionController.text = reason);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Fecha límite con presets rápidos
  Widget _buildDueDateCard(bool isDark) {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FECHA LÍMITE DE PAGO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              if (_dueDate != null)
                InkWell(
                  onTap: () => setState(() => _dueDate = null),
                  child: const Text(
                    'Quitar fecha',
                    style: TextStyle(fontSize: 12, color: Color(0xFFF43F5E), fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDatePresetChip(
                  label: 'Sin fecha',
                  isSelected: _dueDate == null,
                  isDark: isDark,
                  onTap: () => setState(() => _dueDate = null),
                ),
                const SizedBox(width: 8),
                _buildDatePresetChip(
                  label: 'En 7 días',
                  isSelected: _dueDate != null && _dueDate!.difference(now).inDays >= 6 && _dueDate!.difference(now).inDays <= 8,
                  isDark: isDark,
                  onTap: () => setState(() => _dueDate = now.add(const Duration(days: 7))),
                ),
                const SizedBox(width: 8),
                _buildDatePresetChip(
                  label: 'En 15 días',
                  isSelected: _dueDate != null && _dueDate!.difference(now).inDays >= 14 && _dueDate!.difference(now).inDays <= 16,
                  isDark: isDark,
                  onTap: () => setState(() => _dueDate = now.add(const Duration(days: 15))),
                ),
                const SizedBox(width: 8),
                _buildDatePresetChip(
                  label: 'En 1 mes',
                  isSelected: _dueDate != null && _dueDate!.difference(now).inDays >= 28 && _dueDate!.difference(now).inDays <= 32,
                  isDark: isDark,
                  onTap: () => setState(() => _dueDate = now.add(const Duration(days: 30))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickCustomDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _dueDate != null
                    ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E2738) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _dueDate != null ? const Color(0xFF6366F1) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dueDate != null
                          ? 'Vence el ${Formatters.shortDate(_dueDate!)}'
                          : 'Elegir fecha personalizada en el calendario...',
                      style: TextStyle(
                        fontWeight: _dueDate != null ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                        color: _dueDate != null ? const Color(0xFF6366F1) : null,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresetChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.14)
              : (isDark ? const Color(0xFF1E2738) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
            color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await context.read<DebtProvider>().addDebt(
          personName: _nameController.text.trim(),
          amount: double.parse(_amountController.text.replaceAll(',', '.')),
          type: _type,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          dueDate: _dueDate,
        );

    if (mounted) Navigator.pop(context);
  }
}
