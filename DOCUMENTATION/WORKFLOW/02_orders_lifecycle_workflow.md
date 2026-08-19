# Module 2: End-to-End Orders Lifecycle & Delivery Workflows 📦📍

## 1. Overview & Fulfillment Scenarios
The **Orders Module** is the core operational workspace for NovaExpress field agents across Nigeria. NovaExpress operates under **three distinct fulfillment scenarios** depending on client requirements and operational speed:

---

### 🏬 Fulfillment Scenario Matrix

| Scenario Type | Operational Flow | Inventory Allocation Model | Primary Use Case |
| :--- | :--- | :--- | :--- |
| **Scenario 1: Standard Order-First Pickup** | Order Placed ➔ Assigned to PDA ➔ Pickup Package at DC ➔ Deliver to Customer | Package specific to order picked up at DC after order creation. | Standard customer orders, customized packages & non-bulk client goods. |
| **Scenario 2: Failed Delivery & Exception Return** | Out for Delivery ➔ Delivery Attempt Fails ➔ Log Reason ➔ Reattempt / DC Return | Package retained in vehicle for retry or physically returned to DC. | Unreachable customers, wrong address, payment refused, or customer reschedule. |
| **Scenario 3: Major Client Pre-Circulated Float** *(Core High-Volume Model)* | Bulk Float Stock Issued to Vehicles ➔ Standing Buffer ➔ On-Demand Instant Order Matching ➔ Immediate Field Delivery | Bulk physical stock loaded into PDA vehicles **BEFORE** orders arrive. Orders matched on the fly. | **Major Client Products** (*Grazer Herbal Tea, Respira, Alpha Man*). Enables instant same-hour delivery without returning to DC! |

---

## 2. Master Order & Float Stock State Machine Diagram

```mermaid
stateDiagram-v2
    direction TB
    
    state "Scenario 1 & 2: Order-First Fulfillment" as S1 {
        [*] --> Assigned: Order Dispatched by Admin
        Assigned --> ReadyForCollection: Package Ready at DC
        ReadyForCollection --> Collected: Agent Scans Package at DC (ScanToCollectPage)
        Collected --> OutForDelivery: In Transit on Vehicle
    }
    
    state "Scenario 3: Major Client Pre-Circulated Float Model" as S3 {
        [*] --> BulkDCFloat: DC Issues Bulk Float Stock to PDA Vehicle
        BulkDCFloat --> VehicleFloatingBuffer: Held in Vehicle Stock (Available Balance)
        
        state "On-Demand Order Arrival" as OrderMatch {
            VehicleFloatingBuffer --> InstantMatchedOrder: New Client Order Matched to Nearby PDA
            InstantMatchedOrder --> OutForDelivery: Auto-Allocated from Floating Stock (Allocated Balance)
        }
    }
    
    state "Delivery Completion & Exception Handling" as DeliveryPhase {
        OutForDelivery --> Delivered: Successful Handover & POD Cash Collected (ConfirmDeliveryPodPage)
        OutForDelivery --> Failed: Delivery Attempt Failed (LogDeliveryFailurePage)
        
        Failed --> CallBack: Reattempt Scheduled with Customer
        CallBack --> OutForDelivery: Next Route Cycle
        
        Failed --> ReturnedToDC: Return Initiated
        ReturnedToDC --> BulkDCFloat: Stock Re-reconciled at DC
    }

    Delivered --> [*]: Cash Remitted & Vehicle Stock Deducted
```

---

## 3. Detailed Workflows by Scenario

### Scenario 1: Standard Order-First Fulfillment Workflow
1. **Order Dispatched**: Central admin/DC assigns an order (`assigned`) to the PDA.
2. **DC Pickup (`ScanToCollectPage`)**:
   - Agent arrives at DC, scans package QR code or enters tracking number (e.g. `#TRK-8924`).
   - Taps **CONFIRM INTAKE & RECEIVE STOCK**.
   - Order status moves to `in_transit`. Physical stock transfers from DC Warehouse to Agent Vehicle.
3. **Delivery & Handover (`ConfirmDeliveryPodPage`)**:
   - Agent delivers package to customer, collects POD cash (₦), and checks **Customer Confirmed Receipt**.
   - Order status moves to `delivered`. Physical stock is deducted.

---

### Scenario 2: Failed Delivery & Reattempt / Return Workflow
1. **Initiate Exception (`LogDeliveryFailurePage`)**:
   - Agent taps **LOG FAILURE / EXCEPTION** on `OrderDetailPage`.
2. **Select Reason & Enter Notes**:
   - Select reason card (*Customer Unavailable*, *Address Incorrect*, *Payment Refused*, *Package Damaged*).
   - Enter detailed notes or quick chip tags (*Gate locked*, *Security denied entry*).
3. **Select Resolution Path**:
   - **Reattempt Later**: Order status becomes `call_back`. Package stays in vehicle float for next run.
   - **Return to DC**: Order status becomes `failed` / `failed_return`. Physical package returned to DC cashier/warehouse for stock credit.

---

### Scenario 3: Major Client Pre-Circulated Floating Stock Fulfillment Workflow *(Major Client Model)*

```mermaid
sequenceDiagram
    autonumber
    actor PDA as Field Agent (PDA)
    participant Float as Vehicle Floating Stock
    participant Sys as Central Order System
    participant Cust as Customer

    Note over PDA, Float: MORNING BULK FLOAT INTAKE
    PDA->>Sys: Receive Bulk Floating Stock from DC (e.g. 20 Grazer, 10 Respira)
    Sys->>Float: Credit Available Vehicle Float Balance (Quantity Held = 30)

    Note over Sys, Cust: ON-DEMAND FIELD ORDER MATCHING
    Cust->>Sys: Place Order for 3 Grazer Herbal Tea (POD ₦45,000)
    Sys->>Sys: Identify Nearby PDA Holding Required Floating Stock
    Sys->>PDA: Instantly Match & Assign Order (#NEX-9902) to PDA
    Sys->>Float: Reserve 3 Units from Available Float to Allocated Float

    Note over PDA, Cust: IMMEDIATE FIELD DISPATCH
    PDA->>PDA: View Instant Matched Order on Mobile Workspace
    PDA->>Cust: Drive directly to Customer Address (No DC detour needed!)
    PDA->>Cust: Hand over 3 Physical Units & Collect ₦45,000 POD
    PDA->>Sys: Confirm POD Delivery (ConfirmDeliveryPodPage)
    Sys->>Float: Deduct 3 Units from Allocated & Vehicle Total Stock
```

#### Step-by-Step Scenario 3 Operational Instructions:
1. **Morning Bulk Float Intake**:
   - Field agents load bulk quantities of major client SKUs (*Grazer Herbal Tea, Respira, Alpha Man*) into their delivery vehicles at start-of-day.
   - **App Display (`StockPage`)**:
     - `TOTAL HELD`: Total physical units loaded in vehicle (e.g. `30 Units`).
     - `AVAILABLE`: Unallocated floating buffer ready for new on-demand orders (e.g. `18 Units`).
     - `ALLOCATED`: Reserved for orders currently dispatched (e.g. `12 Units`).
2. **On-Demand Field Order Matching**:
   - When a major client customer places an order while the PDA is in the field, the central system matches the order directly to the nearby PDA carrying the required floating stock.
   - The PDA receives a push alert: **New Matched Order #NEX-9902 Assigned from Vehicle Float**.
3. **Immediate Field Fulfillment**:
   - The PDA opens `OrderDetailPage` and proceeds directly to customer delivery without returning to the DC.
   - Upon completing delivery (`ConfirmDeliveryPodPage`), the 3 physical units automatically deduct from `ALLOCATED` and `TOTAL HELD` stock, while POD cash collected updates the **Unremitted Cash Balance (₦)**.
