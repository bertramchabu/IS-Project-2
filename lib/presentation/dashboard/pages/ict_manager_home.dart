import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/app_error_logger.dart';
import '../../../core/utils/csv_util.dart';
import '../../../core/utils/platform_actions.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../../data/models/prediction_model.dart';
import '../../../data/models/user_models.dart';
import '../../../data/repositories/model_inference_repository.dart';
import '../../../di/service_locator.dart' as di;
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/widgets/user_profile_dialog.dart';
import '../../widgets/glass_ui.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _ICTColors {
  static const bg = Color(0xFF0A0E17);
  static const surfaceAlt = Color(0xAA1A2332);
  static const border = Color(0x526A7D98);
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final ModelInferenceRepository _modelRepository;
  late Future<ModelApiStatus> _modelStatusFuture;

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
    'Quarter-to-Date',
  ];

  @override
  void initState() {
    super.initState();
    _modelRepository = di.sl<ModelInferenceRepository>();
    _modelStatusFuture = _loadModelStatus();
  }

  void _refreshModelStatus() {
    setState(() => _modelStatusFuture = _loadModelStatus());
  }

  Future<ModelApiStatus> _loadModelStatus() async {
    try {
      return await _modelRepository.checkStatus();
    } catch (error) {
      AppErrorLogger.log('ICTManagerHome.modelStatus', error);
      rethrow;
    }
  }

  ({DateTime start, DateTime end}) _selectedReportWindow() {
    final end = DateTime.now().toUtc();
    final start = switch (_selectedDateRange) {
      'Last 24 Hours' => end.subtract(const Duration(hours: 24)),
      'Last 7 Days' => end.subtract(const Duration(days: 7)),
      'Quarter-to-Date' => DateTime.utc(
          end.year,
          ((end.month - 1) ~/ 3) * 3 + 1,
        ),
      _ => end.subtract(const Duration(days: 30)),
    };
    return (start: start, end: end);
  }

  Future<_ReportData> _loadReportData() async {
    final window = _selectedReportWindow();
    final start = Timestamp.fromDate(window.start);
    final end = Timestamp.fromDate(window.end);
    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      _firestore
          .collectionGroup('kpiMetrics')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThan: end)
          .get(),
      _firestore
          .collectionGroup('predictions')
          .where('predictionTimestamp', isGreaterThanOrEqualTo: start)
          .where('predictionTimestamp', isLessThan: end)
          .get(),
      _firestore.collection('networkNodes').get(),
    ]);

    final kpiSnapshot = results[0];
    final predictionSnapshot = results[1];
    final nodeSnapshot = results[2];

    String nodeIdFor(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final nodeId = doc.reference.parent.parent?.id;
      if (nodeId == null) {
        throw StateError(
            'Report record ${doc.id} is not under a network node.');
      }
      return nodeId;
    }

    return _ReportData(
      windowStart: window.start,
      windowEnd: window.end,
      activeNodeCount: nodeSnapshot.docs
          .where((doc) => doc.data()['isActive'] as bool? ?? true)
          .length,
      metrics: [
        for (final doc in kpiSnapshot.docs)
          KpiMetricModel.fromFirestore(doc, nodeIdFor(doc)),
      ],
      predictions: [
        for (final doc in predictionSnapshot.docs)
          PredictionModel.fromFirestore(doc, nodeIdFor(doc)),
      ],
    );
  }

  Future<void> _exportPdfReport(UserModel? user) async {
    setState(() => _isExporting = true);
    try {
      final reportData = await _loadReportData();
      ModelApiStatus? modelStatus;
      try {
        modelStatus = await _modelRepository.checkStatus();
      } catch (error) {
        AppErrorLogger.log('ICTManagerHome.reportModelStatus', error);
      }
      final modelReady =
          modelStatus?.isOnline == true && modelStatus?.isModelLoaded == true;

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
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Author: ${user?.username ?? 'ICT Manager'} (${user?.role.displayName ?? 'Manager'})',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600),
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
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'This report covers ${DateFormat('MMM d, yyyy HH:mm').format(reportData.windowStart.toLocal())} '
                'through ${DateFormat('MMM d, yyyy HH:mm').format(reportData.windowEnd.toLocal())}. '
                '${reportData.activeNodeCount} active nodes are registered. '
                'The selected window contains ${reportData.metrics.length} KPI samples '
                'and ${reportData.predictions.length} persisted model predictions. '
                'Uptime, MTBF, and false-positive rates are not inferred because the '
                'required ground-truth records are not available.',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 14),

              // Infrastructure metrics table
              pw.Text(
                '2. Infrastructure Summary',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Metric',
                  'Target Benchmark',
                  'Achieved Value',
                  'Compliance Status'
                ],
                data: [
                  [
                    'Network Uptime / Availability',
                    '>= 99.50%',
                    'Not measured',
                    'Unavailable'
                  ],
                  [
                    'Mean Time Between Failures (MTBF)',
                    '>= 120 hrs',
                    'Not measured',
                    'Unavailable'
                  ],
                  [
                    'Active network nodes',
                    'Live inventory',
                    '${reportData.activeNodeCount}',
                    'Firestore count'
                  ],
                  [
                    'KPI samples in selected window',
                    'Persisted telemetry',
                    '${reportData.metrics.length}',
                    reportData.metrics.isEmpty ? 'No data' : 'Measured'
                  ],
                ],
                headerStyle:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                cellHeight: 22,
              ),
              pw.SizedBox(height: 14),

              if (_includeChartsInReport) ...[
                pw.Text(
                  '3. KPI Summary',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['Metric', 'Samples', 'Average', 'Peak', 'Unit'],
                  data: [
                    for (final type in MetricType.values)
                      _metricSummaryRow(reportData.metrics, type),
                  ],
                  headerStyle:
                      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  cellHeight: 22,
                ),
                pw.SizedBox(height: 14),
              ],

              // Model performance table
              pw.Text(
                '4. BiLSTM Model Status and Evaluation',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [
                  'AI Model Parameter',
                  'Research Target',
                  'Achieved Result',
                  'Evaluation'
                ],
                data: [
                  [
                    'Inference API / model artifacts',
                    'API online and model loaded',
                    modelReady ? 'Ready' : 'Unavailable',
                    modelReady ? 'Connected' : 'Check API'
                  ],
                  [
                    'Fault Prediction F1-Score',
                    '>= 0.85',
                    modelStatus?.f1Score?.toStringAsFixed(4) ?? 'Not reported',
                    modelStatus?.f1Score == null
                        ? 'Not reported'
                        : modelStatus!.f1Score! >= 0.85
                            ? 'Target met'
                            : 'Below target'
                  ],
                  [
                    'Root Mean Squared Error (RMSE)',
                    '<= 0.10',
                    modelStatus?.rmse?.toStringAsFixed(4) ?? 'Not reported',
                    modelStatus?.rmse == null
                        ? 'Not reported'
                        : modelStatus!.rmse! <= 0.10
                            ? 'Target met'
                            : 'Above target'
                  ],
                  [
                    'Adaptive inference reduction',
                    'Configured by deployed function',
                    modelReady ? 'Available' : 'Not verified',
                    modelReady ? 'Model online' : 'Unavailable'
                  ],
                ],
                headerStyle:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                cellHeight: 22,
              ),
              pw.SizedBox(height: 14),

              pw.Text(
                '5. Prediction Activity',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Measure', 'Result'],
                data: [
                  ['Persisted predictions', '${reportData.predictions.length}'],
                  [
                    'Predictions above 70% probability',
                    '${reportData.predictions.where((p) => p.faultProbability >= 0.70).length}',
                  ],
                  [
                    'Average fault probability',
                    reportData.predictions.isEmpty
                        ? 'No data'
                        : '${(reportData.predictions.map((p) => p.faultProbability).reduce((a, b) => a + b) / reportData.predictions.length * 100).toStringAsFixed(1)}%',
                  ],
                ],
                headerStyle:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                cellHeight: 22,
              ),
              pw.SizedBox(height: 14),

              pw.Text(
                '6. Data Limitations',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Bullet(
                text:
                    'Alert thresholds and prediction outcomes are model outputs, not verified incidents.',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Bullet(
                text:
                    'Uptime, MTBF, detection lead time, false-positive rate, and SLA compliance require incident and service-availability ground truth.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name:
            'NetVision_AI_Executive_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      AppErrorLogger.log('ICTManagerHome.exportPdf', e);
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

  List<String> _metricSummaryRow(
    List<KpiMetricModel> metrics,
    MetricType type,
  ) {
    final matching = metrics.where((metric) => metric.metricType == type);
    if (matching.isEmpty) {
      return [type.name, '0', 'No data', 'No data', ''];
    }
    final values = matching.map((metric) => metric.value).toList();
    final average = values.reduce((a, b) => a + b) / values.length;
    final peak = values.reduce((a, b) => a > b ? a : b);
    final unit = matching.first.unit;
    return [
      matching.first.displayName,
      '${values.length}',
      average.toStringAsFixed(2),
      peak.toStringAsFixed(2),
      unit,
    ];
  }

  Future<void> _exportCsvData() async {
    setState(() => _isExporting = true);
    try {
      final reportData = await _loadReportData();
      final rows = <Map<String, Object?>>[
        for (final metric in reportData.metrics)
          {
            'record_type': 'kpi',
            'node_id': metric.nodeId,
            'timestamp': metric.timestamp.toUtc().toIso8601String(),
            'metric': metric.metricTypeId,
            'value': metric.value,
            'unit': metric.unit,
            'fault_probability': '',
            'severity': '',
            'model_version': '',
            'alert_triggered': '',
          },
        for (final prediction in reportData.predictions)
          {
            'record_type': 'prediction',
            'node_id': prediction.nodeId,
            'timestamp':
                prediction.predictionTimestamp.toUtc().toIso8601String(),
            'metric': '',
            'value': '',
            'unit': '',
            'fault_probability': prediction.faultProbability,
            'severity': prediction.severityLabel,
            'model_version': prediction.modelVersionId,
            'alert_triggered': prediction.alertTriggered,
          },
      ];
      final csv = encodeCsv(
        rows,
        headers: const [
          'record_type',
          'node_id',
          'timestamp',
          'metric',
          'value',
          'unit',
          'fault_probability',
          'severity',
          'model_version',
          'alert_triggered',
        ],
      );
      final fileName = timestampFileName(
        'netvision_${_selectedDateRange.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      );
      final location = await downloadCsv(fileName, csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rows.isEmpty
                ? 'No KPI or prediction records found for this time window. Empty CSV saved to $location'
                : 'Exported ${reportData.metrics.length} KPI samples and '
                    '${reportData.predictions.length} predictions to $location'),
            backgroundColor: _ICTColors.surfaceAlt,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      AppErrorLogger.log('ICTManagerHome.exportCsv', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not export report data: $error'),
            backgroundColor: _ICTColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authenticatedUserFrom(authState);
    final username = user?.username ?? 'ICT Manager';
    final initials = username.isNotEmpty ? username[0].toUpperCase() : 'M';

    return Scaffold(
      backgroundColor: _ICTColors.bg,
      appBar: _buildAppBar(context, user, username, initials),
      body: GlassBackground(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        _buildModelPerformanceCard(),
                        const SizedBox(height: 18),
                        _buildAlertTrendsCard(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildModelPerformanceCard()),
                      const SizedBox(width: 18),
                      Expanded(flex: 6, child: _buildAlertTrendsCard()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Bottom Section: Executive Summary Report Generator
              _buildReportGeneratorCard(user),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, UserModel? user, String username, String initials) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return AppBar(
      elevation: 0,
      backgroundColor: Color(0xCC111827),
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: _ICTColors.border, width: 1),
      ),
      titleSpacing: compact ? 12 : 24,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'NetVision AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: _ICTColors.textPrimary,
                ),
              ),
              if (!compact)
                const Text(
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
        if (!compact)
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
        if (!compact) const SizedBox(width: 12),
        // User Profile Clickable Chip
        InkWell(
          onTap:
              user == null ? null : () => UserProfileDialog.show(context, user),
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
                if (!compact) ...[
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ICTColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _ICTColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('networkNodes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print(
              '[ICTManagerHome] Node summary stream error: ${snapshot.error}');
          return _dashboardDataError('Unable to load network node status.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeNodes = snapshot.data!.docs.where(
          (doc) => (doc.data()['isActive'] as bool? ?? true),
        );
        var healthy = 0;
        var warning = 0;
        var critical = 0;
        for (final node in activeNodes) {
          switch ((node.data()['status'] as String? ?? '').toLowerCase()) {
            case 'healthy':
              healthy++;
            case 'warning':
              warning++;
            case 'critical':
              critical++;
          }
        }

        final cards = [
          (
            title: 'ACTIVE NODES',
            value: '${activeNodes.length}',
            subtitle: 'Registered and enabled',
            icon: Icons.hub_rounded,
            color: _ICTColors.accent,
          ),
          (
            title: 'HEALTHY',
            value: '$healthy',
            subtitle: 'Current node status',
            icon: Icons.check_circle_outline_rounded,
            color: _ICTColors.healthy,
          ),
          (
            title: 'WARNING',
            value: '$warning',
            subtitle: 'Require attention',
            icon: Icons.warning_amber_rounded,
            color: _ICTColors.warning,
          ),
          (
            title: 'CRITICAL',
            value: '$critical',
            subtitle: 'Current critical state',
            icon: Icons.error_outline_rounded,
            color: _ICTColors.critical,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final card in cards)
                  _buildStatCard(
                    title: card.title,
                    value: card.value,
                    subtitle: card.subtitle,
                    icon: card.icon,
                    color: card.color,
                    width: width,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dashboardDataError(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _ICTColors.critical.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ICTColors.critical.withOpacity(0.3)),
        ),
        child:
            Text(message, style: const TextStyle(color: _ICTColors.critical)),
      );

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: GlassSurface(
        padding: const EdgeInsets.all(18),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: _ICTColors.textMuted,
                    ),
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
      ),
    );
  }

  Widget _buildModelPerformanceCard() {
    return GlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.psychology_rounded,
                        color: _ICTColors.accent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BiLSTM PREDICTIVE ENGINE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: _ICTColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh model status',
                onPressed: _refreshModelStatus,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: _ICTColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<ModelApiStatus>(
            future: _modelStatusFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _dashboardDataError(
                  'Model API unavailable. Start the inference service to view model metrics.',
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final status = snapshot.data!;
              final ready = status.isOnline && status.isModelLoaded;
              final f1 = status.f1Score;
              final rmse = status.rmse;
              return Column(
                children: [
                  _buildEvaluationRow(
                    'Model API status',
                    ready
                        ? 'READY'
                        : status.isOnline
                            ? 'MODEL NOT LOADED'
                            : 'OFFLINE',
                    status.message,
                    ready,
                  ),
                  const Divider(height: 16, color: _ICTColors.border),
                  _buildEvaluationRow(
                    'F1-score (held-out evaluation)',
                    f1?.toStringAsFixed(4) ?? 'Not available',
                    'Proposal target >= 0.85',
                    f1 != null && f1 >= 0.85,
                  ),
                  const Divider(height: 16, color: _ICTColors.border),
                  _buildEvaluationRow(
                    'RMSE (held-out evaluation)',
                    rmse?.toStringAsFixed(4) ?? 'Not available',
                    'Proposal target <= 0.10',
                    rmse != null && rmse <= 0.10,
                  ),
                  const Divider(height: 16, color: _ICTColors.border),
                  _buildEvaluationRow(
                    'Model version',
                    status.modelVersion,
                    'Read from model metadata',
                    ready,
                  ),
                  const Divider(height: 16, color: _ICTColors.border),
                  _buildEvaluationRow(
                    'Adaptive compute reduction',
                    ready ? '90% configured' : 'Not available',
                    'When fault probability < 30%',
                    ready,
                  ),
                ],
              );
            },
          ),
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
              style:
                  const TextStyle(fontSize: 10.5, color: _ICTColors.textMuted),
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
    return GlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 14,
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
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collectionGroup('alerts')
                .orderBy('createdAt', descending: true)
                .limit(500)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print(
                    '[ICTManagerHome] Alert trend stream error: ${snapshot.error}');
                return _dashboardDataError('Unable to load alert trends.');
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 170,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final now = DateTime.now();
              final weekStart = DateTime(now.year, now.month, now.day)
                  .subtract(Duration(days: now.weekday - 1));
              final counts = List.generate(7, (_) => List<double>.filled(4, 0));
              for (final doc in snapshot.data!.docs) {
                final data = doc.data();
                final created = (data['createdAt'] as Timestamp?)?.toDate();
                if (created == null ||
                    created.isBefore(weekStart) ||
                    !created.isBefore(weekStart.add(const Duration(days: 7)))) {
                  continue;
                }
                final severity =
                    (data['severityId'] as String? ?? '').toLowerCase();
                final severityIndex = switch (severity) {
                  'critical' => 0,
                  'high' => 1,
                  'medium' => 2,
                  'low' => 3,
                  _ => -1,
                };
                if (severityIndex >= 0) {
                  counts[created.weekday - 1][severityIndex]++;
                }
              }

              final groups = [
                for (var day = 0; day < counts.length; day++)
                  _barGroup(
                    day,
                    counts[day][0],
                    counts[day][1],
                    counts[day][2],
                    counts[day][3],
                  ),
              ];
              final maxCount = counts
                  .map(
                      (day) => day.fold<double>(0, (sum, value) => sum + value))
                  .reduce((a, b) => a > b ? a : b);
              if (maxCount == 0) {
                return const SizedBox(
                  height: 170,
                  child: Center(
                    child: Text(
                      'No alerts recorded this week.',
                      style: TextStyle(color: _ICTColors.textMuted),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 170,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxCount < 5 ? 5 : maxCount * 1.2,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            const days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun'
                            ];
                            final idx = val.toInt();
                            if (idx >= 0 && idx < days.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  days[idx],
                                  style: const TextStyle(
                                      color: _ICTColors.textMuted,
                                      fontSize: 10),
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
                          getTitlesWidget: (val, meta) => Text(
                            val.toInt().toString(),
                            style: const TextStyle(
                                color: _ICTColors.textMuted, fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
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
                    barGroups: groups,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(
      int x, double crit, double high, double med, double low) {
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
            BarChartRodStackItem(
                low + med, low + med + high, const Color(0xFFFB923C)),
            BarChartRodStackItem(
                low + med + high, low + med + high + crit, _ICTColors.critical),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: _ICTColors.textMuted)),
      ],
    );
  }

  Widget _buildReportGeneratorCard(UserModel? user) {
    return GlassSurface(
      padding: const EdgeInsets.all(24),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: _ICTColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'EXECUTIVE REPORT GENERATION & EXPORT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _ICTColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportCsvData,
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: const Text('Export to CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ICTColors.textPrimary,
                      side: const BorderSide(color: _ICTColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        _isExporting ? null : () => _exportPdfReport(user),
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
                    label:
                        Text(_isExporting ? 'Generating...' : 'Export as PDF'),
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
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final width = constraints.maxWidth;
              final gap = isNarrow ? 12.0 : 16.0;
              final reportTypeWidth = isNarrow
                  ? (width < 440 ? width : (width - gap) / 2)
                  : (width - 2 * gap) * 0.4;
              final dateRangeWidth = isNarrow
                  ? (width < 440 ? width : (width - gap) / 2)
                  : (width - 2 * gap) * 0.3;
              final optionWidth = isNarrow ? width : (width - 2 * gap) * 0.3;

              return Wrap(
                spacing: gap,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: reportTypeWidth,
                    child: _reportDropdown(
                      title: 'Report Type',
                      value: _selectedReportType,
                      values: _reportTypes,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedReportType = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: dateRangeWidth,
                    child: _reportDropdown(
                      title: 'Time Window',
                      value: _selectedDateRange,
                      values: _dateRanges,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedDateRange = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: optionWidth,
                    child: _reportOptions(),
                  ),
                ],
              );
            },
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = Text(
                      'PREVIEW: $_selectedReportType ($_selectedDateRange)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: _ICTColors.accent,
                      ),
                    );
                    const status = Text(
                      'Status: Ready to Export',
                      style: TextStyle(fontSize: 11, color: _ICTColors.healthy),
                    );
                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 6), status],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 12),
                        status,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Exports use persisted KPI and prediction records in the selected time window.\n'
                  '• Model version, F1-score, and RMSE are read from inference API metadata.\n'
                  '• Uptime, MTBF, detection lead time, false-positive rate, and SLA compliance require ground-truth incident data.',
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

  Widget _reportDropdown({
    required String title,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _ICTColors.textMuted,
          ),
        ),
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
              value: value,
              isExpanded: true,
              dropdownColor: _ICTColors.surfaceAlt,
              style: const TextStyle(
                color: _ICTColors.textPrimary,
                fontSize: 13,
              ),
              items: values
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _reportOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Options',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _ICTColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                visualDensity: VisualDensity.compact,
                onChanged: (value) {
                  setState(() => _includeChartsInReport = value ?? true);
                },
              ),
              const Expanded(
                child: Text(
                  'Include KPI summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _ICTColors.textPrimary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.windowStart,
    required this.windowEnd,
    required this.activeNodeCount,
    required this.metrics,
    required this.predictions,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final int activeNodeCount;
  final List<KpiMetricModel> metrics;
  final List<PredictionModel> predictions;
}
