import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/presentation/providers/auth_provider.dart';
import 'package:novexps/features/dc_console/presentation/providers/dc_console_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DC Hub Client Onboarding & Authentication Verification Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Live Email Validation detects existing accounts & permits unique emails', () async {
      final dcNotifier = container.read(dcConsoleProvider.notifier);

      // Existing client account email must return true
      final existsClient = await dcNotifier.checkClientEmailExists('client.novacale@novaexpress.ng');
      expect(existsClient, isTrue, reason: 'Seed client account should be recognized as existing');

      // Existing rider account email must return true
      final existsRider = await dcNotifier.checkClientEmailExists('emeka.rider@novaexpress.ng');
      expect(existsRider, isTrue, reason: 'Rider account email should not be re-usable by clients');

      // Existing DC supervisor account email must return true
      final existsDcSupervisor = await dcNotifier.checkClientEmailExists('dc.supervisor@novaexpress.ng');
      expect(existsDcSupervisor, isTrue, reason: 'DC supervisor email should not be re-usable by clients');

      // Brand new unique email must return false
      final existsNew = await dcNotifier.checkClientEmailExists('brand.new.merchant.2026@novaexpress.ng');
      expect(existsNew, isFalse, reason: 'Unique unused email should be available for onboarding');
    });

    test('2. Attempting to onboard client with duplicate email throws clear exception', () async {
      final dcNotifier = container.read(dcConsoleProvider.notifier);

      expect(
        () async => await dcNotifier.createClient(
          companyName: 'Duplicate Attempt Brand',
          contactPerson: 'Kalu Okonkwo',
          email: 'client.novacale@novaexpress.ng', // Existing email
          phone: '08099887766',
          address: 'Plot 55 Garki 2, Abuja',
          city: 'Abuja',
          stateName: 'Federal Capital Territory',
          tier: 'enterprise',
          closerLimit: 250,
          password: 'TestPassword123!',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('already exists') &&
            e.toString().contains('client.novacale@novaexpress.ng'))),
      );
    });

    test('3. DC Hub successfully onboards client with credentials & registers authenticated account', () async {
      final dcNotifier = container.read(dcConsoleProvider.notifier);

      const clientEmail = 'admin@pharmaplus-direct.ng';
      const clientPassword = 'PharmaPass2026!';
      const companyName = 'PharmaPlus Direct Laboratories';
      const contactPerson = 'Dr. Ibrahim Yusuf';
      const phone = '08031234567';

      // 1. DC Hub creates the client account
      final newClient = await dcNotifier.createClient(
        companyName: companyName,
        contactPerson: contactPerson,
        email: clientEmail,
        phone: phone,
        address: 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
        city: 'Wuse 2',
        stateName: 'FCT - Abuja',
        tier: 'enterprise',
        closerLimit: 150,
        password: clientPassword,
        bankName: 'Access Bank',
        bankAccountNumber: '0123456789',
        bankAccountName: 'PharmaPlus Direct Ltd',
      );

      // Verify ClientProfile details
      expect(newClient.companyName, equals(companyName));
      expect(newClient.email, equals(clientEmail));
      expect(newClient.contactPerson, equals(contactPerson));
      expect(newClient.phone, equals(phone));
      expect(newClient.tier, equals('enterprise'));
      expect(newClient.closerLimit, equals(150));
      expect(newClient.isEnterprise, isTrue);
      expect(newClient.code, startsWith('CLI-'));

      // Verify client is present in DCConsole state
      final dcState = container.read(dcConsoleProvider);
      expect(dcState.clients.any((c) => c.email == clientEmail), isTrue);

      // 2. Authenticate directly via AuthNotifier using the newly provisioned credentials
      final authNotifier = container.read(authProvider.notifier);
      final loginSuccess = await authNotifier.login(clientEmail, clientPassword);

      expect(loginSuccess, isTrue, reason: 'Client should authenticate successfully with provisioned credentials');

      final authUser = container.read(authProvider).user;
      expect(authUser, isNotNull);
      expect(authUser!.email, equals(clientEmail));
      expect(authUser.role, equals('client'));
      expect(authUser.isClientAdmin, isTrue, reason: 'User must have isClientAdmin = true for merchant portal access');
      expect(authUser.isClient, isTrue);
      expect(authUser.clientCompanyName, equals(companyName));
      expect(authUser.clientId, equals(newClient.id));
      expect(authUser.roleDescription, equals('E-Commerce Merchant Admin'));
    });

    test('4. Onboarded client authentication rejects invalid passwords', () async {
      final authNotifier = container.read(authProvider.notifier);

      const clientEmail = 'admin@pharmaplus-direct.ng';
      final badLogin = await authNotifier.login(clientEmail, 'WrongPassword123!');
      expect(badLogin, isFalse, reason: 'Incorrect password must fail authentication');

      final authState = container.read(authProvider);
      expect(authState.errorMessage, isNotNull);
      expect(authState.errorMessage!.toLowerCase(), contains('invalid email or password'));
    });
  });
}
