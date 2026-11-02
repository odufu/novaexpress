import React, { useState } from 'react';
import { MapPin, Navigation, Radio, Check, Building2 } from 'lucide-react';

const HUBS = [
  { id: 'lagos-ikeja', name: 'Lagos Grand Central Gateway', state: 'Lagos', zone: 'South West', address: 'Ikeja Logistics Corridor, Lagos', services: ['Cold Chain Reefer', 'Intra-City Express', 'Micro-Fulfillment', 'Air Freight Gateway'], activeRiders: '85+ Riders' },
  { id: 'lagos-island', name: 'Lagos Island Micro-Hub', state: 'Lagos', zone: 'South West', address: 'Victoria Island / Lekki Expressway', services: ['Intra-City Express', 'COD Doorstep POS', 'High-Value VIP'], activeRiders: '45+ Riders' },
  { id: 'abuja-wuse', name: 'Wuse Grand Central Distribution Center', state: 'Abuja (FCT)', zone: 'North Central', address: 'Wuse 2 Logistics Hub, Abuja FCT', services: ['North Regional Hub', 'Cold Chain', 'Gov & Corporate Couriers'], activeRiders: '50+ Riders' },
  { id: 'ph-transamadi', name: 'Port Harcourt Regional DC', state: 'Rivers', zone: 'South South', address: 'Trans-Amadi Industrial Layout, Port Harcourt', services: ['B2B Industrial Freight', 'Cold Chain', 'Oil & Gas Express'], activeRiders: '35+ Riders' },
  { id: 'kano-central', name: 'Kano Northern Linehaul Hub', state: 'Kano', zone: 'North West', address: 'Bompai Industrial Area, Kano', services: ['Interstate Trunk Sorting', 'Agricultural & FMCG Bulk'], activeRiders: '30+ Riders' },
  { id: 'ibadan-hub', name: 'Ibadan Micro-Fulfillment Center', state: 'Oyo', zone: 'South West', address: 'Ring Road Commercial Corridor, Ibadan', services: ['E-Commerce Fulfillment', 'Same-Day Dispatch'], activeRiders: '25+ Riders' },
];

export default function CoverageMap() {
  const [activeHub, setActiveHub] = useState(HUBS[0]);

  return (
    <section className="section-padding" style={{ position: 'relative', background: '#FAF9FB' }}>
      <div className="container">
        
        {/* Header */}
        <div style={{ textAlign: 'center', maxWidth: '680px', margin: '0 auto 48px' }}>
          <div className="badge-pill" style={{ marginBottom: '14px', background: '#FFFFFF', borderColor: '#D5BFAF' }}>
            <Navigation size={14} color="#FD7A02" />
            <span style={{ color: '#082658', fontWeight: 700 }}>Nationwide Hub Network</span>
          </div>
          <h2 style={{ fontSize: 'clamp(26px, 3.2vw, 38px)', color: '#082658', fontWeight: 800, marginBottom: '14px' }}>
            Strategic Multi-Hub Infrastructure Across Nigeria
          </h2>
          <p style={{ fontSize: '15px', color: '#4A5B78', lineHeight: 1.6 }}>
            Connected through daily scheduled linehaul routes and intelligent micro-fulfillment hubs to reach your customers within hours.
          </p>
        </div>

        {/* Interactive Hub Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '28px' }} className="hubs-layout">
          
          {/* Hub Selection List */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {HUBS.map((hub) => {
              const isSelected = activeHub.id === hub.id;
              return (
                <div
                  key={hub.id}
                  onClick={() => setActiveHub(hub)}
                  style={{
                    padding: '16px 20px',
                    borderRadius: 'var(--radius-md)',
                    background: isSelected ? '#082658' : '#FFFFFF',
                    border: isSelected ? '1.5px solid #082658' : '1px solid #EAEBEE',
                    boxShadow: isSelected ? '0 6px 20px rgba(8, 38, 88, 0.15)' : '0 2px 6px rgba(8, 38, 88, 0.02)',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    transition: 'all 0.2s',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                    <div 
                      style={{
                        width: '38px',
                        height: '38px',
                        borderRadius: '10px',
                        background: isSelected ? '#FD7A02' : 'rgba(253, 122, 2, 0.1)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                      }}
                    >
                      <Building2 size={18} color={isSelected ? '#FFFFFF' : '#FD7A02'} />
                    </div>
                    <div>
                      <h4 style={{ fontSize: '14px', color: isSelected ? '#FFFFFF' : '#082658', fontWeight: 700, margin: 0 }}>
                        {hub.name}
                      </h4>
                      <p style={{ fontSize: '12px', color: isSelected ? '#D5BFAF' : '#7E8DA6', marginTop: '2px' }}>
                        {hub.state} • {hub.zone}
                      </p>
                    </div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <span style={{ fontSize: '11px', color: isSelected ? '#FD7A02' : '#082658', fontWeight: 700, background: isSelected ? 'rgba(253, 122, 2, 0.18)' : '#EAEBEE', padding: '4px 10px', borderRadius: '12px' }}>
                      {hub.activeRiders}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Active Hub Showcase Preview */}
          <div 
            className="clean-card"
            style={{
              padding: '36px',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
              background: '#082658',
              color: '#FFFFFF',
              border: '1px solid rgba(255, 255, 255, 0.12)',
              boxShadow: '0 12px 35px rgba(8, 38, 88, 0.2)',
            }}
          >
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#FD7A02', fontSize: '12px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: '12px' }}>
                <Radio size={14} color="#FD7A02" />
                <span>Active Regional Gateway</span>
              </div>
              <h3 style={{ fontSize: '24px', color: '#FFFFFF', fontWeight: 800, marginBottom: '10px' }}>
                {activeHub.name}
              </h3>
              <p style={{ fontSize: '14px', color: '#D5BFAF', marginBottom: '24px' }}>
                {activeHub.address}
              </p>

              <div style={{ borderTop: '1px solid rgba(255, 255, 255, 0.1)', paddingTop: '20px', marginBottom: '24px' }}>
                <span style={{ fontSize: '12px', fontWeight: 700, color: '#FAF9FB', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: '12px' }}>
                  Hub Operations & Infrastructure:
                </span>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                  {activeHub.services.map((svc, idx) => (
                    <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', color: '#FAF9FB' }}>
                      <Check size={14} color="#FD7A02" />
                      <span>{svc}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div style={{ background: 'rgba(253, 122, 2, 0.15)', padding: '16px 20px', borderRadius: 'var(--radius-md)', border: '1px solid rgba(253, 122, 2, 0.3)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <span style={{ fontSize: '11px', color: '#D5BFAF', textTransform: 'uppercase', fontWeight: 600 }}>Fleet Status</span>
                <p style={{ fontSize: '15px', fontWeight: 800, color: '#FFFFFF' }}>{activeHub.activeRiders} on Duty</p>
              </div>
              <span style={{ fontSize: '12px', color: '#FFFFFF', fontWeight: 700, background: '#FD7A02', padding: '6px 12px', borderRadius: '6px' }}>
                Dispatching Now
              </span>
            </div>
          </div>

        </div>

      </div>

      <style>{`
        @media (max-width: 900px) {
          .hubs-layout {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </section>
  );
}
