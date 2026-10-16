import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/debt_provider.dart';
import '../../models/debt_model.dart';
import '../../widgets/debt_tile.dart';
import '../../utils/formatters.dart';
import 'add_debt_screen.dart';
import 'debt_detail_screen.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final theyOwe = _filterDebts(provider.theyOweMe);
    final iOwe = _filterDebts(provider.iOwe);
    final paid = _filterDebts(provider.paidDebts);

    final netBalance = provider.totalTheyOweMe - provider.totalIOwe;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 20,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Buscar por persona o motivo...',
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                  filled: false,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              )
            : const Text(
                'Deudas & Préstamos',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: colorScheme.onSurface,
            ),
            tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDebtScreen()),
          );
        },
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Nueva deuda',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner Hero Consolidado Net Debt (solo visible si no estamos buscando activamente)
                if (!_isSearching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _NetDebtHeroBanner(
                      theyOweTotal: provider.totalTheyOweMe,
                      theyOweCount: provider.theyOweMe.length,
                      iOweTotal: provider.totalIOwe,
                      iOweCount: provider.iOwe.length,
                      netBalance: netBalance,
                      isDark: isDark,
                    ),
                  ),

                // Selector de pestañas segmentado ultra moderno con badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151C2C) : const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: isDark ? const Color(0xFF222B3E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      dividerColor: Colors.transparent,
                      tabs: [
                        _buildTab('Me deben', theyOwe.length, const Color(0xFF10B981)),
                        _buildTab('Debo', iOwe.length, const Color(0xFFF43F5E)),
                        _buildTab('Historial', paid.length, const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Vistas de pestañas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _DebtGroupList(
                        debts: theyOwe,
                        type: DebtType.theyOweMe,
                        emptyTitle: _searchQuery.isEmpty ? 'Nadie te debe dinero' : 'Sin coincidencias',
                        emptySubtitle: _searchQuery.isEmpty
                            ? 'Cuando prestes dinero a un amigo o familiar, regístralo aquí.'
                            : 'No encontramos deudas a tu favor con "$_searchQuery"',
                        accentColor: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      _DebtGroupList(
                        debts: iOwe,
                        type: DebtType.iOwe,
                        emptyTitle: _searchQuery.isEmpty ? 'No tienes deudas pendientes' : 'Sin coincidencias',
                        emptySubtitle: _searchQuery.isEmpty
                            ? '¡Excelente! Estás al día y no le debes a nadie.'
                            : 'No encontramos deudas pendientes con "$_searchQuery"',
                        accentColor: const Color(0xFFF43F5E),
                        isDark: isDark,
                      ),
                      _PaidDebtsList(
                        debts: paid,
                        searchQuery: _searchQuery,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTab(String title, int count, Color badgeColor) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DebtModel> _filterDebts(List<DebtModel> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((d) {
      final matchName = d.personName.toLowerCase().contains(_searchQuery);
      final matchDesc = (d.description ?? '').toLowerCase().contains(_searchQuery);
      return matchName || matchDesc;
    }).toList();
  }
}

/// Hero Banner consolidado de deudas con Balance Neto y desglose
class _NetDebtHeroBanner extends StatelessWidget {
  final double theyOweTotal;
  final int theyOweCount;
  final double iOweTotal;
  final int iOweCount;
  final double netBalance;
  final bool isDark;

  const _NetDebtHeroBanner({
    required this.theyOweTotal,
    required this.theyOweCount,
    required this.iOweTotal,
    required this.iOweCount,
    required this.netBalance,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isNetPositive = netBalance >= 0;
    final netColor = isNetPositive ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header balance neto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'BALANCE NETO DEUDAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: netColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isNetPositive ? 'A tu favor' : 'Por saldar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: netColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${isNetPositive ? '+' : '-'}${Formatters.currency(netBalance.abs())}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: netColor,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  color: Color(0xFF6366F1),
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 12),

          // Métricas divididas en dos columnas responsivas
          Row(
            children: [
              // Por cobrar (Me deben)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.08 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            'Por cobrar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Formatters.currency(theyOweTotal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      Text(
                        '$theyOweCount ${theyOweCount == 1 ? 'persona' : 'personas'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Por pagar (Debo)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.08 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFF43F5E)),
                          const SizedBox(width: 4),
                          Text(
                            'Por pagar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFFECDD3) : const Color(0xFF9F1239),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Formatters.currency(iOweTotal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFFF43F5E),
                          ),
                        ),
                      ),
                      Text(
                        '$iOweCount ${iOweCount == 1 ? 'persona' : 'personas'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista de deudas agrupadas por persona con diseño premium
class _DebtGroupList extends StatelessWidget {
  final List<DebtModel> debts;
  final DebtType type;
  final String emptyTitle;
  final String emptySubtitle;
  final Color accentColor;
  final bool isDark;

  const _DebtGroupList({
    required this.debts,
    required this.type,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DebtProvider>();
    final grouped = provider.groupByPerson(debts);

    // Ordenar personas por saldo pendiente total descendente
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final totalA = a.value.fold(0.0, (s, d) => s + d.remainingAmount);
        final totalB = b.value.fold(0.0, (s, d) => s + d.remainingAmount);
        return totalB.compareTo(totalA);
      });

    if (entries.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_outlined,
                  size: 36,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _PersonGroupCard(
          personName: entry.key,
          debts: entry.value,
          type: type,
          accentColor: accentColor,
          isDark: isDark,
        );
      },
    );
  }
}

/// Tarjeta Squircle de Grupo por Persona moderna y colapsable
class _PersonGroupCard extends StatelessWidget {
  final String personName;
  final List<DebtModel> debts;
  final DebtType type;
  final Color accentColor;
  final bool isDark;

  const _PersonGroupCard({
    required this.personName,
    required this.debts,
    required this.type,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalRemaining = debts.fold(0.0, (s, d) => s + d.remainingAmount);
    final totalInitial = debts.fold(0.0, (s, d) => s + d.amount);
    final count = debts.length;
    final hasOverdue = debts.any((d) => d.isOverdue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasOverdue
              ? colorScheme.error.withValues(alpha: 0.3)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: count == 1,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Text(
              personName.isNotEmpty ? personName[0].toUpperCase() : '?',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  personName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasOverdue) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Vencida',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '$count ${count == 1 ? 'deuda' : 'deudas'} · Resta ${Formatters.currency(totalRemaining)}',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Formatters.currency(totalRemaining),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: accentColor, letterSpacing: -0.4),
                ),
              ),
              if (totalInitial > totalRemaining)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'de ${Formatters.currency(totalInitial)}',
                    style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          children: [
            Divider(
              height: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 8),
            ...debts.map(
              (debt) => DebtTile(
                debt: debt,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DebtDetailScreen(debt: debt)),
                  );
                },
              ),
            ),
            if (count > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: Text('¿Marcar todo de $personName como pagado?'),
                          content: Text('Se marcarán como saldadas todas las $count deudas pendientes de esta persona.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Marcar todo'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        HapticFeedback.mediumImpact();
                        await context.read<DebtProvider>().markAllAsPaidForPerson(personName, type);
                      }
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text(
                      'Saldar todas las deudas',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Historial de deudas liquidadas
class _PaidDebtsList extends StatelessWidget {
  final List<DebtModel> debts;
  final String searchQuery;
  final bool isDark;

  const _PaidDebtsList({
    required this.debts,
    required this.searchQuery,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalSettled = debts.fold(0.0, (s, d) => s + d.amount);

    if (debts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 36,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                searchQuery.isEmpty ? 'Sin deudas liquidadas aún' : 'Sin coincidencias en historial',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                searchQuery.isEmpty
                    ? 'Las deudas que marques como totalmente pagadas aparecerán archivadas aquí.'
                    : 'No encontramos deudas saldadas con "$searchQuery"',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Banner resumen de liquidación
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C2C) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF64748B), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL HISTÓRICO SALDADO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Formatters.currency(totalSettled),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${debts.length} saldadas',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        ...debts.map(
          (debt) => DebtTile(
            debt: debt,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DebtDetailScreen(debt: debt)),
              );
            },
          ),
        ),
      ],
    );
  }
}
