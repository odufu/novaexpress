// Default Role-Based Curriculum & Certification Pathways for NovaXpress Academy

export const DEFAULT_COURSES = [
  {
    role_key: 'closer',
    role_title: 'Telesales Representative / Closer',
    certification_name: 'Certified Sales Person',
    badge_color: '#4F46E5',
    icon_name: 'Headphones',
    estimated_duration: '2.5 Hours',
    description: 'Master high-conversion customer verification calls, delivery address geo-normalization, product objection handling, and upsell package recommendations on NovaXpress.',
    modules: [
      {
        id: 'mod-closer-1',
        module_order: 1,
        title: 'Lead Intake & Address Geo-Normalization',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ', // Placeholder until custom NovaXpress recording is uploaded
        video_duration: '14 mins',
        objectives: [
          'Verify customer phone number and delivery location accurately',
          'Normalize address to landmark, local government area (LGA), and state',
          'Identify fake orders or incorrect contact numbers before booking',
          'Understand order confirmation status transitions in NovaXpress'
        ],
        transcript: `Welcome to Module 1 of the Certified Sales Person training track. As a NovaXpress Closer, you are the crucial first link in our fulfillment chain. Over 80% of delivery failures in Nigeria occur because of ambiguous street directions. In this session, we walk through our 3-point address verification framework: First, always confirm the customer will be at the delivery address on the agreed delivery date. Second, ask for a recognizable landmark—such as a bank, petrol station, or market junction—and note it in the special instructions field. Third, confirm the exact product bundle and COD cash amount expected so the recipient is prepared with exact funds upon the courier's arrival. By mastering this simple 2-minute call structure, your delivery success rate will exceed 92%.`,
        summary_markdown: `### Key Closer Best Practices
1. **The 3-Point Address Protocol**:
   - Confirm Recipient Availability on Delivery Day.
   - Record a Major Landmark (Petrol Station, Bank, School, Junction).
   - Reconfirm the Cash on Delivery (COD) Payable Amount.
2. **Address Normalization Checklist**:
   - State & LGA must match our official Distribution Center jurisdictions.
   - Never accept vague descriptions like "Along the express road".
3. **Status Code Standard**:
   - Move leads from \`UNCONFIRMED\` to \`CONFIRMED\` only after verbal consent.
   - If unreachable on call 1, schedule a callback within 2 hours.`,
        questions: [
          {
            id: 'q-closer-1',
            question_text: 'What is the primary reason for delivery failures that closers must mitigate during verification calls?',
            options: [
              'Slow internet connections in the warehouse',
              'Ambiguous address descriptions and unconfirmed recipient availability',
              'The rider arriving with wrong parcel stickers',
              'Excessive warehouse inventory levels'
            ],
            correct_option_index: 1,
            explanation: 'Accurate landmarks and confirming that the customer will be available on the delivery day prevents over 80% of delivery failures.'
          },
          {
            id: 'q-closer-2',
            question_text: 'When should an order status be moved to "CONFIRMED" in the NovaXpress system?',
            options: [
              'Immediately when the lead appears from Facebook ads',
              'After leaving a WhatsApp voicemail',
              'Only after verbal customer confirmation of the item, address landmark, and COD price',
              'When the rider picks up the item from the shelf'
            ],
            correct_option_index: 2,
            explanation: 'Orders must only be confirmed after direct customer verbal confirmation to eliminate fraudulent or accidental bookings.'
          },
          {
            id: 'q-closer-3',
            question_text: 'What should a Closer do if a customer asks to pay half price upon delivery?',
            options: [
              'Agree and deduct the difference from the rider',
              'Explain the fixed official package price and offer an approved smaller bundle if authorized',
              'Cancel the order without speaking further',
              'Tell the customer to negotiate with the courier'
            ],
            correct_option_index: 1,
            explanation: 'Prices are strictly fixed on NovaXpress. Negotiating at the doorstep is prohibited; closers can only offer pre-approved authorized package options.'
          }
        ]
      },
      {
        id: 'mod-closer-2',
        module_order: 2,
        title: 'UPG Package Deals & Upsell Conversion Protocols',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        video_duration: '18 mins',
        objectives: [
          'Master the NovaXpress UPG (Upsell Package Deals) feature',
          'Deliver compelling customer value propositions for multi-item packs',
          'Coordinate package adjustments without disrupting stock reservations',
          'Maintain high customer satisfaction and repeat purchase affinity'
        ],
        transcript: `In Module 2, we dive into NovaXpress UPG—our proprietary Upsell Package Deal system. When speaking with customers who ordered a single unit of health or beauty products, you have the opportunity to offer a 2-pack or 3-pack bundle at a high-value discount. In this video, we review the live order modal in NovaXpress: selecting the UPG dropdown, previewing the adjusted total amount, and saving the update. Note that the warehouse inventory immediately reserves the bundled quantities. Never submit a UPG modification unless the buyer has explicitly agreed to the new package price.`,
        summary_markdown: `### UPG Upsell Workflow
- **When to pitch**: Pitch after establishing trust and confirming the base interest.
- **Value framing**: Focus on full treatment duration or savings per bottle.
- **System Action**: Click the **UPG** badge on the closer portal to select the authorized tier.
- **Important**: System automatically updates invoice total and notifies the handling DC.`,
        questions: [
          {
            id: 'q-closer-4',
            question_text: 'What happens in the NovaXpress backend when a Closer selects an authorized UPG bundle for an order?',
            options: [
              'The order is cancelled and a new one must be manually keyed in',
              'The system automatically recalculates the invoice total and reserves additional stock at the assigned DC',
              'The rider receives a commission penalty',
              'The customer is automatically refunded'
            ],
            correct_option_index: 1,
            explanation: 'The UPG engine automatically cascades the new pricing, items, and inventory reservation straight to the handling DC.'
          }
        ]
      }
    ]
  },
  {
    role_key: 'rider',
    role_title: 'Fleet Delivery Courier / Rider',
    certification_name: 'Certified Mobile Operations',
    badge_color: '#F37021',
    icon_name: 'Smartphone',
    estimated_duration: '1.5 Hours',
    description: 'Master the Rider PDA mobile application, digital proof-of-delivery (POD) signatures, doorstep cash handling, and secure delivery OTP authentication.',
    modules: [
      {
        id: 'mod-rider-1',
        module_order: 1,
        title: 'Doorstep Delivery Protocols & Digital POD',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        video_duration: '12 mins',
        objectives: [
          'Verify customer identity using the 4-digit Delivery OTP',
          'Capture digital proof-of-delivery (POD) signatures on glass',
          'Take compliant parcel handover photos when requested',
          'Follow emergency contact protocols for customer unavailability'
        ],
        transcript: `Welcome couriers to the Certified Mobile Operations training course. The moment of parcel handover is where NovaXpress delivers on its customer promise. Upon arriving at the customer doorstep, greet the recipient professionally. Before unsealing the transit bag, verify the 4-digit Delivery OTP sent to their mobile phone. Once confirmed, collect the full COD cash or verify instant bank transfer. Finally, hand the PDA to the customer for their digital signature on glass. Never mark an order delivered before the funds are secured and the signature is captured.`,
        summary_markdown: `### Rider Standard Operating Procedures (SOP)
1. **Security Handover**:
   - Collect Cash / Verify Transfer BEFORE handing over open package.
   - Enter Customer 4-digit OTP into Rider PDA.
2. **Proof of Delivery (POD)**:
   - Digital signature captured on PDA screen.
   - Clear photo of parcel at doorstep if non-contact.
3. **Cash Holding Rule**:
   - Deposit collected cash to DC Finance daily before the 6:00 PM cutoff.`,
        questions: [
          {
            id: 'q-rider-1',
            question_text: 'When is a rider permitted to mark an order as "Delivered" on the PDA?',
            options: [
              'While still in transit to save time',
              'Only after customer OTP verification, full payment receipt, and digital signature capture',
              'Whenever the customer promises to transfer money tomorrow',
              'When the parcel is dropped with a security guard without notice'
            ],
            correct_option_index: 1,
            explanation: 'Payment, OTP, and digital signature must always precede marking an order as delivered.'
          },
          {
            id: 'q-rider-2',
            question_text: 'What should a rider do if a customer insists on opening and inspecting a parcel before paying COD cash?',
            options: [
              'Walk away and cancel the delivery',
              'Politely explain NovaXpress COD policy: payment is required prior to unsealing, but 100% money-back guarantee applies through merchant support',
              'Let them take the product inside their house while you wait outside',
              'Accept personal belongings as collateral'
            ],
            correct_option_index: 1,
            explanation: 'Explaining company policy respectfully protects both courier safety and merchant merchandise.'
          }
        ]
      }
    ]
  },
  {
    role_key: 'dc_operations',
    role_title: 'DC Dispatch & Hub Operations',
    certification_name: 'Certified Dispatch Operations',
    badge_color: '#059669',
    icon_name: 'Truck',
    estimated_duration: '2 Hours',
    description: 'Master Distribution Center parcel scanning, regional route clustering, rider run-sheet dispatching, and return-to-origin (RTO) triage.',
    modules: [
      {
        id: 'mod-ops-1',
        module_order: 1,
        title: 'Hub Sorting, Waybill Barcodes & Rider Assignment',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        video_duration: '16 mins',
        objectives: [
          'Execute barcode waybill scan-in for arriving line-haul crates',
          'Sort orders by LGA, transit cluster, and designated rider zones',
          'Generate and verify digital rider run-sheets',
          'Handle damaged inbounds and trigger instant merchant alerts'
        ],
        transcript: `Welcome to Certified Dispatch Operations. The dispatch hub is the engine room of NovaXpress. Every morning, hundreds of parcels arrive from national trunking. In this module, you learn the 3-step intake process: Scan the master waybill barcode, verify package weight and packaging integrity, and assign the parcel to the optimal zone courier using our smart route clustering tool in the DC Console.`,
        summary_markdown: `### Dispatch Operational Flow
1. **Inbound Scan**: Scan each waybill into the DC station.
2. **Cluster & Allocate**: Group parcels by LGA and assign to active riders based on rider capacity limits.
3. **Dispatch Confirmation**: Both rider and dispatcher verify item count before rider leaves the station.`,
        questions: [
          {
            id: 'q-ops-1',
            question_text: 'What must a DC Dispatch Officer do if an arriving parcel shows signs of damage or leakage?',
            options: [
              'Tape it up and give it to a rider anyway',
              'Flag the order as "Damaged Inbound", upload photos in the DC console, and isolate the item in the return bin',
              'Deliver it to the nearest customer free of charge',
              'Throw the parcel away'
            ],
            correct_option_index: 1,
            explanation: 'Immediate documentation of damaged goods protects the company and triggers swift merchant notification.'
          }
        ]
      }
    ]
  },
  {
    role_key: 'dc_stock_admin',
    role_title: 'DC Stock & Inventory Officer',
    certification_name: 'Certified Inventory Manager',
    badge_color: '#0284C7',
    icon_name: 'Boxes',
    estimated_duration: '2 Hours',
    description: 'Master warehouse inventory ledger management, inter-DC stock transfer handshakes, bin/shelf allocations, and stock audit discrepancies.',
    modules: [
      {
        id: 'mod-stock-1',
        module_order: 1,
        title: 'Warehouse Bin Allocations & Inter-DC Transfers',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        video_duration: '15 mins',
        objectives: [
          'Maintain 100% stock count accuracy across SKU categories',
          'Execute digital 2-way verification on inter-hub stock transfers',
          'Record damaged returns and quarantined units',
          'Conduct weekly cycle counts using the DC Stock module'
        ],
        transcript: `Welcome to Certified Inventory Manager. At NovaXpress, every item in our warehouses belongs to merchant partners who trust us with their livelihood. In this video, we review how to receive stock, assign SKUs to specific bin locations, and process inter-DC transfers using our two-way cryptographic transfer handshake. Both shipping and receiving stock managers must verify counts digitally.`,
        summary_markdown: `### Stock Management Core Rules
- **Physical vs System Count**: Must match with 0% unexplained tolerance.
- **Two-Way Transfer**: Transfers in transit must remain in \`IN_TRANSIT\` state until receiving DC scans arrival.
- **Quarantine Bin**: Expired or damaged stock must never mix with pickable items.`,
        questions: [
          {
            id: 'q-stock-1',
            question_text: 'When is an Inter-DC Stock Transfer officially added to the receiving warehouse inventory?',
            options: [
              'When the sender clicks send',
              'When the truck leaves the sending city',
              'Only when the receiving DC Stock Officer scans and confirms receipt in the DC Console',
              'After 24 hours automatically'
            ],
            correct_option_index: 2,
            explanation: 'NovaXpress enforces a strict two-way handshake; stock only transfers ownership once scanned at the destination.'
          }
        ]
      }
    ]
  },
  {
    role_key: 'dc_finance_admin',
    role_title: 'DC Finance Operations Officer',
    certification_name: 'Certified Finance Operations',
    badge_color: '#D97706',
    icon_name: 'Wallet',
    estimated_duration: '2.5 Hours',
    description: 'Master daily courier cash reconciliation, bank deposit slip verification, cash-in-transit limits, and remittance dispute clearance.',
    modules: [
      {
        id: 'mod-fin-1',
        module_order: 1,
        title: 'Rider Remittance Reconciliation & Bank Deposit Protocol',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        video_duration: '17 mins',
        objectives: [
          'Audit rider cash collections against PDA delivered order totals',
          'Identify and resolve cash shortages or unremitted funds',
          'Process official bank deposit vouchers and attach teller proofs',
          'Approve or dispute rider end-of-day remittance submissions'
        ],
        transcript: `Welcome to Certified Finance Operations. As DC Finance Officer, you protect the cash flow of our merchant partners. Every evening, couriers return with cash collected from successful deliveries. In this training, we review the DC Finance portal: pulling up the rider remittance modal, comparing cash handed over against PDA recorded totals, and approving verified remittances. If a discrepancy exists, flag it immediately with a remittance dispute.`,
        summary_markdown: `### DC Finance Checklist
1. **Cash Count Verification**: Count all cash in front of the courier.
2. **Match PDA Totals**: COD collected must equal physical cash + verified direct bank transfers.
3. **Vault & Bank Deposit**: Cash exceeding daily threshold must be banked with stamped deposit slips uploaded before 10:00 AM next business day.`,
        questions: [
          {
            id: 'q-fin-1',
            question_text: 'What action should the DC Finance Officer take if a rider remits ₦10,000 less than their PDA recorded COD balance?',
            options: [
              'Approve the remittance and forget about it',
              'Flag the remittance as "Disputed / Shortage", log the exact deficit, and notify the DC Manager',
              'Pay the difference from company petty cash',
              'Delete the orders from the system'
            ],
            correct_option_index: 1,
            explanation: 'All deficits must be formally recorded as shortages to preserve ledger integrity and ensure prompt recovery.'
          }
        ]
      }
    ]
  },
  {
    role_key: 'accountant',
    role_title: 'National General Accountant',
    certification_name: 'Certified Accountant',
    badge_color: '#7C3AED',
    icon_name: 'Calculator',
    estimated_duration: '3 Hours',
    description: 'Master national ledger settlements, merchant COD payout batches, delivery tariff fee calculations, and corporate bank audits.',
    modules: [
      {
        id: 'mod-acc-1',
        module_order: 1,
        title: 'National COD Settlements & Merchant Payout Batches',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        video_duration: '20 mins',
        objectives: [
          'Calculate net merchant settlements after deducting delivery tariffs and platform fees',
          'Generate and authorize automated bank payout batches via Paystack/Monnify',
          'Reconcile multi-DC vault deposits against corporate settlement accounts',
          'Export audit-grade financial statements and merchant remittances'
        ],
        transcript: `Welcome to the Certified Accountant track. You oversee nationwide financial integrity across all 36 states. In this module, you learn how NovaXpress automates merchant settlements: Net Payout = Total COD Collected - (Shipping Fee + Packaging Fee + Tariff Surcharges). You will practice generating automated batch payment instructions, inspecting bank reconciliation reports, and resolving merchant account disputes.`,
        summary_markdown: `### Accounting Formula & Payout Rules
- **Net Merchant Settlement**: \`COD Collected - Delivery Tariff - Return Fees\`.
- **Settlement Schedule**: Tuesday and Thursday national payout runs.
- **Bank Reconciliations**: All multi-hub deposits must match bank statement balances before payouts execute.`,
        questions: [
          {
            id: 'q-acc-1',
            question_text: 'How is the final merchant payout amount calculated in the NovaXpress settlement engine?',
            options: [
              'Gross COD revenue minus delivery fees, return fees, and authorized platform tariffs',
              'Total orders multiplied by rider commission',
              'Fixed payment regardless of collected funds',
              'Whatever the client requests on WhatsApp'
            ],
            correct_option_index: 0,
            explanation: 'Settlements mathematically deduct all contractual tariffs and shipping costs from verified COD funds collected.'
          }
        ]
      }
    ]
  },
  {
    role_key: 'dc_manager',
    role_title: 'Distribution Center Master Manager',
    certification_name: 'Certified Logistics Manager',
    badge_color: '#1E3A8A',
    icon_name: 'ShieldCheck',
    estimated_duration: '3.5 Hours',
    description: 'Master full distribution hub governance: staff performance KPIs, station capacity planning, vault security, and regional SLA compliance.',
    modules: [
      {
        id: 'mod-mgr-1',
        module_order: 1,
        title: 'Hub Governance, SLA Compliance & Leadership Protocols',
        video_url: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        video_duration: '22 mins',
        objectives: [
          'Enforce 95%+ first-attempt delivery success rate across assigned LGA zones',
          'Manage station team rosters (couriers, dispatch officers, stock admins, finance officers)',
          'Maintain security protocols for warehouse stock vaults and cash reserves',
          'Resolve customer and merchant escalations with speed and professionalism'
        ],
        transcript: `Welcome to Certified Logistics Manager. As Distribution Center Manager, the entire hub reports to you. You are accountable for stock security, dispatch speed, rider discipline, and cash governance. In this module, we review the Grand DC Console: reading the morning KPI pulse, monitoring active couriers on the live map, inspecting warehouse capacity, and leading high-performance logistics operations.`,
        summary_markdown: `### Hub Management Pillars
1. **Safety & Security**: Strict access control into the warehouse storage vaults.
2. **Speed & SLA**: 95%+ parcels delivered within 24 hours of hub arrival.
3. **Financial Integrity**: Zero tolerance for unbanked cash or unremitted COD.`,
        questions: [
          {
            id: 'q-mgr-1',
            question_text: 'What is the target first-attempt delivery SLA for a NovaXpress Distribution Center?',
            options: [
              '50%',
              '70%',
              '95% or higher within 24 hours of hub arrival',
              'Delivery speed does not matter as long as parcels arrive eventually'
            ],
            correct_option_index: 2,
            explanation: 'NovaXpress guarantees 95%+ first-attempt success within 24 hours for intrastate parcels.'
          }
        ]
      }
    ]
  }
];

