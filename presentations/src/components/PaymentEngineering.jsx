import React from 'react';
import { 
  Banknote, 
  CreditCard, 
  Smartphone, 
  ShieldCheck, 
  Check, 
  Lock, 
  FileText
} from 'lucide-react';

export default function PaymentEngineering() {
  return (
    <div className="animate-fade-in" style={{ padding: '1rem 0' }}>
      {/* Section Header */}
      <div style={{ marginBottom: '2.5rem' }}>
        <span style={{
          color: 'var(--brand-orange)',
          fontFamily: 'var(--font-mono)',
          fontSize: '0.8rem',
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.1em',
          display: 'block',
          marginBottom: '0.5rem',
        }}>
          Financial Engineering
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.75rem',
        }}>
          Payments, Remittance & Virtual Account Engineering
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '800px' }}>
          Three specialized payment rails engineered to eliminate cash shrinkage while giving Nigerian customers maximum convenience at the doorstep.
        </p>
      </div>

      {/* 3 Payment Rails */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '1.5rem',
        marginBottom: '3rem',
      }}>
        {/* Rail 1: Physical Cash */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          boxShadow: 'var(--shadow-md)',
        }}>
          <div>
            <span style={{
              fontFamily: 'var(--font-mono)',
              fontSize: '0.75rem',
              fontWeight: 700,
              padding: '4px 12px',
              borderRadius: '20px',
              background: 'var(--brand-orange-subtle)',
              color: 'var(--brand-orange)',
              marginBottom: '1rem',
              display: 'inline-block',
            }}>
              Rail 1 • Physical COD
            </span>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.35rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
              Cash on Delivery (COD)
            </h3>
            <p style={{ fontSize: '0.88rem', color: 'var(--text-secondary)', lineHeight: 1.5, marginBottom: '1.25rem' }}>
              Traditional physical currency. High risk for driver assault and cash theft. Governed with strict daily holding thresholds and mandatory same-day DC vault handover.
            </p>
          </div>

          <ul style={{ listStyle: 'none', borderTop: '1px solid var(--border-subtle)', paddingTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.6rem', fontSize: '0.84rem', color: 'var(--text-primary)' }}>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="var(--brand-orange)" /> Hard Cash Limit: ₦50,000 max hold per rider
            </li>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="var(--brand-orange)" /> Mandatory same-day DC vault handover
            </li>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="var(--brand-orange)" /> Discrepancies lock rider dispatch permissions
            </li>
          </ul>
        </div>

        {/* Rail 2: Monnify Dynamic Virtual Accounts */}
        <div style={{
          background: '#FFFFFF',
          border: '2px solid var(--brand-primary)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          boxShadow: '0 10px 25px -3px rgba(0, 108, 76, 0.15)',
          position: 'relative',
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
            Zero Cash Liability
          </div>

          <div>
            <span style={{
              fontFamily: 'var(--font-mono)',
              fontSize: '0.75rem',
              fontWeight: 700,
              padding: '4px 12px',
              borderRadius: '20px',
              background: 'var(--brand-primary-subtle)',
              color: 'var(--brand-primary)',
              marginBottom: '1rem',
              display: 'inline-block',
            }}>
              Rail 2 • Dynamic Virtual Account
            </span>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.35rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
              Monnify Direct Bank Transfer
            </h3>
            <p style={{ fontSize: '0.88rem', color: 'var(--text-secondary)', lineHeight: 1.5, marginBottom: '1.25rem' }}>
              App generates dedicated virtual Wema/Sterling account per order. Customer pays via USSD/Mobile app directly to company bank. <em>Zero cash liability for rider!</em>
            </p>
          </div>

          <ul style={{ listStyle: 'none', borderTop: '1px solid var(--border-subtle)', paddingTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.6rem', fontSize: '0.84rem', color: 'var(--text-primary)' }}>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="var(--brand-primary)" /> Zero physical cash handling by rider
            </li>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="var(--brand-primary)" /> Real-time webhook notification via Supabase
            </li>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="var(--brand-primary)" /> Auto-credits rider commission to "My Balance"
            </li>
          </ul>
        </div>

        {/* Rail 3: Paystack POS & Card */}
        <div style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          boxShadow: 'var(--shadow-md)',
        }}>
          <div>
            <span style={{
              fontFamily: 'var(--font-mono)',
              fontSize: '0.75rem',
              fontWeight: 700,
              padding: '4px 12px',
              borderRadius: '20px',
              background: '#EFF6FF',
              color: '#2563EB',
              marginBottom: '1rem',
              display: 'inline-block',
            }}>
              Rail 3 • Card & POS Gateway
            </span>
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.35rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
              Paystack POS & Online Terminal
            </h3>
            <p style={{ fontSize: '0.88rem', color: 'var(--text-secondary)', lineHeight: 1.5, marginBottom: '1.25rem' }}>
              Integrated mobile card readers and payment links for customers opting for debit cards at the doorstep. Separate transaction fee tracking for accounting.
            </p>
          </div>

          <ul style={{ listStyle: 'none', borderTop: '1px solid var(--border-subtle)', paddingTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.6rem', fontSize: '0.84rem', color: 'var(--text-primary)' }}>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="#2563EB" /> Configurable POS fee surcharge rules
            </li>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="#2563EB" /> Instant digital invoice and SMS receipt
            </li>
            <li style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Check size={16} color="#2563EB" /> Auto-reconciled against Paystack settlement
            </li>
          </ul>
        </div>
      </div>

      {/* Cryptographic SHA-256 Tamper-Evident Receipts Banner */}
      <div style={{
        background: '#FFFFFF',
        border: '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-xl)',
        padding: '2.5rem',
        boxShadow: 'var(--shadow-lg)',
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '2rem',
        alignItems: 'center',
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.75rem' }}>
            <Lock size={22} color="var(--brand-primary)" />
            <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 800, color: 'var(--text-primary)' }}>
              Cryptographic Tamper-Evident Remittance Receipts
            </h3>
          </div>
          <p style={{ fontSize: '0.92rem', color: 'var(--text-secondary)', lineHeight: 1.6 }}>
            Every cash remittance batch approved by DC Operations cryptographically hashes order numbers, rider code, currency breakdown, and timestamp using SHA-256. Any post-settlement database tampering immediately invalidates the signature hash.
          </p>
        </div>

        <div style={{
          background: '#0F172A',
          border: '1px solid #1E293B',
          borderRadius: 'var(--radius-md)',
          padding: '1.5rem',
          fontFamily: 'var(--font-mono)',
          fontSize: '0.82rem',
          color: '#94A3B8',
          lineHeight: 1.7,
        }}>
          <div style={{ color: 'var(--brand-primary-light)', fontWeight: 800 }}>[OFFICIAL REMITTANCE HASH]</div>
          <div>BATCH_ID: REM-20260907-KAN01-042</div>
          <div>VAULT_CASH: <span style={{ color: '#FFFFFF' }}>₦185,000.00 (VERIFIED)</span></div>
          <div>SIGNATURE: <span style={{ color: 'var(--brand-orange)' }}>3b9f84a1e9c204dd128e7b927a41...</span></div>
          <div style={{ color: 'var(--brand-primary-light)', marginTop: '0.4rem' }}>STATUS: IMMUTABLE AUDIT RECORD ✓</div>
        </div>
      </div>
    </div>
  );
}
