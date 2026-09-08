import React from 'react';
import { 
  Banknote, 
  ShieldAlert, 
  WifiOff, 
  PackageCheck, 
  Users, 
  CheckCircle2,
  AlertTriangle
} from 'lucide-react';
import { CURRENT_CHALLENGES_DATA } from '../data/presentationData';

const challengeIcons = {
  Banknote,
  ShieldAlert,
  WifiOff,
  PackageCheck,
  Users,
};

export default function ChallengesSolutions() {
  return (
    <div className="animate-fade-in" style={{ padding: '1rem 0' }}>
      {/* Section Header */}
      <div style={{ marginBottom: '2.5rem' }}>
        <span style={{
          color: 'var(--accent-rose)',
          fontFamily: 'var(--font-mono)',
          fontSize: '0.8rem',
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.1em',
          display: 'block',
          marginBottom: '0.5rem',
        }}>
          Real-World Operations
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.75rem',
        }}>
          Current Operational Challenges & Architectural Countermeasures
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '800px' }}>
          Real-world friction points encountered across Nigerian last-mile delivery, and the exact architectural countermeasures engineered into NoveXPS.
        </p>
      </div>

      {/* Challenges List */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1.75rem' }}>
        {CURRENT_CHALLENGES_DATA.map((item) => {
          const IconComp = challengeIcons[item.icon] || AlertTriangle;
          return (
            <div
              key={item.id}
              style={{
                background: '#FFFFFF',
                border: '1px solid var(--border-subtle)',
                borderRadius: 'var(--radius-xl)',
                padding: '2rem',
                boxShadow: 'var(--shadow-md)',
                display: 'grid',
                gridTemplateColumns: 'auto 1.1fr 1fr',
                gap: '2rem',
                alignItems: 'center',
                transition: 'all 0.25s',
              }}
            >
              {/* Left: Icon & Category */}
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', minWidth: '95px' }}>
                <div style={{
                  width: '56px',
                  height: '56px',
                  borderRadius: '16px',
                  background: '#FFF1F2',
                  color: 'var(--accent-rose)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: '0.5rem',
                }}>
                  <IconComp size={28} />
                </div>
                <span style={{
                  fontFamily: 'var(--font-mono)',
                  fontSize: '0.72rem',
                  fontWeight: 800,
                  color: 'var(--text-muted)',
                  textTransform: 'uppercase',
                }}>
                  {item.category}
                </span>
              </div>

              {/* Center: The Challenge */}
              <div style={{
                borderRight: '1px solid var(--border-subtle)',
                paddingRight: '1.75rem',
              }}>
                <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
                  {item.title}
                </h3>
                <p style={{ fontSize: '0.9rem', color: '#9F1239', lineHeight: 1.5, background: '#FFF1F2', padding: '0.9rem 1.1rem', borderRadius: 'var(--radius-md)', border: '1px solid #FECDD3' }}>
                  <strong>Operational Risk:</strong> {item.challenge}
                </p>
              </div>

              {/* Right: The NoveXPS Solution */}
              <div>
                <h4 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.1rem', fontWeight: 800, color: 'var(--brand-primary)', marginBottom: '0.4rem', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                  <CheckCircle2 size={20} />
                  Architectural Countermeasure
                </h4>
                <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', lineHeight: 1.5, marginBottom: '0.75rem' }}>
                  {item.solution}
                </p>
                <div style={{
                  fontFamily: 'var(--font-mono)',
                  fontSize: '0.8rem',
                  fontWeight: 700,
                  color: 'var(--brand-primary)',
                  background: 'var(--brand-primary-subtle)',
                  padding: '5px 12px',
                  borderRadius: '8px',
                  display: 'inline-block',
                }}>
                  Impact: {item.impact}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
