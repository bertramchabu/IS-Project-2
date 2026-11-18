import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/core/utils/csv_util.dart';

void main() {
  test('encodes rows using stable headers and escapes CSV values', () {
    final csv = encodeCsv(
      [
        {'name': 'Node, "A"', 'status': 'Active'},
      ],
      headers: const ['name', 'status', 'missing'],
    );

    expect(csv, 'name,status,missing\r\n"Node, ""A""",Active,');
  });

  test('writes headers for an empty export', () {
    expect(
      encodeCsv(const [], headers: const ['record_type', 'node_id']),
      'record_type,node_id',
    );
  });

  test('returns an empty string when no rows or headers are supplied', () {
    expect(encodeCsv(const []), isEmpty);
  });
}
