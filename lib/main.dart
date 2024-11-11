import 'dart:io'; // Import for platform checking
import 'package:flutter/material.dart';
import 'package:flutter_desktop_splash/flutter_desktop_splash.dart'; // Import the custom splash package
import 'package:flutter_native_splash/flutter_native_splash.dart'; // Import flutter_native_splash for initial splash support
import 'package:window_size/window_size.dart'; // Import window_size for setting desktop-specific window properties
import 'package:loading_indicator/loading_indicator.dart'; // Import for custom loading indicators
import 'home_screen.dart'; // Import the main HomeScreen widget

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve native splash screen until Flutter rendering is ready
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Configure window properties only for desktop platforms
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    _initializeDesktopWindow(); // Set desktop window properties (e.g., title, min/max size)
  }

  // Remove the native splash screen before showing the custom splash screen
  FlutterNativeSplash.remove();

  // Run the main app widget
  runApp(MyApp());
}

/// Sets up window properties for desktop platforms
void _initializeDesktopWindow() {
  setWindowTitle(
      "Lotus Library"); // Set the application title on desktop platforms
}

/// The root widget of the application.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lotus Library', // Title of the app
      theme: ThemeData(
        brightness: Brightness.dark, // Set dark theme for the app
        primaryColor: Colors.blueAccent,
        cardColor: Colors.grey[900], // Dark card background color
      ),
      // Show the splash screen on desktop platforms, or go directly to HomeScreen on others
      home: Platform.isWindows || Platform.isMacOS || Platform.isLinux
          ? SplashWrapper() // Wrapper widget for managing splash screen on desktop
          : HomeScreen(), // Skip splash and show HomeScreen on non-desktop platforms
    );
  }
}

/// A wrapper widget to display the splash screen on desktop platforms and
/// navigate to HomeScreen after the splash duration completes.
class SplashWrapper extends StatefulWidget {
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
          MaterialPageRoute(builder: (context) => HomeScreen()),
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
          Colors.blueAccent, // Background color of the splash screen
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
