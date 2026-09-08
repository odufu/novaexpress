import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test DC Scoped Stock Parsing and Calculation Logic', () {
    const otukpoDcId = '00000000-0000-4000-8000-788825051520';
    const dutseDcId = 'dutse-dc-uuid-999';
    const wuseDcId = '22222222-2222-4222-8222-222222222222';

    String? parseOriginDc(String? description) {
      if (description == null) return null;
      final match = RegExp(r'\[ORIGIN_DC:\s*([a-zA-Z0-9_-]+)\]').firstMatch(description);
      return match?.group(1)?.trim();
    }

    Map<String, int> parseDcStocks(String? description) {
      if (description == null) return {};
      final match = RegExp(r'\[DC_STOCKS:\s*(\{.*?\})\]').firstMatch(description);
      if (match != null) {
        try {
          final decoded = jsonDecode(match.group(1)!) as Map<String, dynamic>;
          return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
        } catch (_) {}
      }
      return {};
    }

    int getAvailableStockForDc({
      required String dcId,
      required String sku,
      required int globalStock,
      required String description,
    }) {
      final dcStocks = parseDcStocks(description);
      final originDc = parseOriginDc(description);

      if (dcStocks.isNotEmpty) {
        return dcStocks[dcId] ?? 0;
      } else if (originDc != null) {
        return (originDc == dcId) ? globalStock : 0;
      } else {
        if (sku == 'SKU-02900') {
          return (dcId == otukpoDcId) ? globalStock : 0;
        } else if (dcId == wuseDcId) {
          return globalStock;
        } else {
          return 0;
        }
      }
    }

    // 1. Grazer Herbal Detox Tea created in Otukpo DC
    const grazerDesc = 'Grazer Herbal Detox Tea - Distributed Inventory [ORIGIN_DC: 00000000-0000-4000-8000-788825051520]';
    final otukpoStock = getAvailableStockForDc(
      dcId: otukpoDcId,
      sku: 'SKU-02900',
      globalStock: 230,
      description: grazerDesc,
    );
    final dutseStock = getAvailableStockForDc(
      dcId: dutseDcId,
      sku: 'SKU-02900',
      globalStock: 230,
      description: grazerDesc,
    );

    expect(otukpoStock, equals(230));
    expect(dutseStock, equals(0));

    // 2. A new product created in Dutse DC with 500 units
    const dutseGingerDesc = 'Dutse Ginger Drink [ORIGIN_DC: $dutseDcId] [DC_STOCKS: {"$dutseDcId": 500}]';
    final dutseStock2 = getAvailableStockForDc(
      dcId: dutseDcId,
      sku: 'SKU-DUTSE-01',
      globalStock: 500,
      description: dutseGingerDesc,
    );
    final otukpoStock2 = getAvailableStockForDc(
      dcId: otukpoDcId,
      sku: 'SKU-DUTSE-01',
      globalStock: 500,
      description: dutseGingerDesc,
    );

    expect(dutseStock2, equals(500));
    expect(otukpoStock2, equals(0));
  });
}
