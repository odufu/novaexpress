import React from 'react';
import { ShieldCheck, Truck, Cpu, Users, Award, CheckCircle2, MapPin, Sparkles } from 'lucide-react';
import CoverageMap from '../components/CoverageMap';

export default function AboutPage({ onGetInTouch }) {
  const values = [
    { title: 'Zero Compromise on Cold Chain', desc: 'Vaccines and biologics save lives. We treat temperature regulation not as an option, but as a sacred SLA.' },
    { title: '24-Hour Cash Velocity', desc: 'Merchants should never wait weeks to access their own capital. We automate reconciliation so your funds are in your bank next day.' },
    { title: 'Algorithmic Route Efficiency', desc: 'By pairing distributed micro-hubs with smart rider routing, we slash last-mile fuel, transit hours, and delivery failure rates.' },
    { title: 'Radical Traceability', desc: 'From doorstep signature capture to real-time IoT temperature graphs, every single leg of the journey is 100% auditable.' },
  ];

  return (
    <div className="section-padding" style={{ background: '#FAF9FB', minHeight: '85vh' }}>
      <div className="container">
        
        {/* About Hero */}
        <div style={{ textAlign: 'center', maxWidth: '780px', margin: '0 auto 54px' }}>
          <div className="badge-pill" style={{ marginBottom: '14px', background: '#FFFFFF', borderColor: '#D5BFAF' }}>
            <Sparkles size={14} color="#FD7A02" />
            <span style={{ color: '#082658', fontWeight: 700 }}>Pioneering African Logistics</span>
          </div>
          <h1 style={{ fontSize: 'clamp(32px, 4.2vw, 48px)', color: '#082658', fontWeight: 800, letterSpacing: '-0.025em', marginBottom: '16px' }}>
            Transforming Last-Mile Delivery with <span style={{ color: '#FD7A02' }}>Precision & Technology</span>
          </h1>
          <p style={{ fontSize: '16px', color: '#4A5B78', lineHeight: 1.65 }}>
            Founded to eliminate the chaos of lost packages, delayed cash remittance, and broken cold-chains, NovaXpress is building the modern logistics backbone powering Nigeria’s highest-performing enterprises.
          </p>
        </div>

        {/* Story Section */}
        <div 
          className="clean-card"
          style={{
            padding: '44px',
            marginBottom: '54px',
            background: '#FFFFFF',
            border: '1.5px solid #EAEBEE',
            boxShadow: '0 8px 30px rgba(8, 38, 88, 0.05)',
          }}
        >
          <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 0.9fr', gap: '44px', alignItems: 'center' }} className="story-layout">
            <div>
              <span style={{ fontSize: '12px', fontWeight: 800, color: '#FD7A02', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
                Our Mission & Vision
              </span>
              <h2 style={{ fontSize: '26px', color: '#082658', margin: '10px 0 18px', lineHeight: 1.3, fontWeight: 800 }}>
                Solving the Hard Problems of African Supply Chains
              </h2>
              <p style={{ fontSize: '15px', color: '#334155', lineHeight: 1.65, marginBottom: '14px' }}>
                For decades, businesses across Nigeria have had to grapple with fragmented transport operators, manual paper delivery notes, high return-to-origin rates (RTO), and weeks-long delays before receiving cash-on-delivery payments.
              </p>
              <p style={{ fontSize: '15px', color: '#334155', lineHeight: 1.65, marginBottom: '24px' }}>
                NovaXpress was engineered from the ground up to unify micro-hub warehousing, dedicated vetted delivery agents, digital proof of delivery, and instant automated bank payouts into a single, cohesive operating system.
              </p>

              <button onClick={onGetInTouch} className="btn-primary" style={{ fontWeight: 700 }}>
                Partner with NovaXpress
              </button>
            </div>

            <div style={{ background: '#082658', borderRadius: 'var(--radius-lg)', padding: '32px', border: '1px solid rgba(255, 255, 255, 0.12)', boxShadow: '0 12px 30px rgba(8, 38, 88, 0.2)' }}>
              <h3 style={{ fontSize: '18px', color: '#FFFFFF', fontWeight: 800, marginBottom: '20px' }}>
                Operational Guarantees
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
                  <CheckCircle2 size={20} color="#FD7A02" style={{ flexShrink: 0, marginTop: '2px' }} />
                  <div>
                    <h5 style={{ fontSize: '14px', color: '#FFFFFF', fontWeight: 700 }}>T+1 Automated Bank Settlement</h5>
                    <p style={{ fontSize: '12px', color: '#D5BFAF', marginTop: '2px' }}>Daily automated reconciliation without manual invoicing.</p>
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
                  <CheckCircle2 size={20} color="#FD7A02" style={{ flexShrink: 0, marginTop: '2px' }} />
                  <div>
                    <h5 style={{ fontSize: '14px', color: '#FFFFFF', fontWeight: 700 }}>ISO & NAFDAC Cold-Chain Compliance</h5>
                    <p style={{ fontSize: '12px', color: '#D5BFAF', marginTop: '2px' }}>Calibrated data loggers and continuous temperature verification.</p>
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
                  <CheckCircle2 size={20} color="#FD7A02" style={{ flexShrink: 0, marginTop: '2px' }} />
                  <div>
                    <h5 style={{ fontSize: '14px', color: '#FFFFFF', fontWeight: 700 }}>100% In-House Vetted Delivery Fleet</h5>
                    <p style={{ fontSize: '12px', color: '#D5BFAF', marginTop: '2px' }}>Professional riders equipped with signature and photo capture mobile apps.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Core Values Grid */}
        <div style={{ marginBottom: '60px' }}>
          <div style={{ textAlign: 'center', marginBottom: '32px' }}>
            <h2 style={{ fontSize: '26px', color: '#082658', fontWeight: 800 }}>Our Operating Principles</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '20px' }}>
            {values.map((v, i) => (
              <div 
                key={i}
                className="clean-card"
                style={{ padding: '28px', background: '#FFFFFF', border: '1.5px solid #EAEBEE' }}
              >
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(253, 122, 2, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#FD7A02', fontWeight: 800, fontSize: '14px', marginBottom: '14px' }}>
                  0{i + 1}
                </div>
                <h4 style={{ fontSize: '16px', color: '#082658', fontWeight: 700, marginBottom: '8px' }}>{v.title}</h4>
                <p style={{ fontSize: '13px', color: '#4A5B78', lineHeight: 1.6 }}>{v.desc}</p>
              </div>
            ))}
          </div>
        </div>

        <CoverageMap />

      </div>

      <style>{`
        @media (max-width: 900px) {
          .story-layout {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </div>
  );
}
