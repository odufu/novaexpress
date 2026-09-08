import React, { useState } from 'react';
import { 
  Package, 
  Layers, 
  CreditCard, 
  CheckCircle, 
  Search, 
  Filter, 
  ArrowRight,
  Shield,
  FileText
} from 'lucide-react';
import { OPERATIONAL_MATRIX, BUSINESS_RULES } from '../data/presentationData';

export default function MatrixAndRules() {
  const [selectedQuadrant, setSelectedQuadrant] = useState('quadrant-4');
  const [filterCategory, setFilterCategory] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  const categories = ['ALL', 'Client', 'Order', 'Payment', 'POD', 'Remittance', 'Inventory', 'Compensation', 'Security'];

  const filteredRules = BUSINESS_RULES.filter(rule => {
    const matchesCat = filterCategory === 'ALL' || rule.category.toLowerCase() === filterCategory.toLowerCase();
    const matchesQuery = searchQuery === '' || 
      rule.id.toLowerCase().includes(searchQuery.toLowerCase()) || 
      rule.text.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCat && matchesQuery;
  });

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
          Architectural Core
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2.4rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '0.75rem',
        }}>
          The 4-Quadrant Operational Matrix
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.05rem', maxWidth: '800px' }}>
          In NoveXPS, Pay-on-Delivery (POD) is not treated as an order type. Every operational delivery is modeled as the intersection of two independent dimensions: <strong>Fulfillment Type</strong> and <strong>Payment Type</strong>.
        </p>
      </div>

      {/* 4 Quadrants Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '1.5rem',
        marginBottom: '3.5rem',
      }}>
        {OPERATIONAL_MATRIX.map((q) => {
          const isSelected = selectedQuadrant === q.id;
          return (
            <div
              key={q.id}
              onClick={() => setSelectedQuadrant(q.id)}
              style={{
                background: '#FFFFFF',
                border: isSelected ? '2px solid var(--brand-primary)' : '1px solid var(--border-subtle)',
                borderRadius: 'var(--radius-lg)',
                padding: '1.75rem',
                cursor: 'pointer',
                transition: 'all 0.25s ease',
                boxShadow: isSelected ? '0 10px 25px -3px rgba(0, 108, 76, 0.15)' : 'var(--shadow-sm)',
                position: 'relative',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem' }}>
                <span style={{
                  fontFamily: 'var(--font-mono)',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  padding: '4px 10px',
                  borderRadius: '6px',
                  background: 'var(--bg-subtle)',
                  color: 'var(--text-primary)',
                }}>
                  {q.fulfillment}
                </span>

                <span style={{
                  fontFamily: 'var(--font-mono)',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  padding: '4px 10px',
                  borderRadius: '6px',
                  background: q.payment.includes('POD') ? 'var(--brand-orange-subtle)' : 'var(--brand-primary-subtle)',
                  color: q.payment.includes('POD') ? 'var(--brand-orange)' : 'var(--brand-primary)',
                }}>
                  {q.payment}
                </span>
              </div>

              <h3 style={{ fontFamily: 'var(--font-heading)', fontSize: '1.25rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '0.5rem' }}>
                {q.title}
              </h3>

              <p style={{ fontSize: '0.88rem', color: 'var(--text-secondary)', marginBottom: '1.25rem', lineHeight: 1.5 }}>
                {q.description}
              </p>

              {/* Step pills */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem', marginBottom: '1rem' }}>
                {q.steps.map((step, idx) => (
                  <div
                    key={idx}
                    style={{
                      background: 'var(--bg-subtle)',
                      padding: '0.45rem 0.75rem',
                      borderRadius: 'var(--radius-sm)',
                      fontSize: '0.78rem',
                      fontFamily: 'var(--font-mono)',
                      color: 'var(--text-secondary)',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.5rem',
                    }}
                  >
                    <span style={{ color: 'var(--brand-primary)', fontWeight: 700 }}>{idx + 1}.</span>
                    <span>{step}</span>
                  </div>
                ))}
              </div>

              <div style={{
                borderTop: '1px solid var(--border-subtle)',
                paddingTop: '0.75rem',
                fontSize: '0.78rem',
                color: 'var(--brand-primary)',
                fontWeight: 600,
              }}>
                {q.settlement}
              </div>
            </div>
          );
        })}
      </div>

      {/* Business Rules Header & Search */}
      <div style={{ marginBottom: '1.75rem' }}>
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
          Governance Axioms
        </span>
        <h2 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '2rem',
          fontWeight: 800,
          color: 'var(--text-primary)',
          letterSpacing: '-0.02em',
          marginBottom: '1rem',
        }}>
          Master Business Rules (BR-001 — BR-024)
        </h2>

        {/* Filter & Search Bar */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '1rem',
          background: '#FFFFFF',
          padding: '0.85rem 1.25rem',
          borderRadius: 'var(--radius-lg)',
          border: '1px solid var(--border-subtle)',
          boxShadow: 'var(--shadow-sm)',
        }}>
          {/* Category Chips */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', flexWrap: 'wrap' }}>
            <Filter size={16} color="var(--text-muted)" style={{ marginRight: '0.25rem' }} />
            {categories.map((cat) => (
              <button
                key={cat}
                onClick={() => setFilterCategory(cat)}
                style={{
                  background: filterCategory === cat ? 'var(--brand-primary)' : 'var(--bg-subtle)',
                  color: filterCategory === cat ? '#FFFFFF' : 'var(--text-secondary)',
                  border: 'none',
                  padding: '4px 10px',
                  borderRadius: '6px',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                }}
              >
                {cat}
              </button>
            ))}
          </div>

          {/* Search Box */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            background: 'var(--bg-subtle)',
            border: '1px solid var(--border-subtle)',
            padding: '5px 12px',
            borderRadius: 'var(--radius-sm)',
            width: '260px',
          }}>
            <Search size={14} color="var(--text-muted)" />
            <input
              type="text"
              placeholder="Search rule (e.g. BR-021, Monnify)..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{
                background: 'transparent',
                border: 'none',
                outline: 'none',
                color: 'var(--text-primary)',
                fontSize: '0.82rem',
                width: '100%',
              }}
            />
          </div>
        </div>
      </div>

      {/* Rules Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
        gap: '1rem',
      }}>
        {filteredRules.map((rule) => (
          <div
            key={rule.id}
            style={{
              background: '#FFFFFF',
              border: '1px solid var(--border-subtle)',
              borderRadius: 'var(--radius-md)',
              padding: '1.25rem',
              boxShadow: 'var(--shadow-sm)',
              transition: 'all 0.2s',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.4rem' }}>
              <span style={{
                fontFamily: 'var(--font-mono)',
                fontSize: '0.82rem',
                fontWeight: 800,
                color: 'var(--brand-primary)',
              }}>
                {rule.id}
              </span>

              <span style={{
                fontFamily: 'var(--font-mono)',
                fontSize: '0.7rem',
                background: 'var(--bg-subtle)',
                color: 'var(--text-muted)',
                padding: '2px 8px',
                borderRadius: '4px',
                fontWeight: 600,
              }}>
                {rule.category}
              </span>
            </div>

            <p style={{ fontSize: '0.88rem', color: 'var(--text-primary)', lineHeight: 1.5 }}>
              {rule.text}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
