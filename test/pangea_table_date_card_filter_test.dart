import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_date_range_picker_modal.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_excel_data_table.dart';

class TestRecord {
  final String id;
  final String title;
  final double amount;
  final DateTime timestamp;

  const TestRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.timestamp,
  });
}

void main() {
  group('PangeaExcelDataTable Date Card Filter Integration Tests', () {
    final records = [
      TestRecord(
        id: 'rec-1',
        title: 'Grazer Herbal Tea Batch 1',
        amount: 45000.0,
        timestamp: DateTime(2026, 9, 14, 10, 30),
      ),
      TestRecord(
        id: 'rec-2',
        title: 'Novacare Honey Detox 2',
        amount: 32000.0,
        timestamp: DateTime(2026, 9, 20, 14, 15),
      ),
      TestRecord(
        id: 'rec-3',
        title: 'Respira Herbal Blend 3',
        amount: 58000.0,
        timestamp: DateTime(2026, 9, 26, 18, 0),
      ),
      TestRecord(
        id: 'rec-4',
        title: 'Historical Intake Archive',
        amount: 12000.0,
        timestamp: DateTime(2026, 8, 1, 9, 0),
      ),
      TestRecord(
        id: 'rec-5',
        title: 'Future Scheduled Delivery',
        amount: 80000.0,
        timestamp: DateTime(2026, 10, 15, 11, 0),
      ),
    ];

    List<ExcelColumnDef<TestRecord>> buildColumns() {
      return [
        ExcelColumnDef<TestRecord>(
          key: 'title',
          label: 'TITLE & DATE',
          defaultWidth: 200,
          dateValue: (r) => r.timestamp,
          searchString: (r) => r.title,
          sortValue: (r) => r.title,
          cellBuilder: (ctx, item, index, isDark, brand) => Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        ExcelColumnDef<TestRecord>(
          key: 'amount',
          label: 'AMOUNT',
          defaultWidth: 120,
          searchString: (r) => r.amount.toString(),
          sortValue: (r) => r.amount,
          cellBuilder: (ctx, item, index, isDark, brand) => Text(
            '₦${item.amount}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ];
    }

    testWidgets('Automatically discovers date column and renders Date Card Filter button in toolbar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PangeaExcelDataTable<TestRecord>(
              items: records,
              columns: buildColumns(),
              enablePagination: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify toolbar shows total rows count and Date Range button
      expect(find.text('Showing 1 to 5 of 5 rows'), findsWidgets);
      expect(find.byKey(const ValueKey('pangea_table_date_filter_btn')), findsOneWidget);
      expect(find.text('Date Range'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    });

    testWidgets('Filters rows in real-time when initialDateRange is supplied', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Range covers Sep 14 to Sep 26 (records 1, 2, 3)
      final filterRange = DateTimeRange(
        start: DateTime(2026, 9, 14),
        end: DateTime(2026, 9, 26),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PangeaExcelDataTable<TestRecord>(
              items: records,
              columns: buildColumns(),
              initialDateRange: filterRange,
              dateExtractor: (r) => r.timestamp,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Record 4 (August) and Record 5 (October) should be filtered out
      expect(find.text('Showing 1 to 3 of 3 rows'), findsWidgets);
      expect(find.text('Grazer Herbal Tea Batch 1'), findsOneWidget);
      expect(find.text('Novacare Honey Detox 2'), findsOneWidget);
      expect(find.text('Respira Herbal Blend 3'), findsOneWidget);
      expect(find.text('Historical Intake Archive'), findsNothing);
      expect(find.text('Future Scheduled Delivery'), findsNothing);

      // Verify active badge label
      expect(find.text('14 Sep 2026 – 26 Sep 2026'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Tapping Date Card Filter button opens dual-month modal and applies date selection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      DateTimeRange? notifiedRange;
      DateRangePreset? notifiedPreset;
      bool? notifiedCompare;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PangeaExcelDataTable<TestRecord>(
              items: records,
              columns: buildColumns(),
              dateExtractor: (r) => r.timestamp,
              onDateRangeChanged: (range, preset, compare) {
                notifiedRange = range;
                notifiedPreset = preset;
                notifiedCompare = compare;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Date Card Filter modal
      await tester.tap(find.byKey(const ValueKey('pangea_table_date_filter_btn')));
      await tester.pumpAndSettle();

      // Verify modal UI components
      expect(find.text('Recently used'), findsOneWidget);
      expect(find.text('Dates are shown in Lagos Time'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      // Tap 'Last 7 days' preset radio button
      await tester.tap(find.text('Last 7 days').first);
      await tester.pumpAndSettle();

      // Tap 'Update' button to apply
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      // Callback should have fired
      expect(notifiedRange, isNotNull);
      expect(notifiedPreset, DateRangePreset.last7Days);
      expect(notifiedCompare, false);

      // Table should now display the active date range pill in the toolbar
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Clearing the filter
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // All rows should be restored
      expect(find.text('Showing 1 to 5 of 5 rows'), findsWidgets);
      expect(find.text('Date Range'), findsOneWidget);
      expect(notifiedRange, isNull);
    });
  });
}
