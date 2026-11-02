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
  Clock, 
  ArrowRight,
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

export default function ServicesPage({ services, onSelectService }) {
  const activeServices = (services || []).filter((s) => s.is_active !== false);

  return (
    <div className="section-padding" style={{ background: '#FAF9FB', minHeight: '85vh' }}>
      <div className="container">
        
        {/* Page Hero */}
        <div style={{ textAlign: 'center', maxWidth: '750px', margin: '0 auto 54px' }}>
          <div className="badge-pill" style={{ marginBottom: '14px', background: '#FFFFFF', borderColor: '#D5BFAF' }}>
            <Sparkles size={14} color="#FD7A02" />
            <span style={{ color: '#082658', fontWeight: 700 }}>End-to-End Logistics Architecture</span>
          </div>
          <h1 style={{ fontSize: 'clamp(32px, 4vw, 48px)', color: '#082658', fontWeight: 800, letterSpacing: '-0.025em', marginBottom: '16px' }}>
            Enterprise Delivery & Distribution <span style={{ color: '#FD7A02' }}>Solutions</span>
          </h1>
          <p style={{ fontSize: '16px', color: '#4A5B78', lineHeight: 1.65 }}>
            NovaXpress offers purpose-built logistics services tailored to the demanding requirements of pharmaceuticals, e-commerce brands, FMCG distributors, and corporate shippers.
          </p>
        </div>

        {/* Detailed Service Cards */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
          {activeServices.map((service, index) => {
            const IconComp = ICON_MAP[service.icon_name] || Truck;
            const features = Array.isArray(service.features) ? service.features : [];

            return (
              <div 
                key={service.id || index}
                className="clean-card"
                style={{
                  padding: '36px',
                  background: '#FFFFFF',
                  border: '1.5px solid #EAEBEE',
                  boxShadow: '0 4px 20px rgba(8, 38, 88, 0.04)',
                  display: 'grid',
                  gridTemplateColumns: '1.2fr 0.8fr',
                  gap: '36px',
                  alignItems: 'center',
                }}
              >
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '16px' }}>
                    <div 
                      style={{
                        width: '52px',
                        height: '52px',
                        borderRadius: '14px',
                        background: 'rgba(253, 122, 2, 0.12)',
                        border: '1px solid rgba(253, 122, 2, 0.3)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <IconComp size={26} color="#FD7A02" />
                    </div>
                    <div>
                      <h2 style={{ fontSize: '22px', fontWeight: 800, color: '#082658', letterSpacing: '-0.02em', marginBottom: '4px' }}>
                        {service.title}
                      </h2>
                      {service.sla_delivery_time && (
                        <span style={{ fontSize: '12px', color: '#082658', background: '#EAEBEE', padding: '3px 10px', borderRadius: '16px', fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: '5px' }}>
                          <Clock size={12} color="#FD7A02" /> SLA: {service.sla_delivery_time}
                        </span>
                      )}
                    </div>
                  </div>

                  <p style={{ fontSize: '15px', color: '#334155', lineHeight: 1.65, marginBottom: '24px' }}>
                    {service.full_description || service.short_description}
                  </p>

                  <button
                    onClick={() => onSelectService(service)}
                    className="btn-primary"
                    style={{ padding: '12px 24px', fontSize: '14px' }}
                  >
                    <span>Request Proposal for this Solution</span>
                    <ArrowRight size={16} />
                  </button>
                </div>

                {/* Features & Guarantees Box with High Contrast Deep Navy */}
                <div 
                  style={{
                    background: '#082658',
                    borderRadius: 'var(--radius-md)',
                    padding: '28px',
                    boxShadow: '0 8px 24px rgba(8, 38, 88, 0.18)',
                    border: '1px solid rgba(255, 255, 255, 0.12)',
                  }}
                >
                  <span style={{ fontSize: '12px', fontWeight: 800, color: '#FD7A02', textTransform: 'uppercase', letterSpacing: '0.08em', display: 'block', marginBottom: '16px' }}>
                    Operational Highlights & SLAs
                  </span>

                  <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {features.map((feat, idx) => (
                      <li key={idx} style={{ display: 'flex', alignItems: 'flex-start', gap: '10px', fontSize: '13px', color: '#FAF9FB', lineHeight: 1.5 }}>
                        <div style={{ width: '18px', height: '18px', borderRadius: '50%', background: 'rgba(253, 122, 2, 0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: '2px' }}>
                          <Check size={12} color="#FD7A02" />
                        </div>
                        <span style={{ fontWeight: 500 }}>{feat}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            );
          })}
        </div>

      </div>

      <style>{`
        @media (max-width: 900px) {
          .clean-card {
            grid-template-columns: 1fr !important;
            padding: 24px !important;
          }
        }
      `}</style>
    </div>
  );
}
