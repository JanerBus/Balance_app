import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/goal_model.dart';
import '../../providers/goal_provider.dart';
import '../../utils/formatters.dart';
import 'add_edit_goal_screen.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _filterIndex = 0; // 0: Todas, 1: En progreso, 2: Cumplidas

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allGoals = goalProvider.goals;
    final activeGoals = goalProvider.activeGoals;
    final completedGoals = goalProvider.completedGoals;

    List<GoalModel> displayedGoals;
    if (_filterIndex == 1) {
      displayedGoals = activeGoals;
    } else if (_filterIndex == 2) {
      displayedGoals = completedGoals;
    } else {
      displayedGoals = allGoals;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas de Ahorro'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditGoalScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva meta'),
      ),
      body: goalProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : allGoals.isEmpty
              ? _buildEmptyState(context, colorScheme)
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Tarjeta de Resumen Global de Alcancías
                    _buildSummaryCard(goalProvider, colorScheme, isDark),
                    const SizedBox(height: 20),

                    // Selector de Filtros
                    _buildFilterChips(allGoals.length, activeGoals.length, completedGoals.length),
                    const SizedBox(height: 16),

                    // Lista de Metas
                    if (displayedGoals.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text(
                          _filterIndex == 1
                              ? '¡No tienes metas pendientes! Todas están cumplidas.'
                              : 'Aún no has completado ninguna meta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    else
                      ...displayedGoals.map((goal) => _buildGoalCard(context, goal, colorScheme, isDark)),

                    const SizedBox(height: 80),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(GoalProvider provider, ColorScheme colorScheme, bool isDark) {
    final totalSaved = provider.totalSaved;
    final totalTarget = provider.totalTarget;
    final overallProgress = provider.overallProgress;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.4 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Ahorro Consolidado',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.completedCount}/${provider.goals.length} cumplidas',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            Formatters.currency(totalSaved),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'de ${Formatters.currency(totalTarget)} en metas totales',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Progreso general',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(overallProgress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int total, int active, int completed) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(0, 'Todas ($total)'),
          const SizedBox(width: 8),
          _filterChip(1, 'En progreso ($active)'),
          const SizedBox(width: 8),
          _filterChip(2, 'Cumplidas ($completed)'),
        ],
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    final isSelected = _filterIndex == index;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _filterIndex = index);
      },
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalModel goal, ColorScheme colorScheme, bool isDark) {
    final color = goal.colorValue;
    final isCompleted = goal.isCompleted || goal.currentAmount >= goal.targetAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : color.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id)),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(goal.iconData, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            goal.targetDate != null
                                ? (goal.isOverdue
                                    ? 'Vencida'
                                    : 'Meta: ${goal.targetDate!.day}/${goal.targetDate!.month}/${goal.targetDate!.year}')
                                : 'Sin fecha límite',
                            style: TextStyle(
                              fontSize: 12,
                              color: goal.isOverdue ? const Color(0xFFF43F5E) : colorScheme.onSurfaceVariant,
                              fontWeight: goal.isOverdue ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted ? '✓ Cumplida' : '${goal.progressPercentage}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isCompleted ? const Color(0xFF10B981) : color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? const Color(0xFF10B981) : color,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ahorrado',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            Formatters.currency(goal.currentAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Objetivo',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            Formatters.currency(goal.targetAmount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.savings_rounded, size: 64, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alcancías y Metas de Ahorro',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea metas para tus vacaciones, fondo de emergencias o compras grandes, y haz un seguimiento paso a paso de tu progreso.',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditGoalScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear mi primera meta'),
            ),
          ],
        ),
      ),
    );
  }
}
