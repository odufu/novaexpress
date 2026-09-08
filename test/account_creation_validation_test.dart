import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';
import 'package:novexps/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

void main() {
  group('Account Creation Validation & Duplicate Email Handling Tests', () {
    late SupabaseClient dbClient;
    late AuthRemoteDataSourceImpl authDataSource;

    setUp(() {
      dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );
      authDataSource = AuthRemoteDataSourceImpl(dbClient);
    });

    test('Creating DC Supervisor with existing email throws clear duplicate exception', () async {
      final notifier = DCConsoleNotifier();

      expect(
        () async => await notifier.createDistributionCenter(
          name: 'Test Duplicate Hub',
          code: 'DC-TEST-DUP-01',
          stateName: 'Federal Capital Territory',
          city: 'Abuja Municipal (AMAC)',
          address: 'Plot 100 Test St',
          supervisorEmail: 'dc.supervisor@novaexpress.ng', // Existing supervisor email
          supervisorPassword: 'Password123!',
          authDataSource: authDataSource,
        ),
        throwsA(predicate((e) =>
            e.toString().contains('already exists') &&
            e.toString().contains('dc.supervisor@novaexpress.ng'))),
      );
    });

    test('Registering Rider with existing email throws clear duplicate exception', () async {
      expect(
        () async => await authDataSource.registerDeliveryAgent(
          email: 'emeka.rider@novaexpress.ng', // Existing rider email
          password: 'Password123!',
          firstName: 'Duplicate',
          lastName: 'Emeka',
          phone: '08000000000',
          personnelType: 'pda',
          compensationType: 'commission',
          commissionRate: 1000.0,
          transportAllowance: 1500.0,
          fuelAllowance: 0.0,
          baseSalary: 0.0,
          vehicleType: 'Motorcycle',
          vehiclePlateNumber: 'TEST-123',
          bankName: 'Access Bank',
          bankAccountNumber: '1234567890',
          bankAccountName: 'Test Duplicate',
          distributionCenterId: '22222222-2222-4222-8222-222222222222',
          assignedZone: 'Abuja Municipal (AMAC)',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('already exists') &&
            e.toString().contains('emeka.rider@novaexpress.ng'))),
      );
    });

    test('Creating Client with existing email throws clear duplicate exception', () async {
      final notifier = DCConsoleNotifier();

      expect(
        () async => await notifier.createClient(
          companyName: 'Test Novacare Duplicate',
          contactPerson: 'Dr. Test',
          email: 'client.novacale@novaexpress.ng', // Existing client email
          phone: '08000000000',
          address: 'Plot 12 Test Avenue',
          city: 'Abuja',
          stateName: 'Federal Capital Territory',
          tier: 'enterprise',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('already exists') &&
            e.toString().contains('client.novacale@novaexpress.ng'))),
      );
    });

    test('Verify Database remains pristine without test corruption', () async {
      final orders = await dbClient.from('orders').select('id');
      expect(orders.length, 0);

      final remittances = await dbClient.from('cash_remittances').select('id');
      expect(remittances.length, 0);

      final products = await dbClient.from('products').select('id');
      expect(products, isA<List>());

      final dcs = await dbClient.from('distribution_centers').select('id, code');
      expect(dcs.isNotEmpty, isTrue);
      expect(dcs.any((d) => d['code'] == 'DC-WUSE-01'), isTrue);
    });
  });
}
