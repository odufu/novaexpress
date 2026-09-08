import React from 'react';
import { 
  ShieldCheck, 
  Layers, 
  CreditCard, 
  Zap, 
  AlertCircle, 
  CheckCircle2, 
  ArrowRight,
  TrendingUp,
  Sparkles,
  Award
} from 'lucide-react';
import { EXECUTIVE_STATS } from '../data/presentationData';

const iconMap = {
  ShieldCheck,
  Layers,
  CreditCard,
  Zap,
};

export default function HeroOverview({ goToSlide }) {
  return (
    <div className="animate-fade-in" style={{ padding: '1rem 0' }}>
      {/* Hero Banner with Brand Logo */}
      <div style={{ textAlign: 'center', marginBottom: '3.5rem' }}>
        {/* Brand Logo Presentation Badge */}
        <div style={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: '24px',
          padding: '12px 28px',
          boxShadow: 'var(--shadow-md)',
          marginBottom: '1.75rem',
          gap: '1rem',
        }}>
          <img
            src="./square_logo.png"
            alt="NovaExpress"
            style={{ width: '48px', height: '48px', objectFit: 'contain' }}
            onError={(e) => { e.target.style.display = 'none'; }}
          />
          <div style={{ textAlign: 'left' }}>
            <div style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '1.25rem',
              fontWeight: 800,
              color: 'var(--brand-primary)',
              lineHeight: 1.1,
            }}>
              NovaExpress Logistics
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Nigerian Distribution & Cash Settlement Network
            </div>
          </div>
        </div>

        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: 'clamp(2.3rem, 5vw, 4rem)',
          fontWeight: 800,
          lineHeight: 1.18,
          letterSpacing: '-0.03em',
          maxWidth: '960px',
          margin: '0 auto 1.5rem',
          color: 'var(--text-primary)',
        }}>
          Next-Generation{' '}
          <span style={{
            background: 'var(--grad-brand)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
          }}>
            Distributed Logistics & Cash Fulfillment
          </span>{' '}
          Platform
        </h2>

        <p style={{
          fontSize: '1.15rem',
          color: 'var(--text-secondary)',
          maxWidth: '780px',
          margin: '0 auto 2.5rem',
          fontWeight: 400,
          lineHeight: 1.6,
        }}>
          Engineered to eliminate Nigeria's toughest e-commerce friction points: Zero-leakage Pay-on-Delivery (POD), instant dynamic Monnify virtual accounts, multi-hub inventory scoping, and automated driver earnings.
        </p>

        {/* Action quick links */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '1rem', flexWrap: 'wrap' }}>
          <button
            onClick={() => goToSlide(1)}
            style={{
              background: 'var(--brand-primary)',
              color: '#FFFFFF',
              border: 'none',
              padding: '0.85rem 1.85rem',
              borderRadius: 'var(--radius-md)',
              fontWeight: 700,
              fontSize: '0.95rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              boxShadow: '0 4px 15px rgba(0, 108, 76, 0.3)',
              transition: 'transform 0.2s',
            }}
          >
            <span>View Mermaid Workflows</span>
            <ArrowRight size={18} />
          </button>

          <button
            onClick={() => goToSlide(7)}
            style={{
              background: '#FFFFFF',
              color: 'var(--brand-primary)',
              border: '1.5px solid var(--brand-primary)',
              padding: '0.85rem 1.85rem',
              borderRadius: 'var(--radius-md)',
              fontWeight: 700,
              fontSize: '0.95rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              boxShadow: 'var(--shadow-sm)',
            }}
          >
            <span>Live ROI Calculator</span>
            <TrendingUp size={18} />
          </button>
        </div>
      </div>

      {/* 4 Key Metric Cards (Light Theme) */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '1.25rem',
        margin: '3rem 0',
      }}>
        {EXECUTIVE_STATS.map((stat, i) => {
          const IconComp = iconMap[stat.icon] || ShieldCheck;
          return (
            <div
              key={i}
              style={{
                background: '#FFFFFF',
                border: '1px solid var(--border-subtle)',
                borderRadius: 'var(--radius-lg)',
                padding: '1.75rem 1.5rem',
                position: 'relative',
                overflow: 'hidden',
                boxShadow: 'var(--shadow-md)',
                transition: 'all 0.3s ease',
              }}
            >
              <div style={{
                position: 'absolute',
                top: 0,
                left: 0,
                width: '100%',
                height: '4px',
                background: i % 2 === 0 ? 'var(--brand-primary)' : 'var(--brand-orange)',
              }} />

              <div style={{
                width: '44px',
                height: '44px',
                borderRadius: '12px',
                background: i % 2 === 0 ? 'var(--brand-primary-subtle)' : 'var(--brand-orange-subtle)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: i % 2 === 0 ? 'var(--brand-primary)' : 'var(--brand-orange)',
                marginBottom: '1rem',
              }}>
                <IconComp size={22} />
              </div>

              <div style={{
                fontFamily: 'var(--font-heading)',
                fontSize: '2.3rem',
                fontWeight: 800,
                letterSpacing: '-0.02em',
                color: 'var(--text-primary)',
                marginBottom: '0.25rem',
              }}>
                {stat.value}
              </div>

              <div style={{
                fontSize: '0.95rem',
                fontWeight: 700,
                color: 'var(--text-primary)',
                marginBottom: '0.25rem',
              }}>
                {stat.label}
              </div>

              <div style={{
                fontSize: '0.8rem',
                color: 'var(--text-muted)',
              }}>
                {stat.sublabel}
              </div>
            </div>
          );
        })}
      </div>

      {/* Dilemma vs Solution Canvas */}
      <div style={{
        background: '#FFFFFF',
        border: '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-xl)',
        padding: '2.5rem',
        boxShadow: 'var(--shadow-lg)',
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '2rem',
        margin: '2rem 0',
      }}>
        {/* Left: The Dilemma */}
        <div style={{
          background: '#FFF5F5',
          border: '1px solid #FECDD3',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '1rem' }}>
            <AlertCircle size={24} color="var(--accent-rose)" />
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.25rem', color: '#9F1239', fontWeight: 800 }}>
              The Nigerian Logistics Dilemma
            </h3>
          </div>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.85rem', fontSize: '0.9rem', color: '#4C0519' }}>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--accent-rose)', fontWeight: 800 }}>✕</span>
              <span><strong>Cash-on-Delivery physical leakage:</strong> Riders holding physical cash face robbery threats, delayed remittances, and personal "borrowing".</span>
            </li>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--accent-rose)', fontWeight: 800 }}>✕</span>
              <span><strong>Sub-DC visibility leaks:</strong> Sub-branch supervisors seeing other regional hubs' cash vaults, driver manifests, and merchant customer records.</span>
            </li>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--accent-rose)', fontWeight: 800 }}>✕</span>
              <span><strong>Regional inventory blindspots:</strong> Stock depleted in northern hubs (Kano/Kaduna) while sitting idle in Lagos depots with no transfer tracking.</span>
            </li>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--accent-rose)', fontWeight: 800 }}>✕</span>
              <span><strong>Disputed driver compensations:</strong> Constant friction over unpaid fuel allowances, disputed commissions, and fleet turnover.</span>
            </li>
          </ul>
        </div>

        {/* Right: The Solution */}
        <div style={{
          background: '#F0FDF4',
          border: '1px solid #BBF7D0',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '1rem' }}>
            <CheckCircle2 size={24} color="var(--brand-primary)" />
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.25rem', color: '#065F46', fontWeight: 800 }}>
              The NoveXPS Architecture Solution
            </h3>
          </div>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.85rem', fontSize: '0.9rem', color: '#064E3B' }}>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>✓</span>
              <span><strong>Monnify Dynamic Virtual Accounts:</strong> Order-specific bank accounts allow instant customer transfer directly to company bank. <em>Zero cash liability for rider!</em></span>
            </li>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>✓</span>
              <span><strong>Sub-DC Zero-State Scoping:</strong> Sub-DCs boot with clean ₦0.00 ledgers, scoped strictly to their own distribution_center_id.</span>
            </li>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>✓</span>
              <span><strong>Inter-DC Transfers with Escrow:</strong> Automated stock decrements, in-transit status flags, and receiving QC inspection scans.</span>
            </li>
            <li style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
              <span style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>✓</span>
              <span><strong>Rule-Based Compensation & Ledgers:</strong> BR-010 to BR-015 locks rates at order creation, automatically crediting rider "My Balance".</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
