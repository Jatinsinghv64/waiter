// Main App Structure
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // required for FlutterFire
  );
  runApp( MyApp());
}
class MyApp extends StatelessWidget {
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
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Waiter Login')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) =>
                value!.isEmpty ? 'Please enter email' : null,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) =>
                value!.isEmpty ? 'Please enter password' : null,
              ),
              SizedBox(height: 30),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _login,
                child: Text('Login'),
              ),
            ],
          ),
        ),
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
  final List<Widget> _screens = [
    TablesScreen(),
    ActiveOrdersScreen(),
    MenuBrowserScreen(),
    TakeawayOrderScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Waiter App'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Add this line
        backgroundColor: Colors.blue, // Optional: set background color
        selectedItemColor: Colors.white, // Optional: set selected color
        unselectedItemColor: Colors.white70, // Optional: set unselected color
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.table_restaurant),
            label: 'Tables',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.takeout_dining), // Better icon for takeaway
            label: 'Take Away',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Tables Screen - Using CustomScrollView (Most Robust)
// Tables Screen - Fixed Pixel Overflow
class TablesScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, secondaryColor],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('Branch').doc('Old_Airport').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: CircularProgressIndicator());
            }

            final branchData = snapshot.data!.data() as Map<String, dynamic>;
            final tables = branchData['Tables'] as Map<String, dynamic>? ?? {};
            final tableList = tables.entries.toList();

            return Column(
              children: [
                // Fixed Header with proper padding
                Container(
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Table Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap on a table to take order',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // GridView with proper constraints
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85, // Adjusted for better fit
                      ),
                      itemCount: tableList.length,
                      itemBuilder: (context, index) {
                        final tableEntry = tableList[index];
                        final tableNumber = tableEntry.key;
                        final tableData = tableEntry.value as Map<String, dynamic>;
                        final status = tableData['status']?.toString() ?? 'available';
                        final seats = tableData['seats']?.toString() ?? '0';
                        final currentOrderId = tableData['currentOrderId']?.toString();

                        Color statusColor;
                        IconData statusIcon;
                        String statusText;

                        switch (status) {
                          case 'occupied':
                            statusColor = Colors.orange;
                            statusIcon = Icons.group;
                            statusText = 'Occupied';
                            break;
                          case 'needs_attention':
                            statusColor = Colors.red;
                            statusIcon = Icons.warning;
                            statusText = 'Needs Help';
                            break;
                          case 'ordered':
                            statusColor = Colors.green;
                            statusIcon = Icons.restaurant;
                            statusText = 'Ordered';
                            break;
                          default:
                            statusColor = primaryColor;
                            statusIcon = Icons.event_available;
                            statusText = 'Available';
                        }

                        return GestureDetector(
                          onTap: () {
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
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: statusColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    statusIcon,
                                    color: statusColor,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Table $tableNumber',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: primaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '$seats Seats',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Order Screen - Improved Previous Design
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
  List<Map<String, dynamic>> _cartItems = [];
  double _totalAmount = 0.0;
  List<Map<String, dynamic>> _existingOrderItems = [];
  bool _isCheckingOut = false;
  String _tableStatus = 'available';

  @override
  void initState() {
    super.initState();
    _tableStatus = widget.tableData['status']?.toString() ?? 'available';

    if (widget.isAddingToExisting && widget.existingOrderId != null) {
      _loadExistingOrder();
    }
  }

  Future<void> _loadExistingOrder() async {
    try {
      final orderDoc = await _firestore
          .collection('Orders')
          .doc(widget.existingOrderId)
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
        setState(() {
          _existingOrderItems = items;
        });
      }
    } catch (e) {
      print('Error loading existing order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAddingToExisting
              ? 'Add to Table ${widget.tableNumber} Order'
              : 'Table ${widget.tableNumber} Order',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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
            // Existing Order Items (if adding to existing order)
            if (widget.isAddingToExisting && _existingOrderItems.isNotEmpty)
              _buildExistingOrderSection(),

            // Current Cart Section
            if (_cartItems.isNotEmpty) _buildCartSection(),

            // Menu Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_cartItems.isEmpty && !widget.isAddingToExisting)
                    _buildEmptyCart(),

                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Menu Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildMenuList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildExistingOrderSection() {
    return Container(
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
        ],
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
                  widget.isAddingToExisting ? 'Additional Items' : 'Current Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  '+\$$_totalAmount',
                  style: TextStyle(
                    fontSize: 16,
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
                        // Item name and price
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
                              '\$${item['price'].toStringAsFixed(2)} each',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        // Centered quantity controls: - 1 +
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Remove button (-)
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

                            // Quantity number
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                            // Add button (+)
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
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add items from the menu below',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList() {
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

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            final itemData = item.data() as Map<String, dynamic>;
            final name = itemData['name']?.toString() ?? 'Unknown Item';
            final description = itemData['description']?.toString() ?? '';
            final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
            final imageUrl = itemData['imageUrl']?.toString();
            final estimatedTime = itemData['EstimatedTime']?.toString() ?? '';
            final isPopular = itemData['isPopular'] ?? false;

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(12),
                leading: imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderIcon(),
                  ),
                )
                    : _buildPlaceholderIcon(),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPopular) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'POPULAR',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        if (estimatedTime.isNotEmpty) ...[
                          SizedBox(width: 16),
                          Icon(Icons.timer, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            '$estimatedTime mins',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: Colors.white, size: 20),
                    onPressed: () => _addToCart(item),
                    padding: EdgeInsets.all(6),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant_menu, color: primaryColor),
    );
  }

  Widget? _buildBottomNavigationBar() {
    if (_cartItems.isEmpty && _tableStatus != 'ordered') return null;

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
          // Submit Order Button (for new items)
          if (_cartItems.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isAddingToExisting ? 'Additional Total' : 'Total Amount',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '\$$_totalAmount',
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
                        widget.isAddingToExisting ? 'Add Items' : 'Submit Order',
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

          // Checkout Button - Show when table is ordered/occupied
          if (_tableStatus == 'ordered' || _tableStatus == 'occupied')
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

  void _addToCart(QueryDocumentSnapshot item) {
    setState(() {
      final itemData = item.data() as Map<String, dynamic>;
      final existingIndex = _cartItems.indexWhere(
              (cartItem) => cartItem['id'] == item.id);

      if (existingIndex >= 0) {
        _cartItems[existingIndex]['quantity'] += 1;
      } else {
        _cartItems.add({
          'id': item.id,
          'name': itemData['name']?.toString() ?? 'Unknown Item',
          'price': (itemData['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': 1,
        });
      }
      _calculateTotal();
    });
  }

  void _updateQuantity(int index, int change) {
    setState(() {
      _cartItems[index]['quantity'] += change;
      if (_cartItems[index]['quantity'] <= 0) {
        _cartItems.removeAt(index);
      }
      _calculateTotal();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      return sum + (item['price'] * item['quantity']);
    });
  }

  Future<void> _submitOrder() async {
    try {
      if (widget.isAddingToExisting && widget.existingOrderId != null) {
        await _addToExistingOrder();
      } else {
        await _createNewOrder();
      }

      // Update local table status after successful order submission
      setState(() {
        _tableStatus = 'ordered';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAddingToExisting
              ? 'Items added to order successfully!'
              : 'Order submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Clear cart but stay on the screen
      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
      });

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

    // Create order document
    final orderRef = await _firestore.collection('Orders').add({
      'order_type': 'dine_in',
      'tableNumber': widget.tableNumber,
      'items': _cartItems,
      'subtotal': _totalAmount,
      'totalAmount': _totalAmount,
      'status': 'pending',
      'timestamp': Timestamp.now(),
      'dailyOrderNumber': dailyOrderNumber,
      'branchId': 'Old_Airport',
    });

    // Update table status
    await _firestore.collection('Branch').doc('Old_Airport').update({
      'Tables.${widget.tableNumber}.status': 'ordered',
      'Tables.${widget.tableNumber}.currentOrderId': orderRef.id,
    });
  }

  Future<void> _addToExistingOrder() async {
    // Get current order
    final orderDoc = await _firestore
        .collection('Orders')
        .doc(widget.existingOrderId)
        .get();

    if (orderDoc.exists) {
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final currentItems = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      final currentTotal = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final currentSubtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;

      // Merge with new items
      final mergedItems = _mergeOrderItems(currentItems, _cartItems);
      final newTotal = currentTotal + _totalAmount;
      final newSubtotal = currentSubtotal + _totalAmount;

      // Update order
      await _firestore.collection('Orders').doc(widget.existingOrderId).update({
        'items': mergedItems,
        'subtotal': newSubtotal,
        'totalAmount': newTotal,
        'status': 'pending', // Reset to pending if it was prepared
        'timestamp': Timestamp.now(), // Update timestamp
      });
    }
  }

  List<Map<String, dynamic>> _mergeOrderItems(
      List<Map<String, dynamic>> existingItems,
      List<Map<String, dynamic>> newItems) {

    final merged = List<Map<String, dynamic>>.from(existingItems);

    for (final newItem in newItems) {
      final existingIndex = merged.indexWhere(
              (item) => item['id'] == newItem['id']);

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
                  // Cash Payment
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
                  // Card Payment
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
    Navigator.pop(context); // Close the payment options dialog
    setState(() => _isCheckingOut = true);

    try {
      // Get the current order total
      final orderDoc = await _firestore
          .collection('Orders')
          .doc(widget.existingOrderId ?? widget.tableData['currentOrderId'])
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;

        // Update order status to paid
        await _firestore.collection('Orders').doc(widget.existingOrderId ?? widget.tableData['currentOrderId']).update({
          'status': 'paid',
          'paymentMethod': paymentMethod,
          'paymentTime': Timestamp.now(),
          'paidAmount': totalAmount,
        });

        // Clear the table
        await _firestore.collection('Branch').doc('Old_Airport').update({
          'Tables.${widget.tableNumber}.status': 'available',
          'Tables.${widget.tableNumber}.currentOrderId': FieldValue.delete(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processed successfully with ${paymentMethod.toUpperCase()}!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to tables screen
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
// Active Orders Screen
class ActiveOrdersScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Orders')
          .where('order_type', isEqualTo: 'dine_in')
          .where('branchId', isEqualTo: 'Old_Airport')
          .where('status', whereIn: ['pending', 'preparing', 'prepared'])
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final tableNumber = order['tableNumber'] ?? 'Unknown';
            final status = order['status'];

            Color statusColor;
            switch (status) {
              case 'prepared':
                statusColor = Colors.green;
                break;
              case 'preparing':
                statusColor = Colors.orange;
                break;
              default:
                statusColor = Colors.red;
            }

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: Icon(Icons.receipt, color: statusColor),
                title: Text('Order #${order['dailyOrderNumber']}'),
                subtitle: Text(
                  'Table: $tableNumber\n'
                      'Total: \$${order['totalAmount'].toStringAsFixed(2)}',
                ),
                trailing: Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: statusColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailScreen(order: order),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// Order Detail Screen
class OrderDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot order;

  OrderDetailScreen({required this.order});

  @override
  Widget build(BuildContext context) {
    final orderData = order.data() as Map<String, dynamic>;
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final status = orderData['status']?.toString() ?? 'unknown';
    final tableNumber = orderData['tableNumber']?.toString() ?? 'Unknown';
    final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: Text('Order Details')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                Text('Order #$dailyOrderNumber',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Table: $tableNumber',
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 16),
                Text('Status: ${status.toUpperCase()}',
                    style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map((item) => ListTile(
                  title: Text(item['name']?.toString() ?? 'Unknown Item'),
                  subtitle: Text(
                      'Quantity: ${item['quantity']} × \$${(item['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                  trailing: Text(
                      '\$${((item['price'] as num?)?.toDouble() ?? 0.0 * (item['quantity'] as num?)!.toInt() ?? 1).toStringAsFixed(2)}'),
                )),
                Divider(),
                ListTile(
                  title: Text('TOTAL',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text('\$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (status == 'prepared')
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _markAsServed(context),
                child: Text('Mark as Served'),
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50)),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'prepared':
        return Colors.green;
      case 'preparing':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Future<void> _markAsServed(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(order.id)
          .update({'status': 'delivered'});

      // Update table status in Branch document
      final orderData = order.data() as Map<String, dynamic>;
      final tableNumber = orderData['tableNumber']?.toString();

      if (tableNumber != null) {
        final tableUpdate = <String, dynamic>{};
        tableUpdate['Tables.$tableNumber.status'] = 'occupied';
        tableUpdate['Tables.$tableNumber.currentOrderId'] = '';

        await FirebaseFirestore.instance
            .collection('Branch')
            .doc('Old_Airport')
            .update(tableUpdate);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order marked as served!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order: $e')),
      );
    }
  }
}
// Menu Browser Screen
class MenuBrowserScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Menu Browser'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Categories'),
              Tab(text: 'All Items'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CategoriesTab(),
            AllMenuItemsTab(),
          ],
        ),
      ),
    );
  }
}
// Categories Tab
class CategoriesTab extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('menu_categories')
          .where('isActive', isEqualTo: true)
          .where('branchId', isEqualTo: 'Old_Airport')
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs;

        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              leading: category['imageUrl'] != null
                  ? Image.network(category['imageUrl'], width: 50, height: 50)
                  : Icon(Icons.category),
              title: Text(category['name']),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryItemsScreen(category: category),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Category Items Screen - Updated with proper type casting
class CategoryItemsScreen extends StatelessWidget {
  final QueryDocumentSnapshot category;

  CategoryItemsScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    final categoryData = category.data() as Map<String, dynamic>;
    final categoryName = categoryData['name']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('menu_items')
            .where('categoryId', isEqualTo: categoryName)
            .where('branchId', isEqualTo: 'Old_Airport')
            .where('isAvailable', isEqualTo: true)
            .orderBy('sortOrder')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final itemData = item.data() as Map<String, dynamic>;
              final name = itemData['name']?.toString() ?? 'Unknown Item';
              final description = itemData['description']?.toString() ?? '';
              final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
              final estimatedTime = itemData['EstimatedTime']?.toString() ?? '';

              return ListTile(
                leading: itemData['imageUrl'] != null
                    ? Image.network(itemData['imageUrl']!, width: 50, height: 50)
                    : Icon(Icons.fastfood),
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) Text(description),
                    Text('\$${price.toStringAsFixed(2)}'),
                    if (estimatedTime.isNotEmpty)
                      Text('Prep time: $estimatedTime mins'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// All Menu Items Tab
class AllMenuItemsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('menu_items')
          .where('isAvailable', isEqualTo: true)
          .where('branchId', isEqualTo: 'Old_Airport')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: item['imageUrl'] != null
                  ? Image.network(item['imageUrl'], width: 50, height: 50)
                  : Icon(Icons.fastfood),
              title: Text(item['name']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['description'] ?? ''),
                  Text('\$${item['price'].toStringAsFixed(2)}'),
                  if (item['EstimatedTime'] != null)
                    Text('Prep time: ${item['EstimatedTime']} mins'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class TakeawayOrderScreen extends StatefulWidget {
  @override
  _TakeawayOrderScreenState createState() => _TakeawayOrderScreenState();
}

class _TakeawayOrderScreenState extends State<TakeawayOrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);
  List<Map<String, dynamic>> _cartItems = [];
  double _totalAmount = 0.0;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Takeaway Orders'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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
            // Customer Information Section
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _customerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            // Cart Section
            if (_cartItems.isNotEmpty) _buildCartSection(),

            // Menu Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_cartItems.isEmpty)
                    _buildEmptyCart(),

                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Menu Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildMenuList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
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
                  'Current Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  '+\$$_totalAmount',
                  style: TextStyle(
                    fontSize: 16,
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
                        // Item name and price
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
                              '\$${item['price'].toStringAsFixed(2)} each',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        // Centered quantity controls: - 1 +
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Remove button (-)
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

                            // Quantity number
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                            // Add button (+)
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
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add items from the menu below',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList() {
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

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            final itemData = item.data() as Map<String, dynamic>;
            final name = itemData['name']?.toString() ?? 'Unknown Item';
            final description = itemData['description']?.toString() ?? '';
            final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
            final imageUrl = itemData['imageUrl']?.toString();
            final estimatedTime = itemData['EstimatedTime']?.toString() ?? '';
            final isPopular = itemData['isPopular'] ?? false;

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(12),
                leading: imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderIcon(),
                  ),
                )
                    : _buildPlaceholderIcon(),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPopular) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'POPULAR',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        if (estimatedTime.isNotEmpty) ...[
                          SizedBox(width: 16),
                          Icon(Icons.timer, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            '$estimatedTime mins',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: Colors.white, size: 20),
                    onPressed: () => _addToCart(item),
                    padding: EdgeInsets.all(6),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant_menu, color: primaryColor),
    );
  }

  Widget? _buildBottomNavigationBar() {
    if (_cartItems.isEmpty) return null;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '\$$_totalAmount',
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
            onPressed: _isSubmitting ? null : _submitTakeawayOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 8),
                Text(
                  'Submit Order',
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
    );
  }

  void _addToCart(QueryDocumentSnapshot item) {
    setState(() {
      final itemData = item.data() as Map<String, dynamic>;
      final existingIndex = _cartItems.indexWhere(
              (cartItem) => cartItem['id'] == item.id);

      if (existingIndex >= 0) {
        _cartItems[existingIndex]['quantity'] += 1;
      } else {
        _cartItems.add({
          'id': item.id,
          'name': itemData['name']?.toString() ?? 'Unknown Item',
          'price': (itemData['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': 1,
        });
      }
      _calculateTotal();
    });
  }

  void _updateQuantity(int index, int change) {
    setState(() {
      _cartItems[index]['quantity'] += change;
      if (_cartItems[index]['quantity'] <= 0) {
        _cartItems.removeAt(index);
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      return sum + (item['price'] * item['quantity']);
    });
  }

  Future<void> _submitTakeawayOrder() async {
    // Validate customer information
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter customer name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final ordersToday = await _firestore
          .collection('Orders')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();

      final dailyOrderNumber = ordersToday.size + 1;

      // Create takeaway order document
      await _firestore.collection('Orders').add({
        'order_type': 'takeaway',
        'customerName': _customerNameController.text,
        'customerPhone': _customerPhoneController.text,
        'items': _cartItems,
        'subtotal': _totalAmount,
        'totalAmount': _totalAmount,
        'status': 'pending',
        'timestamp': Timestamp.now(),
        'dailyOrderNumber': dailyOrderNumber,
        'branchId': 'Old_Airport',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Takeaway order submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Clear the form
      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
        _customerNameController.clear();
        _customerPhoneController.clear();
        _isSubmitting = false;
      });

    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
