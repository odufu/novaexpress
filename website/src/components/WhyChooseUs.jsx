import React from 'react';
import { ShieldCheck, Banknote, ThermometerSnowflake, QrCode, MapPin, Cpu, ArrowRight } from 'lucide-react';

export default function WhyChooseUs({ onLearnMore }) {
  const points = [
    {
      icon: Banknote,
      title: '24-Hour COD Remittance',
      desc: 'All doorstep cash & POS collections settled to your bank within 24 hours (T+1). Zero discrepancy guarantee.',
    },
    {
      icon: ThermometerSnowflake,
      title: 'Pharma Cold Chain (2°C–8°C)',
      desc: 'IoT telemetry & vacuum-insulated shippers ensuring vaccines and biologics arrive with zero temperature spikes.',
    },
    {
      icon: QrCode,
      title: 'Electronic Proof of Delivery',
      desc: 'Every completed drop captures instant electronic customer signature, doorstep photo verification, and GPS pin.',
    },
    {
      icon: MapPin,
      title: 'Micro-Hub Fast Dispatch',
      desc: 'Distributed micro-fulfillment hubs across prime commercial zones cut last-mile transit times under 3 hours.',
    },
    {
      icon: Cpu,
      title: 'API & Store Integrations',
      desc: 'Plug directly into our system via REST API, Webhooks, Shopify, or custom ERPs for automated dispatching.',
    },
    {
      icon: ShieldCheck,
      title: 'Comprehensive Transit Insurance',
      desc: 'High-value electronics, pharmaceuticals, and luxury items covered by verified cargo protection policies.',
    },
  ];

  return (
    <section 
      className="section-padding" 
      style={{
        background: '#FAF9FB',
        borderTop: '1px solid #EAEBEE',
        borderBottom: '1px solid #EAEBEE',
      }}
    >
      <div className="container">
        
        {/* Header */}
        <div style={{ textAlign: 'center', maxWidth: '640px', margin: '0 auto 48px' }}>
          <div className="badge-pill" style={{ marginBottom: '12px' }}>
            <ShieldCheck size={13} color="#FD7A02" />
            <span>Operational Integrity</span>
          </div>
          <h2 style={{ fontSize: 'clamp(26px, 3.2vw, 38px)', color: '#082658', marginBottom: '12px' }}>
            Why Nigeria’s Top Brands <span style={{ color: '#FD7A02' }}>Trust NovaXpress</span>
          </h2>
          <p style={{ fontSize: '15px', color: '#4A5B78' }}>
            Eliminating perennial logistics bottlenecks: no delayed cash payouts, no temperature spoilage, and zero phantom deliveries.
          </p>
        </div>

        {/* Minimalist Grid */}
        <div 
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(330px, 1fr))',
            gap: '20px',
          }}
        >
          {points.map((item, idx) => {
            const IconComponent = item.icon;
            return (
              <div 
                key={idx}
                className="clean-card"
                style={{
                  padding: '28px',
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: '18px',
                  background: '#FFFFFF',
                }}
              >
                <div 
                  style={{
                    width: '46px',
                    height: '46px',
                    borderRadius: '12px',
                    background: 'rgba(253, 122, 2, 0.1)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <IconComponent size={22} color="#FD7A02" />
                </div>

                <div>
                  <h3 style={{ fontSize: '16px', color: '#082658', fontWeight: 700, marginBottom: '6px' }}>
                    {item.title}
                  </h3>
                  <p style={{ fontSize: '13px', color: '#4A5B78', lineHeight: 1.55 }}>
                    {item.desc}
                  </p>
                </div>
              </div>
            );
          })}
        </div>

      </div>
    </section>
  );
}
