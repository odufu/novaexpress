import React, { useState, useEffect } from 'react';
import { Send, CheckCircle2, Phone, Mail, MapPin, Clock, Sparkles } from 'lucide-react';
import confetti from 'canvas-confetti';
import { submitInquiry } from '../lib/supabase';

export default function QuoteSection({ settings, prefillData }) {
  const [formData, setFormData] = useState({
    full_name: '',
    email: '',
    phone: '',
    company: '',
    service_type: 'Express Delivery',
    destination_hub: 'Lagos State Hub',
    estimated_volume: '100 - 500 parcels/month',
    message: '',
  });

  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  useEffect(() => {
    if (prefillData) {
      setFormData((prev) => ({
        ...prev,
        service_type: prefillData.serviceType || prev.service_type,
        destination_hub: prefillData.destination || prev.destination_hub,
        message: prefillData.estimatedCost 
          ? `Estimated Route: ${prefillData.origin} -> ${prefillData.destination} (${prefillData.weight}). Estimated Rate: ${prefillData.estimatedCost}` 
          : prev.message,
      }));
    }
  }, [prefillData]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.full_name || !formData.email || !formData.message) {
      setErrorMsg('Please enter your name, email, and requirements.');
      return;
    }

    setLoading(true);
    setErrorMsg('');

    try {
      const res = await submitInquiry(formData);
      if (res.success) {
        setSubmitted(true);
        confetti({
          particleCount: 70,
          spread: 60,
          origin: { y: 0.6 },
          colors: ['#082658', '#FD7A02', '#D5BFAF', '#FFFFFF'],
        });
      } else {
        setErrorMsg('Could not submit request. Please reach us via direct phone.');
      }
    } catch (err) {
      setErrorMsg('Failed to submit. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <section 
      id="quote-section" 
      className="section-padding" 
      style={{
        background: '#FAF9FB',
        borderTop: '1px solid #EAEBEE',
      }}
    >
      <div className="container">
        <div style={{ display: 'grid', gridTemplateColumns: '0.9fr 1.1fr', gap: '40px', alignItems: 'flex-start' }} className="quote-grid">
          
          {/* Left Contact Card */}
          <div>
            <div className="badge-pill" style={{ marginBottom: '12px' }}>
              <Sparkles size={13} color="#FD7A02" />
              <span>Dedicated Account Support</span>
            </div>
            <h2 style={{ fontSize: 'clamp(26px, 3.2vw, 38px)', color: '#082658', marginBottom: '14px' }}>
              Book Your Delivery or <span style={{ color: '#FD7A02' }}>Request Custom SLA</span>
            </h2>
            <p style={{ fontSize: '15px', color: '#4A5B78', lineHeight: 1.65, marginBottom: '32px' }}>
              Speak with a dedicated logistics specialist. We customize enterprise SLAs, integrate APIs, set up local micro-fulfillment, and automate daily remittance for your business.
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', background: '#FFFFFF', padding: '14px 18px', borderRadius: 'var(--radius-md)', border: '1px solid #EAEBEE' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(253, 122, 2, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Phone size={18} color="#FD7A02" />
                </div>
                <div>
                  <span style={{ fontSize: '11px', color: '#7E8DA6', fontWeight: 600, textTransform: 'uppercase' }}>Direct Line</span>
                  <p style={{ fontSize: '15px', fontWeight: 700, color: '#082658' }}>{settings?.contact_phone || '+234 812 345 6789'}</p>
                </div>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', background: '#FFFFFF', padding: '14px 18px', borderRadius: 'var(--radius-md)', border: '1.5px solid #CBD5E1', boxShadow: '0 2px 8px rgba(8, 38, 88, 0.04)' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(253, 122, 2, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Mail size={18} color="#FD7A02" />
                </div>
                <div>
                  <span style={{ fontSize: '11px', color: '#7E8DA6', fontWeight: 700, textTransform: 'uppercase' }}>Logistics Operations Email</span>
                  <p style={{ fontSize: '15px', fontWeight: 800, color: '#082658' }}>{settings?.contact_email || 'operations@novaxpressng.com'}</p>
                </div>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', background: '#FFFFFF', padding: '14px 18px', borderRadius: 'var(--radius-md)', border: '1px solid #EAEBEE' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(8, 38, 88, 0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <MapPin size={18} color="#082658" />
                </div>
                <div>
                  <span style={{ fontSize: '11px', color: '#7E8DA6', fontWeight: 600, textTransform: 'uppercase' }}>Central Hub</span>
                  <p style={{ fontSize: '14px', fontWeight: 600, color: '#082658' }}>{settings?.headquarters_address || 'NovaXpress Gateway Hub, Ikeja, Lagos'}</p>
                </div>
              </div>

            </div>
          </div>

          {/* Right Lead Capture Form */}
          <div 
            className="clean-card"
            style={{
              padding: '36px',
              background: '#FFFFFF',
              border: '2px solid #EAEBEE',
            }}
          >
            {submitted ? (
              <div style={{ textAlign: 'center', padding: '36px 20px' }}>
                <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(253, 122, 2, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 18px', border: '2px solid #FD7A02' }}>
                  <CheckCircle2 size={30} color="#FD7A02" />
                </div>
                <h3 style={{ fontSize: '22px', color: '#082658', marginBottom: '8px' }}>
                  Request Received!
                </h3>
                <p style={{ fontSize: '14px', color: '#4A5B78', lineHeight: 1.6, maxWidth: '400px', margin: '0 auto 20px' }}>
                  Thank you, <strong>{formData.full_name}</strong>. Our logistics operations team will contact you within 30 minutes.
                </p>
                <button
                  type="button"
                  onClick={() => setSubmitted(false)}
                  className="btn-secondary btn-sm"
                >
                  Submit Another Request
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <h3 style={{ fontSize: '19px', color: '#082658', marginBottom: '4px' }}>
                  Request Delivery Proposal
                </h3>

                {errorMsg && (
                  <div style={{ padding: '10px 14px', borderRadius: '6px', background: '#FEE2E2', border: '1px solid #F87171', color: '#B91C1C', fontSize: '13px' }}>
                    {errorMsg}
                  </div>
                )}

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }} className="quote-form-row">
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                      Full Name *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Samuel Adekunle"
                      value={formData.full_name}
                      onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                      style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1.5px solid #CBD5E1', borderRadius: '6px', color: '#082658', fontSize: '13px', fontWeight: 600 }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                      Work Email *
                    </label>
                    <input
                      type="email"
                      required
                      placeholder="samuel@company.com"
                      value={formData.email}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                      style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1.5px solid #CBD5E1', borderRadius: '6px', color: '#082658', fontSize: '13px', fontWeight: 600 }}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }} className="quote-form-row">
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                      Phone / WhatsApp Number *
                    </label>
                    <input
                      type="tel"
                      required
                      placeholder="+234 800 000 0000"
                      value={formData.phone}
                      onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                      style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1.5px solid #CBD5E1', borderRadius: '6px', color: '#082658', fontSize: '13px', fontWeight: 600 }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                      Company / Brand Name
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Apex Pharma Ltd"
                      value={formData.company}
                      onChange={(e) => setFormData({ ...formData, company: e.target.value })}
                      style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1.5px solid #CBD5E1', borderRadius: '6px', color: '#082658', fontSize: '13px', fontWeight: 600 }}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }} className="quote-form-row">
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                      Logistics Service Required
                    </label>
                    <select
                      value={formData.service_type}
                      onChange={(e) => setFormData({ ...formData, service_type: e.target.value })}
                      style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1.5px solid #CBD5E1', borderRadius: '6px', color: '#082658', fontSize: '13px', fontWeight: 700 }}
                    >
                      <option value="Express Delivery">Intra-City Express Dispatch</option>
                      <option value="Cold Chain Logistics">Pharma & Cold Chain (2°C - 8°C)</option>
                      <option value="Cash on Delivery (COD)">Cash on Delivery & Remittance</option>
                      <option value="Micro-Hub Warehousing">Micro-Hub Warehousing</option>
                      <option value="Interstate Linehaul">Interstate Trunk Cargo</option>
                    </select>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                      Estimated Monthly Volume
                    </label>
                    <select
                      value={formData.estimated_volume}
                      onChange={(e) => setFormData({ ...formData, estimated_volume: e.target.value })}
                      style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1.5px solid #CBD5E1', borderRadius: '6px', color: '#082658', fontSize: '13px', fontWeight: 700 }}
                    >
                      <option value="Under 100 parcels/month">Under 100 parcels/month</option>
                      <option value="100 - 500 parcels/month">100 - 500 parcels/month</option>
                      <option value="500 - 2,500 parcels/month">500 - 2,500 parcels/month</option>
                      <option value="2,500+ Enterprise Tier">2,500+ Enterprise Tier</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                    Shipment Details & Requirements *
                  </label>
                  <textarea
                    rows={3}
                    required
                    placeholder="Route origin, delivery destinations, special handling (e.g. cold storage)..."
                    value={formData.message}
                    onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                    style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1.5px solid #CBD5E1', borderRadius: '6px', color: '#082658', fontSize: '13px', fontWeight: 600, resize: 'vertical' }}
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="btn-primary"
                  style={{ width: '100%', padding: '14px', fontSize: '15px', borderRadius: 'var(--radius-sm)' }}
                >
                  <Send size={16} />
                  <span>{loading ? 'Submitting...' : 'Submit Request'}</span>
                </button>
              </form>
            )}
          </div>

        </div>
      </div>

      <style>{`
        @media (max-width: 900px) {
          .quote-grid {
            grid-template-columns: 1fr !important;
          }
          .quote-form-row {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </section>
  );
}
