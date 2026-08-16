class SupabaseConstants {
  static const String supabaseUrl = 'https://oygtaeriljuelhshfvkv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3MDAsImV4cCI6MjA5OTQ0NDcwMH0.o32kkHf1QSUs2xy4_5RrTFGw7_T-3iI8YGDml72oGxc';
  static const String supabaseServiceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mzg2ODcwMCwiZXhwIjoyMDk5NDQ0NzAwfQ.2kSLYbRoGqntCvZzpxknqh7gbk2FYICcjWq5vrXRkHM';

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
}
