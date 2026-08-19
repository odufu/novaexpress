# NovaExpress PDA — Complete Function to Database & API Mapping

This document provides a comprehensive mapping of every screen, widget, user interaction, Riverpod provider, and backend database interaction across the entire NovaExpress PDA application.

---

## 1. Authentication & Session Management

### 1.1. Login (`LoginPage`)
- **File**: [`lib/features/auth/presentation/pages/login_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/auth/presentation/pages/login_page.dart)
- **Provider**: `authNotifierProvider` (`AuthProvider`)
- **Trigger**: Click `Sign In` button.
- **Backend Query / RPC**:
  ```sql
  -- Supabase Auth sign-in with email and password
  SELECT * FROM auth.users WHERE email = :email;
  -- Profile lookup
  SELECT u.*, da.id as agent_id, da.agent_code, da.current_cod_balance, da.direct_transfer_balance 
  FROM users u
  LEFT JOIN delivery_agents da ON da.user_id = u.id
  WHERE u.id = auth.uid();
  ```
- **State Updated**: Authenticated session, user profile, cached agent ID `b1111111-1111-4111-8111-111111111111`.

---

## 2. Main Dashboard & Home Screen

### 2.1. Home Screen Overview (`PdaHomePage`)
- **File**: [`lib/features/dashboard/presentation/pages/pda_home_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/dashboard/presentation/pages/pda_home_page.dart)
- **Providers**: `ordersNotifierProvider`, `stockNotifierProvider`, `financeNotifierProvider`

#### Function: Availability Status Toggle
- **Trigger**: Tap `● Available ⌄` pill.
- **Database Mutation**:
  ```sql
  UPDATE delivery_agents 
  SET current_status = :new_status, last_sync_at = NOW() 
  WHERE id = :agent_id;
  ```

#### Function: Remittance Required Card (`Remit Now`)
- **Trigger**: Tap `Remit Now` button on the Remittance Hero Card (`₦2,000.00`).
- **Action**: Navigation to `/cash/remit`.
- **Database Query**: Reads `delivery_agents.current_cod_balance`.

#### Function: Hero "My Balance" Card & Payout History
- **Trigger**: Tap anywhere on `MY BALANCE (Direct Transfers): ₦18,500.00` card or `Request Payout` button.
- **Action**: Navigation to `/finance/payouts`.
- **Database Query**:
  ```sql
  SELECT direct_transfer_balance FROM delivery_agents WHERE id = :agent_id;
  SELECT * FROM payout_requests WHERE delivery_agent_id = :agent_id ORDER BY created_at DESC;
  ```

#### Function: View Financial Breakdown
- **Trigger**: Tap `View breakdown >` link on Financial Summary section.
- **Action**: Navigation to `/finance/transactions`.
- **Database Query**:
  ```sql
  SELECT * FROM rider_transactions WHERE delivery_agent_id = :agent_id ORDER BY created_at DESC;
  ```

#### Function: View More Today's Deliveries
- **Trigger**: Tap `View More (4) >` header button.
- **Action**: Switches bottom navigation index to `2` (`OrdersListPage`).

#### Function: Direct 1-Tap Customer Call
- **Trigger**: Tap `[ 📞 Call ]` button on delivery card.
- **Action**: Invokes device native dialer `tel:${order.customerPhone}`.

---

## 3. Orders & Delivery Operations

### 3.1. Deliveries List (`OrdersListPage`)
- **File**: [`lib/features/orders/presentation/pages/orders_list_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/orders/presentation/pages/orders_list_page.dart)
- **Provider**: `ordersNotifierProvider` (`OrdersNotifier`)

#### Function: Fetch Active Deliveries
- **Database Query**:
  ```sql
  SELECT * FROM orders 
  WHERE delivery_agent_id = :agent_id 
  ORDER BY created_at DESC;
  ```

#### Function: Filter Orders by Tab
- **Tabs**: `All`, `In Progress`, `Pending`, `Delivered`, `Failed`
- **Client Logic**: Filters memory list by `order.status` (`'in_transit'`, `'accepted'`, `'delivered'`, `'call_back'`, `'cancelled'`).

---

### 3.2. Order Details (`OrderDetailPage`)
- **File**: [`lib/features/orders/presentation/pages/order_detail_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/orders/presentation/pages/order_detail_page.dart)
- **Database Query**:
  ```sql
  SELECT o.*, va.account_number, va.bank_name, va.account_name 
  FROM orders o
  LEFT JOIN monnify_virtual_accounts va ON va.order_id = o.id
  WHERE o.id = :order_id;
  ```

#### Function: Start Delivery (`in_transit`)
- **Trigger**: Tap `Start Delivery` CTA button.
- **Database Mutation**:
  ```sql
  UPDATE orders SET status = 'in_transit', updated_at = NOW() WHERE id = :order_id;
  INSERT INTO order_activities (order_id, user_id, activity_type, notes)
  VALUES (:order_id, :user_id, 'status_changed', 'Delivery started by rider');
  ```

---

### 3.3. Confirm Delivery POD (`ConfirmDeliveryPodPage`)
- **File**: [`lib/features/orders/presentation/pages/confirm_delivery_pod_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/orders/presentation/pages/confirm_delivery_pod_page.dart)

#### Function: Switch Payment Method (Cash vs Monnify Dynamic Account)
- **Options**:
  1. `Cash Collection (POD)`
  2. `Direct Transfer (Monnify Dedicated Virtual Account)`

#### Function: Submit Delivery POD (Atomic RPC Execution)
- **Trigger**: Tap `Confirm & Complete Delivery` button.
- **Database Stored Procedure**:
  ```sql
  SELECT confirm_delivery_pod(
      p_order_id => :order_id,
      p_agent_id => :agent_id,
      p_payment_type => :payment_type, -- 'pay_on_delivery' or 'monnify_transfer'
      p_amount => :total_amount,
      p_proof_url => :signature_or_photo_url,
      p_notes => :delivery_notes
  );
  ```
- **Ledger Side Effects**:
  - `orders.status` $\rightarrow$ `'delivered'`
  - If Cash: `delivery_agents.current_cod_balance` $+=$ `total_amount`
  - If Monnify: `delivery_agents.direct_transfer_balance` $+=$ `agent_entitlement` (₦2,500)
  - `agent_inventory.delivered_count_today` $+=$ `quantity`

---

### 3.4. Log Delivery Failure / Reschedule (`LogDeliveryFailurePage`)
- **File**: [`lib/features/orders/presentation/pages/log_delivery_failure_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/orders/presentation/pages/log_delivery_failure_page.dart)

#### Function: Log Failure & Reschedule
- **Trigger**: Select Reason (`Customer Unavailable`, `Phone Switched Off`, `Rescheduled`, `Wrong Address`, `Refused Payment`) + Select Date & Time + Tap `Submit Delivery Failure`.
- **Database Stored Procedure**:
  ```sql
  SELECT log_delivery_failure(
      p_order_id => :order_id,
      p_agent_id => :agent_id,
      p_reason_code => :reason_code,
      p_reschedule_time => :reschedule_timestamp,
      p_notes => :rider_notes
  );
  ```
- **Ledger Side Effects**:
  - `orders.status` $\rightarrow$ `'call_back'` or `'cancelled'`
  - `orders.scheduled_callback_at` $\rightarrow$ `:reschedule_timestamp`
  - `agent_inventory.awaiting_return_count` $+=$ `quantity`

---

## 4. Vehicle Stock & Inventory Custody

### 4.1. Stock Custody (`StockPage`)
- **File**: [`lib/features/stock/presentation/pages/stock_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/stock/presentation/pages/stock_page.dart)
- **Provider**: `stockNotifierProvider` (`StockNotifier`)

#### Function: Fetch Vehicle Loaded Items
- **Database Query**:
  ```sql
  SELECT ai.*, p.name, p.sku, p.base_price, p.category, p.image_url, p.low_stock_threshold, pb.batch_number
  FROM agent_inventory ai
  JOIN products p ON p.id = ai.product_id
  LEFT JOIN product_batches pb ON pb.id = ai.batch_id
  WHERE ai.delivery_agent_id = :agent_id;
  ```

#### Function: Request Restock Handover
- **Trigger**: Tap `Request Stock` button.
- **Action**: Opens Modal / Navigates to `StockHandoverPage`.
- **Database Mutation**:
  ```sql
  INSERT INTO stock_requests (request_number, delivery_agent_id, distribution_center_id, status, request_type)
  VALUES (:request_number, :agent_id, :dc_id, 'pending', 'restock');
  ```

#### Function: Process Stock Returns
- **Trigger**: Tap `Process Returns` button.
- **Action**: Navigates to `ProcessReturnsPage`.
- **Database Mutation**:
  ```sql
  INSERT INTO stock_returns (return_number, delivery_agent_id, distribution_center_id, product_id, quantity, reason, status)
  VALUES (:return_number, :agent_id, :dc_id, :product_id, :qty, :reason, 'submitted');
  ```

---

## 5. Cash Remittance & Financial Settlement

### 5.1. Cash Remittance Dashboard (`CashPage`)
- **File**: [`lib/features/finance/presentation/pages/cash_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/finance/presentation/pages/cash_page.dart)
- **Provider**: `financeNotifierProvider` (`FinanceNotifier`)

#### Function: Fetch Remittance History
- **Database Query**:
  ```sql
  SELECT * FROM cash_remittances 
  WHERE delivery_agent_id = :agent_id 
  ORDER BY created_at DESC;
  ```

---

### 5.2. Log New Remittance (`LogRemittancePage`)
- **File**: [`lib/features/finance/presentation/pages/log_remittance_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/finance/presentation/pages/log_remittance_page.dart)

#### Function: Submit Bank Transfer / Cash / POS Remittance
- **Trigger**: Enter Amount, Select Channel (`Bank Transfer`, `Cash to DC`, `POS`), Attach Receipt Image, Tap `Submit Remittance`.
- **Database Mutation**:
  ```sql
  INSERT INTO cash_remittances (
      company_id,
      delivery_agent_id,
      reference_number,
      amount,
      gross_collections,
      commission_deducted,
      transport_allowance_deducted,
      payment_method,
      deposit_receipt_url,
      status,
      notes
  ) VALUES (
      :company_id,
      :agent_id,
      :reference_number,
      :amount,
      :gross_collections,
      :commission_deducted,
      :transport_allowance_deducted,
      :payment_method,
      :receipt_url,
      'submitted',
      :notes
  ) RETURNING *;
  ```

---

### 5.3. Remittance Details & Receipt (`RemittanceDetailsPage`)
- **File**: [`lib/features/finance/presentation/pages/remittance_details_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/finance/presentation/pages/remittance_details_page.dart)
- **Database Query**:
  ```sql
  SELECT cr.*, ro.order_id, o.order_number, o.customer_name 
  FROM cash_remittances cr
  LEFT JOIN remittance_orders ro ON ro.cash_remittance_id = cr.id
  LEFT JOIN orders o ON o.id = ro.order_id
  WHERE cr.id = :remittance_id;
  ```

---

## 6. Payout Requests & Balance Ledger

### 6.1. Direct Transfer Payout Requests (`PayoutsPage`)
- **File**: [`lib/features/finance/presentation/pages/payouts_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/finance/presentation/pages/payouts_page.dart)

#### Function: Request Balance Payout
- **Trigger**: Tap `[ 💵 Request Payout ]` button $\rightarrow$ Enter withdrawal amount $\rightarrow$ Confirm Bank Details $\rightarrow$ Submit.
- **Database Mutation**:
  ```sql
  INSERT INTO payout_requests (
      payout_number,
      delivery_agent_id,
      amount,
      bank_name,
      account_number,
      account_name,
      status
  ) VALUES (
      :payout_number,
      :agent_id,
      :amount,
      :bank_name,
      :account_number,
      :account_name,
      'pending'
  );

  INSERT INTO rider_transactions (
      delivery_agent_id,
      transaction_code,
      title,
      category,
      amount,
      is_credit,
      reference,
      status,
      description
  ) VALUES (
      :agent_id,
      :txn_code,
      'Balance Payout Requested',
      'payout',
      :amount,
      false,
      :payout_number,
      'pending',
      'Withdrawal from My Balance to registered bank account.'
  );
  ```

---

### 6.2. Transaction History Ledger (`TransactionHistoryPage`)
- **File**: [`lib/features/finance/presentation/pages/transaction_history_page.dart`](file:///c:/PROJECT/NoveXPS/lib/features/finance/presentation/pages/transaction_history_page.dart)

#### Function: Fetch Full Audit Ledger
- **Database Query**:
  ```sql
  SELECT * FROM rider_transactions 
  WHERE delivery_agent_id = :agent_id 
  ORDER BY created_at DESC;
  ```
- **Categories Filterable**: `All`, `Direct Transfers`, `Earnings`, `Payouts`, `Remittances`.
