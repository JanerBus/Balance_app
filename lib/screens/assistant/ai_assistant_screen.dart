import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../utils/formatters.dart';
import '../transactions/add_transaction_screen.dart';

class ChatMessageItem {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ParsedAiTransaction? transaction;
  final String? source;
  bool isSaved;

  ChatMessageItem({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.transaction,
    this.source,
    this.isSaved = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final List<ChatMessageItem> _messages = [];
  bool _isLoading = false;
  String? _activeApiKey;
  bool _speechEnabled = false;
  bool _isListeningVoice = false;

  final List<String> _quickSuggestions = [
    '🍔 Ayer gasté 35 mil en pizza con Nequi',
    '💰 ¿Cuál es mi saldo total?',
    '📊 ¿En qué gasté más este mes?',
    '🎯 ¿Cómo van mis presupuestos?',
    '📑 ¿Cuánto debo en deudas?',
    '💡 Consejos para ahorrar dinero',
    '🚕 Pagué 14.000 de taxi en efectivo',
  ];

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _initSpeech();
    _addInitialGreeting();
  }

  @override
  void dispose() {
    try {
      _speechToText.stop();
    } catch (_) {}
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _isListeningVoice = _speechToText.isListening;
            });
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech recognition error: ${errorNotification.errorMsg}');
          if (mounted) {
            setState(() {
              _isListeningVoice = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (e) {
      debugPrint('Speech recognition not available: $e');
    }
  }

  Future<void> _loadApiKey() async {
    final key = await AiAssistantService.getSavedApiKey();
    if (mounted) {
      setState(() {
        _activeApiKey = key;
      });
    }
  }

  void _addInitialGreeting() {
    _messages.add(
      ChatMessageItem(
        isUser: false,
        text: '¡Hola! Soy tu **Asistente Inteligente My Money** 🤖✨\n\n'
            'Puedes decirme o escribir tus movimientos de forma natural:\n'
            '• *"Ayer gasté 35 mil en comida con Nequi"*\n'
            '• *"Pagué 12.000 de taxi en efectivo hoy"*\n'
            '• *"Me pagaron 1.500.000 de salario"*\n\n'
            'O preguntarme sobre tu dinero:\n'
            '• *"¿Cuál es mi saldo total?"*\n'
            '• *"¿En qué he gastado más este mes?"*\n'
            '• *"¿Cómo van mis presupuestos?"*',
        source: _activeApiKey != null ? 'gemini' : 'local',
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  AiFinancialContext _buildContext() {
    final finance = context.read<FinanceProvider>();
    final account = context.read<AccountProvider>();
    final budget = context.read<BudgetProvider>();
    final debt = context.read<DebtProvider>();
    final currency = context.read<CurrencyProvider>();

    return AiFinancialContext(
      totalBalance: account.totalBalance,
      monthIncome: finance.totalIncome,
      monthExpense: finance.totalExpense,
      accounts: account.accounts,
      recentTransactions: finance.transactions,
      budgets: budget.budgets,
      debts: debt.debts,
      currency: currency.currency,
    );
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = (overrideText ?? _inputController.text).trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    if (overrideText == null) {
      _inputController.clear();
    }

    setState(() {
      _messages.add(ChatMessageItem(
        text: text,
        isUser: true,
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    final financialContext = _buildContext();
    final response = await AiAssistantService.processUserInput(
      input: text,
      context: financialContext,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessageItem(
          text: response.message,
          isUser: false,
          transaction: response.transaction,
          source: response.source,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveTransactionFromAi(ChatMessageItem message) async {
    final parsedTx = message.transaction;
    if (parsedTx == null || message.isSaved) return;

    HapticFeedback.mediumImpact();
    final financeProvider = context.read<FinanceProvider>();
    final accountProvider = context.read<AccountProvider>();

    try {
      try {
        await financeProvider.addTransaction(
          title: parsedTx.title,
          amount: parsedTx.amount,
          type: parsedTx.type,
          category: parsedTx.category,
          date: parsedTx.date,
          note: parsedTx.note,
          accountId: parsedTx.accountId,
        );
      } catch (e1) {
        debugPrint('First addTransaction failed: $e1');
        await financeProvider.addTransaction(
          title: parsedTx.title,
          amount: parsedTx.amount,
          type: parsedTx.type,
          category: parsedTx.category,
          date: parsedTx.date,
          note: parsedTx.note,
          accountId: 'default-cash',
        );
      }
      try {
        await accountProvider.loadAccounts();
      } catch (e2) {
        debugPrint('loadAccounts failed: $e2');
      }

      if (mounted) {
        setState(() {
          message.isSaved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('¡Guardado! ${parsedTx.title} por ${Formatters.currency(parsedTx.amount, context.read<CurrencyProvider>().currency)}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('_saveTransactionFromAi general error: $e');
    }
  }

  void _editTransactionFromAi(ParsedAiTransaction tx) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: tx.type,
          initialAmount: tx.amount,
          initialCategory: tx.category,
          initialAccountId: tx.accountId,
          initialTitle: tx.title,
        ),
      ),
    );
  }

  void _showApiSettingsDialog() {
    final controller = TextEditingController(text: _activeApiKey ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Configuración de IA',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'My Money funciona 100% offline, privado y gratis con el Motor Local sin necesidad de internet.',
                            style: TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Google Gemini API Key (Opcional):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'AIzaSy...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si agregas tu clave gratuita de Google AI Studio, activarás Gemini 3.5 Flash Lite para análisis conversacional avanzado.',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            actions: [
              if (_activeApiKey != null)
                TextButton(
                  onPressed: () async {
                    await AiAssistantService.removeApiKey();
                    await _loadApiKey();
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  },
                  child: const Text('Eliminar clave', style: TextStyle(color: Color(0xFFEF4444))),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final key = controller.text.trim();
                  if (key.isNotEmpty) {
                    await AiAssistantService.saveApiKey(key);
                  } else {
                    await AiAssistantService.removeApiKey();
                  }
                  await _loadApiKey();
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openVoiceSheet() {
    HapticFeedback.mediumImpact();
    if (!_speechEnabled) {
      _initSpeech();
    }

    String currentWords = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Iniciar escucha si está disponible y no está escuchando aún
            if (_speechEnabled && !_speechToText.isListening) {
              try {
                _speechToText.listen(
                  onResult: (result) {
                    setSheetState(() {
                      currentWords = result.recognizedWords;
                    });
                    _inputController.text = result.recognizedWords;
                    if (result.finalResult && currentWords.trim().isNotEmpty) {
                      HapticFeedback.mediumImpact();
                      try {
                        _speechToText.stop();
                      } catch (_) {}
                      Navigator.pop(sheetCtx);
                      _handleSendMessage(currentWords);
                    }
                  },
                );
              } catch (e) {
                debugPrint('Speech listen error: $e');
              }
            }

            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(sheetCtx).padding.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131824) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Micrófono con indicador visual de escucha
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _speechToText.isListening
                            ? [const Color(0xFFEF4444), const Color(0xFFF43F5E)]
                            : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_speechToText.isListening
                                  ? const Color(0xFFF43F5E)
                                  : const Color(0xFF6366F1))
                              .withValues(alpha: 0.4),
                          blurRadius: 22,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _speechToText.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _speechToText.isListening
                        ? 'Escuchando tu voz...'
                        : (_speechEnabled ? 'Micrófono activo' : 'Micrófono o ejemplos de voz'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _speechToText.isListening
                        ? 'Habla ahora (ej: "Ayer me gasté 25 mil en almuerzo con Nequi")'
                        : 'Habla con naturalidad o toca un comando de ejemplo:',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),

                  // Si se están reconociendo palabras en tiempo real, mostrarlas en una tarjeta interactiva
                  if (currentWords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Transcripción en directo:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '"$currentWords"',
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                try {
                                  _speechToText.stop();
                                } catch (_) {}
                                Navigator.pop(sheetCtx);
                                _handleSendMessage(currentWords);
                              },
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Enviar mensaje', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildVoicePresetChip(
                        '🎙️ "Ayer gasté 35 mil en pizza con Nequi"',
                        () {
                          try {
                            _speechToText.stop();
                          } catch (_) {}
                          Navigator.pop(sheetCtx);
                          _handleSendMessage('Ayer gasté 35 mil en pizza con Nequi');
                        },
                      ),
                      _buildVoicePresetChip(
                        '🎙️ "Pagué 12.000 de taxi en efectivo"',
                        () {
                          try {
                            _speechToText.stop();
                          } catch (_) {}
                          Navigator.pop(sheetCtx);
                          _handleSendMessage('Pagué 12.000 de taxi en efectivo');
                        },
                      ),
                      _buildVoicePresetChip(
                        '🎙️ "¿Cuál es mi saldo total?"',
                        () {
                          try {
                            _speechToText.stop();
                          } catch (_) {}
                          Navigator.pop(sheetCtx);
                          _handleSendMessage('¿Cuál es mi saldo total?');
                        },
                      ),
                      _buildVoicePresetChip(
                        '🎙️ "¿Cómo van mis presupuestos?"',
                        () {
                          try {
                            _speechToText.stop();
                          } catch (_) {}
                          Navigator.pop(sheetCtx);
                          _handleSendMessage('¿Cómo van mis presupuestos?');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      try {
                        _speechToText.stop();
                      } catch (_) {}
                      Navigator.pop(sheetCtx);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      try {
        _speechToText.stop();
      } catch (_) {}
      if (mounted) setState(() => _isListeningVoice = false);
    });
  }

  Widget _buildVoicePresetChip(String text, VoidCallback onTap) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(
                  child: Text(
                    'Asistente IA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _activeApiKey != null ? const Color(0xFF10B981) : const Color(0xFF06B6D4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _activeApiKey != null ? 'Gemini 3.5' : 'Motor Local Offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 21),
            tooltip: 'Configurar IA',
            onPressed: _showApiSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, size: 21),
            tooltip: 'Reiniciar conversación',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _messages.clear();
                _addInitialGreeting();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Área de conversación
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg, isDark);
                },
              ),
            ),

            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analizando...',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

            // Chips de sugerencias rápidas
            Container(
              height: 42,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final suggestion = _quickSuggestions[idx];
                  return ActionChip(
                    label: Text(suggestion, style: const TextStyle(fontSize: 11)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _handleSendMessage(suggestion),
                    backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  );
                },
              ),
            ),

            // Barra inferior de texto y voz
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131824) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Botón de dictado por voz
                  IconButton(
                    icon: Icon(
                      _isListeningVoice ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: const Color(0xFF6366F1),
                    ),
                    tooltip: 'Dictar por voz',
                    onPressed: _openVoiceSheet,
                  ),
                  // Campo de texto
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe o dicta tu movimiento...',
                        hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                      ),
                      onSubmitted: (val) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón Enviar
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      onPressed: () => _handleSendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem message, bool isDark) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF6366F1)
                        : (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isUser
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      if (message.source != null && !isUser) ...[
                        const SizedBox(height: 4),
                        Text(
                          message.source == 'gemini' ? '✨ Gemini AI' : '⚡ Motor Local',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 4),
            ],
          ),

          // Tarjeta interactiva de transacción detectada
          if (message.transaction != null)
            _buildInteractiveTransactionCard(message, isDark),
        ],
      ),
    );
  }

  Widget _buildInteractiveTransactionCard(ChatMessageItem message, bool isDark) {
    final tx = message.transaction!;
    final isIncome = tx.type == TransactionType.income;
    final catColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    final categoryModel = AppCategories.findByName(tx.category, tx.type);
    final currency = context.read<CurrencyProvider>().currency;
    final formattedAmount = Formatters.currency(tx.amount, currency);

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 40, right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: message.isSaved
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : catColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryModel.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryModel.icon, color: categoryModel.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${tx.category} • ${tx.accountName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedAmount,
                style: TextStyle(
                  color: catColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badges informativos
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.dayMonth(tx.date),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      tx.accountName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Botones de acción
          if (message.isSaved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Registrado en My Money',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _saveTransactionFromAi(message),
                    icon: const Icon(Icons.add_task_rounded, size: 16),
                    label: const Text('Registrar movimiento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _editTransactionFromAi(tx),
                  child: const Text('Editar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
