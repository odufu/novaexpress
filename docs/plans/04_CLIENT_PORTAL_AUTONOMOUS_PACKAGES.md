# Client Portal: Package Autonomy & Multi-Tenancy Plan

## 1. Overview

This document details the exact surgical fix to eradicate the forced 4-tier package re-injection bug and enforce true commercial autonomy for merchants.

---

## 2. The Forced Re-injection Bug in `product_catalog_provider.dart`

### 2.1 File Location & Line Numbers
- **File**: `lib/features/dc_console/presentation/providers/product_catalog_provider.dart`
- **Lines 605–616**:
```dart
    final updatedPackages = existingProduct.packages.where((p) => p.id != packageId).toList();
    if (updatedPackages.isEmpty) {
      // Keep at least standard commercial defaults
      updatedPackages.addAll(
        buildDefaultPackagesForProduct(
          productId: existingProduct.id,
          productName: existingProduct.name,
          productSku: existingProduct.sku,
          baseUnitPrice: existingProduct.defaultUnitPrice,
          clientName: existingProduct.clientName,
        ),
      );
    }
```

### 2.2 Surgical Replacement
Replace lines 605–616 with:
```dart
    final updatedPackages = existingProduct.packages.where((p) => p.id != packageId).toList();
    // Do not force re-injection of defaults; allow merchants 100% package autonomy
```

---

## 3. Unique Package Deal Identification

When creating packages:
- Package IDs must never use generic names (`pkg-${sku}-${qty}`).
- Format:
```dart
final packageId = 'pkg_${clientId}_${sku}_${totalUnits}_${DateTime.now().millisecondsSinceEpoch}';
```
This guarantees cross-tenant uniqueness in the database.

---

## 4. Client Catalog Scoping

In `client_portal_provider.dart`:
- Products and packages loaded in `ClientPortalNotifier` are strictly scoped to `p.clientId == authenticatedClientId`.
- If a client has 0 products, render a clean empty state with a "Create Product" CTA rather than populating demo products from Novacale.
