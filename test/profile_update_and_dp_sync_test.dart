import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/features/auth/domain/entities/user.dart';
import 'package:novexps/features/client_portal/domain/entities/client_closer.dart';
import 'package:novexps/features/client_portal/domain/entities/client_profile.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';

void main() {
  group('Profile Update and DP Cross-Platform Synchronization Tests', () {
    test('ClientPortalNotifier.syncUserProfile updates closer and merchant profile in state immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Setup initial state with a closer
      final initialCloser = ClientCloser(
        id: 'closer-uuid-1',
        clientId: 'client-uuid-1',
        userId: 'user-uuid-1',
        closerCode: 'CLS-NOVA-001',
        fullName: 'Amaka Chioma',
        email: 'closer@novacare.com',
        phone: '08012345678',
        avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
      );

      final notifier = container.read(clientPortalProvider.notifier);
      notifier.state = notifier.state.copyWith(
        closers: [initialCloser],
        clientProfile: const ClientProfile(
          id: 'client-uuid-1',
          companyName: 'Novacare Health & Wellness Ltd',
          contactPerson: 'Amaka Chioma',
          email: 'closer@novacare.com',
          phone: '08012345678',
          address: 'Abuja, Nigeria',
          code: 'NOVA-001',
        ),
      );

      expect(container.read(clientPortalProvider).closers.first.avatarUrl, contains('unsplash.com'));

      // 2. Perform sync with new DP and updated details
      const newAvatarUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co/storage/v1/object/public/avatars/avatar_44444444_test.jpg';
      notifier.syncUserProfile(
        fullName: 'Amaka Chioma Updated',
        avatarUrl: newAvatarUrl,
        phone: '08099998888',
        bankName: 'Zenith Bank',
        accountNumber: '2081234567',
        accountName: 'Amaka Chioma',
        email: 'closer@novacare.com',
        closerId: 'closer-uuid-1',
      );

      final updatedState = container.read(clientPortalProvider);
      final updatedCloser = updatedState.closers.first;

      // Assert closer in list is immediately updated
      expect(updatedCloser.fullName, equals('Amaka Chioma Updated'));
      expect(updatedCloser.avatarUrl, equals(newAvatarUrl));
      expect(updatedCloser.phone, equals('08099998888'));

      // Assert merchant profile is updated
      expect(updatedState.clientProfile.contactPerson, equals('Amaka Chioma Updated'));
      expect(updatedState.clientProfile.phone, equals('08099998888'));
      expect(updatedState.clientProfile.bankName, equals('Zenith Bank'));
      expect(updatedState.clientProfile.accountNumber, equals('2081234567'));
      expect(updatedState.clientProfile.accountName, equals('Amaka Chioma'));
    });

    test('ClientCloser.copyWith cleanly updates or clears avatarUrl', () {
      final closer = ClientCloser(
        id: 'c1',
        clientId: 'cl1',
        closerCode: 'CLS-001',
        fullName: 'Test Closer',
        email: 'test@example.com',
        phone: '08012345678',
        avatarUrl: 'https://old-avatar.png',
      );

      // Updating with new URL
      final updated = closer.copyWith(avatarUrl: 'https://new-avatar.png');
      expect(updated.avatarUrl, equals('https://new-avatar.png'));

      // Clearing with empty string
      final cleared = updated.copyWith(avatarUrl: '');
      expect(cleared.avatarUrl, isNull);

      // Omitting leaves existing
      final unchanged = updated.copyWith();
      expect(unchanged.avatarUrl, equals('https://new-avatar.png'));
    });

    test('Effective avatar URL prioritizes authenticated user entity over stale closer entity', () {
      final userWithAvatar = UserEntity(
        id: 'u1',
        email: 'closer@novacare.com',
        firstName: 'Amaka',
        lastName: 'Chioma',
        phone: '08012345678',
        role: 'closer',
        avatarUrl: 'https://supabase.co/new_dp.png',
      );

      final closerWithStaleAvatar = ClientCloser(
        id: 'c1',
        clientId: 'cl1',
        closerCode: 'CLS-001',
        fullName: 'Amaka Chioma',
        email: 'closer@novacare.com',
        phone: '08012345678',
        avatarUrl: 'https://unsplash.com/old_stale_dp.jpg',
      );

      // Simulation of effective avatar calculation
      String? resolveEffectiveAvatar(UserEntity? user, ClientCloser closer) {
        return user != null
            ? ((user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty) ? user.avatarUrl!.trim() : null)
            : (closer.avatarUrl?.trim().isNotEmpty == true ? closer.avatarUrl : null);
      }

      // 1. User has new DP: Must return user's new DP
      expect(resolveEffectiveAvatar(userWithAvatar, closerWithStaleAvatar), equals('https://supabase.co/new_dp.png'));

      // 2. User removed DP (null or empty string): Must return null (initials fallback), NOT stale closer avatar
      final userNullAvatar = UserEntity(
        id: 'u1',
        email: 'closer@novacare.com',
        firstName: 'Amaka',
        lastName: 'Chioma',
        phone: '08012345678',
        role: 'closer',
        avatarUrl: null,
      );
      expect(resolveEffectiveAvatar(userNullAvatar, closerWithStaleAvatar), isNull);

      // 3. User not logged in (e.g. previewing): fallback to closer entity
      expect(resolveEffectiveAvatar(null, closerWithStaleAvatar), equals('https://unsplash.com/old_stale_dp.jpg'));
    });
  });
}
