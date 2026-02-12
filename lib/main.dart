// Main App Structure
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'Screens/LoginScreen.dart';
import 'Firebase/firebase_options.dart';
import 'Screens/WelcomeScreen.dart';
import 'constants.dart';

import 'package:provider/provider.dart'; // Add provider import
import 'Providers/UserProvider.dart';
import 'Providers/MenuProvider.dart'; // Add UserProvider import

// Alias for customer session screen
// typedef CustomerSessionScreen = SessionScreen; // Removed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Enable offline persistence for Firestore
    // This allows the app to work offline and sync when connection is restored
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue app startup - Firebase errors will be handled per-operation
  }


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Restaurant Server App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // onGenerateRoute logic removed for deleted customer ordering
      home: AuthWrapper(),
    );
  }
}




class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          }

          // Fetch profile when user is authenticated
          // Using addPostFrameCallback to avoid state errors during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Only fetch if not already loaded or if different user
            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
            if (userProvider.userProfile == null && user.email != null) {
              userProvider.fetchUserProfile(user.email!);
            }
          });

          // Show welcome screen with animations, which then transitions to MainWaiterApp
          return const WelcomeScreen();
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

