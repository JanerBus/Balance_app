import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/goal_model.dart';
import '../../providers/currency_provider.dart';
import '../../providers/goal_provider.dart';
import '../../utils/calculator_evaluator.dart';
import '../../widgets/financial_calculator_sheet.dart';

class AddEditGoalScreen extends StatefulWidget {
  final GoalModel? existingGoal;

  const AddEditGoalScreen({super.key, this.existingGoal});

  @override
  State<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

class _AddEditGoalScreenState extends State<AddEditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _initialAmountController;
  late final TextEditingController _noteController;

  DateTime? _targetDate;
  late int _selectedColor;
  late String _selectedIcon;

  static const List<int> _colorPalette = [
    0xFF4F46E5, // Electric Indigo
    0xFF10B981, // Emerald Jade
    0xFFF43F5E, // Coral Rose
    0xFFF59E0B, // Amber Gold
    0xFF06B6D4, // Cyan Sky
    0xFF8B5CF6, // Purple Violet
    0xFFEC4899, // Pink Fuchsia
    0xFF0EA5E9, // Ocean Blue
  ];

  static const List<Map<String, dynamic>> _iconList = [
    {'name': 'savings', 'icon': Icons.savings_rounded, 'label': 'Alcancía'},
    {'name': 'flight', 'icon': Icons.flight_takeoff_rounded, 'label': 'Viaje'},
    {'name': 'car', 'icon': Icons.directions_car_rounded, 'label': 'Vehículo'},
    {'name': 'home', 'icon': Icons.home_rounded, 'label': 'Vivienda'},
    {'name': 'computer', 'icon': Icons.computer_rounded, 'label': 'Tecnología'},
    {'name': 'phone', 'icon': Icons.phone_iphone_rounded, 'label': 'Celular'},
    {'name': 'school', 'icon': Icons.school_rounded, 'label': 'Educación'},
    {'name': 'emergency', 'icon': Icons.health_and_safety_rounded, 'label': 'Emergencia'},
    {'name': 'beach', 'icon': Icons.beach_access_rounded, 'label': 'Vacaciones'},
    {'name': 'game', 'icon': Icons.sports_esports_rounded, 'label': 'Gamer'},
    {'name': 'shopping', 'icon': Icons.shopping_bag_rounded, 'label': 'Compras'},
    {'name': 'gift', 'icon': Icons.card_giftcard_rounded, 'label': 'Regalo'},
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    _titleController = TextEditingController(text: g?.title ?? '');
    _targetAmountController = TextEditingController(
      text: g != null ? CalculatorEvaluator.formatResult(g.targetAmount) : '',
    );
    _initialAmountController = TextEditingController();
    _noteController = TextEditingController(text: g?.note ?? '');
    _targetDate = g?.targetDate;
    _selectedColor = g?.color ?? _colorPalette.first;
    _selectedIcon = g?.icon ?? 'savings';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _initialAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingGoal != null;

  Future<void> _openCalculator(TextEditingController controller, String title) async {
    final current = double.tryParse(controller.text.replaceAll(',', '.'));
    final calc = await FinancialCalculatorSheet.show(
      context,
      initialValue: current,
      title: title,
    );
    if (calc != null) {
      setState(() {
        controller.text = CalculatorEvaluator.formatResult(calc);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = context.watch<CurrencyProvider>().currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Meta de Ahorro' : 'Nueva Meta de Ahorro'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Preview de la tarjeta de la meta
            _buildGoalPreview(colorScheme, currency.symbol),
            const SizedBox(height: 24),

            // Nombre de la meta
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la meta',
                hintText: 'Ej. Fondo de emergencia, Viaje a Cancún...',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre para tu meta' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Monto objetivo
            TextFormField(
              controller: _targetAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto objetivo',
                prefixText: '${currency.symbol} ',
                prefixIcon: const Icon(Icons.savings_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calculate_rounded, color: Color(0xFF6366F1)),
                  tooltip: 'Calculadora integrada',
                  onPressed: () => _openCalculator(_targetAmountController, 'Monto Objetivo'),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa el monto objetivo';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Monto inválido';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Aporte inicial (solo al crear)
            if (!_isEditing) ...[
              TextFormField(
                controller: _initialAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Aporte inicial (opcional)',
                  hintText: '¿Tienes dinero ya ahorrado para esta meta?',
                  prefixText: '${currency.symbol} ',
                  prefixIcon: const Icon(Icons.add_circle_outline_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate_rounded, color: Color(0xFF6366F1)),
                    tooltip: 'Calculadora integrada',
                    onPressed: () => _openCalculator(_initialAmountController, 'Aporte Inicial'),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed == null || parsed < 0) return 'Monto inválido';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],

            // Fecha límite (opcional)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Fecha límite (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _targetDate != null
                    ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                    : 'Sin fecha límite definida',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              trailing: _targetDate != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _targetDate = null),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // Selector de Icono
            Text('Ícono de la meta', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _iconList.map((item) {
                final isSelected = item['name'] == _selectedIcon;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedIcon = item['name'] as String);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(_selectedColor).withValues(alpha: 0.2)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? Color(_selectedColor) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: isSelected ? Color(_selectedColor) : colorScheme.onSurfaceVariant,
                      size: 26,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Selector de Color
            Text('Color temático', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: _colorPalette.map((colorValue) {
                final isSelected = colorValue == _selectedColor;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedColor = colorValue);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Color(colorValue).withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Notas
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo o notas (opcional)',
                hintText: '¿Por qué quieres cumplir esta meta?',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 32),

            // Botón Guardar
            FilledButton.icon(
              onPressed: _saveGoal,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(_isEditing ? 'Guardar Cambios' : 'Crear Meta de Ahorro'),
              style: FilledButton.styleFrom(
                backgroundColor: Color(_selectedColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalPreview(ColorScheme colorScheme, String currencySymbol) {
    final title = _titleController.text.trim().isEmpty ? 'Nombre de tu meta' : _titleController.text.trim();
    final target = double.tryParse(_targetAmountController.text.replaceAll(',', '.')) ?? 0.0;
    final initial = double.tryParse(_initialAmountController.text.replaceAll(',', '.')) ??
        (widget.existingGoal?.currentAmount ?? 0.0);
    final progress = target > 0 ? (initial / target).clamp(0.0, 1.0) : 0.0;
    final color = Color(_selectedColor);

    IconData iconData = Icons.savings_rounded;
    for (final item in _iconList) {
      if (item['name'] == _selectedIcon) {
        iconData = item['icon'] as IconData;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(iconData, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _targetDate != null
                          ? 'Meta para el ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                          : 'Sin fecha límite',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ahorrado: $currencySymbol ${initial.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Text(
                'Objetivo: $currencySymbol ${target.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final targetAmount = double.parse(_targetAmountController.text.replaceAll(',', '.'));
    final initialAmount = double.tryParse(_initialAmountController.text.replaceAll(',', '.')) ?? 0.0;
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    final goalProvider = context.read<GoalProvider>();

    if (_isEditing) {
      final updated = widget.existingGoal!.copyWith(
        title: title,
        targetAmount: targetAmount,
        targetDate: _targetDate,
        clearTargetDate: _targetDate == null,
        color: _selectedColor,
        icon: _selectedIcon,
        note: note,
        clearNote: note == null,
      );
      await goalProvider.updateGoal(updated);
    } else {
      await goalProvider.addGoal(
        title: title,
        targetAmount: targetAmount,
        currentAmount: initialAmount,
        targetDate: _targetDate,
        color: _selectedColor,
        icon: _selectedIcon,
        note: note,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
