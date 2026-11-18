import 'package:csv/csv.dart';

/// FR-NA-13: encode tabular rows as CSV text.
String encodeCsv(
  List<Map<String, Object?>> rows, {
  List<String>? headers,
}) {
  if (rows.isEmpty && headers == null) return '';
  final columns = headers ?? rows.first.keys.toList();
  final table = <List<Object?>>[
    columns,
    ...rows.map((row) => columns.map((header) => row[header] ?? '').toList()),
  ];
  return const ListToCsvConverter().convert(table);
}

String timestampFileName(String prefix) {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${prefix}_${now.year}${two(now.month)}${two(now.day)}'
      '_${two(now.hour)}${two(now.minute)}${two(now.second)}.csv';
}
