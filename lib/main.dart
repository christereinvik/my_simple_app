import 'package:flutter/material.dart';

// The main entry point of the application
void main() {
  runApp(const MySimpleApp());
}

// Root widget configuring the application theme and initial screen
class MySimpleApp extends StatelessWidget {
  const MySimpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true, // Uses the modern Material 3 design system
      ),
      home: const HomeScreen(),
    );
  }
}

// Stateful widget representing the interactive home screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Application state variable tracking button presses
  int _counter = 0;

  // Function to increment the state value safely
  void _incrementCounter() {
    setState(() {
      _counter++; // Tells Flutter to redraw the UI with the updated value
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top header bar
      appBar: AppBar(
        title: const Text('My First iPhone App!'),
        backgroundColor: Colors.blue,
        foregroundColor: const Color.fromARGB(255, 138, 15, 15),
      ),
      // Main interface body layout
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '$_counter', // Dynamic text displaying our state counter
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
      // Floating button in the bottom right corner
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
