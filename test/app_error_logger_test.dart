import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/core/utils/app_error_logger.dart';

void main() {
  group('AppErrorLogger', () {
    test('prints Firebase Functions error codes', () {
      final error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Access denied',
      );

      expect(
        AppErrorLogger.format('ThreatDemo', error),
        '[ThreatDemo] errorCode=permission-denied',
      );
    });

    test('prints Firebase and platform error codes', () {
      expect(
        AppErrorLogger.format(
          'Authentication',
          FirebaseAuthException(code: 'wrong-password'),
        ),
        '[Authentication] errorCode=wrong-password',
      );
      expect(
        AppErrorLogger.format(
          'Firestore',
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        '[Firestore] errorCode=unavailable',
      );
      expect(
        AppErrorLogger.format(
          'Platform',
          PlatformException(code: 'permissionDenied'),
        ),
        '[Platform] errorCode=permissionDenied',
      );
    });

    test('reports the type when an exception has no error code', () {
      expect(
        AppErrorLogger.format('Parser', const FormatException('bad input')),
        '[Parser] errorType=FormatException',
      );
    });
  });
}
