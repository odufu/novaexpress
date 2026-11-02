import React, { useState } from 'react';
import { Search, X, CheckCircle2, Clock, MapPin, Truck, ShieldAlert, ArrowRight } from 'lucide-react';
import { trackShipment } from '../lib/supabase';

export default function TrackingModal({ isOpen, onClose, initialCode }) {
  const [query, setQuery] = useState(initialCode || '');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleSearch = async (e) => {
    if (e) e.preventDefault();
    if (!query.trim()) return;

    setLoading(true);
    try {
      const data = await trackShipment(query.trim());
      setResult(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  // Perform initial search if code is provided
  React.useEffect(() => {
    if (initialCode && isOpen) {
      setQuery(initialCode);
      setLoading(true);
      trackShipment(initialCode).then((data) => {
        setResult(data);
        setLoading(false);
      });
    }
  }, [initialCode, isOpen]);

  if (!isOpen) return null;

  return (
    <div 
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0, 0, 0, 0.85)',
        backdropFilter: 'blur(10px)',
        zIndex: 1000,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px',
      }}
      onClick={onClose}
    >
      <div 
        className="glass-panel"
        style={{
          maxWidth: '640px',
          width: '100%',
          maxHeight: '90vh',
          overflowY: 'auto',
          padding: '36px',
          background: '#0B1120',
          border: '1px solid rgba(59, 130, 246, 0.4)',
          boxShadow: '0 25px 60px rgba(0, 0, 0, 0.9), var(--shadow-glow)',
          position: 'relative',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close Button */}
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '20px',
            right: '20px',
            background: 'rgba(255, 255, 255, 0.08)',
            color: '#FFFFFF',
            padding: '8px',
            borderRadius: '50%',
          }}
        >
          <X size={18} />
        </button>

        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
          <div style={{ width: '32px', height: '32px', borderRadius: '8px', background: 'rgba(59, 130, 246, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Truck size={18} color="#60A5FA" />
          </div>
          <h3 style={{ fontSize: '20px', color: '#FFFFFF' }}>Live Consignment Tracker</h3>
        </div>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '24px' }}>
          Enter your NovaXpress waybill or order tracking number to inspect real-time milestones.
        </p>

        {/* Search input form */}
        <form onSubmit={handleSearch} style={{ display: 'flex', gap: '10px', marginBottom: '28px' }}>
          <div style={{ position: 'relative', flex: 1 }}>
            <Search size={18} color="#94A3B8" style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)' }} />
            <input
              type="text"
              placeholder="e.g. NX-042969 or LAG-2910"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              style={{
                width: '100%',
                padding: '12px 14px 12px 42px',
                background: 'rgba(7, 10, 19, 0.9)',
                border: '1px solid rgba(255, 255, 255, 0.12)',
                borderRadius: 'var(--radius-sm)',
                color: '#FFFFFF',
                fontSize: '14px',
                fontFamily: 'var(--font-mono)',
              }}
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="btn-primary"
            style={{ padding: '12px 24px', fontSize: '14px' }}
          >
            {loading ? 'Locating...' : 'Locate'}
          </button>
        </form>

        {/* Tracking Result View */}
        {result && (
          <div style={{ background: 'rgba(7, 10, 19, 0.7)', borderRadius: 'var(--radius-md)', padding: '24px', border: '1px solid rgba(255, 255, 255, 0.08)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid rgba(255, 255, 255, 0.08)', paddingBottom: '16px', marginBottom: '20px' }}>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-dim)', textTransform: 'uppercase' }}>Waybill Code</span>
                <h4 style={{ fontSize: '18px', color: '#FFFFFF', fontFamily: 'var(--font-mono)' }}>{result.code}</h4>
                <p style={{ fontSize: '12px', color: '#60A5FA', marginTop: '2px' }}>Destination: {result.destination}</p>
              </div>
              <span style={{ background: 'rgba(16, 185, 129, 0.15)', color: '#10B981', border: '1px solid rgba(16, 185, 129, 0.3)', padding: '6px 12px', borderRadius: '14px', fontSize: '12px', fontWeight: 700 }}>
                {result.status}
              </span>
            </div>

            {/* Milestones timeline */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '18px', position: 'relative' }}>
              {result.timeline.map((step, idx) => (
                <div key={idx} style={{ display: 'flex', alignItems: 'flex-start', gap: '14px', position: 'relative' }}>
                  
                  {/* Indicator Icon */}
                  <div 
                    style={{
                      width: '28px',
                      height: '28px',
                      borderRadius: '50%',
                      background: step.done ? '#10B981' : '#1E293B',
                      border: step.done ? 'none' : '2px solid rgba(255, 255, 255, 0.15)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                      marginTop: '2px',
                    }}
                  >
                    {step.done ? <CheckCircle2 size={16} color="#FFFFFF" /> : <Clock size={14} color="#94A3B8" />}
                  </div>

                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <h5 style={{ fontSize: '14px', color: step.done ? '#FFFFFF' : 'var(--text-dim)', fontWeight: 600 }}>
                        {step.label}
                      </h5>
                      <span style={{ fontSize: '12px', color: 'var(--text-dim)', fontFamily: 'var(--font-mono)' }}>
                        {step.time}
                      </span>
                    </div>
                    <p style={{ fontSize: '12px', color: '#94A3B8', marginTop: '2px' }}>
                      Checkpoint: {step.hub}
                    </p>
                  </div>

                </div>
              ))}
            </div>

            <div style={{ borderTop: '1px solid rgba(255, 255, 255, 0.08)', marginTop: '20px', paddingTop: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12px', color: 'var(--text-dim)' }}>
              <span>Telemetry Timestamp: {result.lastUpdate}</span>
              <span style={{ color: '#10B981', fontWeight: 600 }}>Security Verified</span>
            </div>

          </div>
        )}

      </div>
    </div>
  );
}
