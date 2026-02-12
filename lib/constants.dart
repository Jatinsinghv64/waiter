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
  
  /// Base URL for customer self-ordering (set this to your deployed web app URL)
  /// Example: 'https://your-restaurant.web.app' or 'https://order.yourrestaurant.com'
  /// Set to null or empty string to generate relative URLs
  static const String? customerOrderBaseUrl = 'https://mddprod-2954f.web.app';
  
  /// Builds the customer ordering URL for a QR session
  /// Returns a fully qualified URI with session parameter
  static Uri buildCustomerOrderUri(String sessionId) {
    final baseUrl = customerOrderBaseUrl;
    
    if (baseUrl != null && baseUrl.isNotEmpty) {
      // Use configured base URL for shareable links
      return Uri.parse(baseUrl).replace(
        path: '/order',
        queryParameters: {'session': sessionId},
      );
    }
    
    // Fallback to relative URL (for local/dev use)
    return Uri(
      path: '/order',
      queryParameters: {'session': sessionId},
    );
  }
  
  /// Validates if a customer order URI has the required structure
  static bool isValidCustomerOrderUri(Uri uri) {
    final sessionId = uri.queryParameters['session'];
    return sessionId != null && sessionId.isNotEmpty;
  }
}

/// App theme colors
class AppColors {
  static const Color primary = Color(0xFF1976D2);
  static const Color secondary = Color(0xFFE3F2FD);
  static const Color background = Color(0xFFF5F5F5);
  
  // Welcome screen gradient colors
  static const Color welcomeGradientStart = Color(0xFF1976D2);
  static const Color welcomeGradientMiddle = Color(0xFF1565C0);
  static const Color welcomeGradientEnd = Color(0xFF0D47A1);

  static const Color primaryColor = Color(0xFF1E88E5); // Blue
  static const Color secondaryColor = Color(0xFF26A69A); // Teal
  static const Color backgroundColor = Color(0xFFF5F5F5); // Light Grey
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color textColor = Color(0xFF212121);
  static const Color white = Colors.white;

  // Table Status Colors
  static const Color tableAvailable = Color(0xFF4CAF50); // Green
  static const Color tableOccupied = Color(0xFFF44336); // Red
  static const Color tableReserved = Color(0xFFFF9800); // Orange
  static const Color tableBilled = Color(0xFF2196F3);

  // Status colors
  static const Color statusPending = Color(0xFFFFA726); // Orange
  static const Color statusPreparing = Color(0xFFFF9800); // Orange darker
  static const Color statusPrepared = Color(0xFF4CAF50); // Green
  static const Color statusServed = Color(0xFF2196F3); // Blue
  static const Color statusPaid = Color(0xFF009688); // Teal
  static const Color statusCancelled = Color(0xFFF44336); // Red

  // Table status colors

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
