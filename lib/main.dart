import 'dart:io'; // Import for platform checking
import 'package:flutter/material.dart';
import 'package:flutter_desktop_splash/flutter_desktop_splash.dart'; // Import the custom splash package
import 'package:flutter_native_splash/flutter_native_splash.dart'; // Import flutter_native_splash for initial splash support
import 'package:lotus_library/parse_service.dart';
import 'package:window_size/window_size.dart'; // Import window_size for setting desktop-specific window properties
import 'package:loading_indicator/loading_indicator.dart'; // Import for custom loading indicators
import 'home_screen.dart'; // Import the main HomeScreen widget

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve splash screen
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize data in the background
  final progressNotifier = ValueNotifier<String>("Initializing...");
  await initializeApp(progressNotifier);

  // Remove the splash screen
  FlutterNativeSplash.remove();

  // Run the main app
  runApp(MyApp(progressNotifier: progressNotifier));
}

Future<void> initializeApp(ValueNotifier<String> progressNotifier) async {
  try {
    progressNotifier.value = "Setting up environment...";
    final cardLoader = CardLoader(
        progressNotifier: progressNotifier, selectedFormat: 'commander');
    await cardLoader.downloadIfNeeded();
    await cardLoader.initialize();
    progressNotifier.value = "Initialization complete.";
  } catch (e) {
    progressNotifier.value = "Error during initialization: $e";
  }
}

/// Sets up window properties for desktop platforms
void _initializeDesktopWindow() {
  setWindowTitle(
      "Lotus Library"); // Set the application title on desktop platforms
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    setWindowMinSize(const Size(
        500, 600)); // Set the minimum width and height (e.g., 500x600)
  }
}

/// The root widget of the application.
class MyApp extends StatelessWidget {
  final ValueNotifier<String> progressNotifier;

  const MyApp({Key? key, required this.progressNotifier}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lotus Library',
      theme: ThemeData(
        primaryColor: Colors.deepPurple, // Main purple color
        hintColor: Colors.purpleAccent, // Secondary accent purple
        brightness: Brightness.dark,

        cardColor: Colors.grey[900],
      ),
      home: SplashWrapper(progressNotifier: progressNotifier),
    );
  }
}

/// A wrapper widget to display the splash screen on desktop platforms and
/// navigate to HomeScreen after the splash duration completes.
class SplashWrapper extends StatefulWidget {
  final ValueNotifier<String> progressNotifier;

  const SplashWrapper({Key? key, required this.progressNotifier})
      : super(key: key);

  @override
  _SplashWrapperState createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();

    // Use a post-frame callback to delay navigation, ensuring the Navigator context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(seconds: 5), () {
        // Wait for the splash duration
        // Navigate to HomeScreen using a replacement to clear splash from the stack
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                HomeScreen(progressNotifier: widget.progressNotifier),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopSplashScreen(
      // Logo image displayed in the splash screen center
      logo: Image.asset(
        'assets/playstore.png',
        width: 300, // Logo width
        height: 300, // Logo height
      ),
      backgroundColor:
          Colors.purpleAccent, // Background color of the splash screen
      duration:
          Duration(seconds: 5), // Duration for which the splash screen is shown
      onInitializationComplete: () {
        // No navigation here; navigation is handled in `initState` to avoid context issues
      },
      loadingIndicator: LoadingIndicator(
        indicatorType:
            Indicator.ballClipRotatePulse, // Custom loading animation
        colors: [Colors.white], // Loading indicator color
        strokeWidth: 3, // Stroke width for line-based indicators
      ),
      loadingText:
          'Loading Lotus Library...', // Optional loading text displayed below the indicator
    );
  }
}
