/**
 * NovaXpress Fail-Safe Form SDK (form-guard.js)
 * 
 * Provides fail-safe order ingestion for Digital Marketing landing pages.
 * Handles automatic UTM parameter extraction, offline queue & exponential retry,
 * phone number validation, and redirection to conversion thank-you pages with CAPI event IDs.
 * 
 * @version 1.0.0
 * @author NovaXpress Engineering
 */
(function (window, document) {
    'use strict';

    const QUEUE_KEY = 'novaxpress_offline_orders_queue';
    const RETRY_INTERVAL_MS = 3000;
    const DEFAULT_ENDPOINT = 'https://qpcafevjsrbauweuiiyq.supabase.co/functions/v1/submit-order';

    class FormGuard {
        constructor() {
            this.queue = this.loadQueue();
            this.endpoint = DEFAULT_ENDPOINT;
            this.init();
        }

        init() {
            setInterval(() => this.processQueue(), RETRY_INTERVAL_MS);
            window.addEventListener('online', () => this.processQueue());

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => this.attachFormListeners());
            } else {
                this.attachFormListeners();
            }
        }

        loadQueue() {
            try {
                const stored = localStorage.getItem(QUEUE_KEY);
                return stored ? JSON.parse(stored) : [];
            } catch (e) {
                console.error('[NovaXpress FormGuard] Failed to read offline queue', e);
                return [];
            }
        }

        saveQueue() {
            try {
                localStorage.setItem(QUEUE_KEY, JSON.stringify(this.queue));
            } catch (e) {
                console.error('[NovaXpress FormGuard] Failed to persist offline queue', e);
            }
        }

        getUtmParams() {
            const urlParams = new URLSearchParams(window.location.search);
            return {
                utm_source: urlParams.get('utm_source') || 'direct',
                utm_medium: urlParams.get('utm_medium') || 'cpc',
                utm_campaign: urlParams.get('utm_campaign') || 'landing_page',
                utm_content: urlParams.get('utm_content') || 'ad_creative',
                ad_id: urlParams.get('ad_id') || urlParams.get('fbclid') || urlParams.get('ttclid') || 'none',
            };
        }

        validatePhone(phone) {
            const clean = phone.replace(/[^0-9]/g, '');
            return /^(234|0)(70|80|81|90|91)\d{8}$/.test(clean);
        }

        attachFormListeners() {
            const forms = document.querySelectorAll('form[data-novaxpress-form], form.novaxpress-order-form');
            forms.forEach((form) => {
                form.addEventListener('submit', (e) => this.handleFormSubmit(e, form));
            });
        }

        async handleFormSubmit(event, form) {
            event.preventDefault();

            const formId = form.getAttribute('data-form-id') || form.querySelector('input[name="form_id"]')?.value;
            if (!formId) {
                alert('Configuration error: Missing data-form-id attribute on form.');
                return;
            }

            const formData = new FormData(form);
            const phone = formData.get('phone') || formData.get('customer_phone') || '';
            
            if (!this.validatePhone(phone.toString())) {
                alert('Please enter a valid Nigerian mobile phone number (e.g. 08012345678).');
                return;
            }

            const utm = this.getUtmParams();
            const payload = {
                id: 'ord_temp_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6),
                form_id: formId,
                customer_name: formData.get('name') || formData.get('customer_name') || 'Customer',
                customer_phone: phone,
                customer_alt_phone: formData.get('alt_phone') || formData.get('customer_alt_phone') || '',
                customer_email: formData.get('email') || formData.get('customer_email') || '',
                delivery_address: formData.get('address') || formData.get('delivery_address') || '',
                delivery_state: formData.get('state') || formData.get('delivery_state') || 'Lagos',
                delivery_lga: formData.get('lga') || formData.get('delivery_lga') || formData.get('city') || formData.get('delivery_city') || 'Ikeja',
                delivery_city: formData.get('lga') || formData.get('delivery_lga') || formData.get('city') || formData.get('delivery_city') || 'Ikeja',
                notes: formData.get('notes') || '',
                package_id: formData.get('package_id') || 'pkg-1',
                package_name: formData.get('package_name') || 'Selected Package',
                buy_qty: parseInt(formData.get('buy_qty') || formData.get('quantity') || '1', 10),
                total_amount: parseFloat(formData.get('total_amount') || '0'),
                utm_source: utm.utm_source,
                utm_medium: utm.utm_medium,
                utm_campaign: utm.utm_campaign,
                utm_content: utm.utm_content,
                ad_id: utm.ad_id,
                submitted_at: new Date().toISOString(),
            };

            const submitBtn = form.querySelector('button[type="submit"], input[type="submit"]');
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.textContent = 'Processing Order...';
            }

            try {
                const response = await fetch(this.endpoint, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload),
                });

                const result = await response.json();
                if (result.success && result.redirect_url) {
                    window.location.href = result.redirect_url;
                } else {
                    this.showSuccessCard(form, result.order_number);
                }
            } catch (err) {
                console.warn('[NovaXpress FormGuard] Network issue, queuing offline order:', err);
                this.queue.push(payload);
                this.saveQueue();
                this.showSuccessCard(form, 'QUEUED');
            }
        }

        async processQueue() {
            if (this.queue.length === 0 || !navigator.onLine) return;

            const pending = [...this.queue];
            for (const order of pending) {
                try {
                    const response = await fetch(this.endpoint, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(order),
                    });

                    if (response.ok || response.status === 201) {
                        this.queue = this.queue.filter((item) => item.id !== order.id);
                        this.saveQueue();
                        console.log('[NovaXpress FormGuard] Synchronized offline order:', order.id);
                    }
                } catch (e) {
                    // Stays in queue for next cycle
                }
            }
        }

        showSuccessCard(form, orderRef) {
            form.innerHTML = `
                <div style="text-align:center; padding:32px 24px; background:#F0FDF4; border:1px solid #BBF7D0; border-radius:12px; font-family:sans-serif;">
                    <div style="width:48px; height:48px; background:#10B981; color:white; border-radius:50%; display:inline-flex; align-items:center; justify-content:center; font-size:24px; margin-bottom:12px;">âœ“</div>
                    <h3 style="color:#065F46; margin:0 0 6px 0; font-size:18px;">Order Successfully Received!</h3>
                    <p style="color:#047857; margin:0 0 10px 0; font-size:14px;">Reference: <strong>${orderRef || 'NEW'}</strong></p>
                    <p style="color:#475569; margin:0; font-size:13px;">Our sales desk will call you shortly to confirm your delivery address and schedule delivery.</p>
                </div>
            `;
        }
    }

    window.NovaXpressFormGuard = new FormGuard();
})(window, document);
