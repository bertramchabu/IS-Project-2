import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class WebSafeBackdropBlur extends StatelessWidget {
  final double sigma;
  final Widget child;

  const WebSafeBackdropBlur({
    super.key,
    required this.sigma,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
