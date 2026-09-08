class SupabaseConstants {
  // =========================================================================
  // SUPABASE ENVIRONMENT CONFIGURATION
  // To switch projects, toggle comments between ENVIRONMENT 1 and ENVIRONMENT 2.
  // Full backup stored in: supabase_environments.md
  // =========================================================================

  // --- ENVIRONMENT 1: Original Production / Staging (oygtaeriljuelhshfvkv) ---
  // Status: Bandwidth quota reached (402). Reserved for when quota resets / plan upgraded.
  static const String originalUrl = 'https://oygtaeriljuelhshfvkv.supabase.co';
  static const String originalAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3MDAsImV4cCI6MjA5OTQ0NDcwMH0.o32kkHf1QSUs2xy4_5RrTFGw7_T-3iI8YGDml72oGxc';
  static const String originalServiceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM';

  // --- ENVIRONMENT 2: Fresh Testing Project (qpcafevjsrbauweuiiyq) ---
  static const String testingUrl = 'https://qpcafevjsrbauweuiiyq.supabase.co';
  static const String testingAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3ODYzNjQsImV4cCI6MjEwNDM2MjM2NH0.L07TBq9gfNjLPYnaAjA7F9IGXN1_UoyOcelgsofnXK8';
  static const String testingServiceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwY2FmZXZqc3JiYXV3ZXVpaXlxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODc4NjM2NCwiZXhwIjoyMTA0MzYyMzY0fQ.RM1BJWKYWnhI7kkDVACqAxDj8U9shpWxQX8h8_K7UiU';

  // --- ACTIVE CONNECTION ---
  // Currently set to: ENVIRONMENT 2 (Testing)
  static const String supabaseUrl = testingUrl;
  static const String supabaseAnonKey = testingAnonKey;
  static const String supabaseServiceRoleKey = testingServiceRoleKey;

  // Primary Agent ID
  static const String defaultDeliveryAgentId = 'b1111111-1111-4111-8111-111111111111';

  // Table names
  static const String usersTable = 'users';
  static const String deliveryAgentsTable = 'delivery_agents';
  static const String ordersTable = 'orders';
  static const String productsTable = 'products';
  static const String warehousesTable = 'warehouses';
  static const String cashRemittancesTable = 'cash_remittances';
  static const String stockTransfersTable = 'stock_transfers';
  static const String paystackTransactionsTable = 'paystack_transactions';
  static const String paystackVirtualAccountsTable = 'paystack_virtual_accounts';

  // Paystack Credentials
  static const String paystackSecretKey = 'sk_test_94f116e6e978f0e75dc42f8a789837931b487006';
  static const String paystackPublicKey = 'pk_test_0ac140673685b32b2e9613b548991cd9563e917a';
  static const String paystackWebhookUrl = 'https://vacyxnehxpqvwtaimkgc.supabase.co/functions/v1/paystack-webhook';

  // Storage Buckets
  static const String avatarsBucket = 'avatars';
  static const String productsBucket = 'products';
  static const String podSignaturesBucket = 'pod-proofs';
  static const String proofOfDeliveryBucket = 'pod-proofs';
  static const String remittanceReceiptsBucket = 'remittance-proofs';
  static const String receiptsBucket = 'receipts';
}
