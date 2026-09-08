import React from 'react';
import { 
  Maximize2, 
  Minimize2, 
  Search, 
  Layout, 
  ScrollText, 
  Calculator, 
  BookOpen, 
  GitBranch,
  AlertTriangle 
} from 'lucide-react';

export default function TopHeader({
  viewMode,
  setViewMode,
  isFullScreen,
  toggleFullScreen,
  setIsSearchOpen,
}) {
  return (
    <header style={{
      position: 'sticky',
      top: 0,
      zIndex: 50,
      background: 'rgba(255, 255, 255, 0.95)',
      backdropFilter: 'blur(16px)',
      WebkitBackdropFilter: 'blur(16px)',
      borderBottom: '1px solid var(--border-subtle)',
      padding: '0.75rem 2rem',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      flexWrap: 'wrap',
      gap: '1rem',
      boxShadow: 'var(--shadow-sm)',
    }}>
      {/* Brand & Logo Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
        <div style={{
          width: '46px',
          height: '46px',
          borderRadius: '12px',
          background: '#FFFFFF',
          border: '1px solid var(--border-subtle)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: 'var(--shadow-md)',
          padding: '4px',
          overflow: 'hidden',
        }}>
          <img
            src="./square_logo.png"
            alt="NovaExpress Logo"
            style={{ width: '100%', height: '100%', objectFit: 'contain' }}
            onError={(e) => {
              // Fallback if image path differs
              e.target.style.display = 'none';
              e.target.parentElement.innerHTML = '<span style="font-weight:900;color:#006C4C;">NX</span>';
            }}
          />
        </div>

        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <h1 style={{
              fontFamily: 'var(--font-heading)',
              fontSize: '1.35rem',
              fontWeight: 800,
              color: 'var(--brand-primary)',
              letterSpacing: '-0.02em',
              lineHeight: 1.1,
            }}>
              NovaExpress
            </h1>
            <span style={{
              background: 'var(--brand-orange-subtle)',
              color: 'var(--brand-orange)',
              padding: '2px 8px',
              borderRadius: '6px',
              fontSize: '0.7rem',
              fontWeight: 800,
              fontFamily: 'var(--font-mono)',
            }}>
              NoveXPS
            </span>
          </div>
          <p style={{
            fontSize: '0.78rem',
            color: 'var(--text-muted)',
            fontWeight: 600,
          }}>
            Interactive Master Presentation • Architecture • Mermaid Workflows • Costing
          </p>
        </div>
      </div>

      {/* Controls & Nav Modes */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
        <div style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: '6px',
          background: 'var(--brand-primary-subtle)',
          border: '1px solid rgba(0, 108, 76, 0.25)',
          color: 'var(--brand-primary)',
          padding: '4px 12px',
          borderRadius: '20px',
          fontSize: '0.75rem',
          fontWeight: 700,
        }}>
          <span className="pulse-dot"></span>
          <span>Live Demo Ready</span>
        </div>

        {/* View Mode Nav Tabs */}
        <div style={{
          display: 'flex',
          background: 'var(--bg-subtle)',
          padding: '4px',
          borderRadius: 'var(--radius-md)',
          border: '1px solid var(--border-subtle)',
        }}>
          <button
            onClick={() => setViewMode('deck')}
            style={{
              background: viewMode === 'deck' ? 'var(--brand-primary)' : 'transparent',
              color: viewMode === 'deck' ? '#FFFFFF' : 'var(--text-secondary)',
              border: 'none',
              padding: '0.45rem 0.85rem',
              borderRadius: 'var(--radius-sm)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              fontSize: '0.82rem',
              fontWeight: 700,
              transition: 'all 0.2s',
            }}
          >
            <Layout size={14} />
            Slide Deck
          </button>

          <button
            onClick={() => setViewMode('workflows')}
            style={{
              background: viewMode === 'workflows' ? 'var(--brand-primary)' : 'transparent',
              color: viewMode === 'workflows' ? '#FFFFFF' : 'var(--text-secondary)',
              border: 'none',
              padding: '0.45rem 0.85rem',
              borderRadius: 'var(--radius-sm)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              fontSize: '0.82rem',
              fontWeight: 700,
              transition: 'all 0.2s',
            }}
          >
            <GitBranch size={14} />
            Mermaid Workflows
          </button>

          <button
            onClick={() => setViewMode('canvas')}
            style={{
              background: viewMode === 'canvas' ? 'var(--brand-primary)' : 'transparent',
              color: viewMode === 'canvas' ? '#FFFFFF' : 'var(--text-secondary)',
              border: 'none',
              padding: '0.45rem 0.85rem',
              borderRadius: 'var(--radius-sm)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              fontSize: '0.82rem',
              fontWeight: 700,
              transition: 'all 0.2s',
            }}
          >
            <ScrollText size={14} />
            Full Canvas
          </button>

          <button
            onClick={() => setViewMode('calc')}
            style={{
              background: viewMode === 'calc' ? 'var(--brand-primary)' : 'transparent',
              color: viewMode === 'calc' ? '#FFFFFF' : 'var(--text-secondary)',
              border: 'none',
              padding: '0.45rem 0.85rem',
              borderRadius: 'var(--radius-sm)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              fontSize: '0.82rem',
              fontWeight: 700,
              transition: 'all 0.2s',
            }}
          >
            <Calculator size={14} />
            ROI Calculator
          </button>

          <button
            onClick={() => setViewMode('rules')}
            style={{
              background: viewMode === 'rules' ? 'var(--brand-primary)' : 'transparent',
              color: viewMode === 'rules' ? '#FFFFFF' : 'var(--text-secondary)',
              border: 'none',
              padding: '0.45rem 0.85rem',
              borderRadius: 'var(--radius-sm)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              fontSize: '0.82rem',
              fontWeight: 700,
              transition: 'all 0.2s',
            }}
          >
            <BookOpen size={14} />
            BR 1-24
          </button>
        </div>

        {/* Search button */}
        <button
          onClick={() => setIsSearchOpen(true)}
          title="Search Rules & Features (Ctrl+K or S)"
          style={{
            background: '#FFFFFF',
            border: '1px solid var(--border-subtle)',
            color: 'var(--text-secondary)',
            width: '38px',
            height: '38px',
            borderRadius: '10px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            transition: 'all 0.2s',
            boxShadow: 'var(--shadow-sm)',
          }}
        >
          <Search size={18} />
        </button>

        {/* Fullscreen button */}
        <button
          onClick={toggleFullScreen}
          title="Toggle Fullscreen (F)"
          style={{
            background: '#FFFFFF',
            border: '1px solid var(--border-subtle)',
            color: 'var(--text-secondary)',
            width: '38px',
            height: '38px',
            borderRadius: '10px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            transition: 'all 0.2s',
            boxShadow: 'var(--shadow-sm)',
          }}
        >
          {isFullScreen ? <Minimize2 size={18} /> : <Maximize2 size={18} />}
        </button>
      </div>
    </header>
  );
}
