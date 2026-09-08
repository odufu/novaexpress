import React, { useState } from 'react';
import { 
  Building2, 
  Warehouse, 
  Bike, 
  Store, 
  ShieldCheck, 
  CheckCircle, 
  Terminal
} from 'lucide-react';
import { ROLE_DETAILS } from '../data/presentationData';

const roleIcons = {
  hq: Building2,
  dc: Warehouse,
  rider: Bike,
  client: Store,
};

export default function RoleArchitecture() {
  const [activeRole, setActiveRole] = useState('hq');
  const role = ROLE_DETAILS[activeRole];
  const IconComponent = roleIcons[activeRole];

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
          Multi-Tenant RBAC Hierarchy
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.75rem',
        }}>
          Role Architecture & Specific Feature Suites
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '800px' }}>
          Each organizational tier operates within a tightly guarded boundary: HQ governs national liquidity, DC Supervisors manage isolated sub-hubs, Riders execute real-time last-mile deliveries, and Clients manage catalog fulfillment.
        </p>
      </div>

      {/* Role Tabs */}
      <div style={{
        display: 'flex',
        gap: '0.75rem',
        marginBottom: '2.5rem',
        overflowX: 'auto',
        paddingBottom: '0.5rem',
      }}>
        {Object.entries(ROLE_DETAILS).map(([key, item]) => {
          const TabIcon = roleIcons[key];
          const isActive = activeRole === key;
          return (
            <button
              key={key}
              onClick={() => setActiveRole(key)}
              style={{
                background: isActive ? 'var(--brand-primary)' : '#FFFFFF',
                border: isActive ? '1px solid var(--brand-primary)' : '1px solid var(--border-subtle)',
                color: isActive ? '#FFFFFF' : 'var(--text-secondary)',
                padding: '0.85rem 1.5rem',
                borderRadius: 'var(--radius-md)',
                fontFamily: 'var(--font-heading)',
                fontWeight: 700,
                fontSize: '0.92rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '0.6rem',
                whiteSpace: 'nowrap',
                transition: 'all 0.25s',
                boxShadow: isActive ? '0 4px 15px rgba(0, 108, 76, 0.25)' : 'var(--shadow-sm)',
              }}
            >
              <TabIcon size={18} color={isActive ? '#FFFFFF' : 'var(--brand-primary)'} />
              {item.title.split(' ')[0]} {item.title.split(' ')[1]}
            </button>
          );
        })}
      </div>

      {/* Active Role Content Layout */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))',
        gap: '2rem',
      }}>
        {/* Left: Features List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{
            background: '#FFFFFF',
            border: '1px solid var(--border-subtle)',
            borderRadius: 'var(--radius-lg)',
            padding: '1.75rem',
            boxShadow: 'var(--shadow-md)',
            marginBottom: '0.5rem',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
              <span style={{
                fontFamily: 'var(--font-mono)',
                fontSize: '0.75rem',
                fontWeight: 700,
                padding: '4px 12px',
                borderRadius: '20px',
                background: 'var(--brand-primary-subtle)',
                color: 'var(--brand-primary)',
              }}>
                {role.badge}
              </span>
              <IconComponent size={24} color="var(--brand-primary)" />
            </div>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.45rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.4rem' }}>
              {role.title}
            </h3>
            <p style={{ fontSize: '0.92rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              {role.description}
            </p>
          </div>

          {/* 4 Feature Items */}
          {role.features.map((feat, idx) => (
            <div
              key={idx}
              style={{
                background: '#FFFFFF',
                border: '1px solid var(--border-subtle)',
                borderRadius: 'var(--radius-md)',
                padding: '1.25rem',
                display: 'flex',
                gap: '1rem',
                boxShadow: 'var(--shadow-sm)',
              }}
            >
              <div style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                background: 'var(--brand-primary-subtle)',
                color: 'var(--brand-primary)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
              }}>
                <CheckCircle size={18} />
              </div>

              <div>
                <h4 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.02rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.25rem' }}>
                  {feat.title}
                </h4>
                <p style={{ fontSize: '0.86rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
                  {feat.desc}
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* Right: Mockup & Runtime State Inspection */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-xl)',
          padding: '2rem',
          boxShadow: 'var(--shadow-lg)',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
        }}>
          <div>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              paddingBottom: '1rem',
              borderBottom: '1px solid var(--border-subtle)',
              marginBottom: '1.25rem',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#EF4444' }} />
                <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#F59E0B' }} />
                <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#10B981' }} />
              </div>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                Live Controller Runtime
              </span>
            </div>

            <div style={{
              background: '#0F172A',
              borderRadius: 'var(--radius-md)',
              padding: '1.5rem',
              border: '1px solid #1E293B',
              fontFamily: 'var(--font-mono)',
              fontSize: '0.84rem',
              color: '#94A3B8',
              lineHeight: 1.7,
              whiteSpace: 'pre-wrap',
            }}>
              {role.mockupCode}
            </div>
          </div>

          <div style={{
            marginTop: '1.5rem',
            padding: '1.1rem',
            borderRadius: 'var(--radius-md)',
            background: 'var(--brand-primary-subtle)',
            border: '1px solid rgba(0, 108, 76, 0.25)',
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
          }}>
            <ShieldCheck size={24} color="var(--brand-primary)" />
            <div style={{ fontSize: '0.85rem', color: 'var(--brand-primary)', fontWeight: 600 }}>
              <strong>Access Token Role Guard:</strong> Scoped via Supabase RLS policies and Riverpod state controllers.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
