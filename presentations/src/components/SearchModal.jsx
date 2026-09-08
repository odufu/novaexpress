import React, { useState, useEffect, useRef } from 'react';
import { Search, X, ArrowRight, BookOpen, Layers, Shield } from 'lucide-react';
import { BUSINESS_RULES, OPERATIONAL_MATRIX, CURRENT_CHALLENGES_DATA } from '../data/presentationData';

export default function SearchModal({ isOpen, onClose, goToSlide }) {
  const [query, setQuery] = useState('');
  const inputRef = useRef(null);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const q = query.toLowerCase().trim();

  // Search Results
  const matchingRules = BUSINESS_RULES.filter(r => 
    r.id.toLowerCase().includes(q) || r.text.toLowerCase().includes(q)
  );

  const matchingChallenges = CURRENT_CHALLENGES_DATA.filter(c =>
    c.title.toLowerCase().includes(q) || c.solution.toLowerCase().includes(q)
  );

  const matchingQuadrants = OPERATIONAL_MATRIX.filter(m =>
    m.title.toLowerCase().includes(q) || m.description.toLowerCase().includes(q)
  );

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100vw',
        height: '100vh',
        background: 'rgba(15, 23, 42, 0.6)',
        backdropFilter: 'blur(6px)',
        zIndex: 200,
        display: 'flex',
        alignItems: 'flex-start',
        justifyContent: 'center',
        paddingTop: '10vh',
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-lg)',
          width: '90%',
          maxWidth: '650px',
          maxHeight: '75vh',
          overflow: 'hidden',
          boxShadow: 'var(--shadow-xl)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {/* Search Input Bar */}
        <div style={{
          padding: '1.25rem 1.5rem',
          borderBottom: '1px solid var(--border-subtle)',
          display: 'flex',
          alignItems: 'center',
          gap: '0.75rem',
          background: '#FFFFFF',
        }}>
          <Search size={20} color="var(--brand-primary)" />
          <input
            ref={inputRef}
            type="text"
            placeholder="Search rules (e.g. BR-021), Monnify, Remittance, Escrow..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            style={{
              background: 'transparent',
              border: 'none',
              outline: 'none',
              fontSize: '1.05rem',
              color: 'var(--text-primary)',
              width: '100%',
              fontFamily: 'inherit',
            }}
          />
          <button
            onClick={onClose}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--text-muted)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Results List */}
        <div style={{ padding: '1.25rem', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '0.75rem', background: 'var(--bg-primary)' }}>
          {q === '' && (
            <div style={{ color: 'var(--text-muted)', fontSize: '0.88rem', textAlign: 'center', padding: '1.5rem' }}>
              Type a keyword to search all 24 Business Rules, Operational Matrices, and Challenges...
            </div>
          )}

          {/* Rules Matches */}
          {matchingRules.length > 0 && (
            <div>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '0.5rem', display: 'block' }}>
                Business Rules ({matchingRules.length})
              </span>
              {matchingRules.slice(0, 6).map((rule) => (
                <div
                  key={rule.id}
                  onClick={() => { goToSlide(2); onClose(); }}
                  style={{
                    background: '#FFFFFF',
                    border: '1px solid var(--border-subtle)',
                    padding: '0.85rem 1rem',
                    borderRadius: 'var(--radius-sm)',
                    cursor: 'pointer',
                    marginBottom: '0.4rem',
                    transition: 'all 0.2s',
                    boxShadow: 'var(--shadow-sm)',
                  }}
                >
                  <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.8rem', color: 'var(--brand-primary)', fontWeight: 800, marginRight: '0.5rem' }}>
                    {rule.id}
                  </span>
                  <span style={{ fontSize: '0.88rem', color: 'var(--text-primary)' }}>
                    {rule.text}
                  </span>
                </div>
              ))}
            </div>
          )}

          {/* Challenges Matches */}
          {matchingChallenges.length > 0 && (
            <div style={{ marginTop: '0.5rem' }}>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '0.5rem', display: 'block' }}>
                Operational Challenges & Solutions ({matchingChallenges.length})
              </span>
              {matchingChallenges.map((ch) => (
                <div
                  key={ch.id}
                  onClick={() => { goToSlide(6); onClose(); }}
                  style={{
                    background: '#FFFFFF',
                    border: '1px solid var(--border-subtle)',
                    padding: '0.85rem 1rem',
                    borderRadius: 'var(--radius-sm)',
                    cursor: 'pointer',
                    marginBottom: '0.4rem',
                    boxShadow: 'var(--shadow-sm)',
                  }}
                >
                  <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--accent-rose)', marginBottom: '0.2rem' }}>
                    {ch.title}
                  </div>
                  <div style={{ fontSize: '0.84rem', color: 'var(--text-secondary)' }}>
                    {ch.solution}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
