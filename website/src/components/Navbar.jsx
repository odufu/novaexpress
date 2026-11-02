import React, { useState, useEffect } from 'react';
import { 
  Search, 
  Menu, 
  X, 
  Sliders, 
  ArrowRight,
  ShieldCheck
} from 'lucide-react';

export default function Navbar({ activePage, setActivePage, settings, onOpenTracking }) {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 15);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const navItems = [
    { id: 'home', label: 'Home' },
    { id: 'services', label: 'Services' },
    { id: 'portfolio', label: 'Case Studies' },
    { id: 'about', label: 'Network' },
    { id: 'tracking', label: 'Track Order' },
  ];

  const handleNavClick = (id) => {
    setActivePage(id);
    setMobileMenuOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <header 
      style={{
        position: 'sticky',
        top: 0,
        zIndex: 100,
        transition: 'all 0.25s ease',
        background: isScrolled ? 'rgba(250, 249, 251, 0.95)' : '#FAF9FB',
        backdropFilter: 'blur(12px)',
        borderBottom: '1px solid #EAEBEE',
        boxShadow: isScrolled ? '0 4px 20px rgba(8, 38, 88, 0.05)' : 'none',
      }}
    >
      <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: '74px' }}>
        
        {/* Brand Logo with square_logo.png as requested */}
        <div 
          onClick={() => handleNavClick('home')}
          style={{ display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }}
        >
          <img 
            src="/branding/square_logo.png" 
            alt="NovaXpress Square Logo" 
            style={{
              width: '42px',
              height: '42px',
              borderRadius: '10px',
              objectFit: 'contain',
              boxShadow: '0 2px 8px rgba(8, 38, 88, 0.08)',
            }}
          />
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontWeight: 800, fontSize: '20px', letterSpacing: '-0.03em', lineHeight: 1, color: '#082658' }}>
              Nova<span style={{ color: '#FD7A02' }}>Xpress</span>
            </span>
            <span style={{ fontSize: '10px', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#7E8DA6', marginTop: '3px' }}>
              Logistics Network
            </span>
          </div>
        </div>

        {/* Simplistic Desktop Navigation */}
        <nav className="desktop-nav" style={{ display: 'flex', alignItems: 'center', gap: '32px' }}>
          {navItems.map((item) => (
            <button
              key={item.id}
              onClick={() => handleNavClick(item.id)}
              style={{
                background: 'transparent',
                color: activePage === item.id ? '#FD7A02' : '#082658',
                fontWeight: activePage === item.id ? 700 : 600,
                fontSize: '14px',
                padding: '8px 0',
                position: 'relative',
                transition: 'color 0.2s',
              }}
              onMouseEnter={(e) => e.target.style.color = '#FD7A02'}
              onMouseLeave={(e) => e.target.style.color = activePage === item.id ? '#FD7A02' : '#082658'}
            >
              {item.label}
              {activePage === item.id && (
                <div style={{
                  position: 'absolute',
                  bottom: -2,
                  left: 0,
                  right: 0,
                  height: '2.5px',
                  background: '#FD7A02',
                  borderRadius: '2px',
                }} />
              )}
            </button>
          ))}
        </nav>

        {/* Header Right Actions */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          
          {/* Quick Track Button */}
          <button
            onClick={onOpenTracking}
            className="btn-secondary btn-sm"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              borderColor: '#EAEBEE',
              color: '#082658',
            }}
            title="Fast Shipment Tracking"
          >
            <Search size={14} color="#FD7A02" />
            <span>Track</span>
          </button>

          {/* Request Quote Button */}
          <button
            onClick={() => handleNavClick('contact')}
            className="btn-primary btn-sm desktop-only"
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <span>Get Quote</span>
            <ArrowRight size={14} />
          </button>

          {/* Mobile Menu Toggle */}
          <button
            className="mobile-toggle"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            style={{
              background: '#EAEBEE',
              color: '#082658',
              padding: '8px',
              borderRadius: 'var(--radius-sm)',
              display: 'none',
            }}
          >
            {mobileMenuOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>

      </div>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div 
          style={{
            background: '#FAF9FB',
            borderTop: '1px solid #EAEBEE',
            padding: '20px 24px 28px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
          }}
        >
          {navItems.map((item) => (
            <button
              key={item.id}
              onClick={() => handleNavClick(item.id)}
              style={{
                textAlign: 'left',
                background: 'transparent',
                color: activePage === item.id ? '#FD7A02' : '#082658',
                fontSize: '16px',
                fontWeight: activePage === item.id ? 700 : 600,
                padding: '8px 0',
              }}
            >
              {item.label}
            </button>
          ))}
          <button
            onClick={() => handleNavClick('contact')}
            className="btn-primary"
            style={{ width: '100%', marginTop: '10px' }}
          >
            Request a Quote
          </button>
        </div>
      )}

      <style>{`
        @media (max-width: 992px) {
          .desktop-nav {
            display: none !important;
          }
          .desktop-only {
            display: none !important;
          }
          .mobile-toggle {
            display: flex !important;
          }
        }
      `}</style>
    </header>
  );
}
