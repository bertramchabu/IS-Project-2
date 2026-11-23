import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rules test specification contains required security cases', () {
    final spec = jsonDecode(
      File('test/firestore_rules/rules_test_spec.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases = spec['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(7));
    expect(
      cases.any((entry) =>
          (entry as Map<String, dynamic>)['name'] ==
          'unknown role is not network administrator'),
      isTrue,
    );
  });
}
