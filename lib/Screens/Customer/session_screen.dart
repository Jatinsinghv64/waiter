import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../Firebase/FirestoreService.dart';
import '../../constants.dart';
import '../../utils.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final Map<String, Map<String, dynamic>> _cartItems = {};
  final Map<String, String?> _selectedVariants = {};
  final TextEditingController _customerNameController =
      TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isLoading = true;
  bool _isPlacingOrder = false;
  String? _errorMessage;
  String? _sessionId;
  Map<String, dynamic>? _sessionData;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _listenConnectivity();
    _loadSession();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  void _listenConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionId = _resolveSessionId();
      if (sessionId == null || sessionId.isEmpty) {
        throw InvalidOrderException('Missing QR session id.');
      }

      final sessionDoc = await FirebaseFirestore.instance
          .collection('qr_sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw OrderNotFoundException('QR session not found.');
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final isActive = sessionData['isActive'] ?? false;
      final isBillLocked = sessionData['isBillLocked'] ?? false;
      final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
      final isExpired =
          expiresAt != null && DateTime.now().isAfter(expiresAt);

      if (!isActive || isBillLocked || isExpired) {
        throw InvalidOrderException('This QR session is no longer active.');
      }

      final branchId = sessionData['branchId']?.toString();
      if (branchId == null || branchId.isEmpty) {
        throw InvalidOrderException('Invalid branch for this session.');
      }

      final categories =
          await FirestoreService.getMenuCategoriesForBranch(branchId);
      final items = await FirestoreService.getMenuItemsForBranch(branchId);

      await FirestoreService.touchQrSession(sessionId);

      if (!mounted) return;

      setState(() {
        _sessionId = sessionId;
        _sessionData = sessionData;
        _categories = categories;
        _menuItems = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorUtils.getFirebaseErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String? _resolveSessionId() {
    final uriSession = Uri.base.queryParameters['session'];
    if (uriSession != null && uriSession.isNotEmpty) {
      return uriSession;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      return args;
    }
    return null;
  }

  double _calculateTotal() {
    double total = 0.0;
    for (final item in _cartItems.values) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      total += price * quantity;
    }
    return total;
  }

  int _cartItemCount() {
    int count = 0;
    for (final item in _cartItems.values) {
      count += (item['quantity'] as num?)?.toInt() ?? 0;
    }
    return count;
  }

  List<Map<String, dynamic>> _parseVariants(Map<String, dynamic> itemData) {
    final variantsData = itemData['variants'];
    if (variantsData == null) return [];

    if (variantsData is List) {
      return List<Map<String, dynamic>>.from(variantsData);
    }

    if (variantsData is Map) {
      return variantsData.entries.map((entry) {
        final value = entry.value;
        if (value is Map) {
          return {
            'name': entry.key,
            ...value,
          };
        }
        return {
          'name': entry.key,
          'variantprice': value,
        };
      }).toList();
    }

    return [];
  }

  double _variantPrice(List<Map<String, dynamic>> variants, String? name) {
    if (name == null) return 0.0;
    final match = variants.firstWhere(
      (variant) => variant['name']?.toString() == name,
      orElse: () => {},
    );
    if (match.isEmpty) return 0.0;
    return (match['variantprice'] as num?)?.toDouble() ?? 0.0;
  }

  bool _isVariantAvailable(Map<String, dynamic> variant) {
    return (variant['isAvailable'] as bool?) ?? true;
  }

  void _addToCart(Map<String, dynamic> itemData) {
    final itemId = itemData['id']?.toString() ?? '';
    if (itemId.isEmpty) {
      UIUtils.showErrorSnackbar(context, 'Item is missing an id.');
      return;
    }

    final isAvailable = (itemData['isAvailable'] as bool?) ?? true;
    if (!isAvailable) {
      UIUtils.showWarningSnackbar(context, 'Item is currently unavailable.');
      return;
    }

    final variants = _parseVariants(itemData);
    final selectedVariant = _selectedVariants[itemId];
    if (variants.isNotEmpty && selectedVariant == null) {
      UIUtils.showWarningSnackbar(context, 'Please select a variant.');
      return;
    }

    final basePrice = (itemData['price'] as num?)?.toDouble() ?? 0.0;
    final variantPrice = _variantPrice(variants, selectedVariant);
    final totalPrice = basePrice + variantPrice;

    final key = '$itemId-${selectedVariant ?? ''}';
    final currentQuantity =
        (_cartItems[key]?['quantity'] as num?)?.toInt() ?? 0;
    if (currentQuantity >= ValidationLimits.maxQuantityPerItem) {
      UIUtils.showWarningSnackbar(
        context,
        'Max quantity reached for this item.',
      );
      return;
    }

    setState(() {
      _cartItems[key] = {
        'itemId': itemId,
        'name': itemData['name']?.toString() ?? 'Item',
        'price': totalPrice,
        'quantity': currentQuantity + 1,
        'variantPrice': variantPrice,
        'selectedVariant': selectedVariant,
        'specialInstructions': '',
      };
    });
  }

  void _updateCartQuantity(String key, int newQuantity) {
    if (newQuantity <= 0) {
      setState(() => _cartItems.remove(key));
      return;
    }
    if (newQuantity > ValidationLimits.maxQuantityPerItem) {
      UIUtils.showWarningSnackbar(
        context,
        'Max quantity reached for this item.',
      );
      return;
    }
    setState(() {
      _cartItems[key]?['quantity'] = newQuantity;
    });
  }

  Future<void> _placeOrder() async {
    if (!_isOnline) {
      UIUtils.showWarningSnackbar(
        context,
        'You are offline. Please reconnect to place your order.',
      );
      return;
    }

    if (_cartItems.isEmpty) {
      UIUtils.showWarningSnackbar(context, 'Your cart is empty.');
      return;
    }

    final sessionId = _sessionId;
    if (sessionId == null) {
      UIUtils.showErrorSnackbar(context, 'Missing session id.');
      return;
    }

    final total = _calculateTotal();
    if (total <= 0) {
      UIUtils.showErrorSnackbar(context, 'Invalid total.');
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final customerName =
          InputSanitizer.sanitize(_customerNameController.text);
      final customerPhone =
          InputSanitizer.sanitize(_customerPhoneController.text);

      final orderItems = _cartItems.values
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final orderId = await FirestoreService.createCustomerOrder(
        sessionId: sessionId,
        items: orderItems,
        totalAmount: total,
        customerName: customerName.isEmpty ? null : customerName,
        customerPhone: customerPhone.isEmpty ? null : customerPhone,
      );

      await FirestoreService.touchQrSession(sessionId);

      if (!mounted) return;
      setState(() {
        _cartItems.clear();
        _isPlacingOrder = false;
      });

      UIUtils.showSuccessSnackbar(
        context,
        'Order placed successfully. Order #$orderId',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      UIUtils.showErrorSnackbar(context, ErrorUtils.getFirebaseErrorMessage(e));
    }
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Your Order',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Text(
                        AppConfig.formatCurrency(_calculateTotal()),
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (_cartItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('Your cart is empty.'),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _cartItems.length,
                        separatorBuilder: (_, __) => Divider(),
                        itemBuilder: (context, index) {
                          final entry = _cartItems.entries.elementAt(index);
                          final item = entry.value;
                          final quantity =
                              (item['quantity'] as num?)?.toInt() ?? 0;
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name']?.toString() ?? 'Item',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (item['selectedVariant'] != null)
                                      Text(
                                        item['selectedVariant'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    Text(
                                      AppConfig.formatCurrency(
                                        (item['price'] as num?)?.toDouble() ??
                                            0.0,
                                      ),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  _updateCartQuantity(entry.key, quantity - 1);
                                  setSheetState(() {});
                                },
                              ),
                              Text('$quantity'),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  _updateCartQuantity(entry.key, quantity + 1);
                                  setSheetState(() {});
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Your name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _customerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone number (optional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPlacingOrder ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isPlacingOrder
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Place Order'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
                SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Unable to load session',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadSession,
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tableNumber = _sessionData?['tableNumber']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Table $tableNumber'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.shopping_cart_outlined),
                if (_cartItemCount() > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _cartItemCount().toString(),
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showCartSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSession,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isOnline)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange[700]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are offline. Ordering is disabled until you reconnect.',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ..._buildCategorySections(),
            if (_categories.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Menu is not available right now.'),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _cartItems.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCartSheet,
              backgroundColor: AppColors.primary,
              icon: Icon(Icons.shopping_cart),
              label: Text(AppConfig.formatCurrency(_calculateTotal())),
            ),
    );
  }

  List<Widget> _buildCategorySections() {
    if (_menuItems.isEmpty) return [];

    final itemsByCategory = <String, List<Map<String, dynamic>>>{};

    for (final category in _categories) {
      itemsByCategory[category['id'].toString()] = [];
    }
    itemsByCategory['other'] = [];

    for (final item in _menuItems) {
      final categoryId = item['categoryId']?.toString();
      final categoryName = item['category']?.toString();

      if (categoryId != null && itemsByCategory.containsKey(categoryId)) {
        itemsByCategory[categoryId]!.add(item);
        continue;
      }

      if (categoryName != null) {
        final matchingCategory = _categories.firstWhere(
          (category) => category['name']?.toString() == categoryName,
          orElse: () => {},
        );
        final matchingId = matchingCategory['id']?.toString();
        if (matchingId != null && itemsByCategory.containsKey(matchingId)) {
          itemsByCategory[matchingId]!.add(item);
          continue;
        }
      }

      itemsByCategory['other']!.add(item);
    }

    final sections = <Widget>[];

    for (final category in _categories) {
      final categoryId = category['id'].toString();
      final items = itemsByCategory[categoryId] ?? [];
      if (items.isEmpty) continue;
      sections.add(_buildCategoryTile(category['name']?.toString() ?? 'Menu', items));
    }

    final otherItems = itemsByCategory['other'] ?? [];
    if (otherItems.isNotEmpty) {
      sections.add(_buildCategoryTile('Other', otherItems));
    }

    return sections;
  }

  Widget _buildCategoryTile(
    String title,
    List<Map<String, dynamic>> items,
  ) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      children: items.map(_buildMenuItemCard).toList(),
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> itemData) {
    final itemId = itemData['id']?.toString() ?? '';
    final name = itemData['name']?.toString() ?? 'Item';
    final description = itemData['description']?.toString() ?? '';
    final basePrice = (itemData['price'] as num?)?.toDouble() ?? 0.0;
    final isAvailable = (itemData['isAvailable'] as bool?) ?? true;
    final variants = _parseVariants(itemData);
    final selectedVariant = _selectedVariants[itemId];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            SizedBox(height: 8),
            if (variants.isNotEmpty)
              DropdownButton<String>(
                value: selectedVariant,
                hint: Text('Select variant'),
                isExpanded: true,
                items: variants.map((variant) {
                  final variantName = variant['name']?.toString() ?? 'Variant';
                  final variantPrice =
                      (variant['variantprice'] as num?)?.toDouble() ?? 0.0;
                  final available = _isVariantAvailable(variant);
                  return DropdownMenuItem(
                    value: variantName,
                    enabled: available,
                    child: Text(
                      available
                          ? '$variantName (+${AppConfig.formatCurrency(variantPrice)})'
                          : '$variantName (Unavailable)',
                    ),
                  );
                }).toList(),
                onChanged: isAvailable
                    ? (value) {
                        setState(() {
                          _selectedVariants[itemId] = value;
                        });
                      }
                    : null,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppConfig.formatCurrency(basePrice),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isAvailable && _isOnline
                      ? () => _addToCart(itemData)
                      : null,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
