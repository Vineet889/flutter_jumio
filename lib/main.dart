import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/jumio_service.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");  // Load environment variables
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jumio Integration Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final JumioService _jumioService = JumioService();

  Future<void> startJumioVerification() async {
    try {
      final jumioService = JumioService();

      // Get a token (will fetch new one if needed)
      final token = await jumioService.getAuthToken();

      // Check if there's a valid token
      final hasToken = await jumioService.hasValidToken();

      // Clear stored tokens if needed
      await jumioService.clearStoredToken();

      // Initialize Jumio verification flow
      await _jumioService.initializeJumio(token);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jumio Integration'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: startJumioVerification,
          child: const Text('Start Verification'),
        ),
      ),
    );
  }
}

