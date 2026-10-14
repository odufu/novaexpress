import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/features/orders/domain/services/smart_order_parser_service.dart';

void main() {
  group('SmartOrderParserService Tests', () {
    const rawOrderSample = '''
Order number: Novacare Ltd-CRM-ORD-10-009197
Order date/time: 05 Oct 2026, 21:42
Customer name: +234 816 469 9784
Customer address: +234 816 469 9784
Country: Nigeria
State: Bayelsa
City: N/A
Phone number: +2348164699784
Whatsapp number: N/A
Details of products:
 - RESPIRA LUNG TEA x1 · NGN 21,500
Total order value: NGN 21,500
Amount to collect: NGN 21,500
Additional information:
 - WhatsApp Number: +234 816 469 9784
Closer details:
Closer name: Caroline Onoja
Closer phone: 08160322891
''';

    test('Parses exact CRM WhatsApp text format correctly', () {
      final parsed = SmartOrderParserService.parse(rawOrderSample);

      expect(parsed.orderNumber, 'Novacare Ltd-CRM-ORD-10-009197');
      expect(parsed.orderDateString, '05 Oct 2026, 21:42');
      expect(parsed.orderDateTime, isNotNull);
      expect(parsed.orderDateTime!.year, 2026);
      expect(parsed.orderDateTime!.month, 10);
      expect(parsed.orderDateTime!.day, 5);
      expect(parsed.orderDateTime!.hour, 21);
      expect(parsed.orderDateTime!.minute, 42);

      // Customer Phone & WhatsApp
      expect(parsed.phoneNumber, '+2348164699784');
      // WhatsApp extracted from notes fallback since Whatsapp number was N/A
      expect(parsed.whatsappNumber, contains('+234 816 469 9784'));

      // State & LGA auto-fallback for Bayelsa
      expect(parsed.state, 'Bayelsa');
      expect(parsed.lga, 'Yenagoa'); // Bayelsa capital/hub fallback since City: N/A
      expect(parsed.isCityEmptyOrNa, isTrue);

      // Address suspicion detected because address is phone number
      expect(parsed.isAddressSuspicious, isTrue);

      // Products parsed
      expect(parsed.items.length, 1);
      final item = parsed.items.first;
      expect(item.productName, contains('RESPIRA LUNG TEA'));
      expect(item.quantity, 1);
      expect(item.unitPrice, 21500.0);
      expect(item.totalPrice, 21500.0);

      // Totals
      expect(parsed.totalAmount, 21500.0);
      expect(parsed.amountToCollect, 21500.0);

      // Closer Details
      expect(parsed.closerName, 'Caroline Onoja');
      expect(parsed.closerPhone, '08160322891');
    });

    test('Handles asterisk bolded WhatsApp formatting', () {
      const boldSample = '''
*Order number:* Novacare-ORD-991
*Customer name:* Tunde Balogun
*Customer address:* 14 Admiralty Way, Lekki Phase 1
*State:* Lagos
*City:* Ikeja
*Phone number:* 08023456789
*Details of products:*
- 2x POWER TONIC · NGN 45,000
*Amount to collect:* NGN 45,000
''';
      final parsed = SmartOrderParserService.parse(boldSample);

      expect(parsed.orderNumber, 'Novacare-ORD-991');
      expect(parsed.customerName, 'Tunde Balogun');
      expect(parsed.customerAddress, '14 Admiralty Way, Lekki Phase 1');
      expect(parsed.state, 'Lagos');
      expect(parsed.lga, 'Ikeja');
      expect(parsed.phoneNumber, '08023456789');
      expect(parsed.items.length, 1);
      expect(parsed.items.first.quantity, 2);
      expect(parsed.amountToCollect, 45000.0);
      expect(parsed.isAddressSuspicious, isFalse);
    });
  });
}
