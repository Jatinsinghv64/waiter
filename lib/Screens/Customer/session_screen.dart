import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _cartItems = [];
  final TextEditingController _customerNameController =
      TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();

  String? _sessionId;
  Map<String, dynamic>? _sessionData;
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _menuCategories = [];
  String? _selectedCategoryId;
  double _totalAmount = 0.0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isOrderingAllowed = false;
  String? _orderingRestrictionMessage;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  void _initializeSession() {
    final uri = Uri.base;
    final sessionId = uri.queryParameters['session'];
    if (sessionId == null || sessionId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Missing session information. Please scan the QR code again.';
      });
      return;
    }

    _sessionId = sessionId;
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionDoc =
          await _firestore.collection('qr_sessions').doc(_sessionId).get();

      if (!sessionDoc.exists) {
        throw OrderNotFoundException('Session not found');
      }

      final sessionData = sessionDoc.data() ?? <String, dynamic>{};
      final branchId = sessionData['branchId'];
      if (branchId is! String || branchId.isEmpty) {
        throw OrderNotFoundException('Session has no branch assigned');
      }

      final isActive = sessionData['isActive'] ?? false;
      final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
      final isBillLocked = sessionData['isBillLocked'] ?? false;
      final isExpired =
          expiresAt != null && DateTime.now().isAfter(expiresAt);

      String? restrictionMessage;
      if (!isActive) {
        restrictionMessage = 'This session is no longer active.';
      } else if (isExpired) {
        restrictionMessage = 'This session has expired.';
      } else if (isBillLocked) {
        restrictionMessage =
            'Ordering is disabled because the bill has been finalized.';
      }

      final menuItems =
          await FirestoreService.getMenuItemsForBranch(branchId);
      final menuCategories =
          await FirestoreService.getMenuCategoriesForBranch(branchId);

      setState(() {
        _sessionData = sessionData;
        _menuItems = menuItems;
        _menuCategories = menuCategories;
        _selectedCategoryId =
            menuCategories.isNotEmpty ? menuCategories.first['id'] : null;
        _isOrderingAllowed = restrictionMessage == null;
        _orderingRestrictionMessage = restrictionMessage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      return sum + (price * quantity);
    });
  }

  bool _matchesCategory(Map<String, dynamic> item) {
    if (_selectedCategoryId == null) {
      return true;
    }
    final categoryId =
        item['categoryId']?.toString() ?? item['category_id']?.toString();
    if (categoryId != null) {
      return categoryId == _selectedCategoryId;
    }
    final categoryName = item['categoryName']?.toString();
    final selectedCategory = _menuCategories
        .firstWhere((cat) => cat['id'] == _selectedCategoryId,
            orElse: () => <String, dynamic>{})
        .cast<String, dynamic>();
    return categoryName != null &&
        categoryName == selectedCategory['name']?.toString();
  }

  void _addToCart({
    required Map<String, dynamic> item,
    required int quantity,
    String? selectedVariant,
    double variantPrice = 0.0,
    String? specialInstructions,
  }) {
    if (_cartItems.length >= ValidationLimits.maxItemsPerOrder) {
      _showError('Cart item limit reached.');
      return;
    }

    if (quantity <= 0 || quantity > ValidationLimits.maxQuantityPerItem) {
      _showError('Invalid quantity.');
      return;
    }

    final basePrice = (item['price'] as num?)?.toDouble() ?? 0.0;
    final totalPrice = basePrice + variantPrice;

    final existingIndex = _cartItems.indexWhere((cartItem) {
      final isSameItem = cartItem['id'] == item['id'];
      final isSameVariant = cartItem['selectedVariant'] == selectedVariant;
      final isSameInstructions =
          (cartItem['specialInstructions'] ?? '') ==
          (specialInstructions ?? '');
      return isSameItem && isSameVariant && isSameInstructions;
    });

    setState(() {
      if (existingIndex >= 0) {
        final currentQuantity =
            (_cartItems[existingIndex]['quantity'] as num?)?.toInt() ?? 0;
        final newQuantity = currentQuantity + quantity;
        if (newQuantity > ValidationLimits.maxQuantityPerItem) {
          _showError('Quantity limit exceeded.');
          return;
        }
        _cartItems[existingIndex]['quantity'] = newQuantity;
      } else {
        _cartItems.add({
          'id': item['id']?.toString() ?? '',
          'name': item['name']?.toString() ?? 'Unknown Item',
          'basePrice': basePrice,
          'variantPrice': variantPrice,
          'price': totalPrice,
          'quantity': quantity,
          'selectedVariant': selectedVariant,
          'variantName': selectedVariant,
          'specialInstructions': specialInstructions,
        });
      }
      _calculateTotal();
    });
  }

  void _updateCartQuantity(int index, int change) {
    setState(() {
      final currentQuantity =
          (_cartItems[index]['quantity'] as num?)?.toInt() ?? 0;
      final newQuantity = currentQuantity + change;
      if (newQuantity <= 0) {
        _cartItems.removeAt(index);
      } else if (newQuantity <= ValidationLimits.maxQuantityPerItem) {
        _cartItems[index]['quantity'] = newQuantity;
      }
      _calculateTotal();
    });
  }

  Future<void> _promptAddItem(Map<String, dynamic> item) async {
    final variants = item['variants'];
    if (variants == null || (variants is List && variants.isEmpty)) {
      _addToCart(item: item, quantity: 1);
      return;
    }

    final variantOptions = _normalizeVariants(variants);
    if (variantOptions.isEmpty) {
      _addToCart(item: item, quantity: 1);
      return;
    }

    String? selectedVariant = variantOptions.first['name']?.toString();
    double selectedVariantPrice =
        (variantOptions.first['price'] as num?)?.toDouble() ?? 0.0;
    int quantity = 1;
    final instructionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item['name']?.toString() ?? 'Select Variant'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...variantOptions.map((variant) {
                      final variantName = variant['name']?.toString() ?? '';
                      final variantPrice =
                          (variant['price'] as num?)?.toDouble() ?? 0.0;
                      return RadioListTile<String>(
                        title: Text(
                          '$variantName (+${AppConfig.formatCurrency(variantPrice)})',
                        ),
                        value: variantName,
                        groupValue: selectedVariant,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedVariant = value;
                            selectedVariantPrice = variantPrice;
                          });
                        },
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quantity'),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (quantity > 1) {
                                  setState(() => quantity--);
                                }
                              },
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(quantity.toString()),
                            IconButton(
                              onPressed: () {
                                if (quantity <
                                    ValidationLimits.maxQuantityPerItem) {
                                  setState(() => quantity++);
                                }
                              },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                    TextField(
                      controller: instructionController,
                      maxLength: ValidationLimits.maxSpecialInstructionsLength,
                      decoration: const InputDecoration(
                        labelText: 'Special instructions (optional)',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == true && selectedVariant != null) {
      _addToCart(
        item: item,
        quantity: quantity,
        selectedVariant: selectedVariant,
        variantPrice: selectedVariantPrice,
        specialInstructions: InputSanitizer.sanitizeInstructions(
          instructionController.text.trim(),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _normalizeVariants(dynamic variants) {
    if (variants is List) {
      return variants.map<Map<String, dynamic>>((variant) {
        final data = variant as Map<String, dynamic>;
        return {
          'name': data['name']?.toString() ?? data['variantName']?.toString(),
          'price': (data['variantprice'] as num?)?.toDouble() ??
              (data['price'] as num?)?.toDouble() ??
              0.0,
        };
      }).where((variant) => variant['name'] != null).toList();
    }

    if (variants is Map) {
      return variants.entries.map<Map<String, dynamic>>((entry) {
        final value = entry.value;
        if (value is Map) {
          return {
            'name': entry.key.toString(),
            'price': (value['variantprice'] as num?)?.toDouble() ??
                (value['price'] as num?)?.toDouble() ??
                0.0,
          };
        }
        return {
          'name': entry.key.toString(),
          'price': 0.0,
        };
      }).toList();
    }

    return [];
  }

  Future<void> _placeOrder() async {
    if (_isSubmitting) return;
    if (!_isOrderingAllowed) {
      _showError(_orderingRestrictionMessage ?? 'Ordering is disabled.');
      return;
    }

    if (_cartItems.isEmpty) {
      _showError('Your cart is empty.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final customerName = InputSanitizer.sanitizeWithLimit(
        _customerNameController.text.trim(),
        ValidationLimits.maxCustomerNameLength,
      );
      final customerPhone = InputSanitizer.sanitize(
        _customerPhoneController.text.trim(),
      );

      await FirestoreService.createCustomerOrder(
        sessionId: _sessionId!,
        items: List<Map<String, dynamic>>.from(_cartItems),
        totalAmount: _totalAmount,
        customerName: customerName,
        customerPhone: customerPhone,
      );

      if (!mounted) return;
      setState(() {
        _cartItems.clear();
        _calculateTotal();
      });

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order placed'),
          content: const Text(
            'Your order has been sent to the kitchen. You can place additional orders anytime.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Failed to place order: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Cart',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_cartItems.isEmpty)
                        const Text('Your cart is empty.'),
                      if (_cartItems.isNotEmpty)
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _cartItems.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              final itemName = item['name']?.toString() ?? '';
                              final itemVariant =
                                  item['selectedVariant']?.toString();
                              final quantity =
                                  (item['quantity'] as num?)?.toInt() ?? 0;
                              final price =
                                  (item['price'] as num?)?.toDouble() ?? 0.0;
                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(itemName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        if (itemVariant != null &&
                                            itemVariant.isNotEmpty)
                                          Text('Variant: $itemVariant'),
                                        Text(
                                          'Subtotal: ${AppConfig.formatCurrency(price * quantity)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () {
                                      _updateCartQuantity(index, -1);
                                      setModalState(() {});
                                    },
                                  ),
                                  Text(quantity.toString()),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () {
                                      _updateCartQuantity(index, 1);
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Total: ${AppConfig.formatCurrency(_totalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customerNameController,
                        maxLength: ValidationLimits.maxCustomerNameLength,
                        decoration: const InputDecoration(
                          labelText: 'Your name (optional)',
                        ),
                      ),
                      TextField(
                        controller: _customerPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _cartItems.isEmpty || _isSubmitting
                              ? null
                              : () async {
                                  Navigator.of(context).pop();
                                  await _placeOrder();
                                },
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Place order'),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _sessionData?['tableNumber'] != null
              ? 'Table ${_sessionData?['tableNumber']}'
              : 'Self Ordering',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    if (_orderingRestrictionMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.orange.shade100,
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_orderingRestrictionMessage!),
                            ),
                          ],
                        ),
                      ),
                    if (_menuCategories.isNotEmpty)
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _menuCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = _menuCategories[index];
                            final categoryId = category['id']?.toString();
                            final isSelected =
                                categoryId != null && categoryId == _selectedCategoryId;
                            return ChoiceChip(
                              label: Text(category['name']?.toString() ?? 'Category'),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategoryId = categoryId;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _menuItems.isEmpty
                          ? const Center(child: Text('No menu items available.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _menuItems.length,
                              itemBuilder: (context, index) {
                                final item = _menuItems[index];
                                if (!_matchesCategory(item)) {
                                  return const SizedBox.shrink();
                                }
                                final itemName =
                                    item['name']?.toString() ?? 'Menu item';
                                final itemPrice =
                                    (item['price'] as num?)?.toDouble() ?? 0.0;
                                final isAvailable =
                                    item['isAvailable'] ?? true;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                AppConfig.formatCurrency(itemPrice),
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              if (!isAvailable)
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    'Unavailable',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: !_isOrderingAllowed || !isAvailable
                                              ? null
                                              : () => _promptAddItem(item),
                                          child: const Text('Add'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Items: ${_cartItems.length}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Total: ${AppConfig.formatCurrency(_totalAmount)}',
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _cartItems.isEmpty ? null : _showCartSheet,
                            child: const Text('View cart'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessionData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
