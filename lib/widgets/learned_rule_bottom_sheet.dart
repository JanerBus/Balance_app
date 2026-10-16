import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/parsed_bank_transaction.dart';
import '../models/transaction_model.dart';
import '../models/user_learned_rule.dart';
import '../providers/account_provider.dart';
import '../providers/notification_sync_provider.dart';
import '../utils/formatters.dart';
import 'concept_glossary_sheet.dart';

/// Modal interactivo para crear o editar reglas de aprendizaje de notificaciones bancarias.
class LearnedRuleBottomSheet extends StatefulWidget {
  final UserLearnedRule? existingRule;
  final String? initialPackage;
  final String? initialTitle;
  final String? initialText;
  final NotificationLogItem? sourceLogItem;

  const LearnedRuleBottomSheet({
    super.key,
    this.existingRule,
    this.initialPackage,
    this.initialTitle,
    this.initialText,
    this.sourceLogItem,
  });

  static Future<void> show(
    BuildContext context, {
    UserLearnedRule? existingRule,
    String? initialPackage,
    String? initialTitle,
    String? initialText,
    NotificationLogItem? sourceLogItem,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LearnedRuleBottomSheet(
        existingRule: existingRule,
        initialPackage: initialPackage,
        initialTitle: initialTitle,
        initialText: initialText,
        sourceLogItem: sourceLogItem,
      ),
    );
  }

  @override
  State<LearnedRuleBottomSheet> createState() => _LearnedRuleBottomSheetState();
}

class _LearnedRuleBottomSheetState extends State<LearnedRuleBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bankNameController;
  late TextEditingController _packageNameController;
  late TextEditingController _keywordsController;
  late TextEditingController _merchantController;

  late TransactionType _selectedType;
  String? _selectedAccountId;
  String? _selectedCategory;
  final List<String> _keywords = [];

  ParsedBankTransaction? _previewTx;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bankNameController = TextEditingController();
    _packageNameController = TextEditingController();
    _keywordsController = TextEditingController();
    _merchantController = TextEditingController();

    _initFromWidget();
  }

  @override
  void didUpdateWidget(covariant LearnedRuleBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText ||
        oldWidget.initialTitle != widget.initialTitle ||
        oldWidget.initialPackage != widget.initialPackage ||
        oldWidget.existingRule != widget.existingRule) {
      _initFromWidget();
    }
  }

  void _initFromWidget() {
    final rule = widget.existingRule;

    _selectedType = rule?.type ?? _guessInitialType(widget.initialTitle, widget.initialText);
    _selectedAccountId = rule?.defaultAccountId;
    _selectedCategory = rule?.defaultCategory;

    _nameController.text = rule?.name ?? _guessRuleName(widget.initialPackage, widget.initialTitle);
    _bankNameController.text = rule?.bankName ?? _guessBankName(widget.initialPackage, widget.initialTitle);
    _packageNameController.text = rule?.packageName ?? widget.initialPackage ?? '';
    _merchantController.text = rule?.fixedMerchant ?? '';
    _keywordsController.clear();

    _keywords.clear();
    if (rule != null) {
      _keywords.addAll(rule.triggerKeywords);
    } else {
      _extractSuggestedKeywords(widget.initialTitle, widget.initialText);
    }

    _updatePreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _packageNameController.dispose();
    _keywordsController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  TransactionType _guessInitialType(String? title, String? text) {
    final lower = '${title ?? ''} ${text ?? ''}'.toLowerCase();
    if (lower.contains('recibiste') ||
        lower.contains('consignacion') ||
        lower.contains('consignación') ||
        lower.contains('abono') ||
        lower.contains('rendimiento') ||
        lower.contains('crecio') ||
        lower.contains('creció') ||
        lower.contains('te llego') ||
        lower.contains('te llegó') ||
        lower.contains('nomina') ||
        lower.contains('nómina')) {
      return TransactionType.income;
    }
    if (lower.contains('transferiste') || lower.contains('enviaste') || lower.contains('paso plata')) {
      return TransactionType.transfer;
    }
    return TransactionType.expense;
  }

  String _guessBankName(String? package, String? title) {
    final p = (package ?? '').toLowerCase();
    if (p.contains('nu.')) return 'Nu';
    if (p.contains('nequi')) return 'Nequi';
    if (p.contains('bancolombia')) return 'Bancolombia';
    if (p.contains('daviplata')) return 'Daviplata';
    if (p.contains('davivienda')) return 'Davivienda';
    if (p.contains('bbva')) return 'BBVA';
    if (p.contains('lulo')) return 'Lulo Bank';
    if (p.contains('rappi')) return 'RappiPay';
    if (p.contains('falabella')) return 'Banco Falabella';
    if (p.contains('scotiabank') || p.contains('colpatria')) return 'Scotiabank Colpatria';
    if (title != null && title.isNotEmpty) return title.split(' ').first;
    return 'Entidad Bancaria';
  }

  String _guessRuleName(String? package, String? title) {
    final bank = _guessBankName(package, title);
    return 'Regla $bank';
  }

  void _extractSuggestedKeywords(String? title, String? text) {
    final raw = '${title ?? ''} ${text ?? ''}';
    final lower = raw.toLowerCase();

    // Palabras clave comunes bancarias que sirven de disparador
    final candidateWords = [
      'recibiste', 'te envió', 'te enviaron', 'compra aprobada', 'compra por',
      'pago exitoso', 'pago de', 'rendimiento', 'transferencia', 'abono',
      'retiro', 'consignación', 'factura', 'cajita', 'tarjeta',
    ];

    for (final cand in candidateWords) {
      if (lower.contains(cand) && !_keywords.contains(cand)) {
        _keywords.add(cand);
      }
    }

    if (_keywords.isEmpty && title != null && title.trim().isNotEmpty) {
      _keywords.add(title.trim().toLowerCase());
    }
  }

  void _addKeyword(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isNotEmpty && !_keywords.contains(clean)) {
      setState(() {
        _keywords.add(clean);
        _keywordsController.clear();
        _updatePreview();
      });
    }
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _keywords.remove(keyword);
      _updatePreview();
    });
  }

  void _updatePreview() {
    final sampleTitle = widget.initialTitle ?? _nameController.text;
    final sampleText = widget.initialText ?? 'Transacción de prueba por \$50.000';
    final samplePackage = _packageNameController.text.trim();

    final testRule = UserLearnedRule(
      id: widget.existingRule?.id ?? 'preview',
      name: _nameController.text.trim(),
      bankName: _bankNameController.text.trim().isNotEmpty ? _bankNameController.text.trim() : 'Banco',
      packageName: samplePackage.isNotEmpty ? samplePackage : null,
      triggerKeywords: List.of(_keywords),
      type: _selectedType,
      defaultAccountId: _selectedAccountId,
      defaultCategory: _selectedCategory,
      fixedMerchant: _merchantController.text.trim().isNotEmpty ? _merchantController.text.trim() : null,
      createdAt: DateTime.now(),
    );

    if (_keywords.isNotEmpty &&
        testRule.matches(textToEvaluate: '$sampleTitle $sampleText', incomingPackage: samplePackage)) {
      _previewTx = testRule.processNotification(
        title: sampleTitle,
        text: sampleText,
        incomingPackage: samplePackage,
      );
    } else {
      _previewTx = null;
    }
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_keywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Añade al menos una palabra clave que deba contener la notificación.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final syncProvider = context.read<NotificationSyncProvider>();
    final rule = UserLearnedRule(
      id: widget.existingRule?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      bankName: _bankNameController.text.trim().isNotEmpty ? _bankNameController.text.trim() : 'Banco',
      packageName: _packageNameController.text.trim().isNotEmpty ? _packageNameController.text.trim() : null,
      triggerKeywords: _keywords,
      type: _selectedType,
      defaultAccountId: _selectedAccountId,
      defaultCategory: _selectedCategory,
      fixedMerchant: _merchantController.text.trim().isNotEmpty ? _merchantController.text.trim() : null,
      createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
      sampleText: widget.initialText ?? widget.existingRule?.sampleText,
    );

    HapticFeedback.mediumImpact();

    if (widget.existingRule != null) {
      await syncProvider.updateLearnedRule(rule);
    } else {
      await syncProvider.addLearnedRule(rule);
    }

    // Si viene de un log no reconocido, reprocesar de inmediato
    if (widget.sourceLogItem != null && mounted) {
      syncProvider.reprocessLogItem(widget.sourceLogItem!);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingRule != null
                ? '✅ Regla de aprendizaje actualizada'
                : '🎓 Regla guardada. Balance ahora detectará este formato automáticamente.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accountProvider = context.watch<AccountProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded, color: Color(0xFF6366F1), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingRule != null ? 'Editar Regla de Aprendizaje' : 'Enseñar Patrón a Balance',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          Text(
                            'Entrena a Balance para reconocer tus notificaciones bancarias',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF6366F1)),
                      tooltip: 'Guía y Conceptos',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ConceptGlossarySheet.show(context, initialCategory: 'Motor de Reglas');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // Form Body
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      // Banner Educativo de Conceptos
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF6366F1), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '¿Cómo funcionan las reglas?',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Balance busca las palabras clave que indiques dentro de tus notificaciones bancarias para extraer el monto y clasificar el movimiento en tu cuenta.',
                                    style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                ConceptGlossarySheet.show(context, initialCategory: 'Motor de Reglas');
                              },
                              child: const Text(
                                'Ver Conceptos',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Notificación Origen (si está disponible)
                      if (widget.initialText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.mark_email_unread_outlined, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Texto capturado de la notificación:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty)
                                Text(
                                  widget.initialTitle!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              Text(
                                widget.initialText!,
                                style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Nombre de la Regla y Entidad
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nombre de la regla',
                                hintText: 'Ej. Nómina Nu, Daviplata Pago',
                                helperText: 'Nombre descriptivo para identificarla',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                              onChanged: (_) => setState(_updatePreview),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _bankNameController,
                              decoration: InputDecoration(
                                labelText: 'Entidad',
                                hintText: 'Ej. Nu, Nequi',
                                helperText: 'Banco emisor',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                              onChanged: (_) => setState(_updatePreview),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Tipo de Transacción
                      Text(
                        'Tipo de movimiento detectado',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<TransactionType>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: TransactionType.expense,
                            label: Text('Gasto'),
                            icon: Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFFF43F5E)),
                          ),
                          ButtonSegment(
                            value: TransactionType.income,
                            label: Text('Ingreso'),
                            icon: Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF10B981)),
                          ),
                          ButtonSegment(
                            value: TransactionType.transfer,
                            label: Text('Transfer.'),
                            icon: Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF6366F1)),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (set) {
                          setState(() {
                            _selectedType = set.first;
                            _updatePreview();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Palabras Clave Obligatorias (Tags)
                      Text(
                        'Palabras clave que deben estar en la notificación',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'La regla solo se activará si la notificación contiene estas palabras:',
                        style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: _keywordsController,
                        decoration: InputDecoration(
                          hintText: 'Añadir palabra (ej. "recibiste", "compra")',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            onPressed: () => _addKeyword(_keywordsController.text),
                          ),
                        ),
                        onSubmitted: _addKeyword,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _keywords.map((kw) {
                          return Chip(
                            label: Text(kw, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            onDeleted: () => _removeKeyword(kw),
                            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Cuenta Destino Asociada (Full Width con isExpanded)
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: accountProvider.accounts.any((a) => a.id == _selectedAccountId)
                            ? _selectedAccountId
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Asociar a cuenta bancaria',
                          helperText: 'Saldo que se actualizará automáticamente',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Preguntar siempre')),
                          ...accountProvider.accounts.map(
                            (acc) => DropdownMenuItem(
                              value: acc.id,
                              child: Text(acc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedAccountId = val;
                            _updatePreview();
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      // Paquete de la App y Comercio Fijo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _packageNameController,
                              decoration: InputDecoration(
                                labelText: 'Paquete de app',
                                hintText: 'Cualquier app',
                                helperText: 'Opcional (ej. com.nu)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (_) => setState(_updatePreview),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _merchantController,
                              decoration: InputDecoration(
                                labelText: 'Comercio fijo',
                                hintText: 'Opcional',
                                helperText: 'Ej. Spotify, Nómina',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (_) => setState(_updatePreview),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Vista Previa de Detección en Tiempo Real
                      Builder(
                        builder: (context) {
                          final hasKeywords = _keywords.isNotEmpty;
                          final isSuccess = hasKeywords && _previewTx != null;
                          final cardBg = !hasKeywords
                              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                              : isSuccess
                                  ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08)
                                  : const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.15 : 0.08);
                          final cardBorder = !hasKeywords
                              ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                              : isSuccess
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : const Color(0xFFF43F5E).withValues(alpha: 0.3);
                          final statusColor = !hasKeywords
                              ? colorScheme.onSurfaceVariant
                              : isSuccess
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF43F5E);
                          final statusIcon = !hasKeywords
                              ? Icons.info_outline_rounded
                              : isSuccess
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.warning_amber_rounded;
                          final statusText = !hasKeywords
                              ? 'Añade palabras clave arriba para activar la regla'
                              : isSuccess
                                  ? '¡Regla Coincide Exitosamente!'
                                  : 'No coincide con el texto de muestra';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(statusIcon, size: 18, color: statusColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSuccess && _previewTx != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _previewTx!.merchantOrPayee,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_previewTx!.type == TransactionType.income ? '+' : '-'}${Formatters.currency(_previewTx!.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: _previewTx!.type == TransactionType.income
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF43F5E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Entidad: ${_previewTx!.bankName} • Categoría: ${_previewTx!.category}',
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                  // Botón Guardar
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saveRule,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      widget.existingRule != null ? 'Actualizar Regla' : 'Guardar y Activar Regla',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
