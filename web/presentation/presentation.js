/**
 * NoveXPS Master Interactive Presentation — Logic Engine
 * Features: Deck State Machine, Role Switcher, SVG Diagram Inspection,
 * Live Infrastructure & ROI Cost Calculator, Rule Search Engine.
 */

(function () {
  'use strict';

  // --- State ---
  const state = {
    currentSlideIndex: 0,
    totalSlides: 8,
    activeRole: 'hq',
    isFullScreen: false,
    viewMode: 'deck', // 'deck' | 'document' | 'calculator'
  };

  const slides = [
    { id: 'slide-hero', title: 'Executive Overview' },
    { id: 'slide-matrix', title: 'Operational Matrix & Rules' },
    { id: 'slide-roles', title: 'Role Architecture' },
    { id: 'slide-workflows', title: 'End-to-End Operational Flows' },
    { id: 'slide-payments', title: 'Payments & Financial Engineering' },
    { id: 'slide-costing', title: 'Infrastructure & Server Charges' },
    { id: 'slide-calculator', title: 'Live ROI & Cost Calculator' },
    { id: 'slide-architecture', title: 'Technical Stack & Integrity' }
  ];

  // --- DOM Elements ---
  const el = {
    progressBar: document.getElementById('deck-progress-bar'),
    slideIndicator: document.getElementById('slide-indicator'),
    prevBtn: document.getElementById('deck-prev-btn'),
    nextBtn: document.getElementById('deck-next-btn'),
    slides: document.querySelectorAll('.slide'),
    navTabs: document.querySelectorAll('.nav-tab-btn'),
    roleTabs: document.querySelectorAll('.role-tab'),
    rolePanels: document.querySelectorAll('.role-content-panel'),
    searchOverlay: document.getElementById('search-overlay'),
    searchInput: document.getElementById('search-input'),
    searchResults: document.getElementById('search-results'),
    // Calculator Elements
    calcOrders: document.getElementById('calc-orders'),
    calcOrdersVal: document.getElementById('calc-orders-val'),
    calcDcs: document.getElementById('calc-dcs'),
    calcDcsVal: document.getElementById('calc-dcs-val'),
    calcRiders: document.getElementById('calc-riders'),
    calcRidersVal: document.getElementById('calc-riders-val'),
    calcAov: document.getElementById('calc-aov'),
    calcAovVal: document.getElementById('calc-aov-val'),
    calcDirectPct: document.getElementById('calc-direct-pct'),
    calcDirectPctVal: document.getElementById('calc-direct-pct-val'),
    // Calc Outputs
    resGmv: document.getElementById('res-gmv'),
    resDeliveryRevenue: document.getElementById('res-delivery-revenue'),
    resRiderPayouts: document.getElementById('res-rider-payouts'),
    resServerCosts: document.getElementById('res-server-costs'),
    resGatewayFees: document.getElementById('res-gateway-fees'),
    resSmsFees: document.getElementById('res-sms-fees'),
    resNetProfit: document.getElementById('res-net-profit'),
    resMarginPct: document.getElementById('res-margin-pct'),
  };

  // --- Formatters ---
  const fmtNaira = (val) => '₦' + Math.round(val).toLocaleString('en-NG');
  const fmtUsd = (val) => '$' + Math.round(val).toLocaleString('en-US');

  // --- Slide Navigation ---
  function goToSlide(index) {
    if (index < 0 || index >= state.totalSlides) return;
    state.currentSlideIndex = index;

    // Update active class on slides
    el.slides.forEach((s, idx) => {
      s.classList.toggle('active', idx === index);
    });

    // Update progress bar
    const pct = ((index + 1) / state.totalSlides) * 100;
    if (el.progressBar) el.progressBar.style.width = pct + '%';
    if (el.slideIndicator) {
      el.slideIndicator.textContent = `${index + 1} / ${state.totalSlides} • ${slides[index].title}`;
    }

    // Update buttons
    if (el.prevBtn) el.prevBtn.disabled = index === 0;
    if (el.nextBtn) el.nextBtn.disabled = index === state.totalSlides - 1;

    // Scroll to top of main container
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function nextSlide() {
    if (state.currentSlideIndex < state.totalSlides - 1) {
      goToSlide(state.currentSlideIndex + 1);
    }
  }

  function prevSlide() {
    if (state.currentSlideIndex > 0) {
      goToSlide(state.currentSlideIndex - 1);
    }
  }

  // --- Role Switcher ---
  function setRole(roleKey) {
    state.activeRole = roleKey;
    el.roleTabs.forEach(tab => {
      tab.classList.toggle('active', tab.dataset.role === roleKey);
    });
    el.rolePanels.forEach(panel => {
      panel.classList.toggle('active', panel.id === `role-panel-${roleKey}`);
    });
  }

  // --- Live ROI & Cloud Cost Calculator Engine ---
  function updateCalculator() {
    if (!el.calcOrders) return;

    const dailyOrders = parseInt(el.calcOrders.value, 10);
    const dcs = parseInt(el.calcDcs.value, 10);
    const riders = parseInt(el.calcRiders.value, 10);
    const aov = parseInt(el.calcAov.value, 10);
    const directTransferPct = parseInt(el.calcDirectPct.value, 10);

    // Update label displays
    el.calcOrdersVal.textContent = dailyOrders.toLocaleString() + ' / day';
    el.calcDcsVal.textContent = dcs.toString() + ' Hubs';
    el.calcRidersVal.textContent = riders.toString() + ' Active';
    el.calcAovVal.textContent = fmtNaira(aov);
    el.calcDirectPctVal.textContent = directTransferPct.toString() + '%';

    // Monthly computations (30 days basis)
    const monthlyOrders = dailyOrders * 30;
    const monthlyGmv = monthlyOrders * aov;

    // Platform delivery fee charged to merchants/clients (avg ₦2,200 - ₦2,800 depending on volume, assume ₦2,500)
    const avgDeliveryFeePerOrder = 2500;
    const deliveryRevenue = monthlyOrders * avgDeliveryFeePerOrder;

    // Personnel Compensation (Commission ₦1,000 + Fuel Allowance ₦1,500) = ₦2,500 total payout liability
    // In distributed inventory models, merchant subsidizes or NovaExpress charges delivery fee + commission spread
    const commissionPerOrder = 1000;
    const transportPerOrder = 750; // blent average across urban and inter-hub dispatch
    const riderTotalPayouts = monthlyOrders * (commissionPerOrder + transportPerOrder);

    // Infrastructure & Server Charges:
    // Base Supabase Pro: $25 (₦38,750)
    // Supabase Compute Add-on:
    // < 1,000/day: Micro $10/mo
    // 1,000 - 10,000/day: Small $60/mo
    // 10,000 - 50,000/day: Medium/Large $160 - $320/mo
    let supabaseComputeUsd = 25; // Pro base
    if (dailyOrders <= 500) {
      supabaseComputeUsd += 10;
    } else if (dailyOrders <= 3000) {
      supabaseComputeUsd += 60;
    } else if (dailyOrders <= 15000) {
      supabaseComputeUsd += 160;
    } else {
      supabaseComputeUsd += 350;
    }

    // Realtime & Connection Pooling (Supavisor) + DB Storage
    const storageAndEgressUsd = Math.min(250, 15 + Math.round(monthlyOrders * 0.002));
    const totalInfraUsd = supabaseComputeUsd + storageAndEgressUsd;
    const fxRateNaira = 1550; // ₦ / USD
    const serverCostNaira = totalInfraUsd * fxRateNaira;

    // Payment Gateway Fees:
    // Direct Bank Transfer (Monnify): 0.75% capped at ₦200 per transaction
    // Card / COD: COD has 0% gateway fee (cash handling). Paystack is 1.5% capped at ₦2,000.
    const directTransferOrders = monthlyOrders * (directTransferPct / 100);
    const cardOrders = monthlyOrders * 0.15; // 15% card
    const monnifyFee = directTransferOrders * Math.min(200, aov * 0.0075);
    const paystackFee = cardOrders * Math.min(2000, aov * 0.015);
    const totalGatewayFees = monnifyFee + paystackFee;

    // SMS & WhatsApp telemetry alerts (Termii ~₦3.50/alert, 2 alerts per delivery)
    const smsCharges = monthlyOrders * 2 * 3.5;

    // Net Operating Margin Calculation
    // Gross Income = Delivery Revenue + Merchant Package Storage/Fulfillment Fees (approx ₦500/order)
    const fulfillmentFeePerOrder = 400;
    const grossPlatformRevenue = deliveryRevenue + (monthlyOrders * fulfillmentFeePerOrder);

    const totalOpEx = riderTotalPayouts + serverCostNaira + totalGatewayFees + smsCharges;
    const netProfit = grossPlatformRevenue - totalOpEx;
    const marginPct = ((netProfit / grossPlatformRevenue) * 100).toFixed(1);

    // Update Output Elements
    el.resGmv.textContent = fmtNaira(monthlyGmv);
    el.resDeliveryRevenue.textContent = fmtNaira(grossPlatformRevenue);
    el.resRiderPayouts.textContent = fmtNaira(riderTotalPayouts);
    el.resServerCosts.textContent = `${fmtNaira(serverCostNaira)} (${fmtUsd(totalInfraUsd)})`;
    el.resGatewayFees.textContent = fmtNaira(totalGatewayFees);
    el.resSmsFees.textContent = fmtNaira(smsCharges);
    el.resNetProfit.textContent = fmtNaira(netProfit);
    el.resMarginPct.textContent = `${marginPct}% Margin`;
  }

  // --- Rule Search Engine ---
  const rulesData = [
    { id: 'BR-001', text: 'Every delivery belongs to a client.' },
    { id: 'BR-002', text: 'Every delivery has a fulfillment type (Client Package or Distributed Inventory).' },
    { id: 'BR-003', text: 'Every delivery has a payment type (POD or Non-POD).' },
    { id: 'BR-004', text: 'POD deliveries require collection tracking.' },
    { id: 'BR-005', text: 'POD collections require reconciliation.' },
    { id: 'BR-006', text: 'Successful deliveries may generate client charges.' },
    { id: 'BR-007', text: 'Failed deliveries may generate client charges according to the client agreement.' },
    { id: 'BR-008', text: 'Failed distributed-inventory deliveries require stock return to warehouse.' },
    { id: 'BR-009', text: 'Returned stock must be verified by the receiving DC.' },
    { id: 'BR-010', text: 'Delivery personnel compensation is configuration-driven.' },
    { id: 'BR-011', text: 'PDA and Rider compensation may differ.' },
    { id: 'BR-012', text: 'Salary-based personnel may have no commission.' },
    { id: 'BR-013', text: 'Commission-based personnel accumulate earnings in their ledger.' },
    { id: 'BR-014', text: 'Historical transactions retain the rate that was applied when the transaction occurred.' },
    { id: 'BR-015', text: 'Agents cannot alter rates.' },
    { id: 'BR-016', text: 'POS fees are separate financial transactions.' },
    { id: 'BR-017', text: 'Remittances require verification by DC Manager.' },
    { id: 'BR-018', text: 'Financial variances must be visible in real time.' },
    { id: 'BR-019', text: 'Inventory discrepancies require resolution before close-of-day.' },
    { id: 'BR-020', text: 'Every important financial and inventory action must be auditable.' },
    { id: 'BR-021', text: 'Direct bank transfer orders generate dynamic Monnify virtual accounts specific to that order.' },
    { id: 'BR-022', text: 'Direct transfers do not place cash in rider physical custody (zero cash liability).' },
    { id: 'BR-023', text: 'Monnify direct transfer deliveries automatically credit rider "My Balance" ledger with commission and fuel allowance.' },
    { id: 'BR-024', text: 'Riders can request payout of accrued "My Balance" to personal bank accounts, subject to DC Finance approval.' },
  ];

  function openSearch() {
    if (el.searchOverlay) {
      el.searchOverlay.classList.add('active');
      if (el.searchInput) {
        el.searchInput.value = '';
        el.searchInput.focus();
      }
      renderSearchResults('');
    }
  }

  function closeSearch() {
    if (el.searchOverlay) el.searchOverlay.classList.remove('active');
  }

  function renderSearchResults(query) {
    if (!el.searchResults) return;
    const q = query.toLowerCase().trim();
    const matches = rulesData.filter(r => r.id.toLowerCase().includes(q) || r.text.toLowerCase().includes(q));

    if (matches.length === 0) {
      el.searchResults.innerHTML = `<div style="padding:1rem;color:var(--text-muted);font-size:0.9rem;">No matching business rules found.</div>`;
      return;
    }

    el.searchResults.innerHTML = matches.map(m => `
      <div class="search-result-item" data-rule="${m.id}">
        <span style="color:var(--accent-emerald);font-family:var(--font-mono);font-weight:700;font-size:0.8rem;margin-right:0.5rem;">${m.id}</span>
        <span style="color:var(--text-primary);font-size:0.88rem;">${m.text}</span>
      </div>
    `).join('');
  }

  // --- Fullscreen Toggle ---
  function toggleFullScreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(err => console.log(err));
      state.isFullScreen = true;
    } else {
      if (document.exitFullscreen) document.exitFullscreen();
      state.isFullScreen = false;
    }
  }

  // --- View Mode Toggle ---
  function setViewMode(mode) {
    state.viewMode = mode;
    el.navTabs.forEach(tab => {
      tab.classList.toggle('active', tab.dataset.mode === mode);
    });

    const deckController = document.querySelector('.deck-controller');

    if (mode === 'deck') {
      if (deckController) deckController.style.display = 'flex';
      el.slides.forEach((s, idx) => {
        s.classList.toggle('active', idx === state.currentSlideIndex);
      });
    } else if (mode === 'all') {
      // Show all slides continuously as a single-page document
      if (deckController) deckController.style.display = 'none';
      el.slides.forEach(s => s.classList.add('active'));
    } else if (mode === 'calc') {
      if (deckController) deckController.style.display = 'flex';
      goToSlide(6); // Jump directly to calculator slide
    } else if (mode === 'rules') {
      if (deckController) deckController.style.display = 'flex';
      goToSlide(1); // Jump directly to matrix & rules slide
    }
  }

  // --- Keyboard Shortcuts ---
  document.addEventListener('keydown', (e) => {
    // If search open, Esc closes
    if (el.searchOverlay && el.searchOverlay.classList.contains('active')) {
      if (e.key === 'Escape') closeSearch();
      return;
    }

    if (e.key === 'ArrowRight' || e.key === 'PageDown' || e.key === ' ') {
      e.preventDefault();
      nextSlide();
    } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
      e.preventDefault();
      prevSlide();
    } else if (e.key === 'f' || e.key === 'F') {
      toggleFullScreen();
    } else if (e.key === 's' || e.key === 'S' || (e.ctrlKey && e.key === 'k')) {
      e.preventDefault();
      openSearch();
    } else if (e.key === '1') goToSlide(0);
    else if (e.key === '2') goToSlide(1);
    else if (e.key === '3') goToSlide(2);
    else if (e.key === '4') goToSlide(3);
    else if (e.key === '5') goToSlide(4);
    else if (e.key === '6') goToSlide(5);
    else if (e.key === '7') goToSlide(6);
    else if (e.key === '8') goToSlide(7);
  });

  // --- Attach Event Listeners ---
  function init() {
    // Nav buttons
    if (el.prevBtn) el.prevBtn.addEventListener('click', prevSlide);
    if (el.nextBtn) el.nextBtn.addEventListener('click', nextSlide);

    // Nav tabs
    el.navTabs.forEach(tab => {
      tab.addEventListener('click', () => setViewMode(tab.dataset.mode));
    });

    // Role tabs
    el.roleTabs.forEach(tab => {
      tab.addEventListener('click', () => setRole(tab.dataset.role));
    });

    // Calculator inputs
    [el.calcOrders, el.calcDcs, el.calcRiders, el.calcAov, el.calcDirectPct].forEach(inp => {
      if (inp) inp.addEventListener('input', updateCalculator);
    });

    // Search input
    if (el.searchInput) {
      el.searchInput.addEventListener('input', (e) => renderSearchResults(e.target.value));
    }
    if (el.searchOverlay) {
      el.searchOverlay.addEventListener('click', (e) => {
        if (e.target === el.searchOverlay) closeSearch();
      });
    }

    // Fullscreen btn
    const fsBtn = document.getElementById('btn-fullscreen');
    if (fsBtn) fsBtn.addEventListener('click', toggleFullScreen);

    // Search trigger btn
    const sBtn = document.getElementById('btn-search-trigger');
    if (sBtn) sBtn.addEventListener('click', openSearch);

    // Initial render
    goToSlide(0);
    updateCalculator();
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
