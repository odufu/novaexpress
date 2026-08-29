@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:novexps/core/constants/supabase_constants.dart';

void main() {
  test('Seed remote Supabase database with master operational datasets', () async {
    final client = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    print('🚀 Starting live database seeding on ${SupabaseConstants.supabaseUrl} ...');

    // 1. Companies
    try {
      await client.from('companies').upsert({
        'id': '11111111-1111-4111-8111-111111111111',
        'name': 'NovaExpress Logistics Limited',
        'code': 'NOVEXPS',
        'email': 'operations@novaexpress.ng',
        'phone': '+2348000000000',
        'address': 'Plot 102 Central Business District, Abuja, Nigeria',
        'currency': 'NGN',
      });
      print('✅ Company seeded');
    } catch (e) {
      print('ℹ️ Company notice: $e');
    }

    // 2. Distribution Centers
    try {
      await client.from('distribution_centers').upsert([
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'name': 'Wuse Distribution Center',
          'code': 'DC-WUSE-01',
          'state': 'Abuja (FCT)',
          'city': 'Wuse 2',
          'address': 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
          'is_hub': true,
        },
        {
          'id': '22222222-2222-4222-8222-333333333333',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'name': 'Ikeja Central Distribution Center',
          'code': 'DC-IKEJA-01',
          'state': 'Lagos',
          'city': 'Ikeja',
          'address': 'Plot 14 Commercial Avenue, Ikeja GRA, Lagos',
          'is_hub': true,
        }
      ]);
      print('✅ Distribution Centers seeded');
    } catch (e) {
      print('ℹ️ Distribution Centers notice: $e');
    }

    // 3. Users & Delivery Agents (Emeka Rider - Freelance PDA, and Babatunde Lawal - InHouse)
    try {
      await client.from('users').upsert([
        {
          'id': 'a1111111-1111-4111-8111-111111111111',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'email': 'emeka.rider@novaexpress.ng',
          'phone_number': '08031234567',
          'first_name': 'Emeka',
          'last_name': 'Rider',
          'role': 'delivery_agent',
        },
        {
          'id': 'a3333333-3333-4333-8333-333333333333',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'email': 'babatunde.lawal@novaexpress.ng',
          'phone_number': '08022223344',
          'first_name': 'Babatunde',
          'last_name': 'Lawal',
          'role': 'delivery_agent',
        },
        {
          'id': 'a2222222-2222-4222-8222-222222222222',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'email': 'dc.supervisor@novaexpress.ng',
          'phone_number': '08091112233',
          'first_name': 'Adekunle',
          'last_name': 'Supervisor',
          'role': 'dc_manager',
        }
      ]);
      print('✅ Users seeded');

      final agentPayload = {
        'id': 'b1111111-1111-4111-8111-111111111111',
        'user_id': 'a1111111-1111-4111-8111-111111111111',
        'distribution_center_id': '22222222-2222-4222-8222-222222222222',
        'agent_code': 'PDA-7000',
        'vehicle_type': 'Motorcycle',
        'vehicle_plate_number': 'ABJ-894-XA',
        'operating_state': 'Abuja (FCT)',
        'operating_city': 'Wuse 2',
        'current_status': 'available',
        'current_cod_balance': 55000.0,
        'direct_transfer_balance': 24500.0,
        'bank_name': 'Kuda Microfinance Bank',
        'bank_account_number': '2019847291',
        'bank_account_name': 'Emeka Rider',
        'personnel_type': 'pda',
        'commission_rate': 1000.0,
        'transport_allowance': 1500.0,
        'fuel_allowance': 800.0,
        'base_salary': 150000.0,
        'lifetime_deliveries_count': 4892,
        'rating': 4.9,
      };

      try {
        await client.from('delivery_agents').upsert(agentPayload);
        print('✅ Primary Delivery Agent (PDA-7000) seeded successfully');
      } catch (_) {
        // Fallback for minimal column set
        await client.from('delivery_agents').upsert({
          'id': 'b1111111-1111-4111-8111-111111111111',
          'user_id': 'a1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'agent_code': 'PDA-7000',
        });
        print('✅ Primary Delivery Agent (PDA-7000) seeded with base columns');
      }
    } catch (e) {
      print('ℹ️ Users/Agents notice: $e');
    }

    // 4. Products Master Catalog
    try {
      await client.from('products').upsert([
        {
          'id': 'd1111111-1111-4111-8111-111111111111',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'sku': 'SKU-RSP01',
          'name': 'Respira Detox Tea',
          'category': 'Herbal Detox',
          'description': 'Organic herbal detox blend formulated for respiratory purification, revitalization and digestive health.',
          'base_price': 26000.0,
          'low_stock_threshold': 5,
        },
        {
          'id': 'd2222222-2222-4222-8222-222222222222',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'sku': 'SKU-GRZ02',
          'name': 'Grazer Herbal Tea',
          'category': 'Digestive Care',
          'description': 'Botanical colon cleanse herbal tea for gentle digestive support and natural detox.',
          'base_price': 15000.0,
          'low_stock_threshold': 5,
        },
        {
          'id': 'd3333333-3333-4333-8333-333333333333',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'sku': 'SKU-ALM03',
          'name': 'Alpha Man Vitality',
          'category': 'Mens Wellness',
          'description': 'Daily organic vitality supplement for mens physical endurance and wellness.',
          'base_price': 22000.0,
          'low_stock_threshold': 5,
        },
        {
          'id': 'd4444444-4444-4444-8444-444444444444',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'sku': 'SKU-IBP04',
          'name': 'Immunity Booster Pack',
          'category': 'Immunity & Wellness',
          'description': 'Organic wellness daily defense formula with citrus, ginger, turmeric and herbal antioxidants.',
          'base_price': 18500.0,
          'low_stock_threshold': 5,
        },
        {
          'id': 'd5555555-5555-4555-8555-555555555555',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'sku': 'SKU-SFM05',
          'name': 'SlimFit Herbal Metabolism Pack',
          'category': 'Weight Management',
          'description': 'Targeted green herbal thermogenic blend promoting natural calorie burning and energy support.',
          'base_price': 12500.0,
          'low_stock_threshold': 4,
        }
      ]);
      print('✅ Products catalog seeded');
    } catch (e) {
      print('ℹ️ Products notice: $e');
    }

    // 5. Orders (Diverse Operational States)
    try {
      await client.from('orders').upsert([
        {
          'id': '20202020-2020-4020-8020-202020202020',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'order_number': 'TRK-8924',
          'product_id': 'd1111111-1111-4111-8111-111111111111',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'customer_name': 'Chief Aliyu Mohammed',
          'customer_phone': '08031234567',
          'customer_alt_phone': '08099887766',
          'delivery_state': 'Abuja (FCT)',
          'delivery_city': 'Wuse 2',
          'delivery_address': 'Plot 402 Aminu Kano Crescent, Near KFC, Wuse 2, Abuja',
          'quantity': 3,
          'base_price': 45000.0,
          'upsell_amount': 10000.0,
          'total_amount': 55000.0,
          'payment_type': 'pay_on_delivery',
          'payment_status': 'pending',
          'status': 'in_transit',
          'delivery_notes': 'Call 10 minutes before arrival. Gate code #402.',
        },
        {
          'id': '20202020-2020-4020-8020-303030303030',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'order_number': 'TRK-8925',
          'product_id': 'd2222222-2222-4222-8222-222222222222',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'customer_name': 'Dr. Aisha Garba',
          'customer_phone': '08129990011',
          'delivery_state': 'Abuja (FCT)',
          'delivery_city': 'Maitama',
          'delivery_address': '12 Aguiyi Ironsi Street, Maitama, Abuja',
          'quantity': 2,
          'base_price': 30000.0,
          'upsell_amount': 5000.0,
          'total_amount': 35000.0,
          'payment_type': 'pay_on_delivery',
          'payment_status': 'pending',
          'status': 'accepted',
          'delivery_notes': 'Intake completed at Wuse DC. Vehicle loaded.',
        },
        {
          'id': '20202020-2020-4020-8020-404040404040',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'order_number': 'TRK-8921',
          'product_id': 'd1111111-1111-4111-8111-111111111111',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'customer_name': 'Engr. Nnamdi Eze',
          'customer_phone': '07065554433',
          'delivery_state': 'Abuja (FCT)',
          'delivery_city': 'Garki II',
          'delivery_address': 'Suite B12, Gimbiya Street, Garki II, Abuja',
          'quantity': 4,
          'base_price': 60000.0,
          'upsell_amount': 15000.0,
          'total_amount': 75000.0,
          'payment_type': 'pay_on_delivery',
          'payment_status': 'pending',
          'status': 'delivered',
          'delivery_notes': 'Delivered successfully. POD cash collected in full.',
        },
        {
          'id': '20202020-2020-4020-8020-505050505050',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'order_number': 'TRK-8920',
          'product_id': 'd4444444-4444-4444-8444-444444444444',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'customer_name': 'Mrs. Folake Adebayo',
          'customer_phone': '08051112233',
          'delivery_state': 'Abuja (FCT)',
          'delivery_city': 'Asokoro',
          'delivery_address': '8 Yakubu Gowon Crescent, Asokoro, Abuja',
          'quantity': 1,
          'base_price': 18000.0,
          'upsell_amount': 0.0,
          'total_amount': 18000.0,
          'payment_type': 'pay_on_delivery',
          'payment_status': 'pending',
          'status': 'call_back',
          'delivery_notes': 'Customer requested callback at 4:30 PM after office meeting.',
        },
        {
          'id': '20202020-2020-4020-8020-606060606060',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'order_number': 'TRK-8919',
          'product_id': 'd3333333-3333-4333-8333-333333333333',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'customer_name': 'Mallam Ibrahim Usman',
          'customer_phone': '08023334455',
          'delivery_state': 'Abuja (FCT)',
          'delivery_city': 'Utako',
          'delivery_address': 'Block 5 Plot 18, Obafemi Awolowo Way, Utako, Abuja',
          'quantity': 2,
          'base_price': 32000.0,
          'upsell_amount': 0.0,
          'total_amount': 32000.0,
          'payment_type': 'prepaid',
          'payment_status': 'pending',
          'status': 'delivered',
          'delivery_notes': 'Prepaid order delivered to receptionist Mary.',
        }
      ]);
      print('✅ Orders seeded successfully!');
    } catch (e) {
      print('ℹ️ Orders notice: $e');
    }

    // 6. Cash Remittances
    try {
      await client.from('cash_remittances').upsert([
        {
          'id': '40404040-4040-4040-8040-505050505050',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'amount': 25000.0,
          'deposit_receipt_url': 'https://novexps.storage/receipts/rec-0005.jpg',
          'status': 'pending',
          'notes': 'Bank transfer awaiting DC Finance receipt confirmation.',
        },
        {
          'id': '40404040-4040-4040-8040-404040404040',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'amount': 15000.0,
          'deposit_receipt_url': 'https://novexps.storage/receipts/rec-0004.jpg',
          'status': 'verified',
          'notes': 'Bank transfer verified & reconciled by Wuse DC Finance desk.',
        }
      ]);
      print('✅ Cash remittances seeded');
    } catch (e) {
      print('ℹ️ Cash Remittances notice: $e');
    }

    // 7. Notifications
    try {
      await client.from('notifications').upsert([
        {
          'id': '50505050-5050-4050-8050-101010101010',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'title': 'New Delivery Assigned 📦',
          'message': 'Order TRK-8925 (Dr. Aisha Garba) in Maitama has been assigned to your queue.',
          'category': 'delivery',
          'is_read': false,
          'action_route': '/orders',
        },
        {
          'id': '50505050-5050-4050-8050-202020202020',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'title': 'Remittance Approved ✓',
          'message': 'Your cash remittance of ₦15,000 (RMT-0004) has been verified and reconciled by Wuse DC Finance desk.',
          'category': 'finance',
          'is_read': false,
          'action_route': '/cash/history',
        },
        {
          'id': '50505050-5050-4050-8050-303030303030',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'title': 'Stock Replenishment Ready 🏷️',
          'message': 'Transfer request REQ-00482 (20x Respira, 15x Grazer) is packaged and ready for pickup at Wuse DC counter.',
          'category': 'stock',
          'is_read': false,
          'action_route': '/orders/scan',
        },
        {
          'id': '50505050-5050-4050-8050-404040404040',
          'company_id': '11111111-1111-4111-8111-111111111111',
          'title': 'Security & Field Alert ⚠️',
          'message': 'Severe rain advisory in Lekki/Ajah expressway. Maintain speed safety and verify waterproof package seals.',
          'category': 'system',
          'is_read': true,
        }
      ]);
      print('✅ Notifications seeded');
    } catch (e) {
      print('ℹ️ Notifications notice: $e');
    }

    // 8. Vehicle Stock Custody (Products currently in rider's van/bike)
    try {
      await client.from('product_stock_custody').upsert([
        {
          'id': '60606060-6060-4060-8060-101010101010',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'product_id': 'd1111111-1111-4111-8111-111111111111',
          'quantity': 18,
          'allocated_quantity': 5,
          'available_quantity': 13,
        },
        {
          'id': '60606060-6060-4060-8060-202020202020',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'product_id': 'd2222222-2222-4222-8222-222222222222',
          'quantity': 12,
          'allocated_quantity': 3,
          'available_quantity': 9,
        },
        {
          'id': '60606060-6060-4060-8060-303030303030',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'product_id': 'd3333333-3333-4333-8333-333333333333',
          'quantity': 8,
          'allocated_quantity': 2,
          'available_quantity': 6,
        },
        {
          'id': '60606060-6060-4060-8060-404040404040',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'product_id': 'd4444444-4444-4444-8444-444444444444',
          'quantity': 15,
          'allocated_quantity': 1,
          'available_quantity': 14,
        }
      ]);
      print('✅ Product stock custody seeded');
    } catch (e) {
      print('ℹ️ Product stock custody notice: $e');
    }

    // 9. Stock Transfer Requests
    try {
      await client.from('stock_transfer_requests').upsert([
        {
          'id': '70707070-7070-4070-8070-101010101010',
          'request_number': 'REQ-00482',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'product_id': 'd1111111-1111-4111-8111-111111111111',
          'quantity': 20,
          'status': 'ready_for_pickup',
          'notes': 'Packaged and ready for pickup at Wuse DC counter.',
        },
        {
          'id': '70707070-7070-4070-8070-202020202020',
          'request_number': 'REQ-00483',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'distribution_center_id': '22222222-2222-4222-8222-222222222222',
          'product_id': 'd3333333-3333-4333-8333-333333333333',
          'quantity': 10,
          'status': 'pending',
          'notes': 'Requested by rider for weekend restocking.',
        }
      ]);
      print('✅ Stock transfer requests seeded');
    } catch (e) {
      print('ℹ️ Stock transfer requests notice: $e');
    }

    // 10. Rider Transactions (Direct transfer payouts & commission earnings)
    try {
      await client.from('rider_transactions').upsert([
        {
          'id': '80808080-8080-4080-8080-101010101010',
          'delivery_agent_id': 'b1111111-1111-4111-8111-111111111111',
          'transaction_code': 'TXN-98402',
          'title': 'Direct Transfer Delivery Credited',
          'category': 'direct_transfer',
          'amount': 24500.0,
          'is_credit': true,
          'reference': 'PAY-2026-0091',
          'status': 'settled',
          'description': 'Direct transfer settlement for non-cash commissions & allowances.',
        }
      ]);
      print('✅ Rider transactions seeded');
    } catch (e) {
      print('ℹ️ Rider transactions notice: $e');
    }

    print('🎉 Master Database Seeding Test Completed!');
  }, skip: 'Live seeding disabled - Production data created from DC Console');
}
