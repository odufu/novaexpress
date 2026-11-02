import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// State 9: Form Validation State & Helpers
/// Highlights errors directly where they occur with clear, helpful instructions
/// tailored specifically to shipment forms, phone numbers, delivery addresses, and fees.
class NovaFormValidators {
  /// Validator for required fields
  static FormFieldValidator<String> required([String message = 'This field is required']) {
    return (val) {
      if (val == null || val.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  /// Validates Nigerian phone numbers (080..., 070..., 090..., 081..., +234...)
  static FormFieldValidator<String> nigerianPhone({String requiredMessage = 'Phone number is required'}) {
    return (val) {
      if (val == null || val.trim().isEmpty) {
        return requiredMessage;
      }
      final clean = val.replaceAll(RegExp(r'[^\d+]'), '');
      if (clean.startsWith('+234')) {
        if (clean.length != 14) {
          return 'Enter a valid Nigerian phone number (e.g. 08012345678)';
        }
      } else if (clean.startsWith('0')) {
        if (clean.length != 11) {
          return 'Enter a valid Nigerian phone number (e.g. 08012345678)';
        }
      } else {
        return 'Enter a valid Nigerian phone number (e.g. 08012345678)';
      }
      return null;
    };
  }

  /// Validates physical delivery address (must include street, number, or landmark)
  static FormFieldValidator<String> deliveryAddress() {
    return (val) {
      if (val == null || val.trim().isEmpty) {
        return 'Delivery address is required';
      }
      if (val.trim().length < 10) {
        return 'Please provide a full delivery address (street, number, landmark)';
      }
      return null;
    };
  }

  /// Validates currency amounts
  static FormFieldValidator<String> positiveAmount() {
    return (val) {
      if (val == null || val.trim().isEmpty) {
        return 'Amount is required';
      }
      final clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(clean);
      if (parsed == null) {
        return 'Enter a valid numeric amount';
      }
      if (parsed <= 0) {
        return 'Amount must be greater than zero';
      }
      return null;
    };
  }

  /// Validates item quantity
  static FormFieldValidator<String> validQuantity() {
    return (val) {
      if (val == null || val.trim().isEmpty) {
        return 'Quantity is required';
      }
      final parsed = int.tryParse(val.trim());
      if (parsed == null || parsed <= 0) {
        return 'Quantity must be at least 1 item';
      }
      return null;
    };
  }

  /// Validates email address
  static FormFieldValidator<String> email() {
    return (val) {
      if (val == null || val.trim().isEmpty) {
        return 'Email is required';
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(val.trim())) {
        return 'Enter a valid email address';
      }
      return null;
    };
  }

  /// Validates Nigerian phone numbers directly
  static String? validatePhone(String? val, {String fieldName = 'Phone number'}) {
    return nigerianPhone(requiredMessage: '$fieldName is required for delivery SMS and rider calls')(val);
  }

  /// Validates physical delivery address directly
  static String? validateDeliveryAddress(String? val) {
    return deliveryAddress()(val);
  }

  /// Validates customer recipient full name
  static String? validateRecipientName(String? val) {
    if (val == null || val.trim().isEmpty) {
      return 'Recipient full name is required';
    }
    final parts = val.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return 'Please provide at least first and last name for delivery verification';
    }
    return null;
  }

  /// Validates package parcel quantity directly
  static String? validateQuantity(String? val) {
    return validQuantity()(val);
  }

  /// Validates currency amounts directly
  static String? validateAmount(String? val, {bool allowZero = false}) {
    if (allowZero && val != null && val.trim() == '0') return null;
    return positiveAmount()(val);
  }

  /// Validates official email address directly
  static String? validateEmail(String? val) {
    return email()(val);
  }
}

/// Standalone Form Error Summary Banner
class NovaFormErrorBanner extends StatelessWidget {
  final List<String> errors;

  const NovaFormErrorBanner({
    super.key,
    required this.errors,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                'Please correct the following errors:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...errors.map(
            (e) => Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                '• $e',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
