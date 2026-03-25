import 'package:intl/intl.dart';

/// Format currency in INR
String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  return formatter.format(amount);
}

/// Format file size for display
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Format date for display
String formatDate(DateTime date) {
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}

/// Format date short
String formatDateShort(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

/// Format time only
String formatTime(DateTime time) {
  return DateFormat('hh:mm a').format(time);
}

/// Format duration
String formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours % 24}h';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }
  return '${duration.inSeconds}s';
}

/// Truncate text with ellipsis
String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

/// Validate email format
bool isValidEmail(String email) {
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  return emailRegex.hasMatch(email);
}

/// Validate phone number
bool isValidPhone(String phone) {
  final phoneRegex = RegExp(r'^[0-9]{10}$');
  return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\+]'), ''));
}

/// Generate order ID
String generateOrderId() {
  final now = DateTime.now();
  final timestamp = now.millisecondsSinceEpoch.toString().substring(5);
  final random = DateTime.now().microsecond.toString().padLeft(4, '0');
  return 'PO${now.year}${now.month.toString().padLeft(2, '0')}$timestamp$random';
}

/// Parse amount from text
double? parseAmount(String text) {
  // Remove currency symbols and spaces
  final cleaned = text.replaceAll(RegExp(r'[₹$,\s]'), '');
  return double.tryParse(cleaned);
}

/// Extract transaction ID from OCR text
/// Supports multiple UPI app formats (GPay, PhonePe, Paytm, etc.)
String? extractTransactionId(String text) {
  // 1. UPI Transaction ID (12 digit numeric) - highest priority
  final upiTxnPattern = RegExp(r'[Uu][Pp][Ii]\s*[Tt]ransaction\s*[Ii][Dd]\s*[:\s]*(\d{12,15})');
  var match = upiTxnPattern.firstMatch(text);
  if (match != null && match.groupCount >= 1) {
    return match.group(1);
  }
  
  // 2. Google transaction ID (alphanumeric like CICAgMiCndqbBA)
  final googleTxnPattern = RegExp(r'[Gg]oogle\s*[Tt]ransaction\s*[Ii][Dd]\s*[:\s]*([A-Za-z0-9]{10,20})');
  match = googleTxnPattern.firstMatch(text);
  if (match != null && match.groupCount >= 1) {
    return match.group(1);
  }
  
  // 3. Generic labeled transaction IDs
  final labeledPatterns = [
    RegExp(r'[Tt]ransaction\s*[Ii][Dd][:\s]*([A-Za-z0-9]{10,25})'),
    RegExp(r'[Uu][Tt][Rr][:\s]*([A-Za-z0-9]{10,25})'),
    RegExp(r'[Rr]ef[.\s]*[Nn]o[:\s]*([A-Za-z0-9]{10,25})'),
    RegExp(r'[Rr]eference[:\s]*([A-Za-z0-9]{10,25})'),
    RegExp(r'[Tt]xn\s*[Ii][Dd][:\s]*([A-Za-z0-9]{10,25})'),
  ];

  for (final pattern in labeledPatterns) {
    match = pattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
  }

  // 4. Look for 12-digit numeric sequences (UPI transaction IDs)
  final numericTxnPattern = RegExp(r'\b(\d{12})\b');
  match = numericTxnPattern.firstMatch(text);
  if (match != null) {
    return match.group(1);
  }

  // 5. Look for standalone 12-22 character alphanumeric strings
  final potentialIds = RegExp(r'\b[A-Za-z0-9]{12,22}\b')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .where((s) => s.contains(RegExp(r'[0-9]')) && s.contains(RegExp(r'[A-Za-z]')))
      .toList();

  if (potentialIds.isNotEmpty) {
    potentialIds.sort((a, b) => b.length.compareTo(a.length));
    return potentialIds.first;
  }

  return null;
}


/// Check if text contains success keywords
bool containsSuccessKeywords(String text) {
  final lowerText = text.toLowerCase();
  final successKeywords = [
    'success',
    'successful',
    'completed',
    'paid',
    'payment received',
    'money sent',
    'transferred',
  ];
  return successKeywords.any((keyword) => lowerText.contains(keyword));
}

/// Extract amount from OCR text
double? extractAmountFromText(String text) {
  // Common patterns for amounts in UPI/payment screenshots
  final patterns = [
    RegExp(r'₹\s*([0-9,]+\.?[0-9]*)'),
    RegExp(r'Rs\.?\s*([0-9,]+\.?[0-9]*)'),
    RegExp(r'INR\s*([0-9,]+\.?[0-9]*)'),
    RegExp(r'Amount[:\s]*₹?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
    RegExp(r'Paid[:\s]*₹?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
    RegExp(r'Total[:\s]*₹?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }
  }
  return null;
}

/// Extract UPI ID from OCR text
String? extractUpiId(String text) {
  // UPI ID pattern: xxx@yyy
  final upiPattern = RegExp(r'([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)');
  final match = upiPattern.firstMatch(text);
  if (match != null) {
    final upiId = match.group(1);
    // Validate it looks like a UPI ID (not email)
    if (upiId != null && 
        !upiId.contains('.com') && 
        !upiId.contains('.org') &&
        !upiId.contains('.in')) {
      return upiId;
    }
  }
  return null;
}

/// Extract payment timestamp from OCR text
/// Supports various UPI app date formats
DateTime? extractPaymentTimestamp(String text) {
  final months = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };
  
  // Pattern 1: "17 Jan 2026" or "17 January 2026"
  final pattern1 = RegExp(r'(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec|january|february|march|april|june|july|august|september|october|november|december)\s+(\d{4})', caseSensitive: false);
  
  // Pattern 2: "Jan 17, 2026" or "January 17, 2026"
  final pattern2 = RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec|january|february|march|april|june|july|august|september|october|november|december)\s+(\d{1,2}),?\s+(\d{4})', caseSensitive: false);
  
  // Pattern 3: "17/01/2026" or "17-01-2026"
  final pattern3 = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
  
  // Pattern 4: "2026-01-17" (ISO format)
  final pattern4 = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
  
  // Pattern with time: "17 Jan 2026 10:30 AM" or "17 Jan 2026, 10:30"
  final timePattern = RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)?', caseSensitive: false);
  
  int? day, month, year, hour = 0, minute = 0;
  
  // Try pattern 1
  var match = pattern1.firstMatch(text);
  if (match != null) {
    day = int.tryParse(match.group(1)!);
    month = months[match.group(2)!.toLowerCase()];
    year = int.tryParse(match.group(3)!);
  }
  
  // Try pattern 2
  if (day == null) {
    match = pattern2.firstMatch(text);
    if (match != null) {
      month = months[match.group(1)!.toLowerCase()];
      day = int.tryParse(match.group(2)!);
      year = int.tryParse(match.group(3)!);
    }
  }
  
  // Try pattern 3
  if (day == null) {
    match = pattern3.firstMatch(text);
    if (match != null) {
      day = int.tryParse(match.group(1)!);
      month = int.tryParse(match.group(2)!);
      year = int.tryParse(match.group(3)!);
    }
  }
  
  // Try pattern 4
  if (day == null) {
    match = pattern4.firstMatch(text);
    if (match != null) {
      year = int.tryParse(match.group(1)!);
      month = int.tryParse(match.group(2)!);
      day = int.tryParse(match.group(3)!);
    }
  }
  
  // Extract time if available
  final timeMatch = timePattern.firstMatch(text);
  if (timeMatch != null) {
    hour = int.tryParse(timeMatch.group(1)!) ?? 0;
    minute = int.tryParse(timeMatch.group(2)!) ?? 0;
    final ampm = timeMatch.group(3)?.toLowerCase();
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
  }
  
  if (day != null && month != null && year != null) {
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {}
  }
  
  return null;
}

/// Check if payment timestamp is within valid window (24 hours)
bool isPaymentTimestampValid(DateTime? paymentTime, {int maxHours = 24}) {
  if (paymentTime == null) return true; // If can't extract, allow anyway
  final now = DateTime.now();
  final difference = now.difference(paymentTime);
  return difference.inHours <= maxHours && !paymentTime.isAfter(now);
}
