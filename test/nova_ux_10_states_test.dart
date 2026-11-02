import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/core/widgets/ux_states/ux_states.dart';

void main() {
  group('State 1: NovaEmptyState', () {
    testWidgets('renders generic empty state with action button', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No Items Found',
              message: 'Get started by creating your first record.',
              actionLabel: 'Create Item',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No Items Found'), findsOneWidget);
      expect(find.text('Get started by creating your first record.'), findsOneWidget);
      expect(find.text('Create Item'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

      await tester.tap(find.text('Create Item'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });

    testWidgets('renders domain-specific factories correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NovaEmptyState.orders(),
                  NovaEmptyState.routes(),
                  NovaEmptyState.remittances(),
                  NovaEmptyState.inventory(),
                  NovaEmptyState.staff(),
                  NovaEmptyState.notifications(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Orders Dispatched Yet'), findsOneWidget);
      expect(find.text('No Delivery Routes Active'), findsOneWidget);
      expect(find.text('Remittances Reconciled'), findsOneWidget);
      expect(find.text('Warehouse Stock Empty'), findsOneWidget);
      expect(find.text('No Staff Registered'), findsOneWidget);
      expect(find.text('All Caught Up'), findsOneWidget);
    });
  });

  group('State 2: NovaLoadingState & NovaLoadingSkeleton', () {
    testWidgets('renders loading state with progress and optional cancel', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaLoadingState(
              title: 'Dispatching Shipment',
              message: 'Connecting to courier gateway...',
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('Dispatching Shipment'), findsOneWidget);
      expect(find.text('Connecting to courier gateway...'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, isTrue);
    });

    testWidgets('renders loading skeletons without animation errors in test mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NovaLoadingSkeleton.cardList(cardCount: 2),
                  NovaLoadingSkeleton.table(rows: 2, columns: 3),
                  NovaLoadingSkeleton.dashboardKpis(kpiCount: 2),
                  NovaLoadingSkeleton.trackingTimeline(stepCount: 3),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(NovaLoadingSkeleton), findsNWidgets(4));
    });
  });

  group('State 3: NovaErrorState', () {
    testWidgets('renders plain English error and expands technical diagnostics', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaErrorState(
              title: 'Connection Timed Out',
              message: 'We could not reach the server to book your shipment.',
              technicalDetails: 'HTTP 504: Gateway Timeout at api.novaxpress.ng/dispatch',
              onRetry: () => retried = true,
              retryLabel: 'Retry Booking',
            ),
          ),
        ),
      );

      expect(find.text('Connection Timed Out'), findsOneWidget);
      expect(find.text('We could not reach the server to book your shipment.'), findsOneWidget);
      expect(find.text('Retry Booking'), findsOneWidget);
      expect(find.text('View Technical Details'), findsOneWidget);

      // Expand diagnostics
      await tester.tap(find.text('View Technical Details'));
      await tester.pumpAndSettle();

      expect(find.textContaining('HTTP 504: Gateway Timeout'), findsOneWidget);
      expect(find.text('Copy Error'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry Booking'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('renders domain error factories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NovaErrorState.shipmentFailed(),
                  NovaErrorState.remittanceFailed(),
                  NovaErrorState.serverError(errorMessage: 'DB Connection drop'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Shipment Creation Failed'), findsOneWidget);
      expect(find.text('Remittance Submission Failed'), findsOneWidget);
      expect(find.text('System Connection Issue'), findsOneWidget);
    });
  });

  group('State 4: NovaNoInternetState', () {
    testWidgets('renders offline banner, queue counter, and retry CTA', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaNoInternetState(
              pendingActionsCount: 4,
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('You Are Offline'), findsOneWidget);
      expect(find.textContaining('Your connection to the network was interrupted'), findsOneWidget);
      expect(find.textContaining('All current form drafts and customer data are preserved locally'), findsOneWidget);
      expect(find.text('4 Pending Offline Actions Queued'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);

      await tester.tap(find.text('Retry Connection'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('State 5: NovaSlowNetworkState', () {
    testWidgets('renders slow network screen with safety reassurance', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaSlowNetworkState(
              elapsedSeconds: 8,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('Slow Network Connection'), findsOneWidget);
      expect(find.textContaining('8 seconds'), findsOneWidget);
      expect(find.textContaining('Do not refresh or submit again'), findsOneWidget);
      expect(find.text('Cancel Request'), findsOneWidget);

      await tester.tap(find.text('Cancel Request'));
      await tester.pump();
      expect(cancelled, isTrue);
    });

    testWidgets('renders slow network banner inline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NovaSlowNetworkBanner(
              message: 'Connecting via weak 2G cellular network...',
            ),
          ),
        ),
      );

      expect(find.text('Connecting via weak 2G cellular network...'), findsOneWidget);
      expect(find.byIcon(Icons.network_check_rounded), findsOneWidget);
    });
  });

  group('State 6: NovaNoSearchResultsState', () {
    testWidgets('renders search query highlight and clear filters action', (tester) async {
      bool cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaNoSearchResultsState(
              searchQuery: 'ORD-998822',
              filterContext: 'Status: In Transit',
              suggestions: const ['Verify the tracking number', 'Search by customer phone'],
              onClearFilters: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('No Results Found'), findsOneWidget);
      expect(find.textContaining('ORD-998822'), findsOneWidget);
      expect(find.text('Filter: Status: In Transit'), findsOneWidget);
      expect(find.text('Verify the tracking number'), findsOneWidget);
      expect(find.text('Clear All Filters'), findsOneWidget);

      await tester.tap(find.text('Clear All Filters'));
      await tester.pump();
      expect(cleared, isTrue);
    });
  });

  group('State 7: NovaPermissionDeniedState', () {
    testWidgets('renders logistics permission explanation and action buttons', (tester) async {
      bool requested = false;
      bool settingsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaPermissionDeniedState.camera(
              onGrantPermission: () => requested = true,
              onOpenSettings: () => settingsOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('Camera Permission Required'), findsOneWidget);
      expect(find.textContaining('Scan waybill barcodes and photograph Proof of Delivery'), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
      expect(find.text('Open App Settings'), findsOneWidget);

      await tester.tap(find.text('Grant Permission'));
      await tester.pump();
      expect(requested, isTrue);

      await tester.tap(find.text('Open App Settings'));
      await tester.pump();
      expect(settingsOpened, isTrue);
    });

    testWidgets('renders location and storage permission variants', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NovaPermissionDeniedState.location(),
                  NovaPermissionDeniedState.storage(),
                  NovaPermissionDeniedState.notifications(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('GPS Location Access Required'), findsOneWidget);
      expect(find.text('Storage Access Required'), findsOneWidget);
      expect(find.text('Notification Access Recommended'), findsOneWidget);
    });
  });

  group('State 8: NovaSessionExpiredState', () {
    testWidgets('renders session expired screen with draft preservation notice', (tester) async {
      bool resumed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaSessionExpiredState(
              hasUnsavedDraft: true,
              unsavedDraftDescription: 'New Waybill to Ikeja (2 packages)',
              onSignInResume: () => resumed = true,
            ),
          ),
        ),
      );

      expect(find.text('Session Expired'), findsOneWidget);
      expect(find.textContaining('Your login credentials expired'), findsOneWidget);
      expect(find.textContaining('Unsaved Draft Preserved: New Waybill to Ikeja'), findsOneWidget);
      expect(find.text('Sign In & Resume'), findsOneWidget);

      await tester.tap(find.text('Sign In & Resume'));
      await tester.pump();
      expect(resumed, isTrue);
    });
  });

  group('State 9: NovaFormValidators & NovaFormErrorBanner', () {
    test('validates required fields', () {
      expect(NovaFormValidators.required()(''), 'This field is required');
      expect(NovaFormValidators.required()('   '), 'This field is required');
      expect(NovaFormValidators.required()('NovaXpress'), isNull);
    });

    test('validates Nigerian phone numbers', () {
      expect(NovaFormValidators.nigerianPhone()(''), 'Phone number is required');
      expect(NovaFormValidators.nigerianPhone()('12345'), 'Enter a valid Nigerian phone number (e.g. 08012345678)');
      expect(NovaFormValidators.nigerianPhone()('08012345678'), isNull);
      expect(NovaFormValidators.nigerianPhone()('07031234567'), isNull);
      expect(NovaFormValidators.nigerianPhone()('09098765432'), isNull);
      expect(NovaFormValidators.nigerianPhone()('+2348012345678'), isNull);
    });

    test('validates delivery addresses', () {
      expect(NovaFormValidators.deliveryAddress()(''), 'Delivery address is required');
      expect(NovaFormValidators.deliveryAddress()('Short'), 'Please provide a full delivery address (street, number, landmark)');
      expect(NovaFormValidators.deliveryAddress()('Plot 42 Aminu Kano Crescent, Wuse 2, Abuja'), isNull);
    });

    test('validates positive amounts', () {
      expect(NovaFormValidators.positiveAmount()(''), 'Amount is required');
      expect(NovaFormValidators.positiveAmount()('abc'), 'Enter a valid numeric amount');
      expect(NovaFormValidators.positiveAmount()('0'), 'Amount must be greater than zero');
      expect(NovaFormValidators.positiveAmount()('15000.50'), isNull);
      expect(NovaFormValidators.positiveAmount()('₦25,000'), isNull);
    });

    test('validates quantities', () {
      expect(NovaFormValidators.validQuantity()('0'), 'Quantity must be at least 1 item');
      expect(NovaFormValidators.validQuantity()('-5'), 'Quantity must be at least 1 item');
      expect(NovaFormValidators.validQuantity()('12'), isNull);
    });

    test('validates email addresses', () {
      expect(NovaFormValidators.email()('not-an-email'), 'Enter a valid email address');
      expect(NovaFormValidators.email()('accountant@novaxpress.ng'), isNull);
    });

    testWidgets('renders NovaFormErrorBanner with error list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NovaFormErrorBanner(
              errors: [
                'Customer phone number is invalid',
                'Delivery address must include landmark',
              ],
            ),
          ),
        ),
      );

      expect(find.text('Please correct the following errors:'), findsOneWidget);
      expect(find.text('• Customer phone number is invalid'), findsOneWidget);
      expect(find.text('• Delivery address must include landmark'), findsOneWidget);
    });
  });

  group('State 10: NovaSuccessState', () {
    testWidgets('renders success state with reference code, summary, and action CTAs', (tester) async {
      bool tracked = false;
      bool waybillPrinted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaSuccessState(
              title: 'Waybill Generated',
              message: 'Your shipment has been assigned to Abuja Central Hub.',
              referenceCode: 'NVX-ABJ-89412',
              referenceLabel: 'WAYBILL NUMBER',
              summaryItems: const [
                NovaSuccessSummaryItem(label: 'Destination', value: 'Wuse 2, Abuja'),
                NovaSuccessSummaryItem(label: 'Package Count', value: '3 Units'),
              ],
              primaryActionLabel: 'Track Shipment',
              onPrimaryAction: () => tracked = true,
              secondaryActionLabel: 'Print Waybill',
              onSecondaryAction: () => waybillPrinted = true,
            ),
          ),
        ),
      );

      expect(find.text('Waybill Generated'), findsOneWidget);
      expect(find.text('Your shipment has been assigned to Abuja Central Hub.'), findsOneWidget);
      expect(find.text('NVX-ABJ-89412'), findsOneWidget);
      expect(find.text('WAYBILL NUMBER'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Wuse 2, Abuja'), findsOneWidget);
      expect(find.text('Track Shipment'), findsOneWidget);
      expect(find.text('Print Waybill'), findsOneWidget);

      await tester.tap(find.text('Track Shipment'));
      await tester.pump();
      expect(tracked, isTrue);

      await tester.tap(find.text('Print Waybill'));
      await tester.pump();
      expect(waybillPrinted, isTrue);
    });

    testWidgets('renders domain success factories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NovaSuccessState.shipmentBooked(
                    waybillNumber: 'WAY-1234',
                    destination: 'Lagos Island',
                    totalAmount: 18500,
                  ),
                  NovaSuccessState.deliveryConfirmed(
                    orderNumber: 'ORD-5678',
                    recipientName: 'Aisha Bello',
                    remittanceAmount: 25000,
                  ),
                  NovaSuccessState.settlementApproved(
                    settlementNumber: 'STL-9901',
                    distributionCenter: 'Central Command DC',
                    clearedAmount: 1200000,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Shipment Successfully Booked!'), findsOneWidget);
      expect(find.text('WAY-1234'), findsOneWidget);
      expect(find.text('Delivery Proof Confirmed!'), findsOneWidget);
      expect(find.text('ORD-5678'), findsOneWidget);
      expect(find.text('Settlement Cleared!'), findsOneWidget);
      expect(find.text('STL-9901'), findsOneWidget);
    });
  });

  group('NovaStateWrapper Container', () {
    testWidgets('displays loading state when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NovaStateWrapper<List<String>>(
              isLoading: true,
              data: null,
              builder: _dummyBuilder,
            ),
          ),
        ),
      );

      expect(find.byType(NovaLoadingSkeleton), findsOneWidget);
    });

    testWidgets('displays error state when errorMessage is present and data is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaStateWrapper<List<String>>(
              isLoading: false,
              errorMessage: 'Failed to fetch shipments',
              data: const [],
              builder: _dummyBuilder,
            ),
          ),
        ),
      );

      expect(find.text('Operation Encountered an Issue'), findsOneWidget);
      expect(find.text('Failed to fetch shipments'), findsOneWidget);
    });

    testWidgets('displays offline state when isOffline is true and data is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaStateWrapper<List<String>>(
              isLoading: false,
              isOffline: true,
              data: const [],
              builder: _dummyBuilder,
            ),
          ),
        ),
      );

      expect(find.text('You Are Offline'), findsOneWidget);
    });

    testWidgets('displays no search results when searchQuery is active and list is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaStateWrapper<List<String>>(
              isLoading: false,
              searchQuery: 'Ikeja express',
              data: const [],
              builder: _dummyBuilder,
            ),
          ),
        ),
      );

      expect(find.text('No Results Found'), findsOneWidget);
      expect(find.textContaining('Ikeja express'), findsOneWidget);
    });

    testWidgets('displays empty state when data is empty and no search active', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaStateWrapper<List<String>>(
              isLoading: false,
              data: const [],
              emptyState: NovaEmptyState.orders(),
              builder: _dummyBuilder,
            ),
          ),
        ),
      );

      expect(find.text('No Orders Dispatched Yet'), findsOneWidget);
    });

    testWidgets('displays content when data is populated', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NovaStateWrapper<List<String>>(
              isLoading: false,
              data: ['Order #1', 'Order #2'],
              builder: _dummyBuilder,
            ),
          ),
        ),
      );

      expect(find.text('Items: 2'), findsOneWidget);
    });
  });
}

Widget _dummyBuilder(BuildContext context, List<String> items) {
  return Text('Items: ${items.length}');
}

