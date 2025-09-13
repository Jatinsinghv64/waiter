// Main App Structure
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // required for FlutterFire
  );
  runApp( MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Waiter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
    );
  }
}

// Authentication Wrapper
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
          return MainWaiterApp();
        }
        return Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// Login Screen


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ))..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reverse();
      }
    });
  }

  void _startAnimations() {
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        _shakeController.forward();

        String errorMessage = 'Login failed';
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many attempts. Please try again later';
            break;
          default:
            errorMessage = e.message ?? 'Login failed';
        }

        _showErrorSnackBar(errorMessage);
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('An unexpected error occurred');
      }
    } else {
      _shakeController.forward();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.8),
              Colors.white,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Container(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: _buildLoginContent(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginContent() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLogo(),
          SizedBox(height: 40),
          _buildWelcomeText(),
          SizedBox(height: 40),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: _buildLoginCard(),
              );
            },
          ),
          SizedBox(height: 24),
          _buildForgotPassword(),
          SizedBox(height: 40),
          _buildSocialLogin(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app_logo',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.restaurant_menu,
          size: 60,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black26,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Sign in to continue to your account',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildEmailField(),
              SizedBox(height: 20),
              _buildPasswordField(),
              SizedBox(height: 16),
              _buildRememberMe(),
              SizedBox(height: 24),
              _buildLoginButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'Enter your email',
        prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
          activeColor: primaryColor,
        ),
        Text(
          'Remember me',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          'Sign In',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: () {
        _showForgotPasswordDialog();
      },
      child: Text(
        'Forgot your password?',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white70)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white70)),
          ],
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              icon: Icons.g_mobiledata,
              label: 'Google',
              color: Colors.red,
              onTap: () {
                // Implement Google Sign In
                _showComingSoonSnackBar('Google Sign In');
              },
            ),
            _buildSocialButton(
              icon: Icons.apple,
              label: 'Apple',
              color: Colors.black,
              onTap: () {
                // Implement Apple Sign In
                _showComingSoonSnackBar('Apple Sign In');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your email to receive password reset instructions.'),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showComingSoonSnackBar('Password reset');
              },
              child: Text('Send Reset Email'),
            ),
          ],
        );
      },
    );
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('$feature coming soon!'),
          ],
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}


// Main Waiter App
class MainWaiterApp extends StatefulWidget {
  @override
  _MainWaiterAppState createState() => _MainWaiterAppState();
}

class _MainWaiterAppState extends State<MainWaiterApp> {
  int _selectedIndex = 0;
  final Color primaryColor = Color(0xFF1976D2);

  final List<Widget> _screens = [
    TablesScreen(),
    ActiveOrdersScreen(),
    TakeawayOrderScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No global appBar - each screen handles its own
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: primaryColor,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 10,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.table_restaurant),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.table_restaurant),
                ),
                label: 'Tables',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.receipt_long_outlined),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_long),
                ),
                label: 'Orders',
              ),

              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.shopping_bag_outlined),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_bag),
                ),
                label: 'Takeaway',
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// Tables Screen - Using CustomScrollView (Most Robust)




class TablesScreen extends StatefulWidget {
  @override
  _TablesScreenState createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);

  late AnimationController _refreshController;
  late AnimationController _statsController;
  String _selectedFilter = 'all';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _statsController.forward();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('Branch').doc('Old_Airport').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState();
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildLoadingState();
            }

            final branchData = snapshot.data!.data() as Map<String, dynamic>;
            final tables = branchData['Tables'] as Map<String, dynamic>? ?? {};
            final filteredTables = _getFilteredTablesList(tables);

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: primaryColor,
              child: CustomScrollView(
                physics: BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  _buildQuickStats(tables),
                  _buildFilterChips(tables),
                  _buildViewToggle(),
                  _isGridView
                      ? _buildTablesGrid(filteredTables)
                      : _buildTablesList(filteredTables),
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          ),
          SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Unable to load restaurant tables',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _handleRefresh(),
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading Tables...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest data',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 140.0,
      backgroundColor: primaryColor,
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 20, bottom: 20),
        title: Text(
          'Restaurant Tables',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
                primaryColor.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _refreshController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _refreshController.value * 2 * 3.14159,
              child: IconButton(
                icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
                onPressed: _handleRefresh,
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: Colors.white, size: 26),
          offset: Offset(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'logout') {
              _showLogoutDialog(context);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> tables) {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _statsController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 50 * (1 - _statsController.value)),
            child: Opacity(
              opacity: _statsController.value,
              child: Container(
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat('Total', tables.length, primaryColor, Icons.restaurant),
                    _buildVerticalDivider(),
                    _buildQuickStat('Available', _getStatusCount(tables, 'available'), Colors.green, Icons.check_circle),
                    _buildVerticalDivider(),
                    _buildQuickStat('Occupied', _getStatusCount(tables, 'occupied'), Colors.orange, Icons.group),
                    _buildVerticalDivider(),
                    _buildQuickStat('Ordered', _getStatusCount(tables, 'ordered'), Colors.blue, Icons.restaurant_menu),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _buildQuickStat(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(Map<String, dynamic> tables) {
    final filterData = [
      {'label': 'All', 'value': 'all', 'count': tables.length},
      {'label': 'Available', 'value': 'available', 'count': _getStatusCount(tables, 'available')},
      {'label': 'Occupied', 'value': 'occupied', 'count': _getStatusCount(tables, 'occupied')},
      {'label': 'Ordered', 'value': 'ordered', 'count': _getStatusCount(tables, 'ordered')},
    ];

    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: filterData.length,
          itemBuilder: (context, index) {
            final filter = filterData[index];
            final isSelected = _selectedFilter == filter['value'];

            return Padding(
              padding: EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter['value'] as String;
                  });
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (filter['count'] as int).toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tables',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewButton(Icons.grid_view, true),
                  _buildViewButton(Icons.list, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGridView = isGrid;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey[600],
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTablesGrid(List<MapEntry<String, dynamic>> filteredTables) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7, // Changed from 0.85 to 0.7 to make cards taller
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final entry = filteredTables[index];
            return _buildTableCard(
              context,
              entry.key,
              entry.value as Map<String, dynamic>,
            );
          },
          childCount: filteredTables.length,
        ),
      ),
    );
  }

  Widget _buildTablesList(List<MapEntry<String, dynamic>> filteredTables) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final entry = filteredTables[index];
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildTableListItem(
                context,
                entry.key,
                entry.value as Map<String, dynamic>,
              ),
            );
          },
          childCount: filteredTables.length,
        ),
      ),
    );
  }

  Widget _buildTableCard(BuildContext context, String tableNumber, Map<String, dynamic> tableData) {
    final status = tableData['status']?.toString() ?? 'available';
    final seats = tableData['seats']?.toString() ?? '0';
    final currentOrderId = tableData['currentOrderId']?.toString();
    final tableInfo = _getTableStatusInfo(status);

    return GestureDetector(
      onTap: () => _navigateToOrderScreen(context, tableNumber, tableData, currentOrderId, status),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: tableInfo.color.withOpacity(0.15),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: tableInfo.color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tableInfo.color,
                    tableInfo.color.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tableInfo.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                tableInfo.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Table $tableNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            Text(
              '$seats Seats',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tableInfo.color.withOpacity(0.1),
                    tableInfo.color.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tableInfo.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                tableInfo.statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tableInfo.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableListItem(BuildContext context, String tableNumber, Map<String, dynamic> tableData) {
    final status = tableData['status']?.toString() ?? 'available';
    final seats = tableData['seats']?.toString() ?? '0';
    final currentOrderId = tableData['currentOrderId']?.toString();
    final tableInfo = _getTableStatusInfo(status);

    return GestureDetector(
      onTap: () => _navigateToOrderScreen(context, tableNumber, tableData, currentOrderId, status),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tableInfo.color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tableInfo.color, tableInfo.color.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(tableInfo.icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Table $tableNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    '$seats Seats',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tableInfo.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tableInfo.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                tableInfo.statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tableInfo.color,
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToOrderScreen(BuildContext context, String tableNumber,
      Map<String, dynamic> tableData, String? currentOrderId, String status) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          tableNumber: tableNumber,
          tableData: Map<String, dynamic>.from(tableData),
          existingOrderId: currentOrderId,
          isAddingToExisting: status == 'ordered',
        ),
      ),
    );
  }

  List<MapEntry<String, dynamic>> _getFilteredTablesList(Map<String, dynamic> tables) {
    if (_selectedFilter == 'all') {
      return tables.entries.toList();
    }

    return tables.entries.where((entry) {
      final tableData = entry.value as Map<String, dynamic>;
      final status = tableData['status']?.toString() ?? 'available';
      return status == _selectedFilter;
    }).toList();
  }

  TableStatusInfo _getTableStatusInfo(String status) {
    switch (status) {
      case 'occupied':
        return TableStatusInfo(
          color: Colors.orange[600]!,
          icon: Icons.group_rounded,
          statusText: 'Occupied',
        );
      case 'needs_attention':
        return TableStatusInfo(
          color: Colors.red[600]!,
          icon: Icons.notification_important_rounded,
          statusText: 'Need Help',
        );
      case 'ordered':
        return TableStatusInfo(
          color: Colors.blue[600]!,
          icon: Icons.restaurant_menu_rounded,
          statusText: 'Ordered',
        );
      default:
        return TableStatusInfo(
          color: Colors.green[600]!,
          icon: Icons.check_circle_rounded,
          statusText: 'Available',
        );
    }
  }

  int _getStatusCount(Map<String, dynamic> tables, String targetStatus) {
    return tables.values.where((value) {
      final tableData = value as Map<String, dynamic>;
      final status = tableData['status']?.toString() ?? 'available';
      return status == targetStatus;
    }).length;
  }

  Future<void> _handleRefresh() async {
    _refreshController.forward();
    await Future.delayed(Duration(milliseconds: 1000));
    _refreshController.reset();
    HapticFeedback.mediumImpact();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red[600]),
            SizedBox(width: 12),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out? You will need to log in again to access the app.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class TableStatusInfo {
  final Color color;
  final IconData icon;
  final String statusText;

  TableStatusInfo({
    required this.color,
    required this.icon,
    required this.statusText,
  });
}


// Placeholder for OrderScreen - replace with your actual implementation


class OrderScreen extends StatefulWidget {
  final String tableNumber;
  final Map<String, dynamic> tableData;
  final String? existingOrderId;
  final bool isAddingToExisting;

  OrderScreen({
    required this.tableNumber,
    required this.tableData,
    this.existingOrderId,
    this.isAddingToExisting = false,
  });

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _cartItems = [];
  double _totalAmount = 0.0;
  List<Map<String, dynamic>> _existingOrderItems = [];
  bool _isCheckingOut = false;
  String _tableStatus = 'available';
  String _searchQuery = '';
  StreamSubscription? _tableStatusSubscription;
  StreamSubscription? _existingOrderSubscription;
  bool _isToggling = false;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _occupiedTime;

  // New category-related variables
  List<Map<String, dynamic>> _categories = [];
  Set<String> _expandedCategories = <String>{};
  bool _isLoadingCategories = false;
  bool _isLoadingCart = false;

  // Add this variable to track current order ID
  String? _currentOrderId;
  bool _isAddingToExistingOrder = false;

  // Add these variables to track order status and payment status
  String _currentOrderStatus = '';
  String _currentPaymentStatus = 'unpaid';

  @override
  void initState() {
    super.initState();
    _tableStatus = widget.tableData['status']?.toString() ?? 'available';

    // Initialize current order ID and adding mode
    _currentOrderId = widget.existingOrderId ?? widget.tableData['currentOrderId'];
    _isAddingToExistingOrder = widget.isAddingToExisting || (_currentOrderId != null);

    // Start listening to existing order if we have an order ID
    if (_currentOrderId != null) {
      _listenToExistingOrder();
    }

    _listenToTableStatus();
    _startOrResetTimer();
    _loadCategories();
    _loadCartItems();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableStatusSubscription?.cancel();
    _existingOrderSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // Updated to track order status and payment status
  void _listenToExistingOrder() {
    if (_currentOrderId == null) return;

    _existingOrderSubscription?.cancel();
    _existingOrderSubscription = _firestore
        .collection('Orders')
        .doc(_currentOrderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final orderData = snapshot.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
        final status = orderData['status']?.toString() ?? '';
        final paymentStatus = orderData['paymentStatus']?.toString() ?? 'unpaid';

        setState(() {
          _existingOrderItems = items;
          _currentOrderStatus = status;
          _currentPaymentStatus = paymentStatus;
        });
      }
    });
  }

  // Load cart items from Firestore
  Future<void> _loadCartItems() async {
    setState(() => _isLoadingCart = true);
    try {
      final cartDoc = await _firestore
          .collection('carts')
          .doc('table_${widget.tableNumber}')
          .get();

      if (cartDoc.exists) {
        final cartData = cartDoc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(cartData['items'] ?? []);
        setState(() {
          _cartItems = items;
          _calculateTotal();
        });
      }
    } catch (e) {
      print('Error loading cart items: $e');
    } finally {
      setState(() => _isLoadingCart = false);
    }
  }

  // Save cart items to Firestore
  Future<void> _saveCartItems() async {
    try {
      await _firestore.collection('carts').doc('table_${widget.tableNumber}').set({
        'items': _cartItems,
        'lastUpdated': Timestamp.now(),
        'tableNumber': widget.tableNumber,
      });
    } catch (e) {
      print('Error saving cart items: $e');
    }
  }

  // Load categories from Firestore
  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);

    try {
      // Load categories
      final categoriesSnapshot = await _firestore
          .collection('menu_categories')
          .where('branchId', isEqualTo: 'Old_Airport')
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      setState(() {
        _categories = categoriesSnapshot.docs
            .map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unknown',
          'imageUrl': doc.data()['imageUrl'] ?? '',
          'sortOrder': doc.data()['sortOrder'] ?? 0,
        })
            .toList();
        _isLoadingCategories = false;

        // Auto-expand first category if any exist
        if (_categories.isNotEmpty) {
          _expandedCategories.add(_categories[0]['name']);
        }
      });

    } catch (e) {
      print('Error loading categories: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  void _listenToTableStatus() {
    _tableStatusSubscription = _firestore
        .collection('Branch')
        .doc('Old_Airport')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final branchData = snapshot.data() as Map<String, dynamic>;
        final tables = branchData['Tables'] as Map<String, dynamic>?;
        if (tables != null && tables.containsKey(widget.tableNumber)) {
          final tableData = tables[widget.tableNumber] as Map<String, dynamic>;
          final newStatus = tableData['status']?.toString() ?? 'available';

          if (mounted) {
            setState(() {
              _tableStatus = newStatus;
              _startOrResetTimer();

              // Update current order ID from table data if needed
              final tableOrderId = tableData['currentOrderId']?.toString();
              if (tableOrderId != null && _currentOrderId != tableOrderId) {
                _currentOrderId = tableOrderId;
                _isAddingToExistingOrder = true;
                _listenToExistingOrder();
              }

              if (_tableStatus == 'occupied' || _tableStatus == 'ordered') {
                final Timestamp? ts = tableData['statusTimestamp'];
                if (ts != null) {
                  _occupiedTime = ts.toDate();
                } else if (_occupiedTime == null) {
                  _occupiedTime = DateTime.now();
                }
              } else {
                _occupiedTime = null;
              }
            });
          }
        }
      }
    });
  }

  void _startOrResetTimer() {
    _timer?.cancel();

    if (_tableStatus == 'occupied' || _tableStatus == 'ordered') {
      _occupiedTime ??= DateTime.now();

      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        final now = DateTime.now();
        setState(() {
          _elapsed = now.difference(_occupiedTime!);
        });
      });
    } else {
      _occupiedTime = null;
      _elapsed = Duration.zero;
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'occupied':
        return 'Occupied';
      case 'ordered':
        return 'Order Pending';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.greenAccent;
      case 'occupied':
        return Colors.orangeAccent;
      case 'ordered':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }

  Future<void> _toggleTableAvailability() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    try {
      if (_tableStatus == 'available') {
        await _firestore.collection('Branch').doc('Old_Airport').update({
          'Tables.${widget.tableNumber}.status': 'occupied',
          'Tables.${widget.tableNumber}.statusTimestamp': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table ${widget.tableNumber} marked as occupied!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (_tableStatus == 'occupied' || _tableStatus == 'ordered') {
          _showMarkAvailableDialog();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating table status: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isToggling = false);
    }
  }

  void _showMarkAvailableDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Mark Table Available'),
            ],
          ),
          content: Text(
            'Are you sure you want to mark Table ${widget.tableNumber} as available?\n\n'
                'This will clear any pending orders and reset the table status.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _isToggling = false);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markTableAvailable();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Mark Available'),
            ),
          ],
        );
      },
    ).then((_) {
      setState(() => _isToggling = false);
    });
  }

  Future<void> _markTableAvailable() async {
    try {
      await _firestore.collection('Branch').doc('Old_Airport').update({
        'Tables.${widget.tableNumber}.status': 'available',
        'Tables.${widget.tableNumber}.currentOrderId': FieldValue.delete(),
        'Tables.${widget.tableNumber}.statusTimestamp': FieldValue.delete(),
      });

      // Clear cart when table is marked available
      await _firestore.collection('carts').doc('table_${widget.tableNumber}').delete();

      // Reset local state
      setState(() {
        _currentOrderId = null;
        _isAddingToExistingOrder = false;
        _existingOrderItems.clear();
        _currentOrderStatus = '';
        _currentPaymentStatus = 'unpaid';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table ${widget.tableNumber} marked as available!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating table status: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Add navigation to OrderDetailScreen
  void _navigateToOrderDetail() {
    if (_currentOrderId == null) return;

    _firestore
        .collection('Orders')
        .where(FieldPath.documentId, isEqualTo: _currentOrderId)
        .limit(1)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        final orderDoc = querySnapshot.docs.first; // This is QueryDocumentSnapshot
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: orderDoc),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order not found'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading order details: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    bool timerEnabled = _tableStatus == 'occupied' || _tableStatus == 'ordered';
    bool seatOccupied = timerEnabled;
    Duration timerValue = _elapsed;

    String formatTimer(Duration duration) => _formatDuration(duration);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isAddingToExistingOrder
                  ? 'Add to Table ${widget.tableNumber} Order'
                  : 'Table ${widget.tableNumber} Order',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Status: ${_getStatusDisplayText(_tableStatus)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _getStatusColor(_tableStatus),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (timerEnabled)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          formatTimer(timerValue),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (seatOccupied)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.event_seat, color: Colors.green),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: _isToggling
                ? Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
                : Switch(
              value: _tableStatus == 'available',
              onChanged: (_) => _toggleTableAvailability(),
              activeColor: Colors.green,
              inactiveThumbColor: Colors.orange,
              inactiveTrackColor: Colors.orange.withOpacity(0.3),
              activeTrackColor: Colors.green.withOpacity(0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showTableInfo(),
            tooltip: 'Table Information',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, secondaryColor],
          ),
        ),
        child: Column(
          children: [
            if (_isAddingToExistingOrder && _existingOrderItems.isNotEmpty)
              _buildExistingOrderSection(),
            if (_cartItems.isNotEmpty) _buildCartSection(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_cartItems.isEmpty && !_isAddingToExistingOrder) _buildEmptyCart(),
                  _buildSearchBar(),
                  Expanded(child: _buildMenuList()),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _categories.isNotEmpty ? FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            if (_expandedCategories.length == _categories.length) {
              _expandedCategories.clear(); // Collapse all
            } else {
              _expandedCategories = _categories
                  .map((cat) => cat['name'] as String)
                  .toSet(); // Expand all
            }
          });
        },
        backgroundColor: primaryColor,
        icon: Icon(
          _expandedCategories.length == _categories.length
              ? Icons.expand_less
              : Icons.expand_more,
          color: Colors.white,
        ),
        label: Text(
          _expandedCategories.length == _categories.length
              ? 'Collapse All'
              : 'Expand All',
          style: TextStyle(color: Colors.white),
        ),
      ) : null,
    );
  }

  void _showTableInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.table_restaurant, color: primaryColor),
              SizedBox(width: 8),
              Text('Table ${widget.tableNumber} Info'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                  'Status', _getStatusDisplayText(_tableStatus), _getStatusColor(_tableStatus)),
              SizedBox(height: 8),
              _buildInfoRow('Current Order',
                  _existingOrderItems.isNotEmpty ? 'Yes' : 'No', null),
              SizedBox(height: 8),
              _buildInfoRow('Items in Cart', '${_cartItems.length}', null),
              if (_totalAmount > 0) ...[
                SizedBox(height: 8),
                _buildInfoRow('Cart Total', 'QAR ${_totalAmount.toStringAsFixed(2)}', null),
              ],
              if (_tableStatus == 'occupied' || _tableStatus == 'ordered') ...[
                SizedBox(height: 8),
                _buildInfoRow('Occupied Time', _formatDuration(_elapsed), null),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search dishes...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  // Updated with navigation functionality
  Widget _buildExistingOrderSection() {
    return InkWell(
      onTap: _navigateToOrderDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border(bottom: BorderSide(color: primaryColor.withOpacity(0.2))),
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 16, color: primaryColor),
                SizedBox(width: 8),
                Text(
                  'Existing Order Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    if (_currentOrderStatus == 'served' && _currentPaymentStatus == 'unpaid')
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'UNPAID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _existingOrderItems.map((item) {
                return Chip(
                  label: Text(
                    '${item['name']} (x${item['quantity']})',
                    style: TextStyle(fontSize: 11),
                  ),
                  backgroundColor: primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: primaryColor),
                  side: BorderSide(color: primaryColor.withOpacity(0.3)),
                );
              }).toList(),
            ),
            SizedBox(height: 4),
            Text(
              'Tap to view order details',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isAddingToExistingOrder ? 'Additional Items' : 'Current Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  '+QAR ${_totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 140,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return Container(
                  width: 170,
                  margin: EdgeInsets.only(right: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'QAR ${item['price'].toStringAsFixed(2)} each',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            if (item['specialInstructions'] != null && item['specialInstructions'].isNotEmpty)
                              SizedBox(height: 4),
                            if (item['specialInstructions'] != null && item['specialInstructions'].isNotEmpty)
                              Text(
                                'Special: ${item['specialInstructions']}',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _updateQuantity(index, -1),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.remove, size: 18, color: Colors.grey[700]),
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                              padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['quantity']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _updateQuantity(index, 1),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add, size: 18, color: primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Container(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey[300],
            ),
            SizedBox(height: 8),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Add items from the menu below',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated _buildMenuList with category-based collapsible UI
  Widget _buildMenuList() {
    if (_isLoadingCategories) {
      return Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('menu_items')
          .where('isAvailable', isEqualTo: true)
          .where('branchId', isEqualTo: 'Old_Airport')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final menuItems = snapshot.data!.docs;

        // Filter items based on search query
        final filteredItems = menuItems.where((item) {
          if (_searchQuery.isEmpty) return true;
          final itemData = item.data() as Map<String, dynamic>;
          final name = itemData['name']?.toString().toLowerCase() ?? '';
          final description = itemData['description']?.toString().toLowerCase() ?? '';
          final category = itemData['category']?.toString().toLowerCase() ?? '';

          return name.contains(_searchQuery) ||
              description.contains(_searchQuery) ||
              category.contains(_searchQuery);
        }).toList();

        if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoResultsWidget();
        }

        // Group items by category ID instead of name for better matching
        Map<String, List<QueryDocumentSnapshot>> categorizedItems = {};

        // First, create empty lists for all categories
        for (var category in _categories) {
          categorizedItems[category['id']] = [];
        }

        // Add "Other" category for items that don't match
        categorizedItems['other'] = [];

        // Then add items to their respective categories
        for (var item in filteredItems) {
          final itemData = item.data() as Map<String, dynamic>;
          final itemCategoryId = itemData['categoryId']?.toString(); // Try categoryId first
          final itemCategoryName = itemData['category']?.toString(); // Then try category name

          bool itemCategorized = false;

          // Try to match by category ID
          if (itemCategoryId != null && categorizedItems.containsKey(itemCategoryId)) {
            categorizedItems[itemCategoryId]!.add(item);
            itemCategorized = true;
          }
          // Try to match by category name
          else if (itemCategoryName != null) {
            for (var category in _categories) {
              if (category['name'] == itemCategoryName) {
                categorizedItems[category['id']]!.add(item);
                itemCategorized = true;
                break;
              }
            }
          }

          // If still not categorized, put in "Other"
          if (!itemCategorized) {
            categorizedItems['other']!.add(item);
          }
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _categories.length + (categorizedItems['other']!.isNotEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < _categories.length) {
              final category = _categories[index];
              final categoryItems = categorizedItems[category['id']] ?? [];
              return _buildCategorySection(category, categoryItems);
            } else {
              // "Other" category section
              final otherItems = categorizedItems['other']!;
              return _buildCategorySection({
                'id': 'other',
                'name': 'Other Items',
                'imageUrl': '',
                'sortOrder': 999,
              }, otherItems);
            }
          },
        );
      },
    );
  }

// Helper method to get category name by ID
  String _getCategoryNameById(String categoryId) {
    if (categoryId == 'other') return 'Other Items';
    final category = _categories.firstWhere(
          (cat) => cat['id'] == categoryId,
      orElse: () => {'name': 'Unknown'},
    );
    return category['name'];
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text('No dishes found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          SizedBox(height: 8),
          Text('Try searching with different keywords', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> category, List<QueryDocumentSnapshot> items) {
    final categoryName = category['name'];
    final imageUrl = category['imageUrl'];
    final isExpanded = _expandedCategories.contains(categoryName);
    final hasItems = items.isNotEmpty;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Category Header (always visible)
          InkWell(
            onTap: hasItems ? () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(categoryName);
                } else {
                  _expandedCategories.add(categoryName);
                }
              });
            } : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Category Image
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: primaryColor.withOpacity(0.1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.restaurant_menu, color: primaryColor, size: 24),
                      )
                          : Icon(Icons.restaurant_menu, color: primaryColor, size: 24),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Category Name and Item Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                        if (hasItems)
                          Text(
                            '${items.length} item${items.length != 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),

                  // Expand/Collapse Arrow
                  if (hasItems)
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down, color: primaryColor, size: 28),
                    ),

                  // No items indicator
                  if (!hasItems)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                      child: Text('No items', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                ],
              ),
            ),
          ),

          // Expandable Items Section
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: hasItems ? _buildCategoryItems(items) : SizedBox.shrink(),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItems(List<QueryDocumentSnapshot> items) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildMenuItemCard(items[index]);
        },
      ),
    );
  }

  Widget _buildMenuItemCard(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;
    final name = itemData['name']?.toString() ?? 'Unknown Item';
    final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = itemData['imageUrl']?.toString();
    final estimatedTime = itemData['EstimatedTime']?.toString() ?? '';
    final isPopular = itemData['isPopular'] ?? false;
    final hasCustomization = itemData['hasCustomization'] ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Expanded(
            flex: 4, // Reduced from 5 to give more space to content
            child: Container(
              width: double.infinity,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: primaryColor.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: primaryColor.withOpacity(0.1),
                        child: Icon(Icons.restaurant_menu, color: primaryColor, size: 30),
                      ),
                    )
                        : Container(
                      color: primaryColor.withOpacity(0.1),
                      child: Icon(Icons.restaurant_menu, color: primaryColor, size: 30),
                    ),
                  ),
                  // Popular badge
                  if (isPopular)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'POPULAR',
                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content Section
          Expanded(
            flex: 5, // Increased from 4 to give more space to content
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Item Name
                  Flexible(
                    flex: 2,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  SizedBox(height: 4),

                  // Price and Time Row
                  Flexible(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'QAR ${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (estimatedTime.isNotEmpty)
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer, size: 10, color: Colors.grey),
                                SizedBox(width: 2),
                                Text(
                                  '${estimatedTime}m',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8), // Increased spacing

                  // Add Button - INCREASED HEIGHT
                  Flexible(
                    flex: 2, // Increased from 1 to give more space to button
                    child: SizedBox(
                      width: double.infinity,
                      height: 36, // Increased from 28 to 36
                      child: ElevatedButton(
                        onPressed: () => hasCustomization
                            ? _showCustomizationOptions(item)
                            : _addToCart(item, null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Added padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16), // Slightly larger icon
                            SizedBox(width: 6), // Increased spacing
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 13, // Increased font size
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Enhanced payment button logic with all required conditions
  // Updated to show payment button for served but unpaid orders with all conditions
  Widget? _buildBottomNavigationBar() {
    // Enhanced condition: order served + unpaid + seat occupied + order exists
    bool showPaymentButton = _currentOrderStatus == 'served' &&
        _currentPaymentStatus == 'unpaid' &&
        (_tableStatus == 'occupied' || _tableStatus == 'ordered') &&
        _currentOrderId != null;

    if (_cartItems.isEmpty && _tableStatus != 'ordered' && !showPaymentButton) return null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cartItems.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAddingToExistingOrder
                            ? 'Additional Total'
                            : 'Total Amount',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'QAR ${_totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        _isAddingToExistingOrder ? 'Add Items' : 'Submit Order',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // UPDATED: Payment button with all required conditions
          if (showPaymentButton)
            Padding(
              padding: EdgeInsets.only(top: _cartItems.isNotEmpty ? 12 : 0),
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : _showPaymentOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 48),
                ),
                child: _isCheckingOut
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Pay Now - Order Served',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Original checkout button for other statuses
          if ((_tableStatus == 'ordered' || _tableStatus == 'occupied') && !showPaymentButton)
            Padding(
              padding: EdgeInsets.only(top: _cartItems.isNotEmpty ? 12 : 0),
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : _showPaymentOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 48),
                ),
                child: _isCheckingOut
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Checkout & Pay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }


  void _showCustomizationOptions(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;
    final name = itemData['name']?.toString() ?? 'Unknown Item';
    final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;

    String specialInstructions = '';
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'QAR ${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Quantity Selector
                  Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          if (quantity > 1) {
                            setModalState(() {
                              quantity--;
                            });
                          }
                        },
                      ),
                      Container(
                        width: 50,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          quantity.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setModalState(() {
                            quantity++;
                          });
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Special Instructions
                  Text(
                    'Special Instructions (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'E.g. No onions, extra spicy, etc.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      specialInstructions = value;
                    },
                  ),

                  SizedBox(height: 20),

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addToCart(item, specialInstructions, quantity: quantity);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add to Cart - QAR ${(price * quantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addToCart(QueryDocumentSnapshot item, String? specialInstructions, {int quantity = 1}) {
    setState(() {
      final itemData = item.data() as Map<String, dynamic>;
      final existingIndex =
      _cartItems.indexWhere((cartItem) =>
      cartItem['id'] == item.id &&
          cartItem['specialInstructions'] == specialInstructions
      );

      if (existingIndex >= 0) {
        _cartItems[existingIndex]['quantity'] += quantity;
      } else {
        _cartItems.add({
          'id': item.id,
          'name': itemData['name']?.toString() ?? 'Unknown Item',
          'price': (itemData['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': quantity,
          'specialInstructions': specialInstructions,
        });
      }
      _calculateTotal();
      _saveCartItems(); // Save to Firestore
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to cart successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _updateQuantity(int index, int change) {
    setState(() {
      _cartItems[index]['quantity'] += change;
      if (_cartItems[index]['quantity'] <= 0) {
        _cartItems.removeAt(index);
      }
      _calculateTotal();
      _saveCartItems(); // Save to Firestore
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _calculateTotal();
      _saveCartItems(); // Save to Firestore
    });
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      final double price = (item['price'] as num).toDouble();
      final int quantity = (item['quantity'] as num).toInt();
      return sum + (price * quantity);
    });
  }

  Future<void> _submitOrder() async {
    try {
      // Check if we're adding to existing order or creating new
      if (_isAddingToExistingOrder && _currentOrderId != null) {
        await _addToExistingOrder();
      } else {
        await _createNewOrder();
      }

      setState(() {
        _tableStatus = 'ordered';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAddingToExistingOrder
              ? 'Items added to order successfully!'
              : 'Order submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
      });

      // Clear persisted cart
      await _firestore.collection('carts').doc('table_${widget.tableNumber}').delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createNewOrder() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final ordersToday = await _firestore
        .collection('Orders')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfDay))
        .get();

    final dailyOrderNumber = ordersToday.size + 1;

    final orderRef = await _firestore.collection('Orders').add({
      'Order_type': 'dine_in',
      'tableNumber': widget.tableNumber,
      'items': _cartItems,
      'subtotal': _totalAmount,
      'totalAmount': _totalAmount,
      'status': 'pending',
      'paymentStatus': 'unpaid',
      'timestamp': Timestamp.now(),
      'dailyOrderNumber': dailyOrderNumber,
      'branchId': 'Old_Airport',
    });

    await _firestore.collection('Branch').doc('Old_Airport').update({
      'Tables.${widget.tableNumber}.status': 'ordered',
      'Tables.${widget.tableNumber}.currentOrderId': orderRef.id,
      'Tables.${widget.tableNumber}.statusTimestamp': Timestamp.now(),
    });

    // IMPORTANT: After creating new order, update local state to enable adding more items
    setState(() {
      _currentOrderId = orderRef.id;
      _isAddingToExistingOrder = true;
    });

    // Start listening to the newly created order immediately
    _listenToExistingOrder();
  }

  Future<void> _addToExistingOrder() async {
    if (_currentOrderId == null) return;

    final orderDoc = await _firestore
        .collection('Orders')
        .doc(_currentOrderId)
        .get();

    if (orderDoc.exists) {
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final currentItems = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      final currentTotal = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final currentSubtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;

      final mergedItems = _mergeOrderItems(currentItems, _cartItems);
      final newTotal = currentTotal + _totalAmount;
      final newSubtotal = currentSubtotal + _totalAmount;

      await _firestore.collection('Orders').doc(_currentOrderId).update({
        'items': mergedItems,
        'subtotal': newSubtotal,
        'totalAmount': newTotal,
        'status': 'pending',
        'timestamp': Timestamp.now(),
      });
    }
  }

  List<Map<String, dynamic>> _mergeOrderItems(
      List<Map<String, dynamic>> existingItems,
      List<Map<String, dynamic>> newItems) {
    final merged = List<Map<String, dynamic>>.from(existingItems);

    for (final newItem in newItems) {
      final existingIndex = merged.indexWhere(
              (item) => item['id'] == newItem['id'] && item['specialInstructions'] == newItem['specialInstructions']);

      if (existingIndex >= 0) {
        merged[existingIndex]['quantity'] += newItem['quantity'];
      } else {
        merged.add(newItem);
      }
    }

    return merged;
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _processPayment('cash'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.money, size: 40, color: Colors.green),
                            SizedBox(height: 8),
                            Text(
                              'Cash',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _processPayment('card'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.credit_card, size: 40, color: Colors.blue),
                            SizedBox(height: 8),
                            Text(
                              'Card',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processPayment(String paymentMethod) async {
    Navigator.pop(context);
    setState(() => _isCheckingOut = true);

    try {
      final orderDoc = await _firestore
          .collection('Orders')
          .doc(_currentOrderId ?? widget.tableData['currentOrderId'])
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;

        await _firestore.collection('Orders').doc(_currentOrderId ?? widget.tableData['currentOrderId']).update({
          'paymentStatus': 'paid',
          'paymentMethod': paymentMethod,
          'paymentTime': Timestamp.now(),
          'paidAmount': totalAmount,
        });

        await _firestore.collection('Branch').doc('Old_Airport').update({
          'Tables.${widget.tableNumber}.status': 'available',
          'Tables.${widget.tableNumber}.currentOrderId': FieldValue.delete(),
          'Tables.${widget.tableNumber}.statusTimestamp': FieldValue.delete(),
        });

        // Clear cart after successful payment
        await _firestore.collection('carts').doc('table_${widget.tableNumber}').delete();

        // Reset local state
        setState(() {
          _currentOrderId = null;
          _isAddingToExistingOrder = false;
          _existingOrderItems.clear();
          _currentOrderStatus = '';
          _currentPaymentStatus = 'unpaid';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processed successfully with ${paymentMethod.toUpperCase()}!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isCheckingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}











class ActiveOrdersScreen extends StatefulWidget {
  @override
  _ActiveOrdersScreenState createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // update UI on tab changes
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Active Orders",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(72),
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              height: 70,
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorPadding: EdgeInsets.zero,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                tabs: [
                  _buildTabItem(Icons.restaurant_menu, 'All', 0),
                  _buildTabItem(Icons.table_restaurant, 'Dine In', 1),
                  _buildTabItem(Icons.shopping_bag, 'Takeaway', 2),
                  _buildTabItem(Icons.check_circle, 'Completed', 3),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList('all'),
          _buildOrdersList('dine_in'),
          _buildOrdersList('takeaway'),
          _buildCompletedOrdersList(),
        ],
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String text, int index) {
    final bool isSelected = _tabController.index == index;
    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? primaryColor : Colors.grey[600],
          ),
          SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String orderType) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(orderType),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return _buildLoadingState();
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return _buildEmptyState(orderType);
        }

        // Updated to include 'served' status and filter out paid orders
        final pendingOrders =
        orders.where((order) => order['status'] == 'pending').toList();
        final preparingOrders =
        orders.where((order) => order['status'] == 'preparing').toList();
        final preparedOrders =
        orders.where((order) => order['status'] == 'prepared').toList();
        final servedOrders = orders.where((order) =>
        order['status'] == 'served' &&
            (order['paymentStatus'] ?? 'unpaid') != 'paid').toList();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildSummaryCards(
                pendingOrders.length,
                preparingOrders.length,
                preparedOrders.length,
                servedOrders.length,
              ),
              SizedBox(height: 20),
              if (servedOrders.isNotEmpty) ...[
                _buildSectionHeader('Served (Unpaid)', servedOrders.length, Colors.blue),
                ...servedOrders.map((order) => _buildOrderCard(order, false)),
                SizedBox(height: 16),
              ],
              if (preparedOrders.isNotEmpty) ...[
                _buildSectionHeader('Ready to Serve', preparedOrders.length, Colors.green),
                ...preparedOrders.map((order) => _buildOrderCard(order, true)),
                SizedBox(height: 16),
              ],
              if (preparingOrders.isNotEmpty) ...[
                _buildSectionHeader('Preparing', preparingOrders.length, Colors.orange),
                ...preparingOrders.map((order) => _buildOrderCard(order, false)),
                SizedBox(height: 16),
              ],
              if (pendingOrders.isNotEmpty) ...[
                _buildSectionHeader('New Orders', pendingOrders.length, Colors.red),
                ...pendingOrders.map((order) => _buildOrderCard(order, false)),
              ],
            ],
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getOrdersStream(String orderType) {
    try {
      Query query = _firestore
          .collection('Orders')
          .where('branchId', isEqualTo: 'Old_Airport')
          .where('status', whereIn: ['pending', 'preparing', 'prepared', 'served']);

      if (orderType != 'all') {
        query = query.where('Order_type', isEqualTo: orderType);
      }
      return query.orderBy('timestamp', descending: true).snapshots();
    } catch (e) {
      return Stream.empty();
    }
  }

  Widget _buildSummaryCards(int pending, int preparing, int prepared, int served) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard('New', pending, Colors.red, Icons.fiber_new),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard('Preparing', preparing, Colors.orange, Icons.restaurant),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard('Ready', prepared, Colors.green, Icons.check_circle),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard('Served', served, Colors.blue, Icons.room_service),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [secondaryColor, Colors.white]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Text(count.toString(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot order, bool isPriority) {
    final orderData = order.data() as Map<String, dynamic>;
    final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
    final tableNumber = orderData['tableNumber']?.toString();
    final customerName = orderData['customerName']?.toString();
    final status = orderData['status']?.toString() ?? 'unknown';
    final paymentStatus = orderData['paymentStatus']?.toString() ?? 'unpaid';
    final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final timestamp = orderData['timestamp'] as Timestamp?;
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

    final statusColor = _getFirestoreStatusColor(status);
    final paymentStatusColor = paymentStatus == 'paid' ? Colors.green : Colors.red;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: order),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isPriority ? Colors.green.withOpacity(0.2) : Colors.black12,
                blurRadius: isPriority ? 8 : 4,
                offset: Offset(0, isPriority ? 4 : 2),
              )
            ],
            border: isPriority ? Border.all(color: Colors.green, width: 2) : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: orderType == 'takeaway' ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        orderType == 'takeaway' ? Icons.shopping_bag : Icons.table_restaurant,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Order #$dailyOrderNumber',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                              if (isPriority) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'READY',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            orderType == 'takeaway'
                                ? (customerName != null ? 'Customer: $customerName' : 'Takeaway Order')
                                : 'Table: ${tableNumber ?? 'N/A'}',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor, width: 1),
                          ),
                          child: Text(status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (status == 'served') ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: paymentStatusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: paymentStatusColor, width: 1),
                            ),
                            child: Text(paymentStatus.toUpperCase(),
                                style: TextStyle(color: paymentStatusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.restaurant_menu, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('${items.length} item${items.length != 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                      ]),
                      SizedBox(height: 4),
                      Text(
                        items.take(2).map((item) => '${item['name']} (${item['quantity']})').join(', ') +
                            (items.length > 2 ? '...' : ''),
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(timestamp != null ? _formatTime(timestamp.toDate()) : 'Unknown',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    Text('QAR ${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String orderType) {
    String message;
    IconData icon;
    switch (orderType) {
      case 'dine_in':
        message = 'No active dine-in orders';
        icon = Icons.table_restaurant;
        break;
      case 'takeaway':
        message = 'No active takeaway orders';
        icon = Icons.shopping_bag;
        break;
      case 'completed':
        message = 'No completed orders for today';
        icon = Icons.check_circle_outline;
        break;
      default:
        message = 'No active orders';
        icon = Icons.restaurant;
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey)),
          if (orderType != 'completed') ...[
            SizedBox(height: 8),
            Text('Orders will appear here when they are placed', style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red),
        SizedBox(height: 16),
        Text('Error loading orders', style: TextStyle(fontSize: 18, color: Colors.red)),
        SizedBox(height: 8),
        Text('Please check your connection', style: TextStyle(color: Colors.grey)),
        SizedBox(height: 16),
        ElevatedButton(onPressed: () => setState(() {}), child: Text('Retry')),
      ]),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: primaryColor),
        SizedBox(height: 16),
        Text('Loading orders...', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Color _getFirestoreStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'served':
        return Colors.blue;
      case 'prepared':
        return Colors.green;
      case 'preparing':
        return Colors.orange;
      case 'pending':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  Widget _buildCompletedOrdersList() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Orders')
          .where('branchId', isEqualTo: 'Old_Airport')
          .where('paymentStatus', isEqualTo: 'paid') // Changed to filter by paymentStatus
          .where('paymentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('paymentTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading completed orders'));
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return _buildEmptyState('completed');
        }
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderData = order.data() as Map<String, dynamic>;
            final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
            final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
            final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
            final paymentMethod = orderData['paymentMethod']?.toString() ?? 'N/A';
            final paymentTime = orderData['paymentTime'] as Timestamp?;
            final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(order: order),
                  ),
                );
              },
              child: Card(
                margin: EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                shadowColor: Colors.blueAccent.withOpacity(0.08),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.receipt_long, color: primaryColor, size: 24),
                        SizedBox(width: 8),
                        Text('Order #$dailyOrderNumber',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('PAID',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Chip(
                            label: Text(orderType,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            backgroundColor: orderType == 'takeaway' ? Colors.orange : Colors.blue,
                            visualDensity: VisualDensity.compact,
                          ),
                          SizedBox(width: 8),
                          Chip(
                            label: Text(paymentMethod, style: TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: Colors.green,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Paid At: ${paymentTime != null ? _formatDateTime(paymentTime.toDate()) : 'N/A'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Divider(height: 24, thickness: 1.5, color: secondaryColor),
                      ...items
                          .take(2)
                          .map((item) => Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text('${item['name']} x${item['quantity']}',
                            style: TextStyle(fontSize: 14, color: Colors.black87)),
                      ))
                          .toList(),
                      if (items.length > 2)
                        Text('+ ${items.length - 2} more...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('QAR ${totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}



class OrderDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot order;

  OrderDetailScreen({required this.order});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final orderData = widget.order.data() as Map<String, dynamic>;
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final status = orderData['status']?.toString() ?? 'unknown';
    final paymentStatus = orderData['paymentStatus']?.toString() ?? 'unpaid';
    final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
    final tableNumber = orderData['tableNumber']?.toString();
    final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final timestamp = orderData['timestamp'] as Timestamp?;
    final customerName = orderData['customerName']?.toString();
    final customerPhone = orderData['customerPhone']?.toString();
    final paymentMethod = orderData['paymentMethod']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            // Order Header Card
            Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Number and Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #$dailyOrderNumber',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: orderType == 'takeaway'
                                    ? Colors.orange[100]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                orderType.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: orderType == 'takeaway'
                                      ? Colors.orange[800]
                                      : Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            // Order Status Badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            // Payment Status Badge
                            if (status == 'served') ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (paymentStatus == 'paid' ? Colors.green : Colors.red).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: paymentStatus == 'paid' ? Colors.green : Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  paymentStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: paymentStatus == 'paid' ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),
                    Divider(color: Colors.grey[300]),
                    SizedBox(height: 16),

                    // Order Info Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: orderType == 'takeaway'
                                ? Icons.shopping_bag
                                : Icons.table_restaurant,
                            label: orderType == 'takeaway' ? 'Pickup' : 'Table',
                            value: orderType == 'takeaway'
                                ? 'Counter'
                                : (tableNumber ?? 'N/A'),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.access_time,
                            label: 'Ordered',
                            value: timestamp != null
                                ? _formatTime(timestamp.toDate())
                                : 'Unknown',
                          ),
                        ),
                      ],
                    ),

                    // Customer Info (for takeaway)
                    if (orderType == 'takeaway' && (customerName != null || customerPhone != null)) ...[
                      SizedBox(height: 12),
                      Row(
                        children: [
                          if (customerName != null)
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.person,
                                label: 'Customer',
                                value: customerName,
                              ),
                            ),
                          if (customerPhone != null)
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.phone,
                                label: 'Phone',
                                value: customerPhone,
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Payment Method
                    if (paymentMethod != null) ...[
                      SizedBox(height: 12),
                      _buildInfoItem(
                        icon: paymentMethod == 'cash' ? Icons.money : Icons.credit_card,
                        label: 'Payment',
                        value: paymentMethod.toUpperCase(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Items Section
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Items Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu, color: primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Order Items (${items.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items List
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final name = item['name']?.toString() ?? 'Unknown Item';
                          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                          final total = price * quantity;
                          final specialInstructions = item['specialInstructions']?.toString();

                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                // Quantity Badge
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$quantity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),

                                // Item Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'QAR ${price.toStringAsFixed(2)} each',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
                                        SizedBox(height: 4),
                                        Text(
                                          'Special: $specialInstructions',
                                          style: TextStyle(
                                            color: Colors.orange[700],
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Total Price
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'QAR ${total.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Total Section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (subtotal != totalAmount)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  'QAR ${subtotal.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          if (subtotal != totalAmount) SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                'QAR ${totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      // Action Buttons
      bottomNavigationBar: _buildActionButtons(status, paymentStatus, orderType),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget? _buildActionButtons(String status, String paymentStatus, String orderType) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status-specific action buttons
          if (status == 'pending') ...[
            // Mark as Preparing button
            ElevatedButton(
              onPressed: _isUpdating ? null : _markAsPreparing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant),
                  SizedBox(width: 8),
                  Text(
                    'Mark as Preparing',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Return/Cancel button for pending orders
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined),
                  SizedBox(width: 8),
                  Text(
                    'Cancel Order',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'preparing') ...[
            // Mark as Prepared button
            ElevatedButton(
              onPressed: _isUpdating ? null : _markAsPrepared,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline),
                  SizedBox(width: 8),
                  Text(
                    'Mark as Prepared',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Return to Pending button
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnToPending,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.undo),
                  SizedBox(width: 8),
                  Text(
                    'Return to Pending',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'prepared') ...[
            // Mark as Served button
            ElevatedButton(
              onPressed: _isUpdating ? null : () => _markAsServed(orderType),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.room_service),
                  SizedBox(width: 8),
                  Text(
                    orderType == 'takeaway' ? 'Mark as Picked Up' : 'Mark as Served',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Return to Preparing button
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnToPreparing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.undo),
                  SizedBox(width: 8),
                  Text(
                    'Return to Preparing',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'served') ...[
            if (paymentStatus == 'unpaid') ...[
              // Mark as Paid button
              ElevatedButton(
                onPressed: _isUpdating ? null : _showPaymentOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUpdating
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment),
                    SizedBox(width: 8),
                    Text(
                      'Mark as Paid',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
            ],
            // Return to Prepared button
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnToPrepared,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.undo),
                  SizedBox(width: 8),
                  Text(
                    'Return to Prepared',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Show status info for paid orders
          if (paymentStatus == 'paid') ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Order has been paid',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Show status info for cancelled orders
          if (status == 'cancelled') ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Order was cancelled',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'served':
        return Colors.blue;
      case 'prepared':
        return Colors.green;
      case 'preparing':
        return Colors.orange;
      case 'paid':
        return Colors.teal;
      case 'pending':
        return Colors.amber[700]!;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  Future<void> _markAsPreparing() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'preparing'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as preparing!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsPrepared() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'prepared'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as prepared!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsServed(String orderType) async {
    setState(() => _isUpdating = true);

    try {
      // Changed: Set status to 'served' and paymentStatus to 'unpaid'
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({
        'status': 'served',
        'paymentStatus': 'unpaid',
      });

      // Update table status only for dine-in orders
      if (orderType == 'dine_in') {
        final orderData = widget.order.data() as Map<String, dynamic>;
        final tableNumber = orderData['tableNumber']?.toString();

        if (tableNumber != null) {
          final tableUpdate = <String, dynamic>{};
          tableUpdate['Tables.$tableNumber.status'] = 'occupied';

          await FirebaseFirestore.instance
              .collection('Branch')
              .doc('Old_Airport')
              .update(tableUpdate);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderType == 'takeaway'
              ? 'Order marked as picked up!'
              : 'Order marked as served!'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _returnOrder() async {
    // Show confirmation dialog first
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cancel Order'),
          content: Text('Are you sure you want to cancel this order? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'cancelled'});

      // Clear table if it's a dine-in order
      final orderData = widget.order.data() as Map<String, dynamic>;
      final orderType = orderData['Order_type']?.toString() ?? 'dine_in';

      if (orderType == 'dine_in') {
        final tableNumber = orderData['tableNumber']?.toString();
        if (tableNumber != null) {
          final tableUpdate = <String, dynamic>{};
          tableUpdate['Tables.$tableNumber.status'] = 'available';
          tableUpdate['Tables.$tableNumber.currentOrderId'] = FieldValue.delete();

          await FirebaseFirestore.instance
              .collection('Branch')
              .doc('Old_Airport')
              .update(tableUpdate);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order cancelled successfully!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _returnToPending() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'pending'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order returned to pending!'),
          backgroundColor: Colors.amber[700],
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _returnToPreparing() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'preparing'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order returned to preparing!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _returnToPrepared() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'prepared'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order returned to prepared!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _processPayment('cash'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.money, size: 40, color: Colors.green),
                            SizedBox(height: 8),
                            Text(
                              'Cash',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _processPayment('card'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.credit_card, size: 40, color: Colors.blue),
                            SizedBox(height: 8),
                            Text(
                              'Card',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processPayment(String paymentMethod) async {
    Navigator.pop(context);
    setState(() => _isUpdating = true);

    try {
      final orderData = widget.order.data() as Map<String, dynamic>;
      final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
      final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;

      await FirebaseFirestore.instance.collection('Orders').doc(widget.order.id).update({
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paymentTime': Timestamp.now(),
        'paidAmount': totalAmount,
      });

      // Update table status only for dine-in orders
      if (orderType == 'dine_in') {
        final tableNumber = orderData['tableNumber']?.toString();
        if (tableNumber != null) {
          await FirebaseFirestore.instance.collection('Branch').doc('Old_Airport').update({
            'Tables.$tableNumber.status': 'available',
            'Tables.$tableNumber.currentOrderId': FieldValue.delete(),
            'Tables.$tableNumber.statusTimestamp': FieldValue.delete(),
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment processed successfully with ${paymentMethod.toUpperCase()}!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}





class TakeawayOrderScreen extends StatefulWidget {
  @override
  _TakeawayOrderScreenState createState() => _TakeawayOrderScreenState();
}

class _TakeawayOrderScreenState extends State<TakeawayOrderScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Changed to blue color scheme
  final Color primaryColor = Color(0xFF1565C0); // Blue
  final Color secondaryColor = Color(0xFFF8F8F8);
  final Color accentColor = Color(0xFF42A5F5); // Light blue
  final Color successColor = Color(0xFF4CAF50);
  final Color warningColor = Color(0xFFFF9800);

  List<Map<String, dynamic>> _cartItems = [];
  double _totalAmount = 0.0;
  // Removed platform fee and GST variables

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _specialInstructionsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSubmitting = false;
  String _orderType = 'takeaway'; // Fixed to takeaway
  String _paymentMethod = 'cash';
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _showFilters = false;
  bool _showSubtotalDetails = false;

  late AnimationController _cartAnimationController;
  late AnimationController _filterAnimationController;
  late AnimationController _subtotalAnimationController;
  late Animation<double> _cartSlideAnimation;
  late Animation<double> _filterSlideAnimation;
  late Animation<double> _subtotalSlideAnimation;

  final ScrollController _scrollController = ScrollController();
  List<String> _categories = ['All'];
  Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();

    _cartAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _filterAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _subtotalAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _cartSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cartAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _filterSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _subtotalSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _subtotalAnimationController,
      curve: Curves.easeInOut,
    ));

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _loadCategories();
  }

  void _loadCategories() async {
    try {
      final snapshot = await _firestore
          .collection('menu_categories')
          .where('isActive', isEqualTo: true)
          .where('branchId', isEqualTo: 'Old_Airport')
          .orderBy('sortOrder')
          .get();

      setState(() {
        _categories = ['All'];
        _categories.addAll(
            snapshot.docs.map((doc) => doc['name'].toString()).toList()
        );
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _cartAnimationController.dispose();
    _filterAnimationController.dispose();
    _subtotalAnimationController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _specialInstructionsController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildTakeawayAppBar(),
          _buildSearchAndFilter(),
          if (_showFilters) _buildFilterSection(),
          _buildMenuContent(),
        ],
      ),
      bottomNavigationBar: _buildCartBottomBar(),
      floatingActionButton: _cartItems.isNotEmpty
          ? _buildFloatingCartButton()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTakeawayAppBar() {
    return SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -100,
                top: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -50,
                bottom: -100,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order for Takeaway',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Quick • Fresh • Ready to Go',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_cartItems.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shopping_cart,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '${_cartItems.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Spacer(),
                      Text(
                        '15 min preparation • Old Airport Branch',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for dishes, cuisines...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                setState(() => _showFilters = !_showFilters);
                if (_showFilters) {
                  _filterAnimationController.forward();
                } else {
                  _filterAnimationController.reverse();
                }
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _showFilters ? primaryColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showFilters ? primaryColor : Colors.grey[300]!,
                  ),
                ),
                child: Icon(
                  Icons.tune,
                  color: _showFilters ? Colors.white : Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _filterSlideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -50 * (1 - _filterSlideAnimation.value)),
            child: Opacity(
              opacity: _filterSlideAnimation.value,
              child: Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter by Category',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedCategory = 'All'),
                          child: Text(
                            'Clear',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = category);
                            HapticFeedback.selectionClick();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? primaryColor : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuContent() {
    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('menu_items')
            .where('isAvailable', isEqualTo: true)
            .where('branchId', isEqualTo: 'Old_Airport')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SliverToBoxAdapter(
              child: _buildLoadingState(),
            );
          }

          if (snapshot.hasError) {
            return SliverToBoxAdapter(
              child: _buildErrorState('Something went wrong!'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return SliverToBoxAdapter(
              child: _buildEmptyState(),
            );
          }

          final allItems = snapshot.data!.docs;
          final filteredItems = _filterItems(allItems);

          if (filteredItems.isEmpty) {
            return SliverToBoxAdapter(
              child: _buildNoResultsState(),
            );
          }

          final categorizedItems = _groupItemsByCategory(filteredItems);

          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final entry = categorizedItems.entries.elementAt(index);
                return _buildCategorySection(entry.key, entry.value);
              },
              childCount: categorizedItems.length,
            ),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterItems(List<QueryDocumentSnapshot> items) {
    return items.where((item) {
      final itemData = item.data() as Map<String, dynamic>;

      if (_selectedCategory != 'All') {
        final category = itemData['categoryId']?.toString() ?? '';
        if (category != _selectedCategory) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final name = itemData['name']?.toString().toLowerCase() ?? '';
        final description = itemData['description']?.toString().toLowerCase() ?? '';
        if (!name.contains(_searchQuery) && !description.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Map<String, List<QueryDocumentSnapshot>> _groupItemsByCategory(
      List<QueryDocumentSnapshot> items) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    for (final item in items) {
      final category = item['categoryId']?.toString() ?? 'Others';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(item);
    }

    return grouped;
  }

  Widget _buildCategorySection(String category, List<QueryDocumentSnapshot> items) {
    final isExpanded = _expandedCategories[category] ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedCategories[category] = !isExpanded;
              });
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                  bottom: isExpanded ? Radius.zero : Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          '${items.length} item${items.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: isExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 300),
              opacity: isExpanded ? 1.0 : 0.0,
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildZomatoMenuItem(items[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZomatoMenuItem(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;
    final name = itemData['name']?.toString() ?? 'Unknown Item';
    final description = itemData['description']?.toString() ?? '';
    final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = itemData['imageUrl']?.toString();
    final isPopular = itemData['isPopular'] ?? false;
    final rating = (itemData['rating'] as num?)?.toDouble() ?? 4.0;
    final estimatedTime = itemData['EstimatedTime']?.toString() ?? '';

    final quantityInCart = _cartItems
        .where((cartItem) => cartItem['id'] == item.id)
        .fold(0, (sum, cartItem) => sum + (cartItem['quantity'] as num).toInt());

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.circle,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                    if (isPopular) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text(
                              'Bestseller',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (estimatedTime.isNotEmpty) ...[
                      SizedBox(width: 12),
                      Icon(Icons.access_time, color: Colors.grey[500], size: 14),
                      SizedBox(width: 4),
                      Text(
                        '$estimatedTime mins',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'QAR ${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: 16),

          Column(
            children: [
              Container(
                width: 120,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImagePlaceholder(),
                  )
                      : _buildImagePlaceholder(),
                ),
              ),
              SizedBox(height: 12),
              quantityInCart > 0
                  ? _buildQuantitySelector(item, quantityInCart)
                  : _buildAddButton(item),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.1),
            primaryColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          color: primaryColor.withOpacity(0.6),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildAddButton(QueryDocumentSnapshot item) {
    return GestureDetector(
      onTap: () => _showCustomizationSheet(item),
      child: Container(
        width: 100,
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primaryColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'ADD',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(QueryDocumentSnapshot item, int quantity) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _updateCartQuantity(item, -1),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Icon(Icons.remove, color: Colors.white, size: 18),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Text(
              quantity.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _updateCartQuantity(item, 1),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomizationSheet(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;
    String selectedSpiceLevel = 'Mild';
    Map<String, bool> selectedAddons = {
      'Extra Cheese': false,
      'Extra Sauce': false,
      'Extra Vegetables': false,
    };
    Map<String, double> addonPrices = {
      'Extra Cheese': 1.50,
      'Extra Sauce': 0.75,
      'Extra Vegetables': 2.00,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customize ${itemData['name']}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                Text(
                  'Spice Level',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    _buildSpiceLevelOption('Mild', Icons.local_fire_department,
                        selectedSpiceLevel, (level) => setSheetState(() => selectedSpiceLevel = level)),
                    _buildSpiceLevelOption('Medium', Icons.local_fire_department,
                        selectedSpiceLevel, (level) => setSheetState(() => selectedSpiceLevel = level)),
                    _buildSpiceLevelOption('Spicy', Icons.local_fire_department,
                        selectedSpiceLevel, (level) => setSheetState(() => selectedSpiceLevel = level)),
                  ],
                ),

                SizedBox(height: 20),

                Text(
                  'Add-ons',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 10),
                ...selectedAddons.keys.map((addon) =>
                    _buildAddonOption(addon, addonPrices[addon]!,
                        selectedAddons[addon]!,
                            (value) => setSheetState(() => selectedAddons[addon] = value!))),

                SizedBox(height: 20),

                TextField(
                  decoration: InputDecoration(
                    labelText: 'Special Instructions',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: 'Any special requests...',
                  ),
                  maxLines: 3,
                ),

                SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _addToCart(item);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Add to Cart • QAR ${_calculateItemPrice(itemData['price'], selectedAddons, addonPrices).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpiceLevelOption(String level, IconData icon, String selectedLevel, Function(String) onTap) {
    final isSelected = selectedLevel == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(level),
        child: Container(
          margin: EdgeInsets.only(right: 8),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          ),
          child: Column(
            children: [
              Icon(
                  icon,
                  color: isSelected ? primaryColor : Colors.orange,
                  size: 20
              ),
              SizedBox(height: 4),
              Text(
                  level,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? primaryColor : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddonOption(String name, double price, bool isSelected, Function(bool?) onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? primaryColor.withOpacity(0.05) : Colors.transparent,
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: onChanged,
            activeColor: primaryColor,
          ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '+QAR ${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateItemPrice(num basePrice, Map<String, bool> addons, Map<String, double> prices) {
    double total = basePrice.toDouble();
    addons.forEach((addon, selected) {
      if (selected && prices.containsKey(addon)) {
        total += prices[addon]!;
      }
    });
    return total;
  }

  Widget _buildFloatingCartButton() {
    return AnimatedBuilder(
      animation: _cartSlideAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _cartSlideAnimation.value,
          child: GestureDetector(
            onTap: _showCartBottomSheet,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'QAR ${_totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartBottomBar() {
    if (_cartItems.isEmpty) return SizedBox.shrink();

    final subtotal = _totalAmount;
    final grandTotal = subtotal; // Simplified - no additional fees

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showSubtotalDetails = !_showSubtotalDetails;
                });
                if (_showSubtotalDetails) {
                  _subtotalAnimationController.forward();
                } else {
                  _subtotalAnimationController.reverse();
                }
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total: QAR ${grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            '${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''} • Tap for details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showSubtotalDetails
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),

            // Simplified bill details
            AnimatedBuilder(
              animation: _subtotalSlideAnimation,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _subtotalSlideAnimation.value,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildBillRow('Subtotal', subtotal),
                            Divider(color: Colors.grey[300]),
                            _buildBillRow('Total', grandTotal, isTotal: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showCustomerDetailsBottomSheet,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: primaryColor),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _customerNameController.text.isEmpty
                                  ? 'Add customer details'
                                  : _customerNameController.text,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _customerNameController.text.isEmpty
                                    ? Colors.grey[600]
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              color: Colors.grey[400], size: 16),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _validateAndSubmitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Place Order • QAR ${grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.grey[800] : Colors.grey[600],
            ),
          ),
          Text(
            'QAR ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? primaryColor : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text(
              'Loading delicious food...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No Menu Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Menu items will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No Results Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different keywords or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(QueryDocumentSnapshot item) {
    setState(() {
      final itemData = item.data() as Map<String, dynamic>;
      final existingIndex = _cartItems.indexWhere(
            (cartItem) => cartItem['id'] == item.id,
      );

      if (existingIndex >= 0) {
        int currentQuantity = (_cartItems[existingIndex]['quantity'] as num).toInt();
        _cartItems[existingIndex]['quantity'] = currentQuantity + 1;
      } else {
        _cartItems.add({
          'id': item.id,
          'name': itemData['name']?.toString() ?? 'Unknown Item',
          'price': (itemData['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': 1,
        });
      }
      _calculateTotal();

      if (_cartItems.length == 1) {
        _cartAnimationController.forward();
      }
    });

    HapticFeedback.mediumImpact();
  }

  void _updateCartQuantity(QueryDocumentSnapshot item, int change) {
    setState(() {
      final existingIndex = _cartItems.indexWhere(
            (cartItem) => cartItem['id'] == item.id,
      );

      if (existingIndex >= 0) {
        int currentQuantity = (_cartItems[existingIndex]['quantity'] as num).toInt();
        int newQuantity = currentQuantity + change;

        if (newQuantity <= 0) {
          _cartItems.removeAt(existingIndex);
          if (_cartItems.isEmpty) {
            _cartAnimationController.reverse();
            _showSubtotalDetails = false;
            _subtotalAnimationController.reset();
          }
        } else {
          _cartItems[existingIndex]['quantity'] = newQuantity;
        }
      }
      _calculateTotal();
    });

    HapticFeedback.selectionClick();
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      final double price = (item['price'] as num).toDouble();
      final int quantity = (item['quantity'] as num).toInt();
      return sum + (price * quantity.toDouble());
    });
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Order',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text('Clear Cart'),
                              content: Text('Are you sure you want to remove all items?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Update main widget state
                                    setState(() {
                                      _cartItems.clear();
                                      _totalAmount = 0.0;
                                      _showSubtotalDetails = false;
                                    });
                                    _cartAnimationController.reverse();
                                    _subtotalAnimationController.reset();

                                    // Close dialog and bottom sheet
                                    Navigator.pop(dialogContext); // Close dialog
                                    Navigator.pop(context); // Close bottom sheet
                                  },
                                  child: Text('Clear', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'Clear Cart',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _cartItems.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text(
                          'Your cart is empty',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return _buildCartItem(item, index, setModalState);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index, StateSetter setModalState) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'QAR ${(item['price'] as num).toDouble().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    int currentQuantity = (item['quantity'] as num).toInt();
                    if (currentQuantity > 1) {
                      item['quantity'] = currentQuantity - 1;
                    } else {
                      _cartItems.removeAt(index);
                    }
                    _calculateTotal();
                  });
                  setModalState(() {}); // Update modal state
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove, size: 16),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  (item['quantity'] as num).toInt().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    int currentQuantity = (item['quantity'] as num).toInt();
                    item['quantity'] = currentQuantity + 1;
                    _calculateTotal();
                  });
                  setModalState(() {}); // Update modal state
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomerDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _customerPhoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _specialInstructionsController,
                decoration: InputDecoration(
                  labelText: 'Special Instructions (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Cart'),
        content: Text('Are you sure you want to remove all items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cartItems.clear();
                _totalAmount = 0.0;
                _showSubtotalDetails = false;
              });
              _cartAnimationController.reverse();
              _subtotalAnimationController.reset();
              Navigator.pop(context);
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _validateAndSubmitOrder() async {
    if (_customerNameController.text.trim().isEmpty) {
      _showErrorMessage('Please enter customer name');
      return;
    }

    if (_customerPhoneController.text.trim().isEmpty) {
      _showErrorMessage('Please enter phone number');
      return;
    }

    await _submitOrder();
  }

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final ordersToday = await _firestore
          .collection('Orders')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();

      final dailyOrderNumber = ordersToday.size + 1;
      final subtotal = _totalAmount;
      final grandTotal = subtotal; // No additional fees

      await _firestore.collection('Orders').add({
        'Order_type': 'takeaway',
        'service_type': _orderType,
        'payment_method': _paymentMethod,
        'customerName': _customerNameController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'specialInstructions': _specialInstructionsController.text.trim(),
        'items': _cartItems,
        'subtotal': subtotal,
        'totalAmount': grandTotal,
        'status': 'pending',
        'timestamp': Timestamp.now(),
        'dailyOrderNumber': dailyOrderNumber,
        'branchId': 'Old_Airport',
        'orderTime': DateFormat('HH:mm').format(now),
        'estimatedReadyTime': _calculateEstimatedTime(),
      });

      _showSuccessDialog();
      _clearFormData();

    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorMessage('Failed to place order: $e');
    }
  }

  String _calculateEstimatedTime() {
    final now = DateTime.now();
    final estimatedTime = now.add(Duration(minutes: 15));
    return DateFormat('HH:mm').format(estimatedTime);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: successColor,
                size: 48,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Order Placed Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Your takeaway order has been confirmed and will be ready for pickup soon. You\'ll receive updates on your phone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isSubmitting = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Continue Ordering'),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _clearFormData() {
    setState(() {
      _cartItems.clear();
      _totalAmount = 0.0;
      _showSubtotalDetails = false;
      _customerNameController.clear();
      _customerPhoneController.clear();
      _specialInstructionsController.clear();
    });
    _cartAnimationController.reverse();
    _subtotalAnimationController.reset();
  }
}




