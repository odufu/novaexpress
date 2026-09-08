import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { PRESENTATION_SLIDES } from '../data/presentationData';

export default function DeckController({
  currentSlideIndex,
  totalSlides,
  nextSlide,
  prevSlide,
  goToSlide,
}) {
  const current = PRESENTATION_SLIDES[currentSlideIndex] || PRESENTATION_SLIDES[0];
  const progressPct = ((currentSlideIndex + 1) / totalSlides) * 100;

  return (
    <div style={{
      background: '#FFFFFF',
      borderBottom: '1px solid var(--border-subtle)',
      padding: '0.65rem 2rem',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      flexWrap: 'wrap',
      gap: '1rem',
      boxShadow: '0 2px 4px 0 rgba(0, 0, 0, 0.02)',
    }}>
      {/* Progress Track & Title */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '1.25rem', flex: 1, maxWidth: '650px' }}>
        <span style={{
          fontFamily: 'var(--font-mono)',
          fontSize: '0.8rem',
          color: 'var(--text-muted)',
          whiteSpace: 'nowrap',
        }}>
          Slide {currentSlideIndex + 1} of {totalSlides} • <strong style={{ color: 'var(--brand-primary)' }}>{current.title}</strong>
        </span>

        <div style={{
          height: '6px',
          background: 'var(--bg-muted)',
          borderRadius: '10px',
          flex: 1,
          overflow: 'hidden',
          minWidth: '120px',
        }}>
          <div style={{
            height: '100%',
            background: 'var(--grad-brand)',
            width: `${progressPct}%`,
            transition: 'width 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
          }} />
        </div>
      </div>

      {/* Slide Quick Jump Chips */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', overflowX: 'auto', maxWidth: '400px' }}>
        {PRESENTATION_SLIDES.map((s, idx) => (
          <button
            key={s.id}
            onClick={() => goToSlide(idx)}
            style={{
              width: '26px',
              height: '26px',
              borderRadius: '6px',
              border: 'none',
              background: idx === currentSlideIndex ? 'var(--brand-primary)' : 'var(--bg-subtle)',
              color: idx === currentSlideIndex ? '#FFFFFF' : 'var(--text-secondary)',
              fontSize: '0.75rem',
              fontWeight: '700',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'all 0.2s',
              boxShadow: idx === currentSlideIndex ? '0 2px 8px rgba(0, 108, 76, 0.25)' : 'none',
            }}
            title={s.title}
          >
            {idx + 1}
          </button>
        ))}
      </div>

      {/* Nav Buttons */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
        <button
          onClick={prevSlide}
          disabled={currentSlideIndex === 0}
          style={{
            background: '#FFFFFF',
            border: '1px solid var(--border-subtle)',
            color: 'var(--text-primary)',
            padding: '0.4rem 0.9rem',
            borderRadius: 'var(--radius-sm)',
            fontSize: '0.8rem',
            fontWeight: 700,
            cursor: currentSlideIndex === 0 ? 'not-allowed' : 'pointer',
            opacity: currentSlideIndex === 0 ? 0.35 : 1,
            display: 'flex',
            alignItems: 'center',
            gap: '0.3rem',
            transition: 'all 0.2s',
            boxShadow: 'var(--shadow-sm)',
          }}
        >
          <ChevronLeft size={16} />
          Previous
        </button>

        <button
          onClick={nextSlide}
          disabled={currentSlideIndex === totalSlides - 1}
          style={{
            background: 'var(--brand-primary)',
            border: '1px solid var(--brand-primary)',
            color: '#FFFFFF',
            padding: '0.4rem 1rem',
            borderRadius: 'var(--radius-sm)',
            fontSize: '0.8rem',
            fontWeight: 700,
            cursor: currentSlideIndex === totalSlides - 1 ? 'not-allowed' : 'pointer',
            opacity: currentSlideIndex === totalSlides - 1 ? 0.35 : 1,
            display: 'flex',
            alignItems: 'center',
            gap: '0.3rem',
            transition: 'all 0.2s',
            boxShadow: '0 2px 8px rgba(0, 108, 76, 0.25)',
          }}
        >
          Next
          <ChevronRight size={16} />
        </button>
      </div>
    </div>
  );
}
