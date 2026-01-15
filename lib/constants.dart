/// Centralized constants for the Waiter App
/// This file contains all magic strings, colors, and configuration values.

import 'package:flutter/material.dart';

/// Order status constants
class OrderStatus {
  static const String pending = 'pending';
  static const String preparing = 'preparing';
  static const String prepared = 'prepared';
  static const String served = 'served';
  static const String paid = 'paid';
  static const String cancelled = 'cancelled';
  static const String returned = 'returned';  // For returned/refunded orders

  /// List of active statuses (not completed)
  static const List<String> activeStatuses = [pending, preparing, prepared];

  /// List of completed statuses
  static const List<String> completedStatuses = [served, paid];
  
  /// List of terminal statuses (no further transitions allowed)
  static const List<String> terminalStatuses = [paid, cancelled, returned];
  
  /// Checks if a status is terminal (cannot transition further)
  static bool isTerminal(String status) => terminalStatuses.contains(status);
}


/// Order type constants
class OrderType {
  static const String dineIn = 'dine_in';
  static const String takeaway = 'takeaway';
  static const String delivery = 'delivery';
  static const String pickup = 'pickup';
}

/// Table status constants
class TableStatus {
  static const String available = 'available';
  static const String occupied = 'occupied';
  static const String ordered = 'ordered';
  static const String needsAttention = 'needs_attention';
}

/// Payment status constants
class PaymentStatus {
  static const String unpaid = 'unpaid';
  static const String paid = 'paid';
}

/// Payment method constants
class PaymentMethod {
  static const String cash = 'cash';
  static const String card = 'card';
  static const String online = 'online';
}

/// App configuration
class AppConfig {
  /// Currency symbol used throughout the app
  static const String currencySymbol = 'QAR';

  /// Format amount with currency
  static String formatCurrency(double amount) {
    return '$currencySymbol ${amount.toStringAsFixed(2)}';
  }

  /// Default estimated time for takeaway orders (in minutes)
  static const int defaultEstimatedTimeMinutes = 15;

  /// Maximum items to show before "see more"
  static const int maxPreviewItems = 2;
}

/// App theme colors
class AppColors {
  static const Color primary = Color(0xFF1976D2);
  static const Color secondary = Color(0xFFE3F2FD);
  static const Color background = Color(0xFFF5F5F5);

  // Status colors
  static const Color statusPending = Color(0xFFFFA726); // Orange
  static const Color statusPreparing = Color(0xFFFF9800); // Orange darker
  static const Color statusPrepared = Color(0xFF4CAF50); // Green
  static const Color statusServed = Color(0xFF2196F3); // Blue
  static const Color statusPaid = Color(0xFF009688); // Teal
  static const Color statusCancelled = Color(0xFFF44336); // Red

  // Table status colors
  static const Color tableAvailable = Color(0xFF4CAF50); // Green
  static const Color tableOccupied = Color(0xFFFF9800); // Orange
  static const Color tableOrdered = Color(0xFFF44336); // Red
  static const Color tableNeedsAttention = Color(0xFFF44336); // Red

  /// Get color for order status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return statusPending;
      case 'preparing':
        return statusPreparing;
      case 'prepared':
        return statusPrepared;
      case 'served':
        return statusServed;
      case 'paid':
        return statusPaid;
      case 'cancelled':
        return statusCancelled;
      default:
        return Colors.grey;
    }
  }

  /// Get color for table status
  static Color getTableStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return tableAvailable;
      case 'occupied':
        return tableOccupied;
      case 'ordered':
        return tableOrdered;
      case 'needs_attention':
        return tableNeedsAttention;
      default:
        return tableAvailable;
    }
  }
}
