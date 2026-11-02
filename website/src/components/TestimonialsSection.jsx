import React from 'react';
import { Star, MessageSquareQuote } from 'lucide-react';

export default function TestimonialsSection({ testimonials }) {
  const activeTestimonials = (testimonials || []).filter((t) => t.is_active !== false);

  return (
    <section className="section-padding" style={{ background: '#FAF9FB', position: 'relative' }}>
      <div className="container">
        
        {/* Header */}
        <div style={{ textAlign: 'center', maxWidth: '640px', margin: '0 auto 44px' }}>
          <div className="badge-pill" style={{ marginBottom: '12px' }}>
            <MessageSquareQuote size={13} color="#FD7A02" />
            <span>Customer Feedback</span>
          </div>
          <h2 style={{ fontSize: 'clamp(26px, 3.2vw, 38px)', color: '#082658', marginBottom: '12px' }}>
            What Our Partners <span style={{ color: '#FD7A02' }}>Say</span>
          </h2>
          <p style={{ fontSize: '15px', color: '#4A5B78' }}>
            Direct endorsements from pharmaceutical directors and high-growth e-commerce brand leaders.
          </p>
        </div>

        {/* Testimonials Grid */}
        <div 
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(330px, 1fr))',
            gap: '20px',
          }}
        >
          {activeTestimonials.map((t) => (
            <div 
              key={t.id}
              className="clean-card"
              style={{
                padding: '28px',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                background: '#FFFFFF',
              }}
            >
              <div>
                {/* Star rating */}
                <div style={{ display: 'flex', gap: '3px', marginBottom: '14px' }}>
                  {[...Array(t.rating || 5)].map((_, i) => (
                    <Star key={i} size={15} fill="#FD7A02" color="#FD7A02" />
                  ))}
                </div>

                <p style={{ fontSize: '14px', color: '#082658', fontStyle: 'italic', lineHeight: 1.65, marginBottom: '20px' }}>
                  "{t.quote}"
                </p>
              </div>

              {/* Author info */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', borderTop: '1px solid #EAEBEE', paddingTop: '16px' }}>
                {t.avatar_url ? (
                  <img 
                    src={t.avatar_url} 
                    alt={t.author_name} 
                    style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover', border: '2px solid #EAEBEE' }}
                  />
                ) : (
                  <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: '#082658', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: '#fff', fontSize: '14px' }}>
                    {t.author_name.charAt(0)}
                  </div>
                )}
                <div>
                  <h4 style={{ fontSize: '14px', color: '#082658', fontWeight: 700 }}>{t.author_name}</h4>
                  <p style={{ fontSize: '12px', color: '#7E8DA6' }}>{t.author_title} • <span style={{ color: '#FD7A02', fontWeight: 600 }}>{t.company}</span></p>
                </div>
              </div>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
