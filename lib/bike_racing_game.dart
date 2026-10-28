import 'package:flutter/material.dart';

void main() {
  runApp(const BikeRacingGame());
}

class BikeRacingGame extends StatelessWidget {
  const BikeRacingGame({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سباق الدراجات',
      home: GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  double bikePosition = 0.0;
  double obstaclePosition = 1.0;

  void moveBike(double delta) {
    setState(() {
      bikePosition += delta;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سباق الدراجات')), 
      body: Stack(
        children: [
          Positioned(
            bottom: 50,
            left: bikePosition,
            child: Container(
              width: 50,
              height: 100,
              color: Colors.blue,
            ),
          ),
          Positioned(
            bottom: 50,
            left: obstaclePosition,
            child: Container(
              width: 50,
              height: 100,
              color: Colors.red,
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          FloatingActionButton(
            onPressed: () => moveBike(-10),
            child: const Icon(Icons.arrow_left),
          ),
          FloatingActionButton(
            onPressed: () => moveBike(10),
            child: const Icon(Icons.arrow_right),
          ),
        ],
      ),
    );
  }
}