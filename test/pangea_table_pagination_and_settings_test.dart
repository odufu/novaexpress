import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novexps/features/client_portal/presentation/widgets/pangea_excel_data_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestItem {
  final int id;
  final String name;
  final String category;
  final double amount;

  const TestItem({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
  });
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PangeaTablePreferencesController.instance.resetToDefaults();
  });

  final testItems = List.generate(
    60,
    (i) => TestItem(
      id: i + 1,
      name: 'Product Item #${i + 1}',
      category: i % 2 == 0 ? 'Wellness' : 'Supplements',
      amount: (i + 1) * 1500.0,
    ),
  );

  final testColumns = [
    ExcelColumnDef<TestItem>(
      key: 'id',
      label: 'ID',
      defaultWidth: 60,
      cellBuilder: (ctx, item, row, isDark, brand) => Text('#${item.id}'),
    ),
    ExcelColumnDef<TestItem>(
      key: 'name',
      label: 'PRODUCT NAME',
      group: 'Product Details',
      defaultWidth: 180,
      searchString: (item) => item.name,
      sortValue: (item) => item.name,
      cellBuilder: (ctx, item, row, isDark, brand) => Text(item.name),
    ),
    ExcelColumnDef<TestItem>(
      key: 'category',
      label: 'CATEGORY',
      group: 'Product Details',
      defaultWidth: 140,
      searchString: (item) => item.category,
      sortValue: (item) => item.category,
      cellBuilder: (ctx, item, row, isDark, brand) => Text(item.category),
    ),
    ExcelColumnDef<TestItem>(
      key: 'amount',
      label: 'AMOUNT',
      group: 'Commercials',
      defaultWidth: 120,
      align: TextAlign.right,
      searchString: (item) => item.amount.toString(),
      sortValue: (item) => item.amount,
      cellBuilder: (ctx, item, row, isDark, brand) => Text('₦${item.amount}'),
    ),
  ];

  Widget buildSubject({
    bool enablePagination = true,
    int? initialPageSize = 25,
    double width = 1400,
    double height = 700,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: PangeaExcelDataTable<TestItem>(
              items: testItems,
              columns: testColumns,
              enablePagination: enablePagination,
              initialPageSize: initialPageSize,
              brandPrimary: const Color(0xFF2563EB),
            ),
          ),
        ),
      ),
    );
  }

  group('PangeaExcelDataTable Built-in Pagination & Settings Modal Suite', () {
    testWidgets('1. Displays first page of items with top and bottom pagination controls and navigation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(initialPageSize: 25));
      await tester.pumpAndSettle();

      // Verify first page items are rendered
      expect(find.text('Product Item #1'), findsOneWidget);
      expect(find.text('Product Item #10'), findsOneWidget);
      expect(find.text('Product Item #26'), findsNothing); // Page 2 item

      // Verify pagination text on both top and bottom toolbars
      expect(find.text('Showing 1 to 25 of 60 rows'), findsNWidgets(2));
      expect(find.text('Page 1 of 3'), findsNWidgets(2));
      expect(find.text('Per page:'), findsNWidgets(2));

      // Verify top toolbar has the gear icon
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Navigate to Page 2 using the top toolbar 'Next page' button
      await tester.tap(find.byTooltip('Next page').first);
      await tester.pumpAndSettle();

      expect(find.text('Page 2 of 3'), findsNWidgets(2));
      expect(find.text('Showing 26 to 50 of 60 rows'), findsNWidgets(2));
      expect(find.text('Product Item #26'), findsOneWidget);
      expect(find.text('Product Item #1'), findsNothing);

      // Navigate to Last page using bottom toolbar 'Last page' button
      await tester.tap(find.byTooltip('Last page').last);
      await tester.pumpAndSettle();

      expect(find.text('Page 3 of 3'), findsNWidgets(2));
      expect(find.text('Showing 51 to 60 of 60 rows'), findsNWidgets(2));
      expect(find.text('Product Item #51'), findsOneWidget);

      // Navigate back to First page
      await tester.tap(find.byTooltip('First page').first);
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 3'), findsNWidgets(2));
      expect(find.text('Product Item #1'), findsOneWidget);
    });

    testWidgets('2. Page size dropdown updates rows per page dynamically', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(initialPageSize: 25));
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 3'), findsNWidgets(2));

      // Tap top page size dropdown
      final dropdownFinder = find.byType(DropdownButton<int>);
      expect(dropdownFinder, findsNWidgets(2));
      await tester.tap(dropdownFinder.first);
      await tester.pumpAndSettle();

      // Select '50'
      await tester.tap(find.text('50').last);
      await tester.pumpAndSettle();

      expect(find.text('Showing 1 to 50 of 60 rows'), findsNWidgets(2));
      expect(find.text('Page 1 of 2'), findsNWidgets(2));
      expect(find.text('Product Item #1'), findsOneWidget);
      expect(find.text('Product Item #51'), findsNothing);
    });

    testWidgets('3. Tapping Top Gear Settings button opens PangeaTableSettingsModal with Font Size slider and presets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify top gear settings button exists
      final topGearButton = find.byKey(const ValueKey('pangea_table_top_settings_gear_btn'));
      expect(topGearButton, findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Tap top gear settings button
      await tester.tap(topGearButton);
      await tester.pumpAndSettle();

      // Verify modal opened
      expect(find.byType(PangeaTableSettingsModal), findsOneWidget);
      expect(find.text('Table Display & Typography'), findsOneWidget);
      expect(find.text('Font Size & Scale'), findsOneWidget);
      expect(find.text('Table Header Style'), findsOneWidget);

      // Verify font size presets
      expect(find.text('Compact (10.5px)'), findsOneWidget);
      expect(find.text('Standard (12.0px)'), findsOneWidget);
      expect(find.text('Comfortable (13.5px)'), findsOneWidget);
      expect(find.text('Large (15.0px)'), findsOneWidget);

      // Tap 'Large (15.0px)' preset
      await tester.tap(find.text('Large (15.0px)'));
      await tester.pumpAndSettle();

      expect(PangeaTablePreferencesController.instance.fontSize, 15.0);

      // Tap 'Brand Accent' header style
      await tester.tap(find.text('Brand Accent'));
      await tester.pumpAndSettle();

      expect(PangeaTablePreferencesController.instance.headerStyle, TableHeaderStyle.brandTinted);

      // Tap 'Done'
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Modal closed
      expect(find.byType(PangeaTableSettingsModal), findsNothing);
    });

    testWidgets('4. Preferences controller resetToDefaults restores standard configuration', (tester) async {
      final controller = PangeaTablePreferencesController.instance;

      await controller.setFontSize(16.0);
      await controller.setHeaderStyle(TableHeaderStyle.darkContrast);
      await controller.setDensity(TableDensity.spacious);
      await controller.setVerticalGridlines(false);
      await controller.setZebraStriping(false);

      expect(controller.fontSize, 16.0);
      expect(controller.headerStyle, TableHeaderStyle.darkContrast);
      expect(controller.showVerticalGridlines, isFalse);
      expect(controller.showZebraStriping, isFalse);

      await controller.resetToDefaults();

      expect(controller.fontSize, 12.0);
      expect(controller.headerStyle, TableHeaderStyle.classic);
      expect(controller.density, TableDensity.standard);
      expect(controller.showVerticalGridlines, isTrue);
      expect(controller.showZebraStriping, isTrue);
    });
  });
}
