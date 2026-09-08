import React, { useState } from 'react';
import { 
  Bike, 
  CreditCard, 
  Truck, 
  Scale, 
  Warehouse, 
  Building2, 
  Store,
  CheckCircle2,
  ArrowRight,
  Sparkles
} from 'lucide-react';
import MermaidViewer from './MermaidViewer';
import { MERMAID_ROLE_WORKFLOWS } from '../data/presentationData';

const workflowIcons = {
  riderDelivery: Bike,
  remittanceFlow: CreditCard,
  restockingFlow: Truck,
  reconciliationFlow: Scale,
  dcSupervisorFlow: Warehouse,
  hqExecutiveFlow: Building2,
  clientMerchantFlow: Store,
};

export default function WorkflowsDiagrams() {
  const [selectedWorkflowKey, setSelectedWorkflowKey] = useState('riderDelivery');
  const activeWf = MERMAID_ROLE_WORKFLOWS[selectedWorkflowKey];
  const IconComp = workflowIcons[selectedWorkflowKey] || Bike;

  return (
    <div className="animate-fade-in" style={{ padding: '1rem 0' }}>
      {/* Section Header */}
      <div style={{ marginBottom: '2rem' }}>
        <div style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: '0.4rem',
          color: 'var(--brand-primary)',
          background: 'var(--brand-primary-subtle)',
          padding: '4px 12px',
          borderRadius: '20px',
          fontFamily: 'var(--font-mono)',
          fontSize: '0.78rem',
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.08em',
          marginBottom: '0.5rem',
        }}>
          <Sparkles size={14} />
          <span>Interactive Visual Architecture</span>
        </div>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.5rem',
        }}>
          Mermaid Role Workflows & Operational Engines
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '850px' }}>
          Role-by-role operational sequence and state machine diagrams. Rendered natively with interactive step-by-step audit trails.
        </p>
      </div>

      {/* Workflow Navigation Selector Tabs */}
      <div style={{
        display: 'flex',
        gap: '0.5rem',
        overflowX: 'auto',
        paddingBottom: '0.75rem',
        marginBottom: '2rem',
      }}>
        {Object.entries(MERMAID_ROLE_WORKFLOWS).map(([key, item]) => {
          const TabIcon = workflowIcons[key] || Bike;
          const isSelected = selectedWorkflowKey === key;
          return (
            <button
              key={key}
              onClick={() => setSelectedWorkflowKey(key)}
              style={{
                background: isSelected ? 'var(--brand-primary)' : '#FFFFFF',
                color: isSelected ? '#FFFFFF' : 'var(--text-secondary)',
                border: isSelected ? '1px solid var(--brand-primary)' : '1px solid var(--border-subtle)',
                padding: '0.65rem 1.1rem',
                borderRadius: 'var(--radius-md)',
                fontFamily: 'var(--font-heading)',
                fontWeight: 700,
                fontSize: '0.85rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                whiteSpace: 'nowrap',
                transition: 'all 0.2s',
                boxShadow: isSelected ? '0 4px 14px rgba(0, 108, 76, 0.25)' : 'var(--shadow-sm)',
              }}
            >
              <TabIcon size={16} color={isSelected ? '#FFFFFF' : 'var(--brand-primary)'} />
              <span>{item.title.split(' ')[0]} {item.title.split(' ')[1]}</span>
            </button>
          );
        })}
      </div>

      {/* Active Workflow Card */}
      <div style={{
        background: '#FFFFFF',
        border: '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-xl)',
        padding: '2rem',
        boxShadow: 'var(--shadow-lg)',
        marginBottom: '2.5rem',
      }}>
        {/* Header Info */}
        <div style={{
          display: 'flex',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '1rem',
          borderBottom: '1px solid var(--border-subtle)',
          paddingBottom: '1.25rem',
          marginBottom: '1.5rem',
        }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.25rem' }}>
              <span style={{
                background: 'var(--brand-primary-subtle)',
                color: 'var(--brand-primary)',
                fontFamily: 'var(--font-mono)',
                fontSize: '0.75rem',
                fontWeight: 700,
                padding: '3px 10px',
                borderRadius: '12px',
              }}>
                {activeWf.badge}
              </span>
              <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>• Actor: <strong>{activeWf.actor}</strong></span>
            </div>
            <h3 style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '1.6rem',
              fontWeight: 800,
              color: 'var(--text-primary)',
            }}>
              {activeWf.title}
            </h3>
            <p style={{ fontSize: '0.92rem', color: 'var(--text-secondary)' }}>
              {activeWf.subtitle}
            </p>
          </div>

          <div style={{
            width: '46px',
            height: '46px',
            borderRadius: '14px',
            background: 'var(--brand-orange-subtle)',
            color: 'var(--brand-orange)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}>
            <IconComp size={24} />
          </div>
        </div>

        {/* Live Mermaid Diagram Viewer */}
        <div style={{ marginBottom: '1.5rem' }}>
          <MermaidViewer chart={activeWf.chart} id={activeWf.id} />
        </div>

        {/* Brand Explanatory Notes */}
        <div style={{
          background: 'var(--bg-primary)',
          borderRadius: 'var(--radius-md)',
          padding: '1.25rem',
          border: '1px solid var(--border-subtle)',
          display: 'flex',
          alignItems: 'flex-start',
          gap: '1rem',
        }}>
          <CheckCircle2 size={22} color="var(--brand-primary)" style={{ flexShrink: 0, marginTop: '2px' }} />
          <div style={{ fontSize: '0.88rem', color: 'var(--text-primary)', lineHeight: 1.6 }}>
            <strong>Operational Architecture Standard:</strong> All role state transitions are audited in Supabase PostgreSQL with immutable timestamps. State mutations broadcast to connected mobile and web clients via Realtime WebSockets within <strong>under 150ms</strong> across Nigeria.
          </div>
        </div>
      </div>
    </div>
  );
}
