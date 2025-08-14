import 'package:flutter/material.dart';

// Import the new screens we'll create
import 'menu_screen.dart';
import 'store_screen.dart';
import 'game_screen.dart';

void main() {
  runApp(const FlappyBallApp());
}

class FlappyBallApp extends StatelessWidget {
  const FlappyBallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Define the routes for the different screens
      initialRoute: '/',
      routes: {
        '/': (context) => const MenuScreen(),
        '/game': (context) => const GameScreen(),
        '/store': (context) => const StoreScreen(),
      },
    );
  }
}