import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/progress_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Progress screen with radar chart and category breakdowns
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _selectedPeriod = 'June 2026';

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(authProvider).selectedChildId ?? 'child_1';
    final child = MockData.getChildById(childId);
    final progress = MockData.getProgressForChild(childId, period: _selectedPeriod);
    final prevProgress = MockData.getProgressForChild(childId, period: 'May 2026');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Progress Report',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Child Header ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.purpleGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('📊', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${child?.firstName ?? "Child"}\'s Progress',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          child?.className ?? '',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Period Selector ────────────────────────────
            Row(
              children: [
                _PeriodChip('June 2026', _selectedPeriod == 'June 2026', () {
                  setState(() => _selectedPeriod = 'June 2026');
                }),
                const SizedBox(width: 8),
                _PeriodChip('May 2026', _selectedPeriod == 'May 2026', () {
                  setState(() => _selectedPeriod = 'May 2026');
                }),
              ],
            ),

            const SizedBox(height: 20),

            // ─── Radar Chart ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Skills Overview',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: progress.isNotEmpty
                        ? RadarChart(
                            RadarChartData(
                              radarShape: RadarShape.polygon,
                              dataSets: [
                                RadarDataSet(
                                  fillColor:
                                      AppColors.accent.withValues(alpha: 0.2),
                                  borderColor: AppColors.accent,
                                  borderWidth: 2,
                                  entryRadius: 4,
                                  dataEntries: progress
                                      .map((p) =>
                                          RadarEntry(value: p.score))
                                      .toList(),
                                ),
                                if (prevProgress.isNotEmpty)
                                  RadarDataSet(
                                    fillColor: AppColors.textTertiary
                                        .withValues(alpha: 0.05),
                                    borderColor: AppColors.textTertiary
                                        .withValues(alpha: 0.3),
                                    borderWidth: 1,
                                    entryRadius: 3,
                                    dataEntries: prevProgress
                                        .map((p) =>
                                            RadarEntry(value: p.score))
                                        .toList(),
                                  ),
                              ],
                              titlePositionPercentageOffset: 0.2,
                              titleTextStyle: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                              getTitle: (index, angle) {
                                if (index < progress.length) {
                                  return RadarChartTitle(
                                    text: progress[index].categoryEmoji,
                                  );
                                }
                                return const RadarChartTitle(text: '');
                              },
                              tickCount: 5,
                              ticksTextStyle: GoogleFonts.nunito(
                                fontSize: 9,
                                color: AppColors.textTertiary,
                              ),
                              tickBorderData: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.5),
                              ),
                              gridBorderData: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.3),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              'No data for this period',
                              style: GoogleFonts.nunito(
                                  color: AppColors.textTertiary),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Category Breakdown ─────────────────────────
            Text(
              'Detailed Breakdown',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            ...progress.map((p) {
              final prevData = prevProgress
                  .where((prev) => prev.category == p.category);
              final prevScore =
                  prevData.isNotEmpty ? prevData.first.score : null;
              final improvement =
                  prevScore != null ? p.score - prevScore : null;

              return _ProgressCategoryCard(
                progress: p,
                improvement: improvement,
              );
            }),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProgressCategoryCard extends StatelessWidget {
  final ProgressModel progress;
  final double? improvement;

  const _ProgressCategoryCard({
    required this.progress,
    this.improvement,
  });

  Color get _categoryColor {
    switch (progress.category) {
      case ProgressCategory.social:
        return AppColors.progressSocial;
      case ProgressCategory.motor:
        return AppColors.progressMotor;
      case ProgressCategory.cognitive:
        return AppColors.progressCognitive;
      case ProgressCategory.language:
        return AppColors.progressLanguage;
      case ProgressCategory.creative:
        return AppColors.progressCreative;
      case ProgressCategory.emotional:
        return AppColors.progressEmotional;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                progress.categoryEmoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.categoryLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (improvement != null)
                      Text(
                        improvement! > 0
                            ? '+${improvement!.toStringAsFixed(1)} from last month'
                            : '${improvement!.toStringAsFixed(1)} from last month',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: improvement! >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${progress.score}/5',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _categoryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.score / 5.0,
              minHeight: 8,
              backgroundColor: _categoryColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_categoryColor),
            ),
          ),
          if (progress.teacherNotes != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded,
                      size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      progress.teacherNotes!,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
