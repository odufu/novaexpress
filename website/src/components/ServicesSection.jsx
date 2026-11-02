import React from 'react';
import { 
  Zap, 
  ThermometerSnowflake, 
  Banknote, 
  Warehouse, 
  Truck, 
  RotateCcw, 
  ShieldCheck, 
  Check, 
  ArrowRight,
  Clock,
  Sparkles
} from 'lucide-react';

const ICON_MAP = {
  Zap,
  ThermometerSnowflake,
  Banknote,
  Warehouse,
  Truck,
  RotateCcw,
  ShieldCheck,
};

export default function ServicesSection({ services, onSelectService }) {
  const activeServices = (services || []).filter((s) => s.is_active !== false);

  return (
    <section className="section-padding" style={{ background: '#FAF9FB', position: 'relative' }}>
      <div className="container">
        
        {/* Minimalist Section Header */}
        <div style={{ textAlign: 'center', maxWidth: '640px', margin: '0 auto 48px' }}>
          <div className="badge-pill" style={{ marginBottom: '12px' }}>
            <Sparkles size={13} color="#FD7A02" />
            <span>Dedicated Logistics Capabilities</span>
          </div>
          <h2 style={{ fontSize: 'clamp(26px, 3.2vw, 38px)', color: '#082658', marginBottom: '12px' }}>
            Built for <span style={{ color: '#FD7A02' }}>Speed & Precision</span>
          </h2>
          <p style={{ fontSize: '15px', color: '#4A5B78' }}>
            Less friction, zero guesswork. Specialised last-mile and linehaul logistics engineered for high-volume commercial operations.
          </p>
        </div>

        {/* Minimalist Icon-First Grid */}
        <div 
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))',
            gap: '24px',
          }}
        >
          {activeServices.map((service) => {
            const IconComp = ICON_MAP[service.icon_name] || Truck;
            const features = Array.isArray(service.features) ? service.features : [];

            return (
              <div 
                key={service.id || service.slug}
                className="clean-card"
                style={{
                  padding: '32px',
                  display: 'flex',
                  flexDirection: 'column',
                  background: '#FFFFFF',
                }}
              >
                {/* Header with Icon & SLA badge */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                  <div 
                    style={{
                      width: '48px',
                      height: '48px',
                      borderRadius: '14px',
                      background: 'rgba(253, 122, 2, 0.1)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <IconComp size={24} color="#FD7A02" />
                  </div>

                  {service.sla_delivery_time && (
                    <span 
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '5px',
                        background: '#EAEBEE',
                        color: '#082658',
                        padding: '4px 10px',
                        borderRadius: '20px',
                        fontSize: '11px',
                        fontWeight: 700,
                      }}
                    >
                      <Clock size={12} color="#FD7A02" />
                      {service.sla_delivery_time}
                    </span>
                  )}
                </div>

                {/* Title & Short Description */}
                <h3 style={{ fontSize: '19px', color: '#082658', marginBottom: '10px' }}>
                  {service.title}
                </h3>
                <p style={{ fontSize: '14px', color: '#4A5B78', lineHeight: 1.6, marginBottom: '20px', flex: 1 }}>
                  {service.short_description}
                </p>

                {/* Clean Feature List */}
                {features.length > 0 && (
                  <div style={{ borderTop: '1px solid #EAEBEE', paddingTop: '16px', marginBottom: '20px' }}>
                    <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      {features.slice(0, 3).map((feat, idx) => (
                        <li key={idx} style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', color: '#082658' }}>
                          <div style={{ width: '16px', height: '16px', borderRadius: '50%', background: 'rgba(253, 122, 2, 0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                            <Check size={11} color="#FD7A02" />
                          </div>
                          <span>{feat}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {/* Bottom Action */}
                <button
                  onClick={() => onSelectService(service)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    width: '100%',
                    padding: '11px 16px',
                    borderRadius: 'var(--radius-sm)',
                    background: '#FAF9FB',
                    border: '1px solid #EAEBEE',
                    color: '#082658',
                    fontSize: '13px',
                    fontWeight: 700,
                    transition: 'all 0.2s',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = '#082658';
                    e.currentTarget.style.color = '#FFFFFF';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = '#FAF9FB';
                    e.currentTarget.style.color = '#082658';
                  }}
                >
                  <span>Select Service</span>
                  <ArrowRight size={14} color="#FD7A02" />
                </button>
              </div>
            );
          })}
        </div>

      </div>
    </section>
  );
}
