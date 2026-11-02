import React from 'react';
import { PackageCheck, Clock, Banknote, MapPin, Activity, ShieldCheck } from 'lucide-react';

const ICON_MAP = {
  PackageCheck,
  Clock,
  Banknote,
  MapPin,
  Activity,
  ShieldCheck,
};

export default function StatsBar({ stats }) {
  const displayStats = stats && stats.length > 0 ? stats : [];

  return (
    <section 
      style={{
        padding: '24px 0',
        background: '#FAF9FB',
        borderBottom: '1px solid #EAEBEE',
      }}
    >
      <div className="container">
        <div 
          style={{
            display: 'grid',
            gridTemplateColumns: `repeat(${displayStats.length || 4}, 1fr)`,
            gap: '16px',
          }}
          className="stats-grid"
        >
          {displayStats.map((st, idx) => {
            const IconComponent = ICON_MAP[st.icon_name] || Activity;
            return (
              <div 
                key={st.id || idx}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '14px',
                  padding: '16px 20px',
                  background: '#FFFFFF',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid #EAEBEE',
                  boxShadow: '0 2px 6px rgba(8, 38, 88, 0.03)',
                }}
              >
                <div 
                  style={{
                    width: '42px',
                    height: '42px',
                    borderRadius: '12px',
                    background: 'rgba(253, 122, 2, 0.1)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <IconComponent size={20} color="#FD7A02" />
                </div>
                <div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '2px' }}>
                    <span 
                      style={{
                        fontSize: '24px',
                        fontWeight: 800,
                        color: '#082658',
                        letterSpacing: '-0.02em',
                      }}
                    >
                      {st.value}
                    </span>
                    {st.suffix && (
                      <span style={{ fontSize: '18px', fontWeight: 800, color: '#FD7A02' }}>
                        {st.suffix}
                      </span>
                    )}
                  </div>
                  <p style={{ fontSize: '12px', fontWeight: 600, color: '#4A5B78', marginTop: '2px' }}>
                    {st.label}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <style>{`
        @media (max-width: 992px) {
          .stats-grid {
            grid-template-columns: repeat(2, 1fr) !important;
          }
        }
        @media (max-width: 540px) {
          .stats-grid {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </section>
  );
}
