import 'package:flutter/material.dart';

import '../../../data/repositories/threat_model_inference_repository.dart';

class ThreatModelStatusCard extends StatelessWidget {
  final Future<ThreatModelApiStatus> statusFuture;
  final VoidCallback onRefresh;
  final VoidCallback onRunDemo;

  const ThreatModelStatusCard({
    super.key,
    required this.statusFuture,
    required this.onRefresh,
    required this.onRunDemo,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThreatModelApiStatus>(
      future: statusFuture,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final ready = status?.isOnline == true && status?.isModelLoaded == true;
        final statusText = snapshot.hasError
            ? 'Unavailable'
            : snapshot.connectionState == ConnectionState.waiting
                ? 'Checking cloud model…'
                : ready
                    ? 'Online • ${status!.modelVersion}'
                    : 'Model not loaded';
        final width = MediaQuery.sizeOf(context).width;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(
                ready ? Icons.shield_rounded : Icons.shield_outlined,
                color: ready ? Colors.greenAccent : Colors.orangeAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLOUD THREAT MODEL • SIMULATION ONLY',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status == null
                          ? statusText
                          : '$statusText • ${status.inputFeatureCount} features • '
                              '${status.forecastHorizonMinutes}-minute risk',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    if (status != null)
                      Text(
                        '${status.classifier} • ${status.datasetVersion}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    if (snapshot.hasError)
                      Text(
                        snapshot.error.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh threat model status',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
              if (width >= 520)
                OutlinedButton.icon(
                  onPressed: onRunDemo,
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: const Text('Run synthetic demo'),
                )
              else
                IconButton(
                  tooltip: 'Run synthetic threat demo',
                  onPressed: onRunDemo,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
            ],
          ),
        );
      },
    );
  }
}
