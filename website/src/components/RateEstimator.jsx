import React, { useState } from 'react';
import { Calculator, ArrowRight, Clock, Check, Sparkles } from 'lucide-react';

const CITIES = [
  'Lagos (Ikeja / Island / Mainland)',
  'Abuja (FCT / Wuse / Garki)',
  'Port Harcourt (Rivers)',
  'Kano (Kano Central)',
  'Ibadan (Oyo)',
  'Enugu (Enugu Central)',
  'Benin City (Edo)',
  'Asaba (Delta)',
  'Kaduna (Kaduna)',
  'Calabar (Cross River)',
  'Abeokuta (Ogun)',
  'Owerri (Imo)',
];

export default function RateEstimator({ onBookEstimate }) {
  const [origin, setOrigin] = useState('Lagos (Ikeja / Island / Mainland)');
  const [destination, setDestination] = useState('Abuja (FCT / Wuse / Garki)');
  const [serviceType, setServiceType] = useState('express');
  const [weight, setWeight] = useState('2kg');

  const calculateEstimate = () => {
    let base = 2500;
    const isSameCity = origin.split(' ')[0] === destination.split(' ')[0];

    if (isSameCity) {
      base = 2200;
      if (serviceType === 'cold_chain') base = 4800;
      if (serviceType === 'cargo') base = 8500;
    } else {
      base = 5500;
      if (serviceType === 'cold_chain') base = 12500;
      if (serviceType === 'cargo') base = 18000;
    }

    // Weight multiplier
    if (weight === '5kg') base *= 1.35;
    if (weight === '15kg') base *= 2.1;
    if (weight === '50kg') base *= 3.8;

    const transitTime = isSameCity 
      ? (serviceType === 'express' ? '2 - 4 Hours' : 'Same-Day')
      : (serviceType === 'express' ? '24 - 48 Hours' : '24 - 72 Hours');

    return {
      price: Math.round(base / 100) * 100,
      transitTime,
      isSameCity,
    };
  };

  const estimate = calculateEstimate();

  const handleBookNow = () => {
    onBookEstimate({
      origin,
      destination,
      serviceType: serviceType === 'cold_chain' ? 'Cold Chain Logistics' : (serviceType === 'cargo' ? 'B2B Cargo' : 'Express Delivery'),
      weight,
      estimatedCost: `₦${estimate.price.toLocaleString()}`,
    });
  };

  return (
    <section 
      style={{
        padding: '60px 0',
        background: '#FAF9FB',
      }}
    >
      <div className="container">
        <div 
          className="clean-card"
          style={{
            padding: '36px',
            border: '2px solid #EAEBEE',
            background: '#FFFFFF',
          }}
        >
          <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 0.8fr', gap: '36px', alignItems: 'center' }} className="calc-layout">
            
            {/* Left Inputs */}
            <div>
              <div className="badge-pill" style={{ marginBottom: '12px' }}>
                <Calculator size={13} color="#FD7A02" />
                <span>Instant Shipping Rate Tool</span>
              </div>
              <h2 style={{ fontSize: '26px', color: '#082658', marginBottom: '8px' }}>
                Instant Delivery Cost Estimator
              </h2>
              <p style={{ fontSize: '14px', color: '#4A5B78', marginBottom: '24px' }}>
                Transparent pricing for express dispatch, refrigerated medicine, and interstate linehaul.
              </p>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '16px' }}>
                
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '6px' }}>
                    Origin Hub
                  </label>
                  <select
                    value={origin}
                    onChange={(e) => setOrigin(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '11px 12px',
                      background: '#FAF9FB',
                      border: '1.5px solid #CBD5E1',
                      borderRadius: 'var(--radius-sm)',
                      color: '#082658',
                      fontSize: '13px',
                      fontWeight: 700,
                    }}
                  >
                    {CITIES.map((c) => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '6px' }}>
                    Destination City
                  </label>
                  <select
                    value={destination}
                    onChange={(e) => setDestination(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '11px 12px',
                      background: '#FAF9FB',
                      border: '1.5px solid #CBD5E1',
                      borderRadius: 'var(--radius-sm)',
                      color: '#082658',
                      fontSize: '13px',
                      fontWeight: 700,
                    }}
                  >
                    {CITIES.map((c) => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>

              </div>

              {/* Service Type Selection */}
              <div style={{ marginBottom: '18px' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '6px' }}>
                  Logistics Category
                </label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px' }}>
                  {[
                    { id: 'express', label: 'Express Courier', icon: '⚡' },
                    { id: 'cold_chain', label: 'Cold Chain', icon: '❄️' },
                    { id: 'cargo', label: 'B2B Cargo', icon: '📦' },
                  ].map((s) => (
                    <button
                      key={s.id}
                      type="button"
                      onClick={() => setServiceType(s.id)}
                      style={{
                        padding: '10px 8px',
                        borderRadius: 'var(--radius-sm)',
                        background: serviceType === s.id ? '#082658' : '#FFFFFF',
                        border: serviceType === s.id ? '2px solid #082658' : '1.5px solid #CBD5E1',
                        color: serviceType === s.id ? '#FFFFFF' : '#082658',
                        fontSize: '12px',
                        fontWeight: 700,
                        textAlign: 'center',
                        boxShadow: serviceType === s.id ? '0 4px 12px rgba(8, 38, 88, 0.15)' : 'none',
                        cursor: 'pointer',
                      }}
                    >
                      <span>{s.icon} {s.label}</span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Weight Selector */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '6px' }}>
                  Weight Class
                </label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {['Under 2kg', '5kg', '15kg', '50kg+'].map((w) => {
                    const key = w.toLowerCase().replace(/[^a-z0-9]/g, '');
                    return (
                      <button
                        key={w}
                        type="button"
                        onClick={() => setWeight(key)}
                        style={{
                          flex: 1,
                          padding: '9px 6px',
                          borderRadius: 'var(--radius-sm)',
                          background: weight === key ? '#FD7A02' : '#FFFFFF',
                          color: weight === key ? '#FFFFFF' : '#082658',
                          fontSize: '12px',
                          fontWeight: 700,
                          border: weight === key ? '2px solid #FD7A02' : '1.5px solid #CBD5E1',
                          boxShadow: weight === key ? '0 4px 12px rgba(253, 122, 2, 0.25)' : 'none',
                          cursor: 'pointer',
                        }}
                      >
                        {w}
                      </button>
                    );
                  })}
                </div>
              </div>

            </div>

            {/* Right Result Card */}
            <div 
              style={{
                background: '#082658',
                color: '#FFFFFF',
                borderRadius: 'var(--radius-lg)',
                padding: '32px 28px',
                textAlign: 'center',
                boxShadow: '0 12px 30px rgba(8, 38, 88, 0.25)',
              }}
            >
              <span style={{ fontSize: '11px', color: '#D5BFAF', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em' }}>
                Estimated Cost
              </span>
              
              <div style={{ margin: '14px 0 10px' }}>
                <span style={{ fontSize: '42px', fontWeight: 800, color: '#FFFFFF', letterSpacing: '-0.02em' }}>
                  ₦{estimate.price.toLocaleString()}
                </span>
                <span style={{ fontSize: '13px', color: '#D5BFAF' }}> / ballpark</span>
              </div>

              {/* Transit SLA */}
              <div 
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  background: 'rgba(253, 122, 2, 0.2)',
                  color: '#FD7A02',
                  padding: '5px 12px',
                  borderRadius: '20px',
                  fontSize: '12px',
                  fontWeight: 700,
                  marginBottom: '20px',
                }}
              >
                <Clock size={13} />
                <span>Transit Window: {estimate.transitTime}</span>
              </div>

              <div style={{ borderTop: '1px solid rgba(255, 255, 255, 0.1)', paddingTop: '16px', textAlign: 'left', marginBottom: '22px', fontSize: '12px', color: '#EAEBEE' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                  <Check size={14} color="#FD7A02" />
                  <span>Doorstep Pickup & Signature POD</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Check size={14} color="#FD7A02" />
                  <span>Optional Cash on Delivery (COD) Collection</span>
                </div>
              </div>

              <button
                type="button"
                onClick={handleBookNow}
                className="btn-primary"
                style={{ width: '100%', padding: '13px', borderRadius: 'var(--radius-sm)' }}
              >
                <span>Lock In Rate & Book</span>
                <ArrowRight size={15} />
              </button>
            </div>

          </div>
        </div>
      </div>

      <style>{`
        @media (max-width: 900px) {
          .calc-layout {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </section>
  );
}
