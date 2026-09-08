import React from 'react';
import { 
  Code2, 
  Database, 
  Wifi, 
  CheckCircle2, 
  ExternalLink,
  ShieldCheck
} from 'lucide-react';

export default function TechnicalStack() {
  const launchLiveApp = () => {
    const flutterPort = 54011;
    const url = window.location.hostname === 'localhost' 
      ? `http://localhost:${flutterPort}/` 
      : '/';
    window.open(url, '_blank');
  };

  return (
    <div className="animate-fade-in" style={{ padding: '1rem 0' }}>
      {/* Section Header */}
      <div style={{ marginBottom: '2.5rem' }}>
        <span style={{
          color: 'var(--brand-primary)',
          fontFamily: 'var(--font-mono)',
          fontSize: '0.8rem',
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.1em',
          display: 'block',
          marginBottom: '0.5rem',
        }}>
          Engineering Rigor
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.75rem',
        }}>
          Technical Stack & Production Verification
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '800px' }}>
          Production architecture built on Clean Architecture boundaries, Riverpod 2.0 compile-time dependency injection, Supabase PostgreSQL, and offline-first local persistence.
        </p>
      </div>

      {/* 4 Pillars Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
        gap: '1.5rem',
        marginBottom: '3rem',
      }}>
        {/* Pillar 1 */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          boxShadow: 'var(--shadow-md)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', color: 'var(--brand-primary)', marginBottom: '0.75rem' }}>
            <Code2 size={22} />
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.78rem', fontWeight: 800 }}>FRONTEND & PWA ENGINE</span>
          </div>
          <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.75rem' }}>
            Flutter Clean Architecture
          </h3>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.6rem', fontSize: '0.86rem', color: 'var(--text-secondary)' }}>
            <li>• Single codebase running on Web, Android PWA, and Mobile.</li>
            <li>• Riverpod 2.x for compile-safe immutable state management.</li>
            <li>• GoRouter declarative routing with sub-DC auth guards.</li>
            <li>• 60 FPS responsive animations & glassmorphic design system.</li>
          </ul>
        </div>

        {/* Pillar 2 */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          boxShadow: 'var(--shadow-md)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', color: 'var(--brand-primary)', marginBottom: '0.75rem' }}>
            <Database size={22} />
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.78rem', fontWeight: 800 }}>BACKEND & PERSISTENCE</span>
          </div>
          <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.75rem' }}>
            Supabase PostgreSQL 15
          </h3>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.6rem', fontSize: '0.86rem', color: 'var(--text-secondary)' }}>
            <li>• PostgREST instant RESTful API with Row-Level Security (RLS).</li>
            <li>• WebSocket Realtime channels for instant manifest pushes.</li>
            <li>• RFC4122 v4 UUID primary keys across all entities.</li>
            <li>• Zero-downtime schema hot-reload (`NOTIFY pgrst`).</li>
          </ul>
        </div>

        {/* Pillar 3 */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          boxShadow: 'var(--shadow-md)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', color: 'var(--brand-orange)', marginBottom: '0.75rem' }}>
            <Wifi size={22} />
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.78rem', fontWeight: 800 }}>OFFLINE FIRST</span>
          </div>
          <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.75rem' }}>
            Dual-Layer Local Cache
          </h3>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.6rem', fontSize: '0.86rem', color: 'var(--text-secondary)' }}>
            <li>• SharedPreferences + JSON serialization for zero-latency boot.</li>
            <li>• Scoped sub-DC cache keying (`novexps_cache_orders_dc`).</li>
            <li>• Auto-rehydration allows riders to deliver in cellular dead zones.</li>
            <li>• Server timestamp precedence for merge conflict resolution.</li>
          </ul>
        </div>

        {/* Pillar 4 */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          boxShadow: 'var(--shadow-md)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', color: 'var(--brand-primary)', marginBottom: '0.75rem' }}>
            <ShieldCheck size={22} />
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.78rem', fontWeight: 800 }}>VERIFICATION SUITE</span>
          </div>
          <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.75rem' }}>
            21/21 Passing Test Suites
          </h3>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '0.6rem', fontSize: '0.86rem', color: 'var(--text-secondary)' }}>
            <li>• Comprehensive end-to-end DC creation and onboarding.</li>
            <li>• Sub-hub isolation and zero-state verification.</li>
            <li>• Inter-DC stock transfers and inventory reconciliation.</li>
            <li>• Zero analyzer warnings (`flutter analyze lib/` clean).</li>
          </ul>
        </div>
      </div>

      {/* Big Action Button */}
      <div style={{
        background: '#FFFFFF',
        border: '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-xl)',
        padding: '3rem 2rem',
        textAlign: 'center',
        boxShadow: 'var(--shadow-lg)',
      }}>
        <div style={{
          width: '64px',
          height: '64px',
          borderRadius: '16px',
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: '1rem',
          boxShadow: 'var(--shadow-sm)',
        }}>
          <img src="./square_logo.png" alt="NovaExpress" style={{ width: '42px', height: '42px', objectFit: 'contain' }} />
        </div>
        <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
          Ready to Test the Live Operations Platform?
        </h3>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1rem', maxWidth: '600px', margin: '0 auto 1.75rem' }}>
          Launch the DC Console, Rider Dispatch PDA, and Client Portal running live on Supabase with simulated realtime push and remittance matching.
        </p>
        <button
          onClick={launchLiveApp}
          style={{
            background: 'var(--brand-primary)',
            color: '#FFFFFF',
            border: 'none',
            padding: '1rem 2.5rem',
            borderRadius: 'var(--radius-md)',
            fontFamily: 'var(--font-heading)',
            fontWeight: 800,
            fontSize: '1.05rem',
            cursor: 'pointer',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.6rem',
            boxShadow: '0 4px 15px rgba(0, 108, 76, 0.3)',
            transition: 'transform 0.2s',
          }}
        >
          <span>Launch Live NoveXPS Operations App</span>
          <ExternalLink size={18} />
        </button>
      </div>
    </div>
  );
}
