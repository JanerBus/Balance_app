import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/transactions/add_transaction_screen.dart';

class AccountCardCarousel extends StatefulWidget {
  final List<AccountModel> accounts;
  final double totalBalance;
  final String? selectedAccountId;
  final ValueChanged<String?> onAccountSelected;
  final bool isPrivacyMode;

  const AccountCardCarousel({
    super.key,
    required this.accounts,
    required this.totalBalance,
    required this.selectedAccountId,
    required this.onAccountSelected,
    this.isPrivacyMode = false,
  });

  @override
  State<AccountCardCarousel> createState() => _AccountCardCarouselState();
}

class _AccountCardCarouselState extends State<AccountCardCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final initialPage = _pageForAccountId(widget.selectedAccountId);
    _currentPage = initialPage;
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: initialPage,
    );
  }

  int _pageForAccountId(String? accountId) {
    if (accountId == null) return 0;
    final index = widget.accounts.indexWhere((a) => a.id == accountId);
    return index != -1 ? index + 1 : 0;
  }

  @override
  void didUpdateWidget(covariant AccountCardCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAccountId != widget.selectedAccountId ||
        oldWidget.accounts.length != widget.accounts.length) {
      final targetPage = _pageForAccountId(widget.selectedAccountId);
      if (targetPage != _currentPage) {
        _currentPage = targetPage;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      }
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
    final isDark = theme.brightness == Brightness.dark;

    // Total de páginas = 1 (Consolidada) + cuentas.length + 1 (Añadir cuenta)
    final totalCards = 1 + widget.accounts.length + 1;

    return Column(
      children: [
        SizedBox(
          height: 204,
          child: PageView.builder(
            controller: _pageController,
            clipBehavior: Clip.none,
            itemCount: totalCards,
            onPageChanged: (page) {
              HapticFeedback.selectionClick();
              setState(() => _currentPage = page);
              if (page == 0) {
                widget.onAccountSelected(null); // Consolidada
              } else if (page <= widget.accounts.length) {
                widget.onAccountSelected(widget.accounts[page - 1].id);
              }
            },
            itemBuilder: (context, index) {
              final isSelected = index == _currentPage;

              return AnimatedScale(
                scale: isSelected ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: _buildCardAtIndex(context, index, isDark),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Indicador de Puntos Minimalista
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalCards, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : (isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCardAtIndex(BuildContext context, int index, bool isDark) {
    if (index == 0) {
      // Tarjeta 0: Consolidado Global (Estilo Titanium Apple Card)
      return _buildGlobalCard(context, isDark);
    } else if (index <= widget.accounts.length) {
      // Cuentas individuales
      final account = widget.accounts[index - 1];
      return _buildIndividualAccountCard(context, account, isDark);
    } else {
      // Tarjeta Final: Agregar Nueva Cuenta
      return _buildAddAccountCard(context, isDark);
    }
  }

  Widget _buildGlobalCard(BuildContext context, bool isDark) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E2638),
                  const Color(0xFF111827),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                  const Color(0xFF020617),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.08),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Background graphic elements
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.blur_on_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header: Logo + Chip + Contactless
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildEmvChip(),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.contactless_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ],
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${widget.accounts.length} Cuentas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Center: Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TARJETA CONSOLIDADA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.currency(widget.totalBalance, null, widget.isPrivacyMode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ],
                ),

                // Footer: Masked number + Brand
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '••••  ••••  GLOBAL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BALANCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualAccountCard(BuildContext context, AccountModel account, bool isDark) {
    if (account.isCreditCard) {
      return _buildCreditAccountCard(context, account, isDark);
    }

    final baseColor = Color(account.color);
    final isNu = account.name.toLowerCase().contains('nu');
    final isBancolombia = account.name.toLowerCase().contains('bancolombia');
    final isNequi = account.name.toLowerCase().contains('nequi');

    // Gradient styling tailored to brand or account color
    List<Color> gradientColors;
    if (isNu) {
      gradientColors = const [Color(0xFF820AD1), Color(0xFF4C0677), Color(0xFF28033F)];
    } else if (isBancolombia) {
      gradientColors = const [Color(0xFF2C3240), Color(0xFF191F2D), Color(0xFF0F1420)];
    } else if (isNequi) {
      gradientColors = const [Color(0xFFE91E63), Color(0xFF880E4F), Color(0xFF2A0025)];
    } else {
      gradientColors = [
        baseColor.withValues(alpha: 0.95),
        baseColor.withValues(alpha: 0.75),
        const Color(0xFF0F172A),
      ];
    }

    final maskedCode = (account.id.hashCode.abs() % 9000 + 1000).toString();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -20,
            child: Icon(
              account.iconData,
              size: 120,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: Chip + Type Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildEmvChip(),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.contactless_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ],
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          account.typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Center: Balance & Account Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.currency(account.currentBalance, null, widget.isPrivacyMode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ],
                ),

                // Footer: Masked card digits & bank icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '••••  ••••  $maskedCode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(account.iconData, color: Colors.white, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditAccountCard(BuildContext context, AccountModel account, bool isDark) {
    final baseColor = Color(account.color);
    final isNu = account.name.toLowerCase().contains('nu');
    final isBancolombia = account.name.toLowerCase().contains('bancolombia');
    final isNequi = account.name.toLowerCase().contains('nequi');

    List<Color> gradientColors;
    if (isNu) {
      gradientColors = const [Color(0xFF820AD1), Color(0xFF4C0677), Color(0xFF240338)];
    } else if (isBancolombia) {
      gradientColors = const [Color(0xFF252A38), Color(0xFF161B25), Color(0xFF0C0F17)];
    } else if (isNequi) {
      gradientColors = const [Color(0xFFE91E63), Color(0xFF880E4F), Color(0xFF2A0025)];
    } else {
      gradientColors = [
        baseColor.withValues(alpha: 0.95),
        baseColor.withValues(alpha: 0.75),
        const Color(0xFF0F172A),
      ];
    }

    final maskedCode = (account.id.hashCode.abs() % 9000 + 1000).toString();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -20,
            child: Icon(
              account.iconData,
              size: 120,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: EMV Chip + Due / Cutoff Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildEmvChip(),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.contactless_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ],
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 10.5,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                account.dueDay != null
                                    ? 'Paga: día ${account.dueDay}'
                                    : (account.closingDay != null
                                        ? 'Corte: día ${account.closingDay}'
                                        : 'Crédito'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Center: Account Name + Debt vs Available + Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEUDA ACTUAL',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.currency(account.currentDebt, null, widget.isPrivacyMode),
                                  style: TextStyle(
                                    color: account.currentDebt > 0 ? const Color(0xFFFF8FA3) : Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'DISPONIBLE',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  Formatters.currency(account.availableCredit, null, widget.isPrivacyMode),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (account.creditLimit != null && account.creditLimit! > 0) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: account.creditUtilization,
                          minHeight: 3.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            account.creditUtilizationPercent > 70
                                ? const Color(0xFFFF4E6E)
                                : account.creditUtilizationPercent > 30
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF34D399),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Uso: ${account.creditUtilizationPercent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (account.closingDay != null)
                            Text(
                              'Corte: d.${account.closingDay}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),

                // Footer: Masked card digits & Pagar Quick Action Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '••••  ••••  $maskedCode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                initialType: TransactionType.transfer,
                                initialToAccountId: account.id,
                                initialAmount: account.currentDebt > 0 ? account.currentDebt : null,
                                initialTitle: 'Pago tarjeta ${account.name}',
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payments_outlined, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Pagar Tarjeta',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountCard(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        AccountsScreen.showAddEditAccountDialog(context);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? const Color(0xFF131926) : const Color(0xFFF1F5F9),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Icon(Icons.add_rounded, size: 26, color: Color(0xFF6366F1)),
              ),
              const SizedBox(height: 10),
              Text(
                'Agregar Billetera o Banco',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Nu, Bancolombia, Nequi, etc.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmvChip() {
    return Container(
      width: 32,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFDF79), Color(0xFFC69C2B), Color(0xFFA67C1E)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 26,
          height: 18,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withValues(alpha: 0.25), width: 0.8),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
