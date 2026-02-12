import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Firebase/firebase_options.dart';
import 'Providers/UserProvider.dart';
import 'Screens/LoginScreen.dart';
import 'Screens/TableScreen.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // UserProvider handles staff details (Name, Role, Branch ID)
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Waiter App',
        theme: ThemeData(
          primaryColor: AppColors.primaryColor,
          scaffoldBackgroundColor: AppColors.backgroundColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryColor,
            elevation: 0,
            centerTitle: true,
          ),
          // Consistent card theme for the app
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // The secure entry point determines if the user is logged in
        home: const AuthWrapper(),
      ),
    );
  }
}

/// The AuthWrapper listens to the Firebase Authentication stream.
/// - If a user is logged in: It sends them to the TableScreen (Dashboard).
/// - If no user is logged in: It sends them to the LoginScreen.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Pre-fetch user details if a user is already logged in (persistence)
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (FirebaseAuth.instance.currentUser != null) {
      userProvider.loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Error State
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Authentication Error. Please restart.")),
          );
        }

        // 3. Authenticated State
        if (snapshot.hasData) {
          // User is logged in, show the Main Waiter Dashboard
          return const TableScreen();
        }

        // 4. Unauthenticated State
        return const LoginScreen();
      },
    );
  }
}