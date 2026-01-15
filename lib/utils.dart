/// Utility functions for the Waiter App
/// Contains validators, formatters, and helper functions.

import 'package:flutter/material.dart';

/// Input validators for form fields
class Validators {
  /// Validates car plate number format
  /// Returns null if valid, error message if invalid
  static String? validateCarPlate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Car plate number is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Car plate number must be at least 3 characters';
    }
    if (trimmed.length > 15) {
      return 'Car plate number is too long';
    }
    return null;
  }

  /// Validates special instructions (optional field)
  /// Returns null if valid, error message if invalid
  static String? validateSpecialInstructions(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (value.length > 500) {
      return 'Special instructions must be less than 500 characters';
    }
    return null;
  }

  /// Validates table number
  static String? validateTableNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Table number is required';
    }
    return null;
  }

  /// Validates that cart is not empty
  static String? validateCart(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return 'Cart cannot be empty';
    }
    return null;
  }

  /// Validates amount is positive
  static String? validateAmount(double? amount) {
    if (amount == null || amount <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }
}

/// Date and time formatting utilities
class DateTimeUtils {
  /// Formats a DateTime to relative time string (e.g., "5m ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Formats time for display (HH:MM)
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Formats date for display (DD/MM/YYYY)
  static String formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  /// Gets estimated ready time from now
  static DateTime getEstimatedReadyTime({int minutesFromNow = 15}) {
    return DateTime.now().add(Duration(minutes: minutesFromNow));
  }
}

/// UI helper utilities
class UIUtils {
  /// Shows a success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows an error snackbar
  static void showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows a warning snackbar
  static void showWarningSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows a confirmation dialog
  /// Returns true if user confirms, false otherwise
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: confirmColor),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

/// Network and Firebase error handling utilities
class ErrorUtils {
  /// Returns a user-friendly error message from a Firebase exception
  static String getFirebaseErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('unavailable')) {
      return 'Network error. Please check your internet connection.';
    }
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please contact your administrator.';
    }
    if (errorString.contains('not-found') || errorString.contains('not found')) {
      return 'The requested data was not found.';
    }
    if (errorString.contains('already-exists')) {
      return 'This item already exists.';
    }
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (errorString.contains('cancelled')) {
      return 'Operation was cancelled.';
    }
    
    // For unknown errors, return generic message in production
    return 'An error occurred. Please try again.';
  }
}

/// Validation limits for input fields
class ValidationLimits {
  /// Maximum length for special instructions
  static const int maxSpecialInstructionsLength = 500;
  
  /// Maximum length for car plate number
  static const int maxCarPlateLength = 15;
  
  /// Minimum length for car plate number
  static const int minCarPlateLength = 3;
  
  /// Maximum length for customer name
  static const int maxCustomerNameLength = 100;
  
  /// Maximum items per order
  static const int maxItemsPerOrder = 50;
  
  /// Maximum quantity per item
  static const int maxQuantityPerItem = 99;
}

/// Input sanitization utilities to prevent XSS and injection attacks
class InputSanitizer {
  // Regex to match HTML tags including script tags
  static final RegExp _htmlTagPattern = RegExp(r'<[^>]*>', caseSensitive: false);
  
  // Regex to match common XSS patterns
  static final RegExp _xssPatterns = RegExp(
    r'(javascript:|data:|vbscript:|on\w+\s*=)',
    caseSensitive: false,
  );
  
  // Regex for dangerous characters that could be used in injection
  static final RegExp _dangerousChars = RegExp(r'[<>"\x27]'); // includes single quote
  
  /// Sanitizes text input by removing HTML tags and dangerous patterns
  /// Returns cleaned string safe for storage and display
  static String sanitize(String? input) {
    if (input == null || input.isEmpty) return '';
    
    String sanitized = input
        // Remove HTML/XML tags
        .replaceAll(_htmlTagPattern, '')
        // Remove XSS patterns
        .replaceAll(_xssPatterns, '')
        // Escape remaining dangerous characters
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
    
    return sanitized.trim();
  }
  
  /// Sanitizes and limits text length
  static String sanitizeWithLimit(String? input, int maxLength) {
    final sanitized = sanitize(input);
    if (sanitized.length > maxLength) {
      return sanitized.substring(0, maxLength);
    }
    return sanitized;
  }
  
  /// Validates and sanitizes car plate number
  /// Returns null if invalid, sanitized value if valid
  static String? sanitizeCarPlate(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    
    // Remove any dangerous characters, keep only alphanumeric and spaces
    final sanitized = input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s-]'), '');
    
    if (sanitized.length < ValidationLimits.minCarPlateLength) return null;
    if (sanitized.length > ValidationLimits.maxCarPlateLength) {
      return sanitized.substring(0, ValidationLimits.maxCarPlateLength);
    }
    
    return sanitized;
  }
  
  /// Sanitizes special instructions
  static String sanitizeInstructions(String? input) {
    return sanitizeWithLimit(input, ValidationLimits.maxSpecialInstructionsLength);
  }
}

/// Session management utilities
class SessionManager {
  /// Session timeout duration (30 minutes)
  static const Duration sessionTimeout = Duration(minutes: 30);
  
  /// Last activity timestamp - should be updated on user interactions
  static DateTime _lastActivity = DateTime.now();
  
  /// Updates the last activity timestamp
  static void updateActivity() {
    _lastActivity = DateTime.now();
  }
  
  /// Checks if the session has expired
  static bool isSessionExpired() {
    return DateTime.now().difference(_lastActivity) > sessionTimeout;
  }
  
  /// Resets session timer (call on login)
  static void resetSession() {
    _lastActivity = DateTime.now();
  }
}
