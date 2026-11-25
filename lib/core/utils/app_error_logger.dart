import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppErrorLogger {
  static String format(String context, Object error) {
    final code = switch (error) {
      FirebaseFunctionsException() => error.code,
      FirebaseAuthException() => error.code,
      FirebaseException() => error.code,
      PlatformException() => error.code,
      _ => null,
    };
    return code == null
        ? '[$context] errorType=${error.runtimeType}'
        : '[$context] errorCode=$code';
  }

  static void log(String context, Object error) {
    debugPrint(format(context, error));
  }
}
