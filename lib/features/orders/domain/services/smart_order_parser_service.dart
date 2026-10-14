import 'package:intl/intl.dart';
import '../../../../core/services/location_lookup_service.dart';
import '../../../dc_console/domain/entities/product_package.dart';

/// Single item parsed from structured WhatsApp / CRM order text
class SmartParsedOrderItem {
  final String rawLine;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final CatalogProduct? matchedProduct;
  final ProductPackage? matchedPackage;

  const SmartParsedOrderItem({
    required this.rawLine,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.matchedProduct,
    this.matchedPackage,
  });

  SmartParsedOrderItem copyWith({
    String? rawLine,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    CatalogProduct? matchedProduct,
    ProductPackage? matchedPackage,
  }) {
    return SmartParsedOrderItem(
      rawLine: rawLine ?? this.rawLine,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      matchedProduct: matchedProduct ?? this.matchedProduct,
      matchedPackage: matchedPackage ?? this.matchedPackage,
    );
  }
}

/// Structured order parsed from raw WhatsApp / CRM copied text
class SmartParsedOrder {
  final String rawText;
  final String? orderNumber;
  final String? orderDateString;
  final DateTime? orderDateTime;
  final String customerName;
  final String customerAddress;
  final String country;
  final String state;
  final String city;
  final String lga;
  final String phoneNumber;
  final String? whatsappNumber;
  final List<SmartParsedOrderItem> items;
  final double totalAmount;
  final double amountToCollect;
  final String? additionalInformation;
  final String? closerName;
  final String? closerPhone;
  final bool isAddressSuspicious;
  final bool isCustomerNamePhone;
  final bool isCityEmptyOrNa;
  final List<String> warnings;

  const SmartParsedOrder({
    required this.rawText,
    this.orderNumber,
    this.orderDateString,
    this.orderDateTime,
    required this.customerName,
    required this.customerAddress,
    this.country = 'Nigeria',
    required this.state,
    required this.city,
    required this.lga,
    required this.phoneNumber,
    this.whatsappNumber,
    required this.items,
    required this.totalAmount,
    required this.amountToCollect,
    this.additionalInformation,
    this.closerName,
    this.closerPhone,
    this.isAddressSuspicious = false,
    this.isCustomerNamePhone = false,
    this.isCityEmptyOrNa = false,
    this.warnings = const [],
  });

  /// Primary product parsed from the order
  SmartParsedOrderItem? get primaryItem => items.isNotEmpty ? items.first : null;

  SmartParsedOrder copyWith({
    String? rawText,
    String? orderNumber,
    String? orderDateString,
    DateTime? orderDateTime,
    String? customerName,
    String? customerAddress,
    String? country,
    String? state,
    String? city,
    String? lga,
    String? phoneNumber,
    String? whatsappNumber,
    List<SmartParsedOrderItem>? items,
    double? totalAmount,
    double? amountToCollect,
    String? additionalInformation,
    String? closerName,
    String? closerPhone,
    bool? isAddressSuspicious,
    bool? isCustomerNamePhone,
    bool? isCityEmptyOrNa,
    List<String>? warnings,
  }) {
    return SmartParsedOrder(
      rawText: rawText ?? this.rawText,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDateString: orderDateString ?? this.orderDateString,
      orderDateTime: orderDateTime ?? this.orderDateTime,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      lga: lga ?? this.lga,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      amountToCollect: amountToCollect ?? this.amountToCollect,
      additionalInformation: additionalInformation ?? this.additionalInformation,
      closerName: closerName ?? this.closerName,
      closerPhone: closerPhone ?? this.closerPhone,
      isAddressSuspicious: isAddressSuspicious ?? this.isAddressSuspicious,
      isCustomerNamePhone: isCustomerNamePhone ?? this.isCustomerNamePhone,
      isCityEmptyOrNa: isCityEmptyOrNa ?? this.isCityEmptyOrNa,
      warnings: warnings ?? this.warnings,
    );
  }
}

/// Service that parses structured WhatsApp / CRM order texts into system-ready Order definitions
class SmartOrderParserService {
  /// Primary capital or major hub LGAs for quick fallback when city/LGA is 'N/A'
  static final Map<String, String> _stateCapitalLgas = {
    'Abia': 'Umuahia North',
    'Adamawa': 'Yola North',
    'Akwa Ibom': 'Uyo',
    'Anambra': 'Awka South',
    'Bauchi': 'Bauchi',
    'Bayelsa': 'Yenagoa',
    'Benue': 'Makurdi',
    'Borno': 'Maiduguri',
    'Cross River': 'Calabar Municipal',
    'Delta': 'Oshimili South',
    'Ebonyi': 'Abakaliki',
    'Edo': 'Oredo',
    'Ekiti': 'Ado Ekiti',
    'Enugu': 'Enugu North',
    'Federal Capital Territory': 'Abuja Municipal (AMAC)',
    'Gombe': 'Gombe',
    'Imo': 'Owerri Municipal',
    'Jigawa': 'Dutse',
    'Kaduna': 'Kaduna North',
    'Kano': 'Kano Municipal',
    'Katsina': 'Katsina',
    'Kebbi': 'Birnin Kebbi',
    'Kogi': 'Lokoja',
    'Kwara': 'Ilorin South',
    'Lagos': 'Ikeja',
    'Nasarawa': 'Lafia',
    'Niger': 'Chanchaga',
    'Ogun': 'Abeokuta South',
    'Ondo': 'Akure South',
    'Osun': 'Osogbo',
    'Oyo': 'Ibadan North',
    'Plateau': 'Jos North',
    'Rivers': 'Port Harcourt',
    'Sokoto': 'Sokoto North',
    'Taraba': 'Jalingo',
    'Yobe': 'Damaturu',
    'Zamfara': 'Gusau',
  };

  /// Parses raw text block into a [SmartParsedOrder]
  static SmartParsedOrder parse(
    String rawInput, {
    List<CatalogProduct>? catalogProducts,
  }) {
    final text = rawInput.trim();
    if (text.isEmpty) {
      return const SmartParsedOrder(
        rawText: '',
        customerName: '',
        customerAddress: '',
        state: 'Federal Capital Territory',
        city: 'Abuja Municipal (AMAC)',
        lga: 'Abuja Municipal (AMAC)',
        phoneNumber: '',
        items: [],
        totalAmount: 0.0,
        amountToCollect: 0.0,
      );
    }

    final warnings = <String>[];

    // Clean markdown bolding (*Key:*) common in WhatsApp messages
    final cleanText = text.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => match.group(1) ?? '',
    );

    // 1. Order Number
    final orderNumMatch = RegExp(
      r'(?:order\s*(?:number|no\.?|id|code|#)|ref(?:erence)?)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final orderNumber = orderNumMatch?.group(1)?.trim();

    // 2. Order Date/Time
    final dateMatch = RegExp(
      r'(?:order\s*date(?:\/time)?|date(?:\/time)?|timestamp)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final orderDateString = dateMatch?.group(1)?.trim();
    DateTime? orderDateTime;
    if (orderDateString != null && orderDateString.isNotEmpty) {
      orderDateTime = _tryParseDate(orderDateString);
    }

    // 3. Customer Name
    final nameMatch = RegExp(
      r'(?:customer\s*name|client\s*name|buyer\s*name|recipient\s*name|name)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    String customerName = nameMatch?.group(1)?.trim() ?? '';

    // 4. Phone Number
    final phoneMatch = RegExp(
      r'(?:phone\s*(?:number)?|mobile\s*(?:number)?|tel(?:ephone)?|contact\s*(?:number)?)\s*[:=\-]\s*([+\d\s\(\)\-]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    String rawPhone = phoneMatch?.group(1)?.trim() ?? '';
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    // 5. Customer Address
    final addrMatch = RegExp(
      r'(?:customer\s*address|delivery\s*address|shipping\s*address|street\s*address|address)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    String customerAddress = addrMatch?.group(1)?.trim() ?? '';

    // 6. Country
    final countryMatch = RegExp(
      r'(?:country|nation)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final country = countryMatch?.group(1)?.trim() ?? 'Nigeria';

    // 7. State
    final stateMatch = RegExp(
      r'(?:delivery\s*state|state)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final rawState = stateMatch?.group(1)?.trim() ?? 'Federal Capital Territory';
    final normalizedState = LocationLookupService.normalizeStateName(rawState);

    // 8. City / LGA
    final cityMatch = RegExp(
      r'(?:city|town|lga|local\s*government|municipality)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final rawCity = cityMatch?.group(1)?.trim() ?? '';
    final isCityNa = rawCity.isEmpty ||
        rawCity.toUpperCase() == 'N/A' ||
        rawCity.toUpperCase() == 'NA' ||
        rawCity.toUpperCase() == 'NONE';

    // Available LGAs for this normalized state
    final stateLgas = LocationLookupService.getLgasForState(normalizedState);
    String resolvedLga;
    if (!isCityNa) {
      // Find matching LGA in list
      final matchedLga = stateLgas.where((l) =>
          l.toLowerCase() == rawCity.toLowerCase() ||
          rawCity.toLowerCase().contains(l.toLowerCase()) ||
          l.toLowerCase().contains(rawCity.toLowerCase())).firstOrNull;
      resolvedLga = matchedLga ?? rawCity;
    } else {
      // Auto-fallback to state capital / primary hub LGA
      final capitalLga = _stateCapitalLgas[normalizedState];
      resolvedLga = (capitalLga != null && stateLgas.contains(capitalLga))
          ? capitalLga
          : (stateLgas.isNotEmpty ? stateLgas.first : 'Central LGA');
      warnings.add('City/LGA was "$rawCity". Auto-selected $resolvedLga ($normalizedState).');
    }

    // Check if customer name is actually a phone number
    final isNamePhone = _looksLikePhone(customerName);
    if (customerName.isEmpty || isNamePhone) {
      if (cleanPhone.isNotEmpty) {
        customerName = customerName.isNotEmpty ? customerName : 'Customer ($cleanPhone)';
      } else {
        customerName = 'Customer';
      }
    }

    // Check if address is suspiciously just a phone number
    final isAddrPhone = _looksLikePhone(customerAddress);
    final isAddrNa = customerAddress.isEmpty ||
        customerAddress.toUpperCase() == 'N/A' ||
        customerAddress == cleanPhone ||
        customerAddress == rawPhone;
    final isAddressSuspicious = isAddrPhone || isAddrNa;
    if (isAddressSuspicious) {
      warnings.add('⚠️ Address appears to be a phone number or placeholder. Please verify street address before dispatch.');
      if (customerAddress.isEmpty || isAddrNa) {
        customerAddress = '$resolvedLga, $normalizedState';
      }
    }

    // 9. WhatsApp Number
    final waMatch = RegExp(
      r'(?:whatsapp\s*(?:number)?|wa\s*(?:number)?)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    String? rawWa = waMatch?.group(1)?.trim();
    if (rawWa != null && (rawWa.toUpperCase() == 'N/A' || rawWa.toUpperCase() == 'NA')) {
      rawWa = null;
    }

    // 10. Additional Information
    final addlMatch = RegExp(
      r'(?:additional\s*information|additional\s*info|notes?|remarks?)\s*[:=\-]\s*([\s\S]*?)(?=(?:closer\s*details|sales\s*rep|$))',
      caseSensitive: false,
    ).firstMatch(cleanText);
    String? additionalInfo = addlMatch?.group(1)?.trim();

    // Check additional info for WhatsApp Number if not yet found
    if (rawWa == null && additionalInfo != null) {
      final waInNotes = RegExp(
        r'whatsapp\s*number\s*[:=\-]?\s*([+\d\s\-]+)',
        caseSensitive: false,
      ).firstMatch(additionalInfo);
      if (waInNotes != null) {
        rawWa = waInNotes.group(1)?.trim();
      }
    }

    // 11. Closer Details
    final closerNameMatch = RegExp(
      r'(?:closer\s*name|rep\s*name|agent\s*name|sales\s*closer)\s*[:=\-]\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final closerName = closerNameMatch?.group(1)?.trim();

    final closerPhoneMatch = RegExp(
      r'(?:closer\s*phone|rep\s*phone|agent\s*phone)\s*[:=\-]\s*([+\d\s\(\)\-]+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final closerPhone = closerPhoneMatch?.group(1)?.trim();

    // 12. Total order value & Amount to collect
    final totalValMatch = RegExp(
      r'(?:total\s*order\s*value|total\s*value|order\s*value|total\s*amount)\s*[:=\-]\s*(?:NGN|₦|N)?\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final totalOrderValue = _parseAmount(totalValMatch?.group(1));

    final colValMatch = RegExp(
      r'(?:amount\s*to\s*collect|collection\s*amount|cod\s*amount|amount)\s*[:=\-]\s*(?:NGN|₦|N)?\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final amountToCollect = _parseAmount(colValMatch?.group(1));

    // 13. Details of Products
    final productsSectionMatch = RegExp(
      r'(?:details\s*of\s*products?|products?|items?|order\s*details?)\s*[:=\-]?\s*([\s\S]*?)(?=(?:total\s*order|amount\s*to\s*collect|additional|closer|$))',
      caseSensitive: false,
    ).firstMatch(cleanText);
    final rawProductsText = productsSectionMatch?.group(1)?.trim() ?? '';

    final items = _parseProductItems(
      rawProductsText,
      fallbackTotal: amountToCollect > 0 ? amountToCollect : totalOrderValue,
      catalogProducts: catalogProducts,
    );

    final finalTotal = amountToCollect > 0
        ? amountToCollect
        : (totalOrderValue > 0
            ? totalOrderValue
            : (items.isNotEmpty ? items.map((e) => e.totalPrice).reduce((a, b) => a + b) : 0.0));

    return SmartParsedOrder(
      rawText: rawInput,
      orderNumber: orderNumber,
      orderDateString: orderDateString,
      orderDateTime: orderDateTime,
      customerName: customerName,
      customerAddress: customerAddress,
      country: country,
      state: normalizedState,
      city: isCityNa ? resolvedLga : rawCity,
      lga: resolvedLga,
      phoneNumber: cleanPhone.isNotEmpty ? cleanPhone : rawPhone,
      whatsappNumber: rawWa,
      items: items,
      totalAmount: finalTotal,
      amountToCollect: finalTotal,
      additionalInformation: additionalInfo,
      closerName: closerName,
      closerPhone: closerPhone,
      isAddressSuspicious: isAddressSuspicious,
      isCustomerNamePhone: isNamePhone,
      isCityEmptyOrNa: isCityNa,
      warnings: warnings,
    );
  }

  /// Parses individual product lines such as:
  /// `- RESPIRA LUNG TEA x1 · NGN 21,500`
  static List<SmartParsedOrderItem> _parseProductItems(
    String productsSection, {
    double fallbackTotal = 0.0,
    List<CatalogProduct>? catalogProducts,
  }) {
    if (productsSection.isEmpty) {
      if (fallbackTotal > 0 && catalogProducts != null && catalogProducts.isNotEmpty) {
        final p = catalogProducts.first;
        return [
          SmartParsedOrderItem(
            rawLine: p.name,
            productName: p.name,
            quantity: 1,
            unitPrice: fallbackTotal,
            totalPrice: fallbackTotal,
            matchedProduct: p,
          ),
        ];
      }
      return [];
    }

    final lines = productsSection
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final results = <SmartParsedOrderItem>[];

    for (final line in lines) {
      // Strip leading bullet characters
      final cleanLine = line.replaceFirst(RegExp(r'^[-*•\d\.\)]+\s*'), '').trim();
      if (cleanLine.isEmpty) continue;

      // Extract Quantity: e.g. x1, 1x, x 2, (2)
      int quantity = 1;
      final qtyMatch = RegExp(
        r'(?:[xX]\s*(\d+)|(\d+)\s*[xX]|(?:qty|quantity)\s*[:=\-]?\s*(\d+))',
      ).firstMatch(cleanLine);
      if (qtyMatch != null) {
        final qStr = qtyMatch.group(1) ?? qtyMatch.group(2) ?? qtyMatch.group(3);
        if (qStr != null) {
          quantity = int.tryParse(qStr) ?? 1;
        }
      }

      // Extract Price: e.g. · NGN 21,500 or ₦21,500 or N21,500
      double price = 0.0;
      final priceMatch = RegExp(
        r'(?:·|@|-|–)?\s*(?:NGN|₦|N)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).allMatches(cleanLine).toList();

      for (final pm in priceMatch.reversed) {
        final p = _parseAmount(pm.group(1));
        if (p > 100) {
          price = p;
          break;
        }
      }

      // If price wasn't found in line, fallback
      if (price <= 0 && fallbackTotal > 0) {
        price = fallbackTotal;
      }

      // Extract Product Name: remove quantity and price tokens
      String productName = cleanLine;
      if (qtyMatch != null) {
        productName = productName.replaceFirst(qtyMatch.group(0)!, '');
      }
      productName = productName.replaceAll(RegExp(r'(?:·|@|-|–|\/)\s*(?:NGN|₦|N)?\s*[\d,]+(?:\.\d+)?', caseSensitive: false), '');
      productName = productName.replaceAll(RegExp(r'(?:NGN|₦|N)?\s*[\d,]+(?:\.\d+)?', caseSensitive: false), '');
      productName = productName.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (productName.isEmpty) {
        productName = 'Standard Product';
      }

      // Match against catalog products
      CatalogProduct? matched;
      ProductPackage? matchedPkg;
      if (catalogProducts != null && catalogProducts.isNotEmpty) {
        final cleanPName = productName.toLowerCase();
        matched = catalogProducts.where((p) {
          final cpName = p.name.toLowerCase();
          return cpName == cleanPName ||
              cpName.contains(cleanPName) ||
              cleanPName.contains(cpName);
        }).firstOrNull;

        if (matched != null && matched.packages.isNotEmpty) {
          matchedPkg = matched.packages.where((pkg) =>
              pkg.quantity == quantity ||
              (price > 0 && (pkg.packagePrice - price).abs() < 500)).firstOrNull;
        }
      }

      results.add(
        SmartParsedOrderItem(
          rawLine: line,
          productName: productName,
          quantity: quantity > 0 ? quantity : 1,
          unitPrice: quantity > 1 ? (price / quantity) : price,
          totalPrice: price,
          matchedProduct: matched,
          matchedPackage: matchedPkg,
        ),
      );
    }

    return results;
  }

  /// Parses monetary string like "21,500", "NGN 21,500.00", "₦21500"
  static double _parseAmount(String? raw) {
    if (raw == null) return 0.0;
    final clean = raw.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  /// Checks if string is purely numeric phone format
  static bool _looksLikePhone(String input) {
    final clean = input.replaceAll(RegExp(r'[\s\(\)\-\+]'), '');
    return clean.length >= 7 && RegExp(r'^\d+$').hasMatch(clean);
  }

  /// Flexible date parser for formats like "05 Oct 2026, 21:42", "2026-10-05 21:42", "05/10/2026"
  static DateTime? _tryParseDate(String dateStr) {
    final clean = dateStr.trim();
    final direct = DateTime.tryParse(clean);
    if (direct != null) return direct;

    final formats = [
      'dd MMM yyyy, HH:mm',
      'dd MMMM yyyy, HH:mm',
      'dd MMM yyyy HH:mm',
      'dd/MM/yyyy HH:mm',
      'yyyy-MM-dd HH:mm',
      'dd MMM yyyy',
      'dd/MM/yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(clean);
      } catch (_) {}
    }
    return null;
  }
}
