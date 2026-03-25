/// Application Configuration
/// 
/// PRICING PROTOCOL (Updated):
/// A4: BW ₹2, Color ₹5
/// A3: BW ₹4, Color ₹20
/// Top Sheet: Always B&W price, 1 per ORDER (not per copy)
/// Top Sheet FREE for documents with 50+ pages
/// Spiral Binding: +₹25
/// Soft Binding: +₹100 (mutually exclusive with spiral)
class AppConfig {
  // Backend API Configuration
  static const String backendBaseUrl = 'https://itsmrop-iem-print-gurukul.hf.space';
  
  static bool get isSecureConnection => backendBaseUrl.startsWith('https://');
  
  static const String apiEndpoint = '$backendBaseUrl/api';
  static const String uploadEndpoint = '$apiEndpoint/upload';
  static const String statusEndpoint = '$apiEndpoint/status';
  static const String healthEndpoint = '$apiEndpoint/health';

  // Retry Configuration
  static const Duration retryInterval = Duration(seconds: 30);
  static const int maxRetries = 5;
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // =============================================
  // PRICING CONFIGURATION (in INR per page/unit)
  // =============================================
  
  static const Map<String, Map<String, double>> pricePerUnit = {
    'A4': {
      'BW': 2.00,         // ₹2 per page B&W
      'COLOR': 5.00,      // ₹5 per page Color
    },
    'A3': {
      'BW': 4.00,         // ₹4 per page B&W
      'COLOR': 20.00,     // ₹20 per page Color
    },
  };

  // Binding Prices
  static const double spiralBindingPrice = 25.00;  // ₹25
  static const double softBindingPrice = 100.00;   // ₹100

  // Top sheet free threshold
  static const int topSheetFreeThreshold = 50; // Free top sheet for 50+ pages

  /// Get price per unit for given paper size and print type
  static double getPricePerUnit(String paperSize, String printType) {
    return pricePerUnit[paperSize]?[printType] ?? 2.00;
  }

  /// Get top sheet price - ALWAYS B&W price regardless of document type
  static double getTopSheetPrice(String paperSize) {
    return pricePerUnit[paperSize]?['BW'] ?? 2.00;
  }

  // Front page configuration
  static const int frontPageCount = 1;
  static const bool chargeFrontPage = true;

  /// Calculate billable units based on page count and print side
  /// Single-sided: 1 page = 1 unit
  /// Double-sided: 2 pages = 1 sheet (round up)
  static int calculateBillableUnits(int pageCount, String printSide, {bool includeFrontPage = true}) {
    final totalPages = pageCount;
    
    if (printSide == 'DOUBLE') {
      return (totalPages / 2).ceil();
    }
    return totalPages;
  }

  /// Calculate total cost with updated pricing protocol
  /// Formula: (documentPages × pricePerUnit × copies) + topSheetPrice (1 per order, free for 50+ pages) + bindingPrice
  static double calculateTotalCost({
    required int pageCount,
    required String paperSize,
    required String printType,
    required String printSide,
    required int copies,
    String bindingType = 'NONE', // NONE, SPIRAL, SOFT
    bool includeFrontPage = true,
  }) {
    // Calculate document cost
    final billableUnits = calculateBillableUnits(pageCount, printSide, includeFrontPage: false);
    final unitPrice = getPricePerUnit(paperSize, printType);
    final documentCost = billableUnits * unitPrice * copies;
    
    // Calculate top sheet cost:
    // - 1 per ORDER (not per copy)
    // - FREE for 50+ page documents
    // - Always B&W price
    double topSheetCost = 0.0;
    if (includeFrontPage && chargeFrontPage && pageCount < topSheetFreeThreshold) {
      topSheetCost = getTopSheetPrice(paperSize); // Only 1 top sheet per order
    }
    
    // Calculate binding cost
    double bindingCost = 0.0;
    if (bindingType == 'SPIRAL') {
      bindingCost = spiralBindingPrice;
    } else if (bindingType == 'SOFT') {
      bindingCost = softBindingPrice;
    }
    
    return documentCost + topSheetCost + bindingCost;
  }

  // UPI Configuration
  static const String upiId = 'q014782270@ybl';
  static const String upiMerchantName = 'ABDUL MANNAN MOLLA';

  // App Theme
  static const String appName = 'Print Order';
  static const String appVersion = '1.2.0';

  // File Size Limits
  static const int maxFileSizeMB = 50;
  static const int maxTotalFileSizeMB = 200;
  static const int maxFilesCount = 10;

  // Hive Box Names
  static const String pendingOrdersBox = 'pending_orders';
  static const String studentDetailsBox = 'student_details';
  static const String settingsBox = 'settings';
}

/// Paper Size Options (Removed LETTER)
enum PaperSize {
  A4('A4', 'Standard A4'),
  A3('A3', 'Large A3');

  final String value;
  final String displayName;
  const PaperSize(this.value, this.displayName);
}

/// Print Type Options (Removed PHOTOPAPER)
enum PrintType {
  BW('BW', 'Black & White', 0xFF424242),
  COLOR('COLOR', 'Color', 0xFF2196F3);

  final String value;
  final String displayName;
  final int colorValue;
  const PrintType(this.value, this.displayName, this.colorValue);
}

/// Print Side Options
enum PrintSide {
  SINGLE('SINGLE', 'Single Sided'),
  DOUBLE('DOUBLE', 'Double Sided');

  final String value;
  final String displayName;
  const PrintSide(this.value, this.displayName);
}

/// Binding Type Options
enum BindingType {
  NONE('NONE', 'No Binding', 0.0),
  SPIRAL('SPIRAL', 'Spiral Binding (+₹25)', 25.0),
  SOFT('SOFT', 'Soft Binding (+₹100)', 100.0);

  final String value;
  final String displayName;
  final double price;
  const BindingType(this.value, this.displayName, this.price);
}

/// Order Status
enum OrderStatus {
  pending('pending', 'Pending Upload'),
  uploading('uploading', 'Uploading'),
  processing('processing', 'Processing'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed'),
  queued('queued', 'Queued for Retry');

  final String value;
  final String displayName;
  const OrderStatus(this.value, this.displayName);
}
