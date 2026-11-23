import 'package:flutter_test/flutter_test.dart';

String retrainStatusText(Map<String, dynamic> data) {
  final status = data['status'] as String? ?? 'unknown';
  if (status == 'completed') {
    return 'F1=${data['f1']}, RMSE=${data['rmse']}';
  }
  if (status == 'failed') {
    return data['error'] as String? ?? 'Retraining failed';
  }
  return 'Request state: $status';
}

void main() {
  test('maps queued and in-progress request states', () {
    expect(retrainStatusText({'status': 'Queued'}),
        'Request state: Queued');
    expect(retrainStatusText({'status': 'in_progress'}),
        'Request state: in_progress');
  });

  test('maps completed metrics and failed errors', () {
    expect(
      retrainStatusText({'status': 'completed', 'f1': 0.8593, 'rmse': 0.0197}),
      'F1=0.8593, RMSE=0.0197',
    );
    expect(
      retrainStatusText({'status': 'failed', 'error': 'training error'}),
      'training error',
    );
  });
}
