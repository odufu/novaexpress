import React, { useState } from 'react';
import { Briefcase, ArrowUpRight, TrendingUp, X, Sparkles } from 'lucide-react';
import ImagePlaceholder from './ImagePlaceholder';

export default function PortfolioSection({ portfolio, onSelectProject }) {
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [activeModalProject, setActiveModalProject] = useState(null);

  const activeProjects = (portfolio || []).filter((p) => p.is_active !== false);
  const categories = ['All', ...new Set(activeProjects.map((p) => p.category).filter(Boolean))];

  const filteredProjects = selectedCategory === 'All'
    ? activeProjects
    : activeProjects.filter((p) => p.category === selectedCategory);

  return (
    <section className="section-padding" style={{ background: '#FAF9FB', position: 'relative' }}>
      <div className="container">
        
        {/* Header */}
        <div style={{ textAlign: 'center', maxWidth: '640px', margin: '0 auto 40px' }}>
          <div className="badge-pill" style={{ marginBottom: '12px' }}>
            <Briefcase size={13} color="#FD7A02" />
            <span>Proven Enterprise Track Record</span>
          </div>
          <h2 style={{ fontSize: 'clamp(26px, 3.2vw, 38px)', color: '#082658', marginBottom: '12px' }}>
            Impact Delivered for <span style={{ color: '#FD7A02' }}>Top Shippers</span>
          </h2>
          <p style={{ fontSize: '15px', color: '#4A5B78' }}>
            Measured results in cold-chain survival, cash remittance velocity, and delivery success rates.
          </p>
        </div>

        {/* Category Filters */}
        <div 
          style={{
            display: 'flex',
            flexWrap: 'wrap',
            justifyContent: 'center',
            gap: '8px',
            marginBottom: '36px',
          }}
        >
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              style={{
                padding: '7px 16px',
                borderRadius: 'var(--radius-full)',
                fontSize: '13px',
                fontWeight: 600,
                background: selectedCategory === cat ? '#082658' : '#FFFFFF',
                color: selectedCategory === cat ? '#FFFFFF' : '#082658',
                border: selectedCategory === cat ? 'none' : '1px solid #EAEBEE',
                boxShadow: '0 2px 6px rgba(8, 38, 88, 0.04)',
                transition: 'all 0.2s',
              }}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Portfolio Cards Grid */}
        <div 
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))',
            gap: '24px',
          }}
        >
          {filteredProjects.map((item) => {
            const metrics = Array.isArray(item.metrics) ? item.metrics : [];

            return (
              <div
                key={item.id || item.slug}
                className="clean-card"
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  overflow: 'hidden',
                  cursor: 'pointer',
                  background: '#FFFFFF',
                }}
                onClick={() => setActiveModalProject(item)}
              >
                {/* Image or ImagePlaceholder with descriptive guidance */}
                <div style={{ position: 'relative', height: '200px', overflow: 'hidden' }}>
                  <ImagePlaceholder 
                    src={item.image_url} 
                    alt={item.title}
                    description={`Visual for ${item.client_name} - ${item.category} case study`}
                    dimensions="1200 × 750 px"
                  />
                  <span 
                    style={{
                      position: 'absolute',
                      top: '14px',
                      left: '14px',
                      background: 'rgba(8, 38, 88, 0.9)',
                      color: '#FFFFFF',
                      padding: '4px 10px',
                      borderRadius: '12px',
                      fontSize: '11px',
                      fontWeight: 700,
                    }}
                  >
                    {item.category}
                  </span>
                </div>

                {/* Card Content */}
                <div style={{ padding: '22px', display: 'flex', flexDirection: 'column', flex: 1 }}>
                  <span style={{ fontSize: '11px', color: '#FD7A02', fontWeight: 700, textTransform: 'uppercase', marginBottom: '4px' }}>
                    {item.client_name}
                  </span>
                  <h3 style={{ fontSize: '17px', color: '#082658', lineHeight: 1.35, marginBottom: '10px' }}>
                    {item.title}
                  </h3>
                  <p style={{ fontSize: '13px', color: '#4A5B78', marginBottom: '16px', flex: 1, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                    {item.summary}
                  </p>

                  {/* Impact Metrics Badges */}
                  {metrics.length > 0 && (
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '8px', background: '#FAF9FB', padding: '10px 12px', borderRadius: 'var(--radius-sm)', marginBottom: '14px', border: '1px solid #EAEBEE' }}>
                      {metrics.slice(0, 2).map((m, idx) => (
                        <div key={idx}>
                          <span style={{ fontSize: '16px', fontWeight: 800, color: '#FD7A02' }}>
                            {m.value}
                          </span>
                          <p style={{ fontSize: '11px', color: '#7E8DA6' }}>{m.label}</p>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Bottom Action */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', color: '#082658', fontSize: '13px', fontWeight: 700, borderTop: '1px solid #EAEBEE', paddingTop: '12px' }}>
                    <span>View Case Study</span>
                    <ArrowUpRight size={15} color="#FD7A02" />
                  </div>
                </div>
              </div>
            );
          })}
        </div>

      </div>

      {/* Case Study Detail Modal */}
      {activeModalProject && (
        <div 
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(8, 38, 88, 0.7)',
            backdropFilter: 'blur(8px)',
            zIndex: 1000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px',
          }}
          onClick={() => setActiveModalProject(null)}
        >
          <div 
            style={{
              maxWidth: '680px',
              width: '100%',
              maxHeight: '90vh',
              overflowY: 'auto',
              padding: '36px',
              background: '#FFFFFF',
              borderRadius: 'var(--radius-lg)',
              border: '1px solid #EAEBEE',
              boxShadow: '0 25px 60px rgba(8, 38, 88, 0.3)',
              position: 'relative',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setActiveModalProject(null)}
              style={{
                position: 'absolute',
                top: '20px',
                right: '20px',
                background: '#EAEBEE',
                color: '#082658',
                padding: '8px',
                borderRadius: '50%',
              }}
            >
              <X size={16} />
            </button>

            <span style={{ fontSize: '12px', fontWeight: 700, color: '#FD7A02', textTransform: 'uppercase' }}>
              {activeModalProject.category} • {activeModalProject.client_name}
            </span>
            <h2 style={{ fontSize: '22px', color: '#082658', margin: '8px 0 16px', lineHeight: 1.3 }}>
              {activeModalProject.title}
            </h2>

            {/* Metrics */}
            {Array.isArray(activeModalProject.metrics) && activeModalProject.metrics.length > 0 && (
              <div style={{ display: 'grid', gridTemplateColumns: `repeat(${activeModalProject.metrics.length}, 1fr)`, gap: '10px', background: '#FAF9FB', padding: '14px', borderRadius: 'var(--radius-md)', margin: '18px 0', border: '1px solid #EAEBEE' }}>
                {activeModalProject.metrics.map((m, idx) => (
                  <div key={idx} style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: '20px', fontWeight: 800, color: '#FD7A02' }}>{m.value}</div>
                    <div style={{ fontSize: '11px', color: '#7E8DA6' }}>{m.label}</div>
                  </div>
                ))}
              </div>
            )}

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginTop: '16px' }}>
              {activeModalProject.challenge && (
                <div style={{ background: '#FAF9FB', padding: '14px 18px', borderRadius: 'var(--radius-sm)', border: '1px solid #EAEBEE' }}>
                  <h4 style={{ fontSize: '13px', color: '#E06900', marginBottom: '6px', fontWeight: 700 }}>
                    Operational Challenge
                  </h4>
                  <p style={{ fontSize: '13px', color: '#4A5B78' }}>{activeModalProject.challenge}</p>
                </div>
              )}

              {activeModalProject.solution && (
                <div style={{ background: 'rgba(8, 38, 88, 0.04)', padding: '14px 18px', borderRadius: 'var(--radius-sm)', border: '1px solid rgba(8, 38, 88, 0.1)' }}>
                  <h4 style={{ fontSize: '13px', color: '#082658', marginBottom: '6px', fontWeight: 700 }}>
                    The NovaXpress Solution
                  </h4>
                  <p style={{ fontSize: '13px', color: '#082658' }}>{activeModalProject.solution}</p>
                </div>
              )}

              {activeModalProject.results && (
                <div style={{ background: 'rgba(16, 185, 129, 0.08)', padding: '14px 18px', borderRadius: 'var(--radius-sm)', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
                  <h4 style={{ fontSize: '13px', color: '#10B981', marginBottom: '6px', fontWeight: 700 }}>
                    Quantifiable Impact & Outcome
                  </h4>
                  <p style={{ fontSize: '13px', color: '#082658' }}>{activeModalProject.results}</p>
                </div>
              )}
            </div>

            <button
              onClick={() => {
                setActiveModalProject(null);
                if (onSelectProject) onSelectProject(activeModalProject);
              }}
              className="btn-primary"
              style={{ width: '100%', marginTop: '20px' }}
            >
              Request Similar Enterprise Solution
            </button>
          </div>
        </div>
      )}
    </section>
  );
}
