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
    return MaterialApp(
      title: 'NetVision AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyan,
        useMaterial3: true
        
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar, size: 96, color: Colors.cyanAccent,),
              SizedBox(height: 24,),
              Text(
                'NetVision AI',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold
                ),
              ),
              SizedBox(height: 8,),
              Text('Firebase connected!'),

          ],),
        )
      ),
    );
  }
}