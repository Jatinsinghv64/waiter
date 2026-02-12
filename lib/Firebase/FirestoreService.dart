// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../utils.dart';

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

/// Exception for invalid order data (empty cart, invalid quantities, etc.)
class InvalidOrderException implements Exception {
  final String message;
  InvalidOrderException(this.message);
  @override
  String toString() => 'Invalid order: $message';
}

/// Exception thrown when a waiter tries to claim an order already handled by another waiter
class OrderAlreadyClaimedException implements Exception {
  final String orderId;
  final String claimedBy;
  OrderAlreadyClaimedException(this.orderId, this.claimedBy);
  @override
  String toString() => 'Order $orderId already handled by $claimedBy';
}

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  static bool isValidStatusTransition(String? fromStatus, String toStatus, {bool allowBackward = false}) {
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

    final from = fromStatus ?? '';
    final forwardAllowed = forwardTransitions[from] ?? [];

    if (forwardAllowed.contains(toStatus)) {
      return true;
    }

    if (allowBackward) {
      final backwardAllowed = backwardTransitions[from] ?? [];
      return backwardAllowed.contains(toStatus);
    }

    return false;
  }

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

  // ============================================
  // TABLE OPERATIONS (SCALABLE - SUBCOLLECTIONS)
  // ============================================

  static Future<void> migrateTablesToSubcollection(String branchId) async {
    final branchRef = _firestore.collection('Branch').doc(branchId);

    await _firestore.runTransaction((transaction) async {
      final branchDoc = await transaction.get(branchRef);
      if (!branchDoc.exists) return;

      final data = branchDoc.data() as Map<String, dynamic>;
      final tablesMap = data['Tables'] as Map<String, dynamic>?;

      if (tablesMap == null || tablesMap.isEmpty) return;

      final tablesCollection = branchRef.collection('Tables');

      for (final tableNo in tablesMap.keys) {
        final tableData = tablesMap[tableNo] as Map<String, dynamic>;
        final tableDocRef = tablesCollection.doc(tableNo);
        transaction.set(tableDocRef, tableData, SetOptions(merge: true));
      }
    });
  }

  static Stream<List<Map<String, dynamic>>> getBranchTablesStream(String branchId) {
    return _firestore
        .collection('Branch')
        .doc(branchId)
        .collection('Tables')
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      data['tableNumber'] = doc.id;
      return data;
    }).toList());
  }

  static Stream<DocumentSnapshot> getTableStream(String branchId, String tableNumber) {
    return _firestore
        .collection('Branch')
        .doc(branchId)
        .collection('Tables')
        .doc(tableNumber)
        .snapshots();
  }

  static Future<void> updateTableStatus(
      String branchId,
      String tableNumber,
      String status, {
        String? currentOrderId,
      }) async {
    final tableRef = _firestore
        .collection('Branch')
        .doc(branchId)
        .collection('Tables')
        .doc(tableNumber);

    final updateData = <String, dynamic>{
      'status': status,
      'statusTimestamp': FieldValue.serverTimestamp(),
    };

    if (currentOrderId != null) {
      updateData['currentOrderId'] = currentOrderId;
    } else if (status == TableStatus.available) {
      updateData['currentOrderId'] = FieldValue.delete();
    }

    await tableRef.update(updateData);
  }

  static Future<void> reconcileTableOrderStatus(
      String branchId,
      String tableNumber,
      ) async {
    await _firestore.runTransaction((transaction) async {
      final tableRef = _firestore
          .collection('Branch')
          .doc(branchId)
          .collection('Tables')
          .doc(tableNumber);

      final tableDoc = await transaction.get(tableRef);

      if (!tableDoc.exists) return;

      final tableData = tableDoc.data() as Map<String, dynamic>;
      final currentOrderId = tableData['currentOrderId'] as String?;
      final tableStatus = tableData['status'] as String? ?? 'available';

      if (currentOrderId != null) {
        final orderRef = _firestore.collection('Orders').doc(currentOrderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          transaction.update(tableRef, {
            'status': 'available',
            'currentOrderId': FieldValue.delete(),
            'statusTimestamp': FieldValue.delete(),
          });
        } else {
          final orderData = orderDoc.data() as Map<String, dynamic>;
          final orderStatus = orderData['status'] as String? ?? '';

          if ((orderStatus == 'paid' || orderStatus == 'cancelled') &&
              (tableStatus == 'ordered' || tableStatus == 'occupied')) {
            transaction.update(tableRef, {
              'status': 'available',
              'currentOrderId': FieldValue.delete(),
              'statusTimestamp': FieldValue.delete(),
            });
          }
        }
      } else if (tableStatus == 'ordered') {
        transaction.update(tableRef, {
          'status': 'available',
          'statusTimestamp': FieldValue.delete(),
        });
      }
    });
  }

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
  // ORDER OPERATIONS WITH TRANSACTIONS & SECURITY
  // ============================================

  static Future<String> createDineInOrder({
    required String branchId,
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    String? placedByUserId,
  }) async {
    return await _firestore.runTransaction((transaction) async {
      final tableRef = _firestore
          .collection('Branch')
          .doc(branchId)
          .collection('Tables')
          .doc(tableNumber);

      final tableDoc = await transaction.get(tableRef);

      if (tableDoc.exists) {
        final tableData = tableDoc.data() as Map<String, dynamic>;
        final existingOrderId = tableData['currentOrderId'] as String?;

        if (existingOrderId != null) {
          final existingOrderRef = _firestore.collection('Orders').doc(existingOrderId);
          final existingOrderDoc = await transaction.get(existingOrderRef);

          if (existingOrderDoc.exists) {
            final existingData = existingOrderDoc.data() as Map<String, dynamic>;
            final status = existingData['status'];
            if (status != 'paid' && status != 'cancelled') {
              throw TableOrderMismatchException(tableNumber, existingOrderId);
            }
          }
        }
      }

      double calculatedSubtotal = 0.0;
      final validatedItems = <Map<String, dynamic>>[];

      for (final item in items) {
        final itemId = item['id'];
        final quantity = (item['quantity'] as num).toInt();
        final selectedVariant = item['selectedVariant'] as Map<String, dynamic>?;

        final itemRef = _firestore.collection('menu_items').doc(itemId);
        final itemDoc = await transaction.get(itemRef);

        if (!itemDoc.exists) {
          throw InvalidOrderException('Menu item not found: ${item['name']}');
        }

        final itemData = itemDoc.data() as Map<String, dynamic>;
        double unitPrice = (itemData['price'] as num).toDouble();

        if (selectedVariant != null) {
          unitPrice = (selectedVariant['price'] as num).toDouble();
        }

        final lineTotal = unitPrice * quantity;
        calculatedSubtotal += lineTotal;

        final validatedItem = Map<String, dynamic>.from(item);
        validatedItem['price'] = unitPrice;
        validatedItems.add(validatedItem);
      }

      final finalTotal = calculatedSubtotal;

      final dailyOrderNumber = await getNextDailyOrderNumber(transaction, branchId);

      final orderRef = _firestore.collection('Orders').doc();
      final orderData = <String, dynamic>{
        'Order_type': OrderType.dineIn,
        'tableNumber': tableNumber,
        'items': validatedItems,
        'subtotal': finalTotal,
        'totalAmount': finalTotal,
        'status': OrderStatus.preparing,
        'paymentStatus': PaymentStatus.unpaid,
        'timestamp': FieldValue.serverTimestamp(),
        'dailyOrderNumber': dailyOrderNumber,
        'branchIds': [branchId],
        'version': 1,
        if (placedByUserId != null) 'placedByUserId': placedByUserId,
      };

      transaction.set(orderRef, orderData);

      transaction.update(tableRef, {
        'status': TableStatus.ordered,
        'currentOrderId': orderRef.id,
        'statusTimestamp': FieldValue.serverTimestamp(),
      });

      return orderRef.id;
    });
  }

  static Future<String> createTakeawayOrder({
    required String branchId,
    required List<Map<String, dynamic>> items,
    required String carPlateNumber,
    required String specialInstructions,
    String? placedByUserId,
  }) async {
    return await _firestore.runTransaction((transaction) async {
      double calculatedSubtotal = 0.0;
      final validatedItems = <Map<String, dynamic>>[];

      for (final item in items) {
        final itemId = item['id'];
        final quantity = (item['quantity'] as num).toInt();
        final selectedVariant = item['selectedVariant'] as Map<String, dynamic>?;

        final itemRef = _firestore.collection('menu_items').doc(itemId);
        final itemDoc = await transaction.get(itemRef);

        if (!itemDoc.exists) {
          throw InvalidOrderException('Menu item not found: ${item['name']}');
        }

        final itemData = itemDoc.data() as Map<String, dynamic>;
        double unitPrice = (itemData['price'] as num).toDouble();

        if (selectedVariant != null) {
          unitPrice = (selectedVariant['price'] as num).toDouble();
        }

        final lineTotal = unitPrice * quantity;
        calculatedSubtotal += lineTotal;

        final validatedItem = Map<String, dynamic>.from(item);
        validatedItem['price'] = unitPrice;
        validatedItems.add(validatedItem);
      }

      final finalTotal = calculatedSubtotal;

      final dailyOrderNumber = await getNextDailyOrderNumber(transaction, branchId);

      final now = DateTime.now();
      final estimatedTime = now.add(Duration(minutes: 15));
      final formattedTime = '${estimatedTime.hour.toString().padLeft(2, '0')}:${estimatedTime.minute.toString().padLeft(2, '0')}';

      final orderRef = _firestore.collection('Orders').doc();
      final orderData = <String, dynamic>{
        'Order_type': OrderType.takeaway,
        'carPlateNumber': carPlateNumber,
        'specialInstructions': specialInstructions,
        'items': validatedItems,
        'subtotal': finalTotal,
        'totalAmount': finalTotal,
        'status': OrderStatus.preparing,
        'paymentStatus': PaymentStatus.unpaid,
        'timestamp': FieldValue.serverTimestamp(),
        'dailyOrderNumber': dailyOrderNumber,
        'branchIds': [branchId],
        'estimatedReadyTime': formattedTime,
        'version': 1,
        if (placedByUserId != null) 'placedByUserId': placedByUserId,
      };

      transaction.set(orderRef, orderData);

      return orderRef.id;
    });
  }

  static Future<void> addToExistingOrder({
    required String orderId,
    required List<Map<String, dynamic>> newItems,
    int? expectedVersion,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;

      if (expectedVersion != null) {
        final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;
        if (currentVersion != expectedVersion) {
          throw OrderModifiedException(orderId);
        }
      }

      final currentStatus = orderData['status'] as String? ?? '';
      if (currentStatus == 'paid' || currentStatus == 'cancelled') {
        throw InvalidStatusTransitionException(currentStatus, 'adding items');
      }

      double calculatedAdditional = 0.0;
      final validatedNewItems = <Map<String, dynamic>>[];

      for (final item in newItems) {
        final itemId = item['id'];
        final quantity = (item['quantity'] as num).toInt();

        final itemRef = _firestore.collection('menu_items').doc(itemId);
        final itemDoc = await transaction.get(itemRef);

        if (!itemDoc.exists) throw InvalidOrderException('Item $itemId not found');

        final itemData = itemDoc.data()!;
        double price = (itemData['price'] as num).toDouble();

        if (item['selectedVariant'] != null) {
          price = (item['selectedVariant']['price'] as num).toDouble();
        }

        calculatedAdditional += (price * quantity);

        final validatedItem = Map<String, dynamic>.from(item);
        validatedItem['price'] = price;
        validatedNewItems.add(validatedItem);
      }

      final currentItems = List<Map<String, dynamic>>.from(
        orderData['items'] ?? [],
      );
      final currentTotal =
          (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final currentSubtotal =
          (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;

      final mergedItems = _mergeOrderItems(currentItems, validatedNewItems);
      final newTotal = currentTotal + calculatedAdditional;
      final newSubtotal = currentSubtotal + calculatedAdditional;

      transaction.update(orderRef, {
        'items': mergedItems,
        'subtotal': newSubtotal,
        'totalAmount': newTotal,
        'timestamp': FieldValue.serverTimestamp(),
        'version': currentVersion + 1,
      });
    });
  }

  static Future<void> updateOrderStatusWithTable(
      String branchId,
      String orderId,
      String status, {
        String? tableNumber,
        bool validateTransition = true,
        String? actionBy,
      }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. READ: Get Order Doc
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final currentStatus = orderData['status'] as String?;

      if (validateTransition && !isValidStatusTransition(currentStatus, status)) {
        throw InvalidStatusTransitionException(currentStatus ?? 'unknown', status);
      }

      // 2. READ: Get Table Doc (if needed)
      // Must happen before any write
      DocumentReference? tableRef;
      DocumentSnapshot? tableDoc;
      bool shouldUpdateTable = true;

      if (tableNumber != null) {
        tableRef = _firestore
            .collection('Branch')
            .doc(branchId)
            .collection('Tables')
            .doc(tableNumber);

        tableDoc = await transaction.get(tableRef);
      }

      // 3. LOGIC Check
      if (tableNumber != null && tableDoc != null && tableDoc.exists) {
        final tableData = tableDoc.data() as Map<String, dynamic>;
        final currentTableOrderId = tableData['currentOrderId'] as String?;

        // Conflict Guard: If reactivating an old order on a table occupied by a new one
        if (currentTableOrderId != null && currentTableOrderId != orderId &&
            status != 'paid' && status != 'cancelled') {
          shouldUpdateTable = false;
        }
      }

      // 4. WRITE: Update Order
      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;
      final updateData = <String, dynamic>{
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'version': currentVersion + 1,
      };

      if (actionBy != null && actionBy.isNotEmpty) {
        if (status == OrderStatus.served) {
          updateData['servedBy'] = actionBy;
          updateData['servedAt'] = FieldValue.serverTimestamp();
        } else if (status == OrderStatus.paid) {
          updateData['paidBy'] = actionBy;
          updateData['paidAt'] = FieldValue.serverTimestamp();
        }
      }

      transaction.update(orderRef, updateData);

      // 5. WRITE: Update Table
      if (tableNumber != null && shouldUpdateTable && tableRef != null) {
        String tableStatus = 'occupied';

        if (status == 'pending' || status == 'preparing' || status == 'prepared') {
          tableStatus = 'ordered';
        }
        if (status == 'served') {
          tableStatus = 'occupied';
        }
        if (status == 'paid' || status == 'cancelled') {
          tableStatus = 'available';
        }

        final tableUpdate = <String, dynamic>{
          'status': tableStatus,
          'statusTimestamp': FieldValue.serverTimestamp(),
        };

        if (status == 'paid' || status == 'cancelled') {
          tableUpdate['currentOrderId'] = FieldValue.delete();
        } else {
          tableUpdate['currentOrderId'] = orderId;
        }

        transaction.update(tableRef, tableUpdate);
      }
    });
  }

  // FIX: Moved table read to the top to fix "reads before writes" error
  static Future<void> claimAndServeOrder({
    required String branchId,
    required String orderId,
    required String waiterEmail,
    String? tableNumber,
    String? orderType,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. READ Order
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;

      // Determine if we need to read Table data
      final effectiveTableNumber = tableNumber ?? orderData['tableNumber']?.toString();
      final effectiveOrderType = orderType ?? orderData['Order_type']?.toString() ?? OrderType.dineIn;

      // 2. READ Table (if applicable) - MUST be before any write
      DocumentReference? tableRef;
      if (effectiveOrderType == OrderType.dineIn && effectiveTableNumber != null) {
        tableRef = _firestore
            .collection('Branch')
            .doc(branchId)
            .collection('Tables')
            .doc(effectiveTableNumber);

        // We perform the read even if we don't strictly need data for logic,
        // to ensure the transaction locks the table document.
        await transaction.get(tableRef);
      }

      // 3. Logic & Validations
      final currentStatus = orderData['status'] as String? ?? '';
      if (currentStatus != OrderStatus.prepared) {
        final claimedBy = orderData['servedBy'] as String? ??
            orderData['paidBy'] as String? ??
            'another waiter';
        throw OrderAlreadyClaimedException(orderId, claimedBy);
      }

      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;

      // 4. WRITE Order
      transaction.update(orderRef, {
        'status': OrderStatus.served,
        'servedBy': waiterEmail,
        'servedAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'version': currentVersion + 1,
      });

      // 5. WRITE Table
      if (tableRef != null) {
        transaction.update(tableRef!, {
          'status': 'occupied',
          'statusTimestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // FIX: Moved table read to the top to fix "reads before writes" error
  static Future<void> claimAndPayOrder({
    required String branchId,
    required String orderId,
    required String waiterEmail,
    required String paymentMethod,
    required double amount,
    String? tableNumber,
    String? orderType,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. READ Order
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;

      // Determine if we need to read Table
      final effectiveTableNumber = tableNumber ?? orderData['tableNumber']?.toString();
      final effectiveOrderType = orderType ?? orderData['Order_type']?.toString() ?? OrderType.dineIn;

      // 2. READ Table (if applicable) - MUST be before any write
      DocumentReference? tableRef;
      DocumentSnapshot? tableDoc;

      if (effectiveOrderType == OrderType.dineIn && effectiveTableNumber != null) {
        tableRef = _firestore
            .collection('Branch')
            .doc(branchId)
            .collection('Tables')
            .doc(effectiveTableNumber);

        tableDoc = await transaction.get(tableRef);
      }

      // 3. Logic & Validations
      final currentStatus = orderData['status'] as String? ?? '';
      final currentPaymentStatus = orderData['paymentStatus'] as String? ?? '';

      if (currentPaymentStatus == 'paid' || currentStatus == OrderStatus.paid) {
        final claimedBy = orderData['paidBy'] as String? ?? 'another waiter';
        throw OrderAlreadyClaimedException(orderId, claimedBy);
      }

      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;

      // 4. WRITE Order
      transaction.update(orderRef, {
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paymentTime': FieldValue.serverTimestamp(),
        'paidAmount': amount,
        'paidBy': waiterEmail,
        'paidAt': FieldValue.serverTimestamp(),
        'status': OrderStatus.paid,
        'timestamp': FieldValue.serverTimestamp(),
        'version': currentVersion + 1,
      });

      // 5. WRITE Table
      if (tableRef != null && tableDoc != null && tableDoc.exists) {
        final tData = tableDoc.data() as Map<String, dynamic>;
        final tOrderId = tData['currentOrderId'] as String?;

        // Safe clear: Only clear table if it is linked to THIS order
        if (tOrderId == orderId) {
          transaction.update(tableRef!, {
            'status': 'available',
            'currentOrderId': FieldValue.delete(),
            'statusTimestamp': FieldValue.delete(),
          });
        }
      }
    });
  }

  static Future<void> processPayment({
    required String branchId,
    required String orderId,
    required String paymentMethod,
    required double amount,
    String? tableNumber,
    double? expectedAmount,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. READ Order
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw OrderNotFoundException(orderId);
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;

      // 2. READ Table
      DocumentReference? tableRef;
      DocumentSnapshot? tableDoc;
      if (tableNumber != null) {
        tableRef = _firestore
            .collection('Branch')
            .doc(branchId)
            .collection('Tables')
            .doc(tableNumber);
        tableDoc = await transaction.get(tableRef);
      }

      // 3. Logic & Validations
      final currentPaymentStatus = orderData['paymentStatus'] as String? ?? '';
      if (currentPaymentStatus == 'paid') {
        throw InvalidStatusTransitionException(currentPaymentStatus, 'paid');
      }

      if (expectedAmount != null) {
        final currentTotal = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        if ((currentTotal - expectedAmount).abs() > 0.01) {
          throw OrderModifiedException(orderId);
        }
      }

      final currentVersion = (orderData['version'] as num?)?.toInt() ?? 1;

      // 4. WRITE Order
      transaction.update(orderRef, {
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paymentTime': FieldValue.serverTimestamp(),
        'paidAmount': amount,
        'status': 'paid',
        'version': currentVersion + 1,
      });

      // 5. WRITE Table
      if (tableRef != null && tableDoc != null && tableDoc.exists) {
        final tData = tableDoc.data() as Map<String, dynamic>;
        final tOrderId = tData['currentOrderId'] as String?;

        if (tOrderId == orderId) {
          transaction.update(tableRef!, {
            'status': 'available',
            'currentOrderId': FieldValue.delete(),
            'statusTimestamp': FieldValue.delete(),
          });
        }
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
        merged.add(Map<String, dynamic>.from(newItem));
      }
    }
    return merged;
  }

  // ============================================
  // STREAM GETTERS
  // ============================================

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

  static Stream<QuerySnapshot> getMenuCategoriesStream(String branchId) {
    return _firestore
        .collection('menu_categories')
        .where('branchIds', arrayContains: branchId)
        .orderBy('order', descending: false)
        .snapshots();
  }

  static Stream<QuerySnapshot> getMenuItemsStream(String branchId) {
    return _firestore
        .collection('menu_items')
        .where('branchIds', arrayContains: branchId)
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }
}