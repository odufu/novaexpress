import React, { useState } from 'react';
import { Search, Truck, CheckCircle2, Clock, MapPin, ShieldAlert, ArrowRight, Sparkles } from 'lucide-react';
import { trackShipment } from '../lib/supabase';

export default function TrackingPage({ onBookDispatch }) {
  const [query, setQuery] = useState('');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);

  const sampleCodes = ['Novacare Ltd-CRM-ORD-10-042969', 'NX-LGS-8829-EXP', 'NX-ABJ-3104-MED'];

  const handleSearch = async (codeToUse) => {
    const code = codeToUse || query;
    if (!code || !code.trim()) return;

    setLoading(true);
    try {
      const data = await trackShipment(code.trim());
      setResult(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="section-padding" style={{ background: '#FAF9FB', minHeight: '85vh' }}>
      <div className="container" style={{ maxWidth: '820px' }}>
        
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: '36px' }}>
          <div className="badge-pill" style={{ marginBottom: '14px', background: '#FFFFFF', borderColor: '#D5BFAF' }}>
            <Sparkles size={14} color="#FD7A02" />
            <span style={{ color: '#082658', fontWeight: 700 }}>Real-Time Shipment Telemetry</span>
          </div>
          <h1 style={{ fontSize: 'clamp(28px, 3.8vw, 44px)', color: '#082658', fontWeight: 800, letterSpacing: '-0.025em', marginBottom: '12px' }}>
            Track Your <span style={{ color: '#FD7A02' }}>Consignment</span>
          </h1>
          <p style={{ fontSize: '15px', color: '#4A5B78', lineHeight: 1.6 }}>
            Enter your NovaXpress tracking ID or waybill number to view exact checkpoint milestones, driver status, and proof of delivery.
          </p>
        </div>

        {/* Search Bar Card */}
        <div 
          className="clean-card"
          style={{
            padding: '28px',
            marginBottom: '32px',
            background: '#FFFFFF',
            border: '1.5px solid #EAEBEE',
            boxShadow: '0 8px 30px rgba(8, 38, 88, 0.06)',
          }}
        >
          <form 
            onSubmit={(e) => { e.preventDefault(); handleSearch(); }}
            style={{ display: 'flex', gap: '12px' }}
          >
            <div style={{ position: 'relative', flex: 1 }}>
              <Search size={19} color="#FD7A02" style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)' }} />
              <input
                type="text"
                placeholder="Enter Waybill or Order # (e.g. NX-042969)"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                style={{
                  width: '100%',
                  padding: '15px 16px 15px 48px',
                  background: '#FAF9FB',
                  border: '1.5px solid #CBD5E1',
                  borderRadius: 'var(--radius-md)',
                  color: '#082658',
                  fontSize: '15px',
                  fontFamily: 'var(--font-mono)',
                  fontWeight: 600,
                  outline: 'none',
                }}
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="btn-primary"
              style={{ padding: '0 28px', fontSize: '15px', fontWeight: 700 }}
            >
              {loading ? 'Locating...' : 'Track'}
            </button>
          </form>

          {/* Quick sample chips with HIGH CONTRAST */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '16px', flexWrap: 'wrap' }}>
            <span style={{ fontSize: '12px', color: '#4A5B78', fontWeight: 600 }}>Try demo waybills:</span>
            {sampleCodes.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => {
                  setQuery(c);
                  handleSearch(c);
                }}
                style={{
                  background: '#EAEBEE',
                  border: '1px solid #CBD5E1',
                  color: '#082658',
                  padding: '5px 12px',
                  borderRadius: '14px',
                  fontSize: '12px',
                  fontWeight: 700,
                  fontFamily: 'var(--font-mono)',
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.borderColor = '#FD7A02';
                  e.currentTarget.style.color = '#FD7A02';
                  e.currentTarget.style.background = '#FFFFFF';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.borderColor = '#CBD5E1';
                  e.currentTarget.style.color = '#082658';
                  e.currentTarget.style.background = '#EAEBEE';
                }}
              >
                {c.length > 22 ? c.slice(0, 20) + '...' : c}
              </button>
            ))}
          </div>
        </div>

        {/* Tracking Details View */}
        {result && (
          <div 
            className="clean-card"
            style={{
              padding: '36px',
              background: '#FFFFFF',
              border: '1.5px solid #EAEBEE',
              boxShadow: '0 12px 35px rgba(8, 38, 88, 0.08)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid #EAEBEE', paddingBottom: '20px', marginBottom: '24px', flexWrap: 'wrap', gap: '14px' }}>
              <div>
                <span style={{ fontSize: '11px', color: '#7E8DA6', textTransform: 'uppercase', letterSpacing: '0.06em', fontWeight: 700 }}>
                  Consignment Reference
                </span>
                <h3 style={{ fontSize: '22px', color: '#082658', fontFamily: 'var(--font-mono)', fontWeight: 800, margin: '4px 0' }}>
                  {result.code}
                </h3>
                <p style={{ fontSize: '13px', color: '#FD7A02', fontWeight: 600 }}>
                  Target Delivery: {result.destination}
                </p>
              </div>

              <div style={{ textAlign: 'right' }}>
                <span style={{ background: 'rgba(16, 185, 129, 0.12)', color: '#059669', border: '1px solid #10B981', padding: '6px 14px', borderRadius: '16px', fontSize: '13px', fontWeight: 700, display: 'inline-block', marginBottom: '6px' }}>
                  {result.status}
                </span>
                <p style={{ fontSize: '12px', color: '#7E8DA6' }}>Last Sync: {result.lastUpdate}</p>
              </div>
            </div>

            {/* Timeline Milestones */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', margin: '24px 0' }}>
              {result.timeline.map((step, idx) => (
                <div key={idx} style={{ display: 'flex', alignItems: 'flex-start', gap: '14px' }}>
                  <div 
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '50%',
                      background: step.done ? '#10B981' : '#EAEBEE',
                      border: step.done ? 'none' : '2px solid #CBD5E1',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                      marginTop: '2px',
                    }}
                  >
                    {step.done ? <CheckCircle2 size={18} color="#FFFFFF" /> : <Clock size={16} color="#7E8DA6" />}
                  </div>

                  <div style={{ flex: 1, background: '#FAF9FB', padding: '12px 18px', borderRadius: 'var(--radius-sm)', border: '1px solid #EAEBEE' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '8px' }}>
                      <h4 style={{ fontSize: '14px', color: step.done ? '#082658' : '#7E8DA6', fontWeight: 700 }}>
                        {step.label}
                      </h4>
                      <span style={{ fontSize: '12px', color: '#FD7A02', fontFamily: 'var(--font-mono)', fontWeight: 700 }}>
                        {step.time}
                      </span>
                    </div>
                    <p style={{ fontSize: '12px', color: '#4A5B78', marginTop: '3px' }}>
                      Operational Hub: {step.hub}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            {/* Support shortcut */}
            <div style={{ borderTop: '1px solid #EAEBEE', paddingTop: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
              <span style={{ fontSize: '13px', color: '#4A5B78', fontWeight: 500 }}>
                Questions regarding this delivery?
              </span>
              <button onClick={onBookDispatch} className="btn-secondary btn-sm" style={{ fontWeight: 700 }}>
                Contact Operations Center
              </button>
            </div>

          </div>
        )}

      </div>
    </div>
  );
}
