import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:netvision_ai/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NetVisionAI());
}


class NetVisionAI extends StatelessWidget {
  const NetVisionAI({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("NetVisionAI", style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold
          ),),
        ),
      ),
    );
  }
}