import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/client_portal_repository_impl.dart';
import '../../domain/repositories/client_portal_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/services/order_routing_service.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/customer_lead.dart';

class ClientPortalState {
  final ClientProfile clientProfile;
  final List<OrderEntity> orders;
  final List<CatalogProduct> products;
  final List<ProductPackage> packages;
  final List<ClientCloser> closers;
  final List<CustomerLead> leads;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String selectedStatusFilter; // 'all', 'pending', 'in_transit', 'delivered', 'failed'
  final String? selectedStateFilter;
  final String selectedCloserFilter; // 'all' or closer ID
  final String selectedLeadStatusFilter; // 'all', 'new_lead', 'calling', 'call_back', 'confirmed', 'order_created'

  const ClientPortalState({
    required this.clientProfile,
    this.orders = const [],
    this.products = const [],
    this.packages = const [],
    this.closers = const [],
    this.leads = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedStatusFilter = 'all',
    this.selectedStateFilter,
    this.selectedCloserFilter = 'all',
    this.selectedLeadStatusFilter = 'all',
  });

  ClientPortalState copyWith({
    ClientProfile? clientProfile,
    List<OrderEntity>? orders,
    List<CatalogProduct>? products,
    List<ProductPackage>? packages,
    List<ClientCloser>? closers,
    List<CustomerLead>? leads,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? selectedStatusFilter,
    String? selectedStateFilter,
    String? selectedCloserFilter,
    String? selectedLeadStatusFilter,
  }) {
    return ClientPortalState(
      clientProfile: clientProfile ?? this.clientProfile,
      orders: orders ?? this.orders,
      products: products ?? this.products,
      packages: packages ?? this.packages,
      closers: closers ?? this.closers,
      leads: leads ?? this.leads,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      selectedStateFilter: selectedStateFilter ?? this.selectedStateFilter,
      selectedCloserFilter: selectedCloserFilter ?? this.selectedCloserFilter,
      selectedLeadStatusFilter: selectedLeadStatusFilter ?? this.selectedLeadStatusFilter,
    );
  }

  // Analytics KPIs
  int get totalOrdersCount => orders.length;

  int get pendingOrdersCount => orders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'pending_dispatch' ||
            s == 'created' ||
            s == 'pending_rider_assignment' ||
            s == 'pending_dc_assignment' ||
            s == 'assigned';
      }).length;

  int get inTransitOrdersCount => orders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted';
      }).length;

  int get deliveredOrdersCount => orders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'delivered' || s == 'completed';
      }).length;

  int get failedOrdersCount => orders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'failed' || s == 'cancelled' || s == 'rejected';
      }).length;

  double get deliverySuccessRate {
    final completed = deliveredOrdersCount + failedOrdersCount;
    if (completed == 0) return 100.0;
    return (deliveredOrdersCount / completed) * 100.0;
  }

  double get totalRevenue => orders
      .where((o) => o.isDelivered)
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  double get pendingCodRemittances => orders
      .where((o) => o.isDelivered && o.isPod)
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  // Closer & Telesales KPIs
  int get totalClosersCount => closers.length;
  int get activeClosersCount => closers.where((c) => c.isActive).length;
  int get totalLeadsCount => leads.length;
  int get newLeadsCount => leads.where((l) => l.isNew).length;
  int get callingLeadsCount => leads.where((l) => l.isCalling).length;
  int get callBackLeadsCount => leads.where((l) => l.isCallBack).length;
  int get confirmedLeadsCount => leads.where((l) => l.isConfirmed || l.isOrderCreated).length;
  int get orderCreatedLeadsCount => leads.where((l) => l.isOrderCreated).length;

  double get overallCloserConversionRate {
    if (totalLeadsCount == 0) return 0.0;
    return (confirmedLeadsCount / totalLeadsCount) * 100.0;
  }

  double get totalCloserRevenue => orders
      .where((o) => o.closerId != null && o.isDelivered)
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  List<ClientCloser> get topClosersLeaderboard {
    final sorted = List<ClientCloser>.from(closers);
    sorted.sort((a, b) => b.totalOrdersBooked.compareTo(a.totalOrdersBooked));
    return sorted;
  }

  List<OrderEntity> get filteredOrders {
    return orders.where((o) {
      final s = o.status.toLowerCase();
      if (selectedStatusFilter != 'all') {
        if (selectedStatusFilter == 'pending' &&
            s != 'pending_dispatch' &&
            s != 'created' &&
            s != 'assigned' &&
            s != 'pending_rider_assignment' &&
            s != 'pending_dc_assignment') {
          return false;
        }
        if (selectedStatusFilter == 'in_transit' &&
            s != 'in_transit' &&
            s != 'out_for_delivery' &&
            s != 'accepted') {
          return false;
        }
        if (selectedStatusFilter == 'delivered' &&
            s != 'delivered' &&
            s != 'completed') {
          return false;
        }
        if (selectedStatusFilter == 'failed' &&
            s != 'failed' &&
            s != 'cancelled' &&
            s != 'rejected') {
          return false;
        }
      }

      if (selectedStateFilter != null && selectedStateFilter!.isNotEmpty) {
        if (o.deliveryState.toLowerCase() != selectedStateFilter!.toLowerCase()) {
          return false;
        }
      }

      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesNum = o.orderNumber.toLowerCase().contains(q);
        final matchesCust = o.customerName.toLowerCase().contains(q);
        final matchesPhone = o.customerPhone.contains(q);
        final matchesAddr = o.deliveryAddress.toLowerCase().contains(q);
        final matchesCity = o.deliveryCity.toLowerCase().contains(q);
        final matchesState = o.deliveryState.toLowerCase().contains(q);
        final matchesLga = (o.deliveryLga ?? '').toLowerCase().contains(q);
        final matchesProd = o.productName.toLowerCase().contains(q);
        final matchesCloser = (o.closerName ?? '').toLowerCase().contains(q) || (o.closerCode ?? '').toLowerCase().contains(q);
        if (!matchesNum && !matchesCust && !matchesPhone && !matchesAddr && !matchesCity && !matchesState && !matchesLga && !matchesProd && !matchesCloser) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<CustomerLead> get filteredLeads {
    return leads.where((l) {
      if (selectedCloserFilter != 'all' && l.assignedCloserId != selectedCloserFilter) {
        return false;
      }
      if (selectedLeadStatusFilter != 'all' && l.status != selectedLeadStatusFilter) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesName = l.customerName.toLowerCase().contains(q);
        final matchesPhone = l.customerPhone.contains(q);
        final matchesAddr = l.customerAddress.toLowerCase().contains(q);
        final matchesProd = l.productInterest.toLowerCase().contains(q);
        final matchesCloser = (l.assignedCloserName ?? '').toLowerCase().contains(q);
        if (!matchesName && !matchesPhone && !matchesAddr && !matchesProd && !matchesCloser) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

class ClientPortalNotifier extends StateNotifier<ClientPortalState> {
  final Ref _ref;
  final ClientPortalRepository _repository;

  ClientPortalNotifier(this._ref, {ClientPortalRepository? repository})
      : _repository = repository ?? ClientPortalRepositoryImpl(),
        super(
          ClientPortalState(
            clientProfile: const ClientProfile(
              id: '33333333-3333-4333-8333-333333333333',
              companyName: 'Novacale Limited',
              contactPerson: 'Dr. Chuka Okafor',
              email: 'client.novacale@novaexpress.ng',
              phone: '08034455667',
              address: 'Plot 12, Commercial Avenue, Central Business District, Abuja',
              city: 'Abuja',
              state: 'Federal Capital Territory',
              code: 'CLI-NOVACALE-01',
              tier: 'enterprise',
              closerLimit: 250,
              isEnterprise: true,
            ),
          ),
        ) {
    loadClientData();
    _ref.listen<OrdersState>(ordersProvider, (previous, next) {
      if (next.orders.isEmpty) return;
      final companyName = state.clientProfile.companyName.toLowerCase();
      final clientId = state.clientProfile.id;
      final matchingOrders = next.orders.where((o) =>
          (o.clientName.toLowerCase().contains(companyName)) ||
          (o.clientId != null && o.clientId == clientId) ||
          o.productName.toLowerCase().contains('grazer')).toList();
      if (matchingOrders.isNotEmpty) {
        final merged = [...matchingOrders];
        for (final existing in state.orders) {
          if (!merged.any((m) => m.id == existing.id || m.orderNumber == existing.orderNumber)) {
            merged.add(existing);
          }
        }
        state = state.copyWith(orders: merged);
      }
    });
  }

  /// Syncs an order updated by DC console or rider dispatch back into client portal state
  void syncOrderUpdate(OrderEntity updatedOrder) {
    final updatedOrders = state.orders.map((o) {
      if (o.id == updatedOrder.id || o.orderNumber == updatedOrder.orderNumber) {
        return updatedOrder;
      }
      return o;
    }).toList();
    if (!updatedOrders.any((o) => o.id == updatedOrder.id || o.orderNumber == updatedOrder.orderNumber)) {
      updatedOrders.insert(0, updatedOrder);
    }
    state = state.copyWith(orders: updatedOrders);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(selectedStatusFilter: filter);
  }

  void setStateFilter(String? stateFilter) {
    state = state.copyWith(selectedStateFilter: stateFilter);
  }

  void setCloserFilter(String closerId) {
    state = state.copyWith(selectedCloserFilter: closerId);
  }

  void setLeadStatusFilter(String status) {
    state = state.copyWith(selectedLeadStatusFilter: status);
  }

  /// Initial load and sync of client data
  Future<void> loadClientData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = _ref.read(authProvider).user;
      final clientId = user?.clientId ?? '33333333-3333-4333-8333-333333333333';
      final companyName = user?.clientCompanyName ?? 'Novacale Limited';

      // 1. Fetch live products and packages from ProductCatalogProvider
      final catalogState = _ref.read(productCatalogProvider);
      final clientProducts = catalogState.products.where((p) =>
          p.clientName.toLowerCase() == companyName.toLowerCase() ||
          p.name.toLowerCase().contains('grazer')).toList();

      List<ProductPackage> allPackages = [];
      for (final p in (clientProducts.isNotEmpty ? clientProducts : catalogState.products)) {
        allPackages.addAll(catalogState.getPackagesForProduct(p.name));
      }

      // 2. Fetch all orders from OrdersProvider and filter for this client
      final ordersState = _ref.read(ordersProvider);
      List<OrderEntity> clientOrders = ordersState.orders.where((o) =>
          (o.clientName.toLowerCase().contains(companyName.toLowerCase())) ||
          (o.clientId != null && o.clientId == clientId) ||
          o.productName.toLowerCase().contains('grazer')).toList();

      // If no orders yet, seed a rich initial sample set for Novacale Limited
      if (clientOrders.isEmpty) {
        clientOrders = _generateSeedOrders(clientId, companyName);
      }

      // 3. Fetch Closers and Leads via Repository
      List<ClientCloser> clientClosers = [];
      List<CustomerLead> clientLeads = [];

      try {
        final closersRes = await _repository.getClosers(clientId);
        if (closersRes.isNotEmpty) {
          clientClosers = closersRes;
        }

        final leadsRes = await _repository.getLeads(clientId);
        if (leadsRes.isNotEmpty) {
          clientLeads = leadsRes;
        }
      } catch (dbErr) {
        debugPrint('[CLIENT_PORTAL] ℹ️ Closers/leads sync notice: $dbErr');
      }

      // Fallback seed data if offline or freshly initialised
      if (clientClosers.isEmpty) {
        clientClosers = _generateSeedClosers(clientId);
      }
      if (clientLeads.isEmpty) {
        clientLeads = _generateSeedLeads(clientId, clientClosers.first.id);
      }

      if (!mounted) return;
      state = state.copyWith(
        clientProfile: ClientProfile(
          id: clientId,
          companyName: companyName,
          contactPerson: user?.fullName.isNotEmpty == true ? user!.fullName : 'Dr. Chuka Okafor',
          email: user?.email.isNotEmpty == true ? user!.email : 'client.novacale@novaexpress.ng',
          phone: user?.phone.isNotEmpty == true ? user!.phone : '08034455667',
          address: 'Plot 12, Commercial Avenue, Central Business District, Abuja',
          city: 'Abuja',
          state: 'Federal Capital Territory',
          code: 'CLI-NOVACALE-01',
          tier: 'enterprise',
          closerLimit: 250,
          isEnterprise: true,
          totalClosersCount: clientClosers.length,
        ),
        products: clientProducts.isNotEmpty ? clientProducts : catalogState.products,
        packages: allPackages,
        orders: clientOrders,
        closers: clientClosers,
        leads: clientLeads,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ Error loading client data: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Onboard a new Closer for an Enterprise Client
  Future<ClientCloser> createCloser({
    required String fullName,
    required String email,
    required String phone,
    int dailyCallTarget = 50,
    double commissionRate = 500.0,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final suffix = (100 + state.closers.length + 1).toString().padLeft(3, '0');
      final closerCode = 'CLS-NOVA-$suffix';
      final fallbackId = '00000000-0000-4000-8000-${DateTime.now().millisecondsSinceEpoch.toString().padLeft(12, '0')}';

      ClientCloser newCloser;
      try {
        newCloser = await _repository.createCloser(
          clientId: state.clientProfile.id,
          fullName: fullName.trim(),
          email: email.trim(),
          phone: phone.trim(),
          dailyCallTarget: dailyCallTarget,
          commissionRate: commissionRate,
        );
      } catch (dbErr) {
        if (dbErr.toString().contains('already exists')) {
          rethrow;
        }
        debugPrint('[CLIENT_PORTAL] ℹ️ Remote createCloser notice: $dbErr. Utilizing resilient local fallback.');
        newCloser = ClientCloser(
          id: fallbackId,
          clientId: state.clientProfile.id,
          closerCode: closerCode,
          fullName: fullName.trim(),
          email: email.trim(),
          phone: phone.trim(),
          dailyCallTarget: dailyCallTarget,
          commissionRate: commissionRate,
          isActive: true,
          createdAt: DateTime.now(),
        );
      }

      final updatedClosers = [newCloser, ...state.closers];
      state = state.copyWith(closers: updatedClosers, isLoading: false);
      return newCloser;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Activate or Deactivate an Employee / Closer
  Future<void> toggleCloserStatus(String closerId, bool isActive) async {
    try {
      final updatedClosers = state.closers.map((c) {
        if (c.id == closerId) {
          return c.copyWith(isActive: isActive, updatedAt: DateTime.now());
        }
        return c;
      }).toList();

      state = state.copyWith(closers: updatedClosers);

      // Async update in Repository
      Future.microtask(() async {
        try {
          await _repository.toggleCloserStatus(closerId: closerId, isActive: isActive);
          debugPrint('[CLIENT_PORTAL] ✅ Closer $closerId status updated to isActive: $isActive');
        } catch (dbErr) {
          debugPrint('[CLIENT_PORTAL] ℹ️ Closer toggle notice: $dbErr');
        }
      });
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ Error toggling closer status: $e');
    }
  }

  /// Reset Password for an Employee / Closer
  Future<void> resetCloserPassword({
    required String closerId,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final closer = state.closers.firstWhere((c) => c.id == closerId);

      // Async update in Repository
      Future.microtask(() async {
        try {
          await _repository.resetCloserPassword(
            closerId: closerId,
            userId: closer.userId,
            newPassword: newPassword,
          );
          debugPrint('[CLIENT_PORTAL] ✅ Password reset for closer ${closer.closerCode} (${closer.email})');
        } catch (dbErr) {
          debugPrint('[CLIENT_PORTAL] ℹ️ Reset password notice: $dbErr');
        }
      });

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Update Closer / Employee Details (Name, Phone, Commission, Target)
  Future<ClientCloser> updateCloserDetails({
    required String closerId,
    String? fullName,
    String? phone,
    String? email,
    double? commissionRate,
    int? dailyCallTarget,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      ClientCloser? updatedCloser;
      final updatedClosers = state.closers.map((c) {
        if (c.id == closerId) {
          updatedCloser = c.copyWith(
            fullName: fullName ?? c.fullName,
            phone: phone ?? c.phone,
            email: email ?? c.email,
            commissionRate: commissionRate ?? c.commissionRate,
            dailyCallTarget: dailyCallTarget ?? c.dailyCallTarget,
            isActive: isActive ?? c.isActive,
            updatedAt: DateTime.now(),
          );
          return updatedCloser!;
        }
        return c;
      }).toList();

      if (updatedCloser == null) {
        throw Exception('Closer with ID $closerId not found');
      }

      state = state.copyWith(closers: updatedClosers, isLoading: false);

      // Async update in Repository
      Future.microtask(() async {
        try {
          await _repository.updateCloserDetails(
            closerId: closerId,
            fullName: fullName,
            phone: phone,
            email: email,
            commissionRate: commissionRate,
            dailyCallTarget: dailyCallTarget,
            isActive: isActive,
          );
          debugPrint('[CLIENT_PORTAL] ✅ Closer ${updatedCloser!.closerCode} updated successfully.');
        } catch (dbErr) {
          debugPrint('[CLIENT_PORTAL] ℹ️ Closer update notice: $dbErr');
        }
      });

      return updatedCloser!;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Create a Customer Lead for Telesales Closers to call
  Future<CustomerLead> createLead({
    required String customerName,
    required String customerPhone,
    String? customerAddress,
    String deliveryState = 'Federal Capital Territory',
    String deliveryLga = 'Abuja Municipal (AMAC)',
    String productInterest = 'Grazer Tea',
    String packageInterest = '2 Packs Promo Deal',
    String? assignedCloserId,
    String? callNotes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final leadId = _generateUuid();
      final assignedCloser = state.closers.firstWhere(
        (c) => c.id == assignedCloserId,
        orElse: () => state.closers.isNotEmpty ? state.closers.first : const ClientCloser(id: '', clientId: '', closerCode: '', fullName: '', email: '', phone: ''),
      );

      final newLead = CustomerLead(
        id: leadId,
        clientId: state.clientProfile.id,
        assignedCloserId: assignedCloser.id.isNotEmpty ? assignedCloser.id : null,
        assignedCloserName: assignedCloser.fullName.isNotEmpty ? assignedCloser.fullName : null,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        customerAddress: customerAddress?.trim() ?? '',
        deliveryState: deliveryState.trim(),
        deliveryLga: deliveryLga.trim(),
        productInterest: productInterest.trim(),
        packageInterest: packageInterest.trim(),
        status: 'new_lead',
        callNotes: callNotes?.trim(),
        createdAt: DateTime.now(),
      );

      // Push to Database via Repository
      Future.microtask(() async {
        try {
          await _repository.createLead(newLead);
          debugPrint('[CLIENT_PORTAL] ✅ Customer lead for ${newLead.customerName} pushed to repository.');
        } catch (dbErr) {
          debugPrint('[CLIENT_PORTAL] ℹ️ Lead insert notice: $dbErr');
        }
      });

      final updatedLeads = [newLead, ...state.leads];
      state = state.copyWith(leads: updatedLeads, isLoading: false);
      return newLead;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Update Call Status & Notes for a Lead
  Future<void> updateLeadStatus(String leadId, String newStatus, {String? notes}) async {
    try {
      final updatedLeads = state.leads.map((l) {
        if (l.id == leadId) {
          return l.copyWith(
            status: newStatus,
            callNotes: notes ?? l.callNotes,
            lastCalledAt: DateTime.now(),
          );
        }
        return l;
      }).toList();

      state = state.copyWith(leads: updatedLeads);

      // Async update via Repository
      Future.microtask(() async {
        try {
          await _repository.updateLeadStatus(
            leadId: leadId,
            newStatus: newStatus,
            notes: notes,
          );
        } catch (dbErr) {
          debugPrint('[CLIENT_PORTAL] ℹ️ Lead update notice: $dbErr');
        }
      });
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ Error updating lead status: $e');
    }
  }

  /// 1-Tap Convert Confirmed Lead to Automated Dispatched Order
  Future<OrderEntity> convertLeadToOrder({
    required CustomerLead lead,
    required String productId,
    required String productName,
    required String packageName,
    required int quantity,
    required double totalAmount,
    String paymentType = 'Pay on Delivery (Cash/POS)',
    String? notes,
  }) async {
    // Current logged in closer or lead's assigned closer
    final user = _ref.read(authProvider).user;
    final closer = state.closers.firstWhere(
      (c) => c.id == (user?.closerId ?? lead.assignedCloserId),
      orElse: () => state.closers.firstWhere(
        (c) => c.email == user?.email,
        orElse: () => state.closers.isNotEmpty ? state.closers.first : const ClientCloser(id: '', clientId: '', closerCode: 'CLS-001', fullName: 'Amaka Chioma', email: '', phone: ''),
      ),
    );

    // 1. Create order with full 2-tier dispatch routing and closer attribution
    final createdOrder = await createOrder(
      customerName: lead.customerName,
      customerPhone: lead.customerPhone,
      deliveryState: lead.deliveryState,
      deliveryLga: lead.deliveryLga,
      deliveryAddress: lead.customerAddress.isNotEmpty ? lead.customerAddress : '${lead.deliveryLga}, ${lead.deliveryState}',
      productId: productId,
      productName: productName,
      packageName: packageName,
      quantity: quantity,
      totalAmount: totalAmount,
      paymentType: paymentType,
      closerId: closer.id.isNotEmpty ? closer.id : null,
      closerName: closer.fullName.isNotEmpty ? closer.fullName : null,
      closerCode: closer.closerCode.isNotEmpty ? closer.closerCode : null,
      leadId: lead.id,
      notes: notes ?? lead.callNotes,
    );

    // 2. Update lead status in local state
    final updatedLeads = state.leads.map((l) {
      if (l.id == lead.id) {
        return l.copyWith(
          status: 'order_created',
          convertedOrderId: createdOrder.id,
          lastCalledAt: DateTime.now(),
        );
      }
      return l;
    }).toList();

    // 3. Update closer performance counts
    final updatedClosers = state.closers.map((c) {
      if (c.id == closer.id) {
        return c.copyWith(
          totalLeadsConfirmed: c.totalLeadsConfirmed + 1,
          totalOrdersBooked: c.totalOrdersBooked + 1,
        );
      }
      return c;
    }).toList();

    state = state.copyWith(leads: updatedLeads, closers: updatedClosers);

    // Async push via Repository
    Future.microtask(() async {
      try {
        await _repository.recordLeadConversion(
          leadId: lead.id,
          orderId: createdOrder.id,
          closerId: closer.id.isNotEmpty ? closer.id : null,
          totalLeadsConfirmed: closer.id.isNotEmpty ? closer.totalLeadsConfirmed + 1 : null,
          totalOrdersBooked: closer.id.isNotEmpty ? closer.totalOrdersBooked + 1 : null,
        );
      } catch (dbErr) {
        debugPrint('[CLIENT_PORTAL] ℹ️ Lead conversion sync notice: $dbErr');
      }
    });

    return createdOrder;
  }

  /// Create a new Single Order with 2-tier State/LGA dispatch engine integration & Closer Attribution
  Future<OrderEntity> createOrder({
    required String customerName,
    required String customerPhone,
    String? customerAltPhone,
    required String deliveryState,
    required String deliveryLga,
    required String deliveryAddress,
    required String productId,
    required String productName,
    required int quantity,
    required double totalAmount,
    String? packageId,
    String? packageName,
    String paymentType = 'Pay on Delivery (Cash/POS)',
    bool autoAssignRider = true,
    String? closerId,
    String? closerName,
    String? closerCode,
    String? leadId,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final orderId = _generateUuid();
      final randomSuffix = (1000 + math.Random().nextInt(8999)).toString();
      final orderNumber = 'NOV-${DateTime.now().year}-$randomSuffix';

      // 1. Gather all Distribution Centers and Drivers from DCConsoleProvider
      final dcState = _ref.read(dcConsoleProvider);
      final allDcs = dcState.distributionCenters;
      final allDrivers = dcState.drivers;

      final provisionalOrder = OrderEntity(
        id: orderId,
        orderNumber: orderNumber,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        customerAltPhone: customerAltPhone?.trim(),
        deliveryAddress: deliveryAddress.trim(),
        deliveryCity: deliveryLga.trim(),
        deliveryState: deliveryState.trim(),
        lga: deliveryLga.trim(),
        status: 'pending_dispatch',
        paymentStatus: 'pending',
        paymentType: paymentType,
        totalAmount: totalAmount,
        basePrice: totalAmount,
        upsellAmount: 0.0,
        quantity: quantity,
        productName: productName,
        packageDealId: packageId,
        packageDealName: packageName,
        fulfillmentType: 'client_package',
        clientName: state.clientProfile.companyName,
        clientId: state.clientProfile.id,
        closerId: closerId,
        closerName: closerName,
        closerCode: closerCode,
        leadId: leadId,
        deliveryNotes: notes,
        createdAt: DateTime.now(),
      );

      // 2. Execute 2-Tier Automated Dispatch Engine
      final routingResult = OrderRoutingService.routeOrder(
        order: provisionalOrder,
        distributionCenters: allDcs,
        drivers: allDrivers,
        stockAllocations: const [],
      );

      final String assignedDcId = routingResult.distributionCenter?.id ??
          (allDcs.isNotEmpty ? allDcs.firstWhere((dc) => dc.isHub, orElse: () => allDcs.first).id : '22222222-2222-4222-8222-222222222222');
      final String assignedDcName = routingResult.distributionCenter?.name ?? dcState.activeHubName;

      String? assignedDriverId;
      String? assignedDriverName;
      String? assignedDriverPhone;
      String? assignedDriverCode;
      String initialStatus;
      String assignmentStatus;

      if (autoAssignRider && routingResult.status == RoutingStatus.assignedToRider && routingResult.driver != null) {
        initialStatus = 'assigned';
        assignmentStatus = 'auto_assigned';
        assignedDriverId = routingResult.driver?.id;
        assignedDriverName = routingResult.driver?.name;
        assignedDriverPhone = routingResult.driver?.phone;
        assignedDriverCode = routingResult.driver?.driverCode;
      } else {
        initialStatus = 'pending_dispatch';
        assignmentStatus = 'pending_rider_assignment';
        assignedDriverId = null;
        assignedDriverName = null;
        assignedDriverPhone = null;
        assignedDriverCode = null;
      }

      final newOrder = OrderEntity(
        id: orderId,
        orderNumber: orderNumber,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        customerAltPhone: customerAltPhone?.trim(),
        deliveryAddress: deliveryAddress.trim(),
        deliveryCity: deliveryLga.trim(),
        deliveryState: deliveryState.trim(),
        lga: deliveryLga.trim(),
        status: initialStatus,
        paymentStatus: 'pending',
        paymentType: paymentType,
        totalAmount: totalAmount,
        basePrice: totalAmount,
        upsellAmount: 0.0,
        quantity: quantity,
        productName: productName,
        packageDealId: packageId,
        packageDealName: packageName,
        deliveryAgentId: assignedDriverId,
        deliveryAgentName: assignedDriverName,
        deliveryAgentCode: assignedDriverCode,
        deliveryAgentPhone: assignedDriverPhone,
        distributionCenterId: assignedDcId,
        distributionCenterName: assignedDcName,
        fulfillmentType: 'client_package',
        clientName: state.clientProfile.companyName,
        clientId: state.clientProfile.id,
        closerId: closerId,
        closerName: closerName,
        closerCode: closerCode,
        leadId: leadId,
        deliveryNotes: notes,
        createdAt: DateTime.now(),
      );

      // 3. Persist order via OrdersProvider synchronously so DC & Supabase are immediately live
      try {
        await _ref.read(ordersProvider.notifier).createOrder({
          'id': newOrder.id,
          'order_number': newOrder.orderNumber,
          'customer_name': newOrder.customerName,
          'customer_phone': newOrder.customerPhone,
          'customer_alt_phone': newOrder.customerAltPhone,
          'delivery_address': newOrder.deliveryAddress,
          'delivery_city': newOrder.deliveryCity,
          'delivery_state': newOrder.deliveryState,
          'delivery_lga': newOrder.deliveryLga,
          'lga': newOrder.deliveryLga,
          'distribution_center_id': newOrder.distributionCenterId,
          'distribution_center_name': newOrder.distributionCenterName,
          'delivery_agent_id': newOrder.deliveryAgentId,
          'assigned_agent_id': newOrder.deliveryAgentId,
          'delivery_agent_name': newOrder.deliveryAgentName,
          'delivery_agent_code': newOrder.deliveryAgentCode,
          'delivery_agent_phone': newOrder.deliveryAgentPhone,
          'status': newOrder.status,
          'assignment_status': assignmentStatus,
          'routing_notes': routingResult.dispatchDiagnosis,
          'total_amount': newOrder.totalAmount,
          'base_price': newOrder.basePrice,
          'product_id': productId,
          'product_name': newOrder.productName,
          'package_deal_id': newOrder.packageDealId,
          'package_deal_name': newOrder.packageDealName,
          'quantity': newOrder.quantity,
          'fulfillment_type': 'client_package',
          'client_name': newOrder.clientName,
          'client_id': newOrder.clientId,
          'closer_id': newOrder.closerId,
          'closer_name': newOrder.closerName,
          'closer_code': newOrder.closerCode,
          'lead_id': newOrder.leadId,
          'payment_type': newOrder.paymentType,
          'payment_status': 'pending',
          'delivery_notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[CLIENT_PORTAL] ✅ Order ${newOrder.orderNumber} (Closer: ${newOrder.closerName ?? "N/A"}) persisted live to OrdersProvider & DC.');
      } catch (dbErr) {
        debugPrint('[CLIENT_PORTAL] ℹ️ Order creation sync notice: $dbErr');
      }

      // 4. Update local state
      final updatedOrders = [newOrder, ...state.orders.where((o) => o.id != newOrder.id && o.orderNumber != newOrder.orderNumber)];
      state = state.copyWith(orders: updatedOrders, isLoading: false);

      return newOrder;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  static bool _stateMatches(String dcState, String targetState) {
    final cleanDc = dcState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanTarget = targetState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanDc.isEmpty || cleanTarget.isEmpty) return false;
    if (cleanDc == cleanTarget) return true;
    if (cleanDc.contains(cleanTarget) || cleanTarget.contains(cleanDc)) return true;
    if ((cleanDc.contains('abuja') || cleanDc.contains('fct')) &&
        (cleanTarget.contains('abuja') || cleanTarget.contains('fct'))) {
      return true;
    }
    return false;
  }

  /// Create a new Merchant Product with covering states & DC allocation
  Future<CatalogProduct> createProduct({
    required String name,
    required String sku,
    required double unitPrice,
    String category = 'Health & Wellness',
    String? description,
    String? imageUrl,
    required List<String> coveringStates,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final cleanName = name.trim();
      final cleanSku = sku.trim().toUpperCase();
      final clientCompany = state.clientProfile.companyName;
      final clientId = state.clientProfile.id;

      // 1. Resolve DCs located in the selected covering states
      final dcState = _ref.read(dcConsoleProvider);
      final List<DistributionCenter> allDcs = dcState.distributionCenters.isNotEmpty
          ? dcState.distributionCenters
          : defaultDistributionCenters;

      final matchingDcs = allDcs.where((dc) {
        return coveringStates.any((st) => _stateMatches(dc.state, st));
      }).toList();

      // Initial DC stock is strictly 0 until supplied by the client
      final dcStocks = <String, int>{
        for (final dc in matchingDcs) dc.id: 0,
      };

      // 2. Register into central DC Inventory (StockProvider)
      await _ref.read(stockProvider.notifier).addNewProduct(
        name: cleanName,
        sku: cleanSku,
        category: category,
        price: unitPrice,
        ownerName: clientCompany,
        clientId: clientId,
        initialQuantity: 0,
        description: description ?? '',
        imageAsset: imageUrl,
        coveringStates: coveringStates,
        dcStocks: dcStocks,
      );

      // 3. Register into Master Commercial Catalog with auto-built packages
      final newProd = await _ref.read(productCatalogProvider.notifier).registerNewProduct(
        name: cleanName,
        sku: cleanSku,
        baseUnitPrice: unitPrice,
        category: category,
        clientName: clientCompany,
        clientId: clientId,
        description: description,
        imageUrl: imageUrl,
        coveringStates: coveringStates,
      );

      final updatedProducts = [
        ...state.products.where((p) => p.sku.toUpperCase() != cleanSku),
        newProd,
      ];
      state = state.copyWith(products: updatedProducts, isLoading: false);
      return newProd;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Supply product stock / inbound consignment to NovaExpress covering DCs
  Future<void> supplyProductStock({
    required String productId,
    required String sku,
    required String productName,
    required Map<String, int> dcAllocations, // { dcId: units }
    String? waybillNumber,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final clientCompany = state.clientProfile.companyName;
      final resolvedWaybill = waybillNumber?.trim().isNotEmpty == true
          ? waybillNumber!.trim()
          : 'WAYBILL-${sku.trim().toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      int totalUnitsSupplied = 0;
      for (final entry in dcAllocations.entries) {
        final dcId = entry.key;
        final qty = entry.value;
        if (qty > 0) {
          totalUnitsSupplied += qty;
          await _ref.read(stockProvider.notifier).receiveStock(
            productIdOrSku: sku.trim(),
            quantity: qty,
            waybillNumber: resolvedWaybill,
            distributionCenterId: dcId,
            supplierName: clientCompany,
          );
        }
      }

      // Refresh product catalog & active DC stock
      await _ref.read(productCatalogProvider.notifier).reloadCatalog();
      final activeHub = _ref.read(dcConsoleProvider).activeHubId;
      await _ref.read(stockProvider.notifier).fetchStockItems(null, activeHub);

      // Update local client products stock count
      final updatedProducts = state.products.map((p) {
        if (p.id == productId || p.sku.toUpperCase() == sku.trim().toUpperCase() || p.name.toLowerCase() == productName.trim().toLowerCase()) {
          return p.copyWith(totalStockAcrossHubs: p.totalStockAcrossHubs + totalUnitsSupplied);
        }
        return p;
      }).toList();

      state = state.copyWith(products: updatedProducts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Create a new Commercial Package Deal on a Product
  Future<ProductPackage> createPackage({
    required String productId,
    required String productName,
    required String packageName,
    required int quantity,
    int paidQuantity = 1,
    int freeQuantity = 0,
    required double packagePrice,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final pkg = _ref.read(productCatalogProvider.notifier).addPackageToProduct(
        productName: productName,
        packageName: packageName,
        quantity: quantity,
        paidQuantity: paidQuantity,
        freeQuantity: freeQuantity,
        packagePrice: packagePrice,
        clientName: state.clientProfile.companyName,
        description: description,
      );

      final updatedPackages = [...state.packages, pkg];
      state = state.copyWith(packages: updatedPackages, isLoading: false);
      return pkg;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Update an existing Commercial Package Deal on a Product
  Future<ProductPackage?> updatePackage({
    required String productName,
    required String packageId,
    required String packageName,
    required int quantity,
    int? paidQuantity,
    int? freeQuantity,
    required double packagePrice,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final pkg = _ref.read(productCatalogProvider.notifier).updatePackage(
        productName: productName,
        packageId: packageId,
        packageName: packageName,
        quantity: quantity,
        paidQuantity: paidQuantity,
        freeQuantity: freeQuantity,
        packagePrice: packagePrice,
        description: description,
      );

      if (pkg != null) {
        final updatedPackages = state.packages.map((p) => p.id == packageId ? pkg : p).toList();
        state = state.copyWith(packages: updatedPackages, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return pkg;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Delete a Commercial Package Deal from a Product
  Future<bool> deletePackage({
    required String productName,
    required String packageId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final success = _ref.read(productCatalogProvider.notifier).deletePackage(
        productName: productName,
        packageId: packageId,
      );

      if (success) {
        final updatedPackages = state.packages.where((p) => p.id != packageId).toList();
        state = state.copyWith(packages: updatedPackages, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Bulk CSV Order Import
  Future<int> importOrdersCsv(List<Map<String, dynamic>> rawRows) async {
    state = state.copyWith(isLoading: true);
    int importedCount = 0;
    try {
      for (final row in rawRows) {
        final custName = row['customer_name']?.toString() ?? row['name']?.toString() ?? 'Customer';
        final phone = row['customer_phone']?.toString() ?? row['phone']?.toString() ?? '08000000000';
        final stateName = row['state']?.toString() ?? row['delivery_state']?.toString() ?? 'Federal Capital Territory';
        final lga = row['lga']?.toString() ?? row['delivery_lga']?.toString() ?? 'Abuja Municipal (AMAC)';
        final address = row['address']?.toString() ?? row['delivery_address']?.toString() ?? 'Abuja';
        final prodName = row['product_name']?.toString() ?? 'Grazer Tea';
        final qty = int.tryParse(row['quantity']?.toString() ?? '1') ?? 1;
        final amount = double.tryParse(row['amount']?.toString() ?? '22000') ?? 22000.0;

        await createOrder(
          customerName: custName,
          customerPhone: phone,
          deliveryState: stateName,
          deliveryLga: lga,
          deliveryAddress: address,
          productId: 'prod-grazer-01',
          productName: prodName,
          quantity: qty,
          totalAmount: amount,
        );
        importedCount++;
      }
      state = state.copyWith(isLoading: false);
      return importedCount;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return importedCount;
    }
  }

  Future<int> importBulkOrdersCsv() async {
    final sampleBatch = [
      {
        'customer_name': 'Chief Adeleke',
        'customer_phone': '08033221144',
        'delivery_address': 'Plot 14, Ahmadu Bello Way, Garki',
        'delivery_state': 'Federal Capital Territory',
        'delivery_lga': 'Abuja Municipal (AMAC)',
        'product_name': 'Grazer Tea',
        'quantity': 2,
        'amount': 35000.0,
      },
      {
        'customer_name': 'Mrs. Folashade Bakare',
        'customer_phone': '08055667788',
        'delivery_address': 'Flat 4B, Hillview Estate, Guzape',
        'delivery_state': 'Federal Capital Territory',
        'delivery_lga': 'Abuja Municipal (AMAC)',
        'product_name': 'Grazer Tea',
        'quantity': 3,
        'amount': 50000.0,
      },
    ];
    return importOrdersCsv(sampleBatch);
  }

  String _generateUuid() {
    final random = math.Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  List<ClientCloser> _generateSeedClosers(String clientId) {
    return [
      ClientCloser(
        id: '44444444-4444-4444-8444-444444444444',
        clientId: clientId,
        closerCode: 'CLS-NOVA-001',
        fullName: 'Amaka Chioma',
        email: 'closer.amaka@novacale.ng',
        phone: '08021122334',
        dailyCallTarget: 50,
        totalLeadsAssigned: 45,
        totalLeadsConfirmed: 38,
        totalOrdersBooked: 34,
        totalOrdersDelivered: 31,
        commissionRate: 500.0,
      ),
      ClientCloser(
        id: '44444444-4444-4444-8444-444444444445',
        clientId: clientId,
        closerCode: 'CLS-NOVA-002',
        fullName: 'Ibrahim Musa',
        email: 'ibrahim.musa@novacale.ng',
        phone: '08035566778',
        dailyCallTarget: 50,
        totalLeadsAssigned: 40,
        totalLeadsConfirmed: 32,
        totalOrdersBooked: 29,
        totalOrdersDelivered: 26,
        commissionRate: 500.0,
      ),
      ClientCloser(
        id: '44444444-4444-4444-8444-444444444446',
        clientId: clientId,
        closerCode: 'CLS-NOVA-003',
        fullName: 'Funke Adeleke',
        email: 'funke.adeleke@novacale.ng',
        phone: '08078899001',
        dailyCallTarget: 40,
        totalLeadsAssigned: 35,
        totalLeadsConfirmed: 28,
        totalOrdersBooked: 25,
        totalOrdersDelivered: 22,
        commissionRate: 500.0,
      ),
    ];
  }

  List<CustomerLead> _generateSeedLeads(String clientId, String defaultCloserId) {
    return [
      CustomerLead(
        id: '55555555-5555-4555-8555-000000000001',
        clientId: clientId,
        assignedCloserId: defaultCloserId,
        assignedCloserName: 'Amaka Chioma',
        customerName: 'Chief Emmanuel Adeleke',
        customerPhone: '08033221144',
        customerAddress: 'Plot 14, Ahmadu Bello Way, Area 11, Garki',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        productInterest: 'Grazer Tea',
        packageInterest: '2 Packs Promo Deal',
        status: 'new_lead',
        callNotes: 'Interested in 2-pack promo. Prefers morning delivery.',
      ),
      CustomerLead(
        id: '55555555-5555-4555-8555-000000000002',
        clientId: clientId,
        assignedCloserId: defaultCloserId,
        assignedCloserName: 'Amaka Chioma',
        customerName: 'Mrs. Folashade Bakare',
        customerPhone: '08055667788',
        customerAddress: 'Flat 4B, Hillview Estate, Guzape',
        deliveryState: 'Federal Capital Territory',
        deliveryLga: 'Abuja Municipal (AMAC)',
        productInterest: 'Grazer Tea',
        packageInterest: '3 Packs Family Bundle',
        status: 'calling',
        callNotes: 'Requested call back around 2 PM to confirm delivery address.',
      ),
      CustomerLead(
        id: '55555555-5555-4555-8555-000000000003',
        clientId: clientId,
        assignedCloserId: defaultCloserId,
        assignedCloserName: 'Amaka Chioma',
        customerName: 'Alhaji Bello Usman',
        customerPhone: '08099887766',
        customerAddress: 'No. 8, Bompai Road, Fagge',
        deliveryState: 'Kano State',
        deliveryLga: 'Fagge',
        productInterest: 'Grazer Tea',
        packageInterest: '5 Packs Mega Saver (Buy 4 Get 1 Free)',
        status: 'confirmed',
        callNotes: 'Ready for immediate dispatch to Kano depot.',
      ),
    ];
  }

  List<OrderEntity> _generateSeedOrders(String clientId, String companyName) {
    final now = DateTime.now();
    return [
      OrderEntity(
        id: 'ord-client-001',
        orderNumber: 'NOV-2026-8801',
        customerName: 'Amina Mohammed',
        customerPhone: '08031122334',
        deliveryAddress: 'House 14, 4th Avenue, Gwarinpa Estate',
        deliveryCity: 'Abuja Municipal (AMAC)',
        deliveryState: 'Federal Capital Territory',
        lga: 'Abuja Municipal (AMAC)',
        status: 'in_transit',
        paymentStatus: 'pending',
        paymentType: 'Pay on Delivery (POS/Cash)',
        totalAmount: 35000.0,
        basePrice: 35000.0,
        upsellAmount: 0.0,
        quantity: 2,
        productName: 'Grazer Tea',
        packageDealName: '2 Packs Promo Deal',
        deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
        deliveryAgentName: 'Emeka Rider (PDA-7000)',
        deliveryAgentPhone: '08012345678',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Central Distribution Hub',
        clientName: companyName,
        clientId: clientId,
        closerId: '44444444-4444-4444-8444-444444444444',
        closerName: 'Amaka Chioma',
        closerCode: 'CLS-NOVA-001',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      OrderEntity(
        id: 'ord-client-002',
        orderNumber: 'NOV-2026-8802',
        customerName: 'Chinedu Eze',
        customerPhone: '08059988776',
        deliveryAddress: 'Plot 45, Adetokunbo Ademola Crescent, Wuse II',
        deliveryCity: 'Abuja Municipal (AMAC)',
        deliveryState: 'Federal Capital Territory',
        lga: 'Abuja Municipal (AMAC)',
        status: 'delivered',
        paymentStatus: 'paid',
        paymentType: 'Direct Bank Transfer',
        totalAmount: 50000.0,
        basePrice: 50000.0,
        upsellAmount: 0.0,
        quantity: 3,
        productName: 'Grazer Tea',
        packageDealName: '3 Packs Family Bundle',
        deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
        deliveryAgentName: 'Emeka Rider (PDA-7000)',
        deliveryAgentPhone: '08012345678',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Central Distribution Hub',
        clientName: companyName,
        clientId: clientId,
        closerId: '44444444-4444-4444-8444-444444444444',
        closerName: 'Amaka Chioma',
        closerCode: 'CLS-NOVA-001',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      OrderEntity(
        id: 'ord-client-003',
        orderNumber: 'NOV-2026-8803',
        customerName: 'Fatima Bello',
        customerPhone: '07034455667',
        deliveryAddress: 'Block B, Federal Housing Estate, Kubwa',
        deliveryCity: 'Bwari',
        deliveryState: 'Federal Capital Territory',
        lga: 'Bwari',
        status: 'assigned',
        paymentStatus: 'pending',
        paymentType: 'Pay on Delivery (Cash)',
        totalAmount: 22000.0,
        basePrice: 22000.0,
        upsellAmount: 0.0,
        quantity: 1,
        productName: 'Grazer Tea',
        packageDealName: '1 Pack (Standard Retail)',
        deliveryAgentId: 'b2222222-2222-4222-8222-222222222222',
        deliveryAgentName: 'Musa Garba (RDR-102)',
        deliveryAgentPhone: '08023456789',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Central Distribution Hub',
        clientName: companyName,
        clientId: clientId,
        closerId: '44444444-4444-4444-8444-444444444445',
        closerName: 'Ibrahim Musa',
        closerCode: 'CLS-NOVA-002',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      OrderEntity(
        id: 'ord-client-004',
        orderNumber: 'NOV-2026-8804',
        customerName: 'Oluwaseun Adeyemi',
        customerPhone: '08123344556',
        deliveryAddress: 'No 8, Hospital Road, Gwagwalada',
        deliveryCity: 'Gwagwalada',
        deliveryState: 'Federal Capital Territory',
        lga: 'Gwagwalada',
        status: 'pending_dispatch',
        paymentStatus: 'pending',
        paymentType: 'Paystack Card Checkout',
        totalAmount: 55000.0,
        basePrice: 55000.0,
        upsellAmount: 0.0,
        quantity: 5,
        productName: 'Grazer Tea',
        packageDealName: '5 Packs Mega Saver (Buy 4 Get 1 Free)',
        distributionCenterId: 'dc-gwag-002',
        distributionCenterName: 'Gwagwalada Regional Depot',
        clientName: companyName,
        clientId: clientId,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];
  }
}

final clientPortalRepositoryProvider = Provider<ClientPortalRepository>((ref) {
  return ClientPortalRepositoryImpl();
});

final clientPortalProvider = StateNotifierProvider<ClientPortalNotifier, ClientPortalState>((ref) {
  final repository = ref.watch(clientPortalRepositoryProvider);
  return ClientPortalNotifier(ref, repository: repository);
});
