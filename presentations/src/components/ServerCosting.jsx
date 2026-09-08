import React from 'react';
import { 
  Server, 
  Database, 
  Cpu, 
  ShieldCheck, 
  Check, 
  Layers, 
  TrendingUp 
} from 'lucide-react';
import { SERVER_COSTING_DATA } from '../data/presentationData';

export default function ServerCosting() {
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
          Infrastructure & OpEx Transparency
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.75rem',
        }}>
          Cloud Infrastructure, Server Charges & Maintenance
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '800px' }}>
          Complete transparent cost model: Supabase PostgreSQL compute, connection pooling via Supavisor, blob storage for POD signatures, payment gateway fees, and monthly maintenance estimates.
        </p>
      </div>

      {/* Infrastructure Costing Table */}
      <div style={{
        background: '#FFFFFF',
        border: '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-lg)',
        overflow: 'hidden',
        boxShadow: 'var(--shadow-md)',
        marginBottom: '3rem',
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead>
            <tr style={{ background: 'var(--bg-subtle)', borderBottom: '1px solid var(--border-subtle)' }}>
              <th style={{ padding: '1rem 1.25rem', fontFamily: 'var(--font-heading)', fontSize: '0.85rem', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Component</th>
              <th style={{ padding: '1rem 1.25rem', fontFamily: 'var(--font-heading)', fontSize: '0.85rem', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Provider / Spec</th>
              <th style={{ padding: '1rem 1.25rem', fontFamily: 'var(--font-heading)', fontSize: '0.85rem', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Unit Cost</th>
              <th style={{ padding: '1rem 1.25rem', fontFamily: 'var(--font-heading)', fontSize: '0.85rem', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Operational Purpose & Quota Strategy</th>
            </tr>
          </thead>
          <tbody>
            {SERVER_COSTING_DATA.map((row, idx) => (
              <tr key={idx} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                <td style={{ padding: '1.1rem 1.25rem', fontWeight: 700, fontSize: '0.92rem', color: 'var(--text-primary)' }}>
                  {row.category}
                </td>
                <td style={{ padding: '1.1rem 1.25rem', fontSize: '0.88rem', color: 'var(--text-secondary)' }}>
                  {row.provider}
                </td>
                <td style={{ padding: '1.1rem 1.25rem', whiteSpace: 'nowrap' }}>
                  <div style={{ fontFamily: 'var(--font-mono)', fontWeight: 800, color: 'var(--brand-primary)', fontSize: '0.94rem' }}>
                    {row.unitUsd}
                  </div>
                  <div style={{ fontFamily: 'var(--font-mono)', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                    {row.unitNgn}
                  </div>
                </td>
                <td style={{ padding: '1.1rem 1.25rem', fontSize: '0.86rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
                  {row.description}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Scale Scenarios Header */}
      <div style={{ marginBottom: '1.5rem' }}>
        <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
          Monthly Infrastructure OpEx at Scale
        </h3>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>
          Because NoveXPS utilizes optimized WebSocket push and lightweight Supabase serverless compute, unit server cost decreases exponentially as order volume increases.
        </p>
      </div>

      {/* 3 Tier Scale Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
        gap: '1.5rem',
      }}>
        {/* Tier 1 */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          position: 'relative',
          boxShadow: 'var(--shadow-md)',
        }}>
          <span style={{
            fontFamily: 'var(--font-mono)',
            fontSize: '0.75rem',
            fontWeight: 700,
            color: 'var(--brand-primary)',
            textTransform: 'uppercase',
            marginBottom: '0.5rem',
            display: 'block',
          }}>
            Tier 1 • Regional Pilot
          </span>
          <div style={{ fontFamily: 'var(--font-heading)', fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.2rem' }}>
            1,000 Orders / day
          </div>
          <div style={{ fontFamily: 'var(--font-mono)', fontSize: '1.35rem', fontWeight: 800, color: 'var(--brand-primary)', marginBottom: '1.25rem' }}>
            ~₦65,000 / mo ($42)
          </div>
          <ul style={{ listStyle: 'none', borderTop: '1px solid var(--border-subtle)', paddingTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.5rem', fontSize: '0.84rem', color: 'var(--text-secondary)' }}>
            <li>• 30,000 deliveries / month</li>
            <li>• Supabase Pro ($25) + Micro compute ($10)</li>
            <li>• Storage: ~12GB (signature blobs)</li>
            <li>• 2 regional DCs (Lagos, Abuja)</li>
            <li style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>• Server Cost per Delivery: ₦2.16</li>
          </ul>
        </div>

        {/* Tier 2 */}
        <div style={{
          background: '#FFFFFF',
          border: '2px solid var(--brand-primary)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          position: 'relative',
          boxShadow: '0 10px 25px -3px rgba(0, 108, 76, 0.15)',
        }}>
          <div style={{
            position: 'absolute',
            top: '-12px',
            right: '20px',
            background: 'var(--brand-primary)',
            color: '#FFFFFF',
            fontSize: '0.72rem',
            fontWeight: 800,
            padding: '4px 12px',
            borderRadius: '12px',
            textTransform: 'uppercase',
          }}>
            Optimal Sweet Spot
          </div>
          <span style={{
            fontFamily: 'var(--font-mono)',
            fontSize: '0.75rem',
            fontWeight: 700,
            color: 'var(--brand-primary)',
            textTransform: 'uppercase',
            marginBottom: '0.5rem',
            display: 'block',
          }}>
            Tier 2 • National Scale
          </span>
          <div style={{ fontFamily: 'var(--font-heading)', fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.2rem' }}>
            10,000 Orders / day
          </div>
          <div style={{ fontFamily: 'var(--font-mono)', fontSize: '1.35rem', fontWeight: 800, color: 'var(--brand-primary)', marginBottom: '1.25rem' }}>
            ~₦185,000 / mo ($120)
          </div>
          <ul style={{ listStyle: 'none', borderTop: '1px solid var(--border-subtle)', paddingTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.5rem', fontSize: '0.84rem', color: 'var(--text-secondary)' }}>
            <li>• 300,000 deliveries / month</li>
            <li>• Supabase Small Compute ($60) + Pro ($25) + Egress ($35)</li>
            <li>• Storage: ~85GB</li>
            <li>• 6-10 national distribution centers</li>
            <li style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>• Server Cost per Delivery: ₦0.61 (Extreme Margin!)</li>
          </ul>
        </div>

        {/* Tier 3 */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          position: 'relative',
          boxShadow: 'var(--shadow-md)',
        }}>
          <span style={{
            fontFamily: 'var(--font-mono)',
            fontSize: '0.75rem',
            fontWeight: 700,
            color: 'var(--brand-orange)',
            textTransform: 'uppercase',
            marginBottom: '0.5rem',
            display: 'block',
          }}>
            Tier 3 • Enterprise Dominance
          </span>
          <div style={{ fontFamily: 'var(--font-heading)', fontSize: '1.8rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.2rem' }}>
            50,000 Orders / day
          </div>
          <div style={{ fontFamily: 'var(--font-mono)', fontSize: '1.35rem', fontWeight: 800, color: 'var(--brand-primary)', marginBottom: '1.25rem' }}>
            ~₦580,000 / mo ($375)
          </div>
          <ul style={{ listStyle: 'none', borderTop: '1px solid var(--border-subtle)', paddingTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.5rem', fontSize: '0.84rem', color: 'var(--text-secondary)' }}>
            <li>• 1,500,000 deliveries / month</li>
            <li>• Supabase Medium ($160) + Dedicated Poolers + S3 Storage</li>
            <li>• Multi-region read replicas across Nigeria</li>
            <li>• Full enterprise SLAs with 99.99% uptime</li>
            <li style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>• Server Cost per Delivery: ₦0.38</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
