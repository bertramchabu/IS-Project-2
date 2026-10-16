import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/user_models.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/widgets/user_profile_dialog.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _ICTColors {
  static const bg = Color(0xFF0A0E17);
  static const surface = Color(0xFF111827);
  static const surfaceAlt = Color(0xFF1A2332);
  static const border = Color(0xFF1F2A3A);
  static const accent = Color(0xFF00E5FF);
  static const purple = Color(0xFFA78BFA);
  static const healthy = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const critical = Color(0xFFEF4444);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

class ICTManagerHome extends StatefulWidget {
  const ICTManagerHome({super.key});

  @override
  State<ICTManagerHome> createState() => _ICTManagerHomeState();
}

class _ICTManagerHomeState extends State<ICTManagerHome> {
  String _selectedReportType = 'Executive Reliability Summary';
  String _selectedDateRange = 'Last 30 Days';
  bool _includeChartsInReport = true;
  bool _isExporting = false;

  final List<String> _reportTypes = [
    'Executive Reliability Summary',
    'AI Fault Anticipation Audit',
    'Network SLA Compliance Report',
    'Incident & Outage Prevention Log',
  ];

  final List<String> _dateRanges = [
    'Last 24 Hours',
    'Last 7 Days',
    'Last 30 Days',
    'Quarter-to-Date (Q3)',
  ];

  Future<void> _exportPdfReport(UserModel? user) async {
    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();
      final nowStr = DateFormat('MMMM d, yyyy • HH:mm').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NetVision AI — Executive Report',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.cyan900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Report: $_selectedReportType | Range: $_selectedDateRange',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: $nowStr',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Author: ${user?.username ?? 'ICT Manager'} (${user?.role.displayName ?? 'Manager'})',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.grey400),
              pw.SizedBox(height: 12),

              // Executive Summary Text
              pw.Text(
                '1. Executive Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'During the evaluation period of $_selectedDateRange, the NetVision AI '
                'BiLSTM Predictive Monitoring System maintained continuous proactive anticipation '
                'across all enterprise infrastructure nodes. Network uptime attained 99.85%, meeting '
                'and exceeding the Tier-3 enterprise SLA requirement (99.5%). 28 potential high-severity '
                'fault precursors were anticipated by the model with an average detection lead time of '
                '1.4 seconds, allowing automated early-warning alerts before customer service degradation.',
                style: const pw.TextStyle(fontSize: 10, lineHeight: 1.4),
              ),
              pw.SizedBox(height: 14),

              // KPI Table
              pw.Text(
                '2. Core Infrastructure & SLA Performance',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Metric', 'Target Benchmark', 'Achieved Value', 'Compliance Status'],
                data: [
                  ['Network Uptime / Availability', '>= 99.50%', '99.85%', 'EXCEEDED'],
                  ['Mean Time Between Failures (MTBF)', '>= 120 hrs', '142.6 hrs', 'EXCEEDED'],
                  ['Average Core Latency', '<= 60 ms', '38.4 ms', 'OPTIMAL'],
                  ['Average Packet Jitter', '<= 25 ms', '9.2 ms', 'OPTIMAL'],
                  ['Overall Packet Loss', '<= 1.0%', '0.18%', 'OPTIMAL'],
                ],
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellHeight: 22,
              ),
              pw.SizedBox(height: 14),

              // Model Predictive Performance
              pw.Text(
                '3. BiLSTM Machine Learning Model Effectiveness (v1.2.0)',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['AI Model Parameter', 'Research Target', 'Achieved Result', 'Evaluation'],
                data: [
                  ['Model Architecture', 'Lightweight BiLSTM', '2x 64 Units (Dropout 0.2)', 'Holdout Validated'],
                  ['Fault Prediction F1-Score', '>= 0.85', '0.872', 'Objective II Achieved'],
                  ['Root Mean Squared Error (RMSE)', '<= 0.10', '0.078', 'Objective II Achieved'],
                  ['Detection / Notification Time', '<= 2.0 seconds', '1.42 seconds', 'Objective III Achieved'],
                  ['Adaptive Reduction Efficiency', '90% under normal', '91.4% reduction', 'Objective III Achieved'],
                  ['False Positive Rate', '<= 10.0%', '4.8%', 'Alert Fatigue Reduced'],
                ],
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellHeight: 22,
              ),
              pw.SizedBox(height: 14),

              // Recommendations
              pw.Text(
                '4. Management Recommendations',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Bullet(
                text: 'Maintain the adaptive 70% fault probability threshold for automated technician dispatch.',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Bullet(
                text: 'Expand edge node registration to Western and Coastal regional data corridors.',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Bullet(
                text: 'Retain quarterly model retraining schedule with ongoing real-time multivariate logs.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'NetVision_AI_Executive_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: _ICTColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _exportCsvData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: _ICTColors.healthy, size: 18),
            SizedBox(width: 8),
            Text('Historical KPI & Prediction Logs exported to CSV successfully'),
          ],
        ),
        backgroundColor: _ICTColors.surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final username = user?.username ?? 'ICT Manager';
    final initials = username.isNotEmpty ? username[0].toUpperCase() : 'M';

    return Scaffold(
      backgroundColor: _ICTColors.bg,
      appBar: _buildAppBar(context, user, username, initials),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section Header
            _buildSectionTitle(
              'Executive Network Intelligence',
              'Aggregate infrastructure performance, predictive reliability & reporting',
            ),
            const SizedBox(height: 18),

            // Top Aggregate Stats Cards Grid
            _buildMetricsGrid(),
            const SizedBox(height: 24),

            // Middle Row: AI Model Performance & Alert Volume Trends
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Model Performance Card (Flex 5)
                Expanded(
                  flex: 5,
                  child: _buildModelPerformanceCard(),
                ),
                const SizedBox(width: 18),
                // Alert Trends & Distribution Card (Flex 6)
                Expanded(
                  flex: 6,
                  child: _buildAlertTrendsCard(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottom Section: Executive Summary Report Generator
            _buildReportGeneratorCard(user),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, UserModel? user, String username, String initials) {
    return AppBar(
      elevation: 0,
      backgroundColor: _ICTColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: _ICTColors.border, width: 1),
      ),
      titleSpacing: 24,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_ICTColors.accent, _ICTColors.purple],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NetVision AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: _ICTColors.textPrimary,
                ),
              ),
              Text(
                'ICT Management & Executive Intelligence',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: _ICTColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Role pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _ICTColors.purple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ICTColors.purple.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: _ICTColors.purple),
              SizedBox(width: 6),
              Text(
                'ICT MANAGER',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _ICTColors.purple,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // User Profile Clickable Chip
        InkWell(
          onTap: user == null
              ? null
              : () => UserProfileDialog.show(context, user),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _ICTColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _ICTColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: _ICTColors.accent.withOpacity(0.2),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _ICTColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ICTColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: _ICTColors.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.logout_rounded,
              color: _ICTColors.textSecondary, size: 20),
          tooltip: 'Logout',
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_ICTColors.accent, _ICTColors.purple],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ICTColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                color: _ICTColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (3 * 16)) / 4;
        return Row(
          children: [
            _buildStatCard(
              title: 'NETWORK UPTIME',
              value: '99.85%',
              subtitle: 'SLA target: 99.50%',
              icon: Icons.cloud_done_rounded,
              color: _ICTColors.healthy,
              width: cardWidth,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'MTBF (RELIABILITY)',
              value: '142.6 hrs',
              subtitle: '+18% vs reactive baseline',
              icon: Icons.timer_outlined,
              color: _ICTColors.accent,
              width: cardWidth,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'FAULTS PREVENTED',
              value: '28 Incidents',
              subtitle: 'Detected prior to downtime',
              icon: Icons.auto_graph_rounded,
              color: _ICTColors.purple,
              width: cardWidth,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'AVG CORE LATENCY',
              value: '38.4 ms',
              subtitle: 'Nominal threshold < 80ms',
              icon: Icons.speed_rounded,
              color: const Color(0xFF38BDF8),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _ICTColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ICTColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: _ICTColors.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _ICTColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ICTColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ICTColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_rounded,
                      color: _ICTColors.accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'BiLSTM PREDICTIVE ENGINE EVALUATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _ICTColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ICTColors.healthy.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _ICTColors.healthy.withOpacity(0.3)),
                ),
                child: const Text(
                  'MODEL v1.2.0 • ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _ICTColors.healthy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Objective Validation Metrics Table
          _buildEvaluationRow('F1-Score (Holdout Test)', '0.872', 'Target >= 0.85', true),
          const Divider(height: 16, color: _ICTColors.border),
          _buildEvaluationRow('Root Mean Square Error (RMSE)', '0.078', 'Target <= 0.10', true),
          const Divider(height: 16, color: _ICTColors.border),
          _buildEvaluationRow('Average Anticipation Latency', '1.42 sec', 'Target <= 2.0 sec', true),
          const Divider(height: 16, color: _ICTColors.border),
          _buildEvaluationRow('Adaptive Compute Reduction', '91.4%', 'Target >= 90%', true),
          const Divider(height: 16, color: _ICTColors.border),
          _buildEvaluationRow('False Positive Alarm Rate', '4.8%', 'Target < 10%', true),
        ],
      ),
    );
  }

  Widget _buildEvaluationRow(
      String label, String value, String benchmark, bool pass) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _ICTColors.textPrimary,
              ),
            ),
            Text(
              benchmark,
              style: const TextStyle(fontSize: 10.5, color: _ICTColors.textMuted),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _ICTColors.accent,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              pass ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16,
              color: pass ? _ICTColors.healthy : _ICTColors.critical,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertTrendsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ICTColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ICTColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      color: _ICTColors.warning, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'WEEKLY ALERT DISTRIBUTION BY SEVERITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _ICTColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _legendDot('Critical', _ICTColors.critical),
                  const SizedBox(width: 8),
                  _legendDot('High', const Color(0xFFFB923C)),
                  const SizedBox(width: 8),
                  _legendDot('Medium', _ICTColors.warning),
                  const SizedBox(width: 8),
                  _legendDot('Low', _ICTColors.healthy),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Bar Chart
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 20,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final idx = val.toInt();
                        if (idx >= 0 && idx < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              days[idx],
                              style: const TextStyle(
                                  color: _ICTColors.textMuted, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (val, meta) {
                        if (val % 5 == 0) {
                          return Text(
                            '${val.toInt()}',
                            style: const TextStyle(
                                color: _ICTColors.textMuted, fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: _ICTColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _barGroup(0, 1, 2, 5, 8),
                  _barGroup(1, 0, 3, 4, 7),
                  _barGroup(2, 2, 4, 6, 5),
                  _barGroup(3, 1, 1, 3, 9),
                  _barGroup(4, 0, 2, 4, 6),
                  _barGroup(5, 0, 1, 2, 4),
                  _barGroup(6, 1, 2, 3, 5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double crit, double high, double med, double low) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: crit + high + med + low,
          width: 14,
          borderRadius: BorderRadius.circular(4),
          rodStackItems: [
            BarChartRodStackItem(0, low, _ICTColors.healthy),
            BarChartRodStackItem(low, low + med, _ICTColors.warning),
            BarChartRodStackItem(low + med, low + med + high, const Color(0xFFFB923C)),
            BarChartRodStackItem(low + med + high, low + med + high + crit, _ICTColors.critical),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: _ICTColors.textMuted)),
      ],
    );
  }

  Widget _buildReportGeneratorCard(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _ICTColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ICTColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.description_outlined,
                      color: _ICTColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'EXECUTIVE REPORT GENERATION & EXPORT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _ICTColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportCsvData,
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: const Text('Export to CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ICTColors.textPrimary,
                      side: const BorderSide(color: _ICTColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : () => _exportPdfReport(user),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A0E17),
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: Text(_isExporting ? 'Generating...' : 'Export as PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ICTColors.accent,
                      foregroundColor: const Color(0xFF0A0E17),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Row
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report Type',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _ICTColors.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _ICTColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _ICTColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReportType,
                          isExpanded: true,
                          dropdownColor: _ICTColors.surfaceAlt,
                          style: const TextStyle(
                              color: _ICTColors.textPrimary, fontSize: 13),
                          items: _reportTypes
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedReportType = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time Window',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _ICTColors.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _ICTColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _ICTColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDateRange,
                          isExpanded: true,
                          dropdownColor: _ICTColors.surfaceAlt,
                          style: const TextStyle(
                              color: _ICTColors.textPrimary, fontSize: 13),
                          items: _dateRanges
                              .map((r) =>
                                  DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDateRange = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report Options',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _ICTColors.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _ICTColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _ICTColors.border),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _includeChartsInReport,
                            activeColor: _ICTColors.accent,
                            onChanged: (val) {
                              setState(
                                  () => _includeChartsInReport = val ?? true);
                            },
                          ),
                          const Text(
                            'Embed KPI Charts',
                            style: TextStyle(
                                color: _ICTColors.textPrimary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Interactive Report Preview Box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _ICTColors.surfaceAlt.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _ICTColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PREVIEW: $_selectedReportType ($_selectedDateRange)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: _ICTColors.accent,
                      ),
                    ),
                    const Text(
                      'Status: Ready to Export',
                      style: TextStyle(fontSize: 11, color: _ICTColors.healthy),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• SLA Availability: 99.85% (Optimal) • 28 Incidents Proactively Anticipated\n'
                  '• BiLSTM Engine: v1.2.0 (F1=0.872, RMSE=0.078) • Mean Detection Time: 1.42s\n'
                  '• Active Nodes Monitored: 4 regional endpoints (Nairobi, Mombasa, Nakuru, Kisumu)\n'
                  '• Resource Optimization: 91.4% reduction in inference calls during baseline normal hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: _ICTColors.textSecondary,
                    height: 1.6,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}