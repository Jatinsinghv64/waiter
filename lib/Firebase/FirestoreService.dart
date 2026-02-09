// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

/// Custom exception types for better error handling
class OrderNotFoundException implements Exception {
  final String orderId;
  OrderNotFoundException(this.orderId);
  @override
  String toString() => 'Order not found: $orderId';
}

class OrderModifiedException implements Exception {
  final String orderId;
  OrderModifiedException(this.orderId);
  @override
  String toString() => 'Order was modified by another user: $orderId';
}

class InvalidStatusTransitionException implements Exception {
  final String fromStatus;
  final String toStatus;
  InvalidStatusTransitionException(this.fromStatus, this.toStatus);
  @override
  String toString() => 'Invalid status transition from $fromStatus to $toStatus';
}

class TableOrderMismatchException implements Exception {
  final String tableNumber;
  final String? expectedOrderId;
  TableOrderMismatchException(this.tableNumber, this.expectedOrderId);
  @override
  String toString() => 'Table $tableNumber order mismatch. Expected: $expectedOrderId';
}

class InvalidOrderException implements Exception {
  final String message;
  InvalidOrderException(this.message);
  @override
  String toString() => 'Invalid order: $message';
}

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _maxItemsPerOrder = 50;
  static const int _maxQuantityPerItem = 99;
  static const Duration _defaultQrSessionTtl = Duration(hours: 2);

  // ============================================
  // VALIDATION HELPERS
  // ============================================

  /// Validates that an order exists and returns its data
  static Future<Map<String, dynamic>?> validateOrderExists(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('Orders').doc(orderId).get();
      if (!orderDoc.exists) {
        return null;
      }
      return orderDoc.data() as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Validates if a status transition is allowed
  /// Supports both forward (normal flow) and backward (return/correction) transitions
  static bool isValidStatusTransition(String? fromStatus, String toStatus, {bool allowBackward = false}) {
    // Forward transitions (normal order flow)
    const forwardTransitions = <String, List<String>>{
      // From null (new order) can go to these
      '': ['pending', 'preparing'],
      'pending': ['preparing', 'cancelled'],
      'preparing': ['prepared', 'cancelled'],
      'prepared': ['served', 'paid', 'cancelled'],
      'served': ['paid', 'cancelled'],
      'paid': [], // Terminal state - no further transitions
      'cancelled': [], // Terminal state - no further transitions
      'returned': [], // Terminal state
      // Special cases for exchanges
      'delivered': ['preparing'], // Allow exchange flow
    };
    
    // Backward transitions (for corrections/returns - requires explicit allowBackward flag)
    const backwardTransitions = <String, List<String>>{
      'preparing': ['pending'],
      'prepared': ['preparing'],
      'served': ['prepared'],
    };

    final from = fromStatus ?? '';
    final forwardAllowed = forwardTransitions[from] ?? [];
    
    if (forwardAllowed.contains(toStatus)) {
      return true;
    }
    
    // Only allow backward transitions if explicitly enabled
    if (allowBackward) {
      final backwardAllowed = backwardTransitions[from] ?? [];
      return backwardAllowed.contains(toStatus);
    }
    
    return false;
  }

  /// Gets all valid next statuses for a given current status
  /// Set includeBackward to true to include correction/return transitions
  static List<String> getValidNextStatuses(String? currentStatus, {bool includeBackward = false}) {
    const forwardTransitions = <String, List<String>>{
      '': ['pending', 'preparing'],
      'pending': ['preparing', 'cancelled'],
      'preparing': ['prepared', 'cancelled'],
      'prepared': ['served', 'paid', 'cancelled'],
      'served': ['paid', 'cancelled'],
      'paid': [],
      'cancelled': [],
      'returned': [],
      'delivered': ['preparing'],
    };
    
    const backwardTransitions = <String, List<String>>{
      'preparing': ['pending'],
      'prepared': ['preparing'],
      'served': ['prepared'],
    };
    
    final transitions = List<String>.from(forwardTransitions[currentStatus ?? ''] ?? []);
    
    if (includeBackward) {
      transitions.addAll(backwardTransitions[currentStatus ?? ''] ?? []);
    }
    
    return transitions;
  }

  /// Reconciles table-order status inconsistencies
  static Future<void> reconcileTableOrderStatus(
    String branchId,
    String tableNumber,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final branchRef = _firestore.collection('Branch').doc(branchId);
      final branchDoc = await transaction.get(branchRef);

      if (!branchDoc.exists) return;

      final branchData = branchDoc.data() as Map<String, dynamic>;
      final tables = branchData['Tables'] as Map<String, dynamic>? ?? {};
      final tableData = tables[tableNumber] as Map<String, dynamic>?;

      if (tableData == null) return;

      final currentOrderId = tableData['currentOrderId'] as String?;
      final tableStatus = tableData['status'] as String? ?? 'available';

      // If table has an order ID, verify it exists
      if (currentOrderId != null) {
        final orderRef = _firestore.collection('Orders').doc(currentOrderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          // Order doesn't exist - clear table
          transaction.update(branchRef, {
            'Tables.$tableNumber.status': 'available',
            'Tables.$tableNumber.currentOrderId': FieldValue.delete(),
            'Tables.$tableNumber.statusTimestamp': FieldValue.delete(),
          });
        } else {
          // Order exists - verify status consistency
          final orderData = orderDoc.data() as Map<String, dynamic>;
          final orderStatus = orderData['status'] as String? ?? '';

          // If order is paid/cancelled but table still shows ordered
          if ((orderStatus == 'paid' || orderStatus == 'cancelled') &&
              (tableStatus == 'ordered' || tableStatus == 'occupied')) {
            transaction.update(branchRef, {
              'Tables.$tableNumber.status': 'available',
              'Tables.$tableNumber.currentOrderId': FieldValue.delete(),
              'Tables.$tableNumber.statusTimestamp': FieldValue.delete(),
            });
          }
        }
      } else if (tableStatus == 'ordered') {
        // Table shows ordered but has no order ID - fix status
        transaction.update(branchRef, {
          'Tables.$tableNumber.status': 'available',
          'Tables.$tableNumber.statusTimestamp': FieldValue.delete(),
        });
      }
    });
  }

  // ============================================
  // TABLE OPERATIONS
  // ============================================

  static Future<void> updateTableStatus(
    String branchId,
    String tableNumber,
    String status, {
    String? currentOrderId,
  }) async {
    final updateData = <String, dynamic>{
      'Tables.$tableNumber.status': status,
      'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
    };

    if (currentOrderId != null) {
      updateData['Tables.$tableNumber.currentOrderId'] = currentOrderId;
    } else if (status == TableStatus.available) {
      updateData['Tables.$tableNumber.currentOrderId'] = FieldValue.delete();
    }

    await _firestore.collection('Branch').doc(branchId).update(updateData);
  }

  /// Gets the next daily order number atomically to prevent race conditions.
  /// Uses a counter document per branch per day.
  /// This method MUST be called within a Firestore transaction.
  static Future<int> getNextDailyOrderNumber(
    Transaction transaction,
    String branchId,
  ) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final counterDocId = '${branchId}_$today';
    
    final counterRef = _firestore.collection('daily_order_counters').doc(counterDocId);
    final counterDoc = await transaction.get(counterRef);
    
    int nextNumber = 1;
    if (counterDoc.exists) {
      final data = counterDoc.data()!;
      nextNumber = ((data['count'] as num?) ?? 0).toInt() + 1;
    }
    
    transaction.set(counterRef, {
      'branchId': branchId,
      'date': today,
      'count': nextNumber,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    
    return nextNumber;
  }

  // ============================================
  // QR SESSION OPERATIONS
  // ============================================

  /// Creates or reuses an active QR session for a table.
  /// Ensures only one active session per table and extends expiry on reuse.
  static Future<Map<String, dynamic>> createOrReuseQrSession({
    required String branchId,
    required String tableNumber,
    Duration ttl = _defaultQrSessionTtl,
  }) async {
    final now = DateTime.now();
    final expiresAt = Timestamp.fromDate(now.add(ttl));

    final branchRef = _firestore.collection('Branch').doc(branchId);
    final branchDoc = await branchRef.get();

    if (!branchDoc.exists) {
      throw OrderNotFoundException('Branch not found: $branchId');
    }

    final branchData = branchDoc.data() as Map<String, dynamic>;
    final tables = branchData['Tables'] as Map<String, dynamic>? ?? {};
    final tableData = tables[tableNumber] as Map<String, dynamic>?;

    if (tableData == null) {
      throw TableOrderMismatchException(tableNumber, null);
    }

    final existingSessionSnapshot = await _firestore
        .collection('qr_sessions')
        .where('branchId', isEqualTo: branchId)
        .where('tableNumber', isEqualTo: tableNumber)
        .where('isActive', isEqualTo: true)
        .where('isBillLocked', isEqualTo: false)
        .limit(1)
        .get();

    if (existingSessionSnapshot.docs.isNotEmpty) {
      final sessionDoc = existingSessionSnapshot.docs.first;
      final sessionData = sessionDoc.data();
      final sessionExpiry = (sessionData['expiresAt'] as Timestamp?)?.toDate();
      final isExpired = sessionExpiry != null && now.isAfter(sessionExpiry);

      if (!isExpired) {
        await sessionDoc.reference.update({
          'expiresAt': expiresAt,
          'lastActivity': FieldValue.serverTimestamp(),
        });
        return {
          'id': sessionDoc.id,
          ...sessionData,
          'expiresAt': expiresAt,
        };
      }

      await sessionDoc.reference.update({
        'isActive': false,
        'expiredAt': FieldValue.serverTimestamp(),
      });
    }

    final newSessionRef = _firestore.collection('qr_sessions').doc();
    final sessionData = <String, dynamic>{
      'branchId': branchId,
      'tableNumber': tableNumber,
      'isActive': true,
      'isBillLocked': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivity': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'orderIds': <String>[],
      'totalOrderCount': 0,
    };

    await newSessionRef.set(sessionData);

    return {
      'id': newSessionRef.id,
      ...sessionData,
      'expiresAt': expiresAt,
    };
  }

  /// Updates session activity timestamp (keep-alive).
  static Future<void> touchQrSession(String sessionId) async {
    await _firestore.collection('qr_sessions').doc(sessionId).update({
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  // ============================================
  // ORDER OPERATIONS WITH TRANSACTIONS
  // ============================================

  static Future<String> createDineInOrder({
    required String branchId,
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? placedByUserId,
  }) async {
    return await _firestore.runTransaction((transaction) async {
      // Verify table doesn't already have an active order
      final branchRef = _firestore.collection('Branch').doc(branchId);
      final branchDoc = await transaction.get(branchRef);
      
      if (branchDoc.exists) {
        final branchData = branchDoc.data() as Map<String, dynamic>;
        final tables = branchData['Tables'] as Map<String, dynamic>? ?? {};
        final tableData = tables[tableNumber] as Map<String, dynamic>?;
        
        if (tableData != null) {
          final existingOrderId = tableData['currentOrderId'] as String?;
          if (existingOrderId != null) {
            // Check if the existing order is still active
            final existingOrderRef = _firestore.collection('Orders').doc(existingOrderId);
            final existingOrderDoc = await transaction.get(existingOrderRef);
            
            if (existingOrderDoc.exists) {
              final existingOrderData = existingOrderDoc.data() as Map<String, dynamic>;
              final existingStatus = existingOrderData['status'] as String? ?? '';
              
              // If order is not in terminal state, throw error
              if (existingStatus != 'paid' && existingStatus != 'cancelled') {
                throw TableOrderMismatchException(tableNumber, existingOrderId);
              }
            }
          }
        }
      }

      // Get daily order number atomically (prevents race condition)
      final dailyOrderNumber = await getNextDailyOrderNumber(transaction, branchId);

      // Create order document reference
      final orderRef = _firestore.collection('Orders').doc();

      // Create order data with version for optimistic locking
      final orderData = <String, dynamic>{
        'Order_type': OrderType.dineIn,
        'tableNumber': tableNumber,
        'items': items,
        'subtotal': totalAmount,
        'totalAmount': totalAmount,
        'status': OrderStatus.preparing,
        'paymentStatus': PaymentStatus.unpaid,
        'timestamp': FieldValue.serverTimestamp(),
        'dailyOrderNumber': dailyOrderNumber,
        'branchIds': [branchId],
        'version': 1, // For optimistic locking
      };

      // Add placedByUserId if provided
      if (placedByUserId != null && placedByUserId.isNotEmpty) {
        orderData['placedByUserId'] = placedByUserId;
      }

      // Set order data
      transaction.set(orderRef, orderData);

      // Update table status
      transaction.update(branchRef, {
        'Tables.$tableNumber.status': TableStatus.ordered,
        'Tables.$tableNumber.currentOrderId': orderRef.id,
        'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
      });

      return orderRef.id;
    });
  }

  static Future<void> addToExistingOrder({
    required String orderId,
    required List<Map<String, dynamic>> newItems,
    required double additionalAmount,
    int? expectedVersion, // For optimistic locking
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      
      // Check optimistic locking version if provided
      if (expectedVersion != null) {
        final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;
        if (currentVersion != expectedVersion) {
          throw OrderModifiedException(orderId);
        }
      }

      // Validate order is in a state that allows adding items
      final currentStatus = orderData['status'] as String? ?? '';
      if (currentStatus == 'paid' || currentStatus == 'cancelled') {
        throw InvalidStatusTransitionException(currentStatus, 'adding items');
      }

      final currentItems = List<Map<String, dynamic>>.from(
        orderData['items'] ?? [],
      );
      final currentTotal =
          (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final currentSubtotal =
          (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;

      final mergedItems = _mergeOrderItems(currentItems, newItems);
      final newTotal = currentTotal + additionalAmount;
      final newSubtotal = currentSubtotal + additionalAmount;

      transaction.update(orderRef, {
        'items': mergedItems,
        'subtotal': newSubtotal,
        'totalAmount': newTotal,
        'timestamp': FieldValue.serverTimestamp(),
        'version': currentVersion + 1, // Increment version
      });
    });
  }

  static Future<void> updateOrderStatusWithTable(
    String branchId,
    String orderId,
    String status, {
    String? tableNumber,
    bool validateTransition = true,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final currentStatus = orderData['status'] as String?;

      // Validate status transition
      if (validateTransition && !isValidStatusTransition(currentStatus, status)) {
        throw InvalidStatusTransitionException(currentStatus ?? 'unknown', status);
      }

      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;

      transaction.update(orderRef, {
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'version': currentVersion + 1,
      });

      // Update table status if provided
      if (tableNumber != null) {
        final branchRef = _firestore.collection('Branch').doc(branchId);
        String tableStatus = 'occupied';
        if (status == 'prepared') tableStatus = 'ordered';
        if (status == 'served') tableStatus = 'occupied';
        if (status == 'paid' || status == 'cancelled') tableStatus = 'available';

        final tableUpdate = <String, dynamic>{
          'Tables.$tableNumber.status': tableStatus,
          'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
        };

        // Clear order reference if order is complete
        if (status == 'paid' || status == 'cancelled') {
          tableUpdate['Tables.$tableNumber.currentOrderId'] = FieldValue.delete();
        }

        transaction.update(branchRef, tableUpdate);
      }
    });
  }

  static Future<void> processPayment({
    required String branchId,
    required String orderId,
    required String paymentMethod,
    required double amount,
    String? tableNumber,
    double? expectedAmount, // Validate amount hasn't changed
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      
      // Validate order isn't already paid
      final currentPaymentStatus = orderData['paymentStatus'] as String? ?? '';
      if (currentPaymentStatus == 'paid') {
        throw InvalidStatusTransitionException(currentPaymentStatus, 'paid');
      }

      // Optionally validate amount hasn't changed
      if (expectedAmount != null) {
        final currentTotal = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        if ((currentTotal - expectedAmount).abs() > 0.01) {
          throw OrderModifiedException(orderId);
        }
      }

      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;

      transaction.update(orderRef, {
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paymentTime': FieldValue.serverTimestamp(),
        'paidAmount': amount,
        'status': 'paid',
        'version': currentVersion + 1,
      });

      // Clear table if dine-in order
      if (tableNumber != null) {
        final branchRef = _firestore.collection('Branch').doc(branchId);
        transaction.update(branchRef, {
          'Tables.$tableNumber.status': 'available',
          'Tables.$tableNumber.currentOrderId': FieldValue.delete(),
          'Tables.$tableNumber.statusTimestamp': FieldValue.delete(),
        });
      }
    });
  }

  // ============================================
  // CART OPERATIONS
  // ============================================

  static Future<void> saveCartItems(
    String tableNumber,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      await _firestore.collection('carts').doc('table_$tableNumber').set({
        'items': items,
        'lastUpdated': FieldValue.serverTimestamp(),
        'tableNumber': tableNumber,
      });
    } catch (e) {
      throw Exception('Failed to save cart: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> loadCartItems(
    String tableNumber,
  ) async {
    try {
      final cartDoc = await _firestore
          .collection('carts')
          .doc('table_$tableNumber')
          .get();
      if (cartDoc.exists) {
        final cartData = cartDoc.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(cartData['items'] ?? []);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load cart: $e');
    }
  }

  static Future<void> clearCart(String tableNumber) async {
    try {
      await _firestore.collection('carts').doc('table_$tableNumber').delete();
    } catch (e) {
      throw Exception('Failed to clear cart: $e');
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  static List<Map<String, dynamic>> _mergeOrderItems(
    List<Map<String, dynamic>> existingItems,
    List<Map<String, dynamic>> newItems,
  ) {
    final merged = List<Map<String, dynamic>>.from(existingItems);

    for (final newItem in newItems) {
      final existingIndex = merged.indexWhere(
        (item) =>
            item['id'] == newItem['id'] &&
            item['specialInstructions'] == newItem['specialInstructions'] &&
            item['selectedVariant'] == newItem['selectedVariant'],
      );

      if (existingIndex >= 0) {
        merged[existingIndex]['quantity'] += newItem['quantity'];
      } else {
        merged.add(Map<String, dynamic>.from(newItem)); // Deep copy to prevent mutations
      }
    }
    return merged;
  }

  // ============================================
  // STREAM GETTERS
  // ============================================

  static Stream<DocumentSnapshot> getBranchStream(String branchId) {
    return _firestore.collection('Branch').doc(branchId).snapshots();
  }

  static Stream<DocumentSnapshot> getOrderStream(String orderId) {
    return _firestore.collection('Orders').doc(orderId).snapshots();
  }

  static Stream<QuerySnapshot> getActiveOrdersStream(
    String branchId,
    String orderType,
  ) {
    Query query = _firestore
        .collection('Orders')
        .where('branchIds', arrayContains: branchId)
        .where('status', whereIn: ['pending', 'preparing', 'prepared']);

    if (orderType != 'all') {
      query = query.where('Order_type', isEqualTo: orderType);
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }

  // ============================================
  // CUSTOMER SELF-ORDERING (QR CODE)
  // ============================================

  /// Creates an order from customer self-ordering via QR code
  /// INDUSTRY STANDARD (Petpooja/Social): Always creates NEW order, never merges
  /// Each order is immutable once kitchen accepts it
  /// All orders link to session via sessionId and are tracked in session.orderIds[]
  static Future<String> createCustomerOrder({
    required String sessionId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? customerName,
    String? customerPhone,
  }) async {
    return await _firestore.runTransaction((transaction) async {
      if (items.isEmpty) {
        throw InvalidOrderException('Cart is empty');
      }

      if (items.length > _maxItemsPerOrder) {
        throw InvalidOrderException('Too many items in order');
      }

      double calculatedTotal = 0.0;
      for (final item in items) {
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (quantity <= 0 || quantity > _maxQuantityPerItem) {
          throw InvalidOrderException('Invalid quantity for ${item['name'] ?? 'item'}');
        }

        final price = (item['price'] as num?)?.toDouble();
        if (price == null || price < 0) {
          throw InvalidOrderException('Invalid price for ${item['name'] ?? 'item'}');
        }

        calculatedTotal += price * quantity;
      }

      if (calculatedTotal <= 0) {
        throw InvalidOrderException('Total must be greater than zero');
      }

      // Validate QR session
      final sessionRef = _firestore.collection('qr_sessions').doc(sessionId);
      final sessionDoc = await transaction.get(sessionRef);
      
      if (!sessionDoc.exists) {
        throw OrderNotFoundException('QR Session not found: $sessionId');
      }
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final isActive = sessionData['isActive'] ?? false;
      final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
      final isBillLocked = sessionData['isBillLocked'] ?? false;
      
      if (!isActive) {
        throw InvalidStatusTransitionException('inactive', 'creating order');
      }
      
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        throw InvalidStatusTransitionException('expired', 'creating order');
      }
      
      // Check if session is locked (bill already printed)
      if (isBillLocked) {
        throw InvalidStatusTransitionException('bill_locked', 'creating order');
      }
      
      final branchId = sessionData['branchId'] as String;
      final tableNumber = sessionData['tableNumber'] as String;
      final existingOrderIds = List<String>.from(sessionData['orderIds'] ?? []);
      final orderSequence = existingOrderIds.length + 1;
      
      // Check if restaurant is open
      final branchRef = _firestore.collection('Branch').doc(branchId);
      final branchDoc = await transaction.get(branchRef);
      
      if (!branchDoc.exists) {
        throw OrderNotFoundException('Branch not found: $branchId');
      }
      
      final branchData = branchDoc.data() as Map<String, dynamic>;
      final isOpen = branchData['isOpen'] ?? true;
      
      if (!isOpen) {
        throw InvalidStatusTransitionException('closed', 'creating order');
      }
      
      // Validate table exists
      final tables = branchData['Tables'] as Map<String, dynamic>? ?? {};
      final tableData = tables[tableNumber] as Map<String, dynamic>?;
      
      if (tableData == null) {
        throw TableOrderMismatchException(tableNumber, null);
      }
      
      // ALWAYS CREATE NEW ORDER (Petpooja/Social style - orders are immutable)
      final dailyOrderNumber = await getNextDailyOrderNumber(transaction, branchId);
      final orderRef = _firestore.collection('Orders').doc();
      
      final orderData = <String, dynamic>{
        'Order_type': OrderType.dineIn,
        'tableNumber': tableNumber,
        'items': items,
        'subtotal': calculatedTotal,
        'totalAmount': calculatedTotal,
        'status': OrderStatus.preparing,
        'paymentStatus': PaymentStatus.unpaid,
        'timestamp': FieldValue.serverTimestamp(),
        'dailyOrderNumber': dailyOrderNumber,
        'branchIds': [branchId],
        'version': 1,
        'placedByCustomer': true,
        'qrSessionId': sessionId,
        'clientReportedTotal': totalAmount,
        // Multi-order tracking fields
        'orderType': orderSequence == 1 ? 'initial' : 'addon',
        'orderSequence': orderSequence,
        'isKitchenLocked': false, // Becomes true when kitchen accepts
        if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty) 'customerPhone': customerPhone,
      };
      
      transaction.set(orderRef, orderData);
      
      // Update table status to ordered (only if first order)
      if (orderSequence == 1) {
        transaction.update(branchRef, {
          'Tables.$tableNumber.status': TableStatus.ordered,
          'Tables.$tableNumber.currentOrderId': orderRef.id,
          'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // For addon orders, update the currentOrderId to the latest order
        transaction.update(branchRef, {
          'Tables.$tableNumber.currentOrderId': orderRef.id,
          'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
        });
      }
      
      // Add order to session's order list
      transaction.update(sessionRef, {
        'orderIds': FieldValue.arrayUnion([orderRef.id]),
        'totalOrderCount': FieldValue.increment(1),
        'lastActivity': FieldValue.serverTimestamp(),
      });
      
      return orderRef.id;
    });
  }

  /// Locks an order once kitchen has accepted it (makes it immutable)
  /// Called by kitchen staff when they start preparing
  static Future<void> lockOrderForKitchen(String orderId) async {
    await _firestore.collection('Orders').doc(orderId).update({
      'isKitchenLocked': true,
      'kitchenLockedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gets all orders for a session
  static Future<List<Map<String, dynamic>>> getSessionOrders(String sessionId) async {
    final querySnapshot = await _firestore
        .collection('Orders')
        .where('qrSessionId', isEqualTo: sessionId)
        .orderBy('orderSequence', descending: false)
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['orderId'] = doc.id;
      return data;
    }).toList();
  }

  /// Gets the total amount for all orders in a session
  static Future<double> getSessionTotal(String sessionId) async {
    final orders = await getSessionOrders(sessionId);
    return orders.fold<double>(
      0.0,
      (sum, order) => sum + ((order['totalAmount'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Processes payment for an entire session (all orders)
  static Future<void> processSessionPayment({
    required String sessionId,
    required String branchId,
    required String paymentMethod,
    required double amount,
    String? tableNumber,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // Get session
      final sessionRef = _firestore.collection('qr_sessions').doc(sessionId);
      final sessionDoc = await transaction.get(sessionRef);
      
      if (!sessionDoc.exists) {
        throw OrderNotFoundException('Session not found: $sessionId');
      }
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final orderIds = List<String>.from(sessionData['orderIds'] ?? []);
      final sessionTableNumber = sessionData['tableNumber'] as String;
      
      // Mark all orders as paid
      for (final orderId in orderIds) {
        final orderRef = _firestore.collection('Orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);
        
        if (orderDoc.exists) {
          transaction.update(orderRef, {
            'paymentStatus': 'paid',
            'paymentMethod': paymentMethod,
            'paymentTime': FieldValue.serverTimestamp(),
            'status': 'paid',
          });
        }
      }
      
      // Lock session permanently
      transaction.update(sessionRef, {
        'isBillLocked': true,
        'isActive': false, // Session is complete
        'paidAt': FieldValue.serverTimestamp(),
        'paidAmount': amount,
        'paymentMethod': paymentMethod,
      });
      
      // Clear table
      final branchRef = _firestore.collection('Branch').doc(branchId);
      transaction.update(branchRef, {
        'Tables.$sessionTableNumber.status': 'available',
        'Tables.$sessionTableNumber.currentOrderId': FieldValue.delete(),
        'Tables.$sessionTableNumber.statusTimestamp': FieldValue.delete(),
      });
    });
  }


  /// Gets menu categories for a branch
  static Stream<QuerySnapshot> getMenuCategoriesStream(String branchId) {
    return _firestore
        .collection('menu_categories')
        .where('branchIds', arrayContains: branchId)
        .orderBy('order', descending: false)
        .snapshots();
  }

  /// Gets menu items for a branch
  static Stream<QuerySnapshot> getMenuItemsStream(String branchId) {
    return _firestore
        .collection('menu_items')
        .where('branchIds', arrayContains: branchId)
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }

  /// Gets menu items as a one-time fetch (for customer ordering)
  static Future<List<Map<String, dynamic>>> getMenuItemsForBranch(String branchId) async {
    final snapshot = await _firestore
        .collection('menu_items')
        .where('branchIds', arrayContains: branchId)
        .where('isAvailable', isEqualTo: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Gets menu categories as a one-time fetch (for customer ordering)
  static Future<List<Map<String, dynamic>>> getMenuCategoriesForBranch(String branchId) async {
    final snapshot = await _firestore
        .collection('menu_categories')
        .where('branchIds', arrayContains: branchId)
        .orderBy('order', descending: false)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
