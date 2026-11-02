import React, { useState, useEffect } from 'react';
import { 
  ArrowRight, 
  Search, 
  ChevronLeft, 
  ChevronRight, 
  Zap, 
  ThermometerSnowflake, 
  Banknote, 
  MapPin, 
  CheckCircle2, 
  ShieldCheck,
  Package,
  Clock,
  Sparkles
} from 'lucide-react';
import ImagePlaceholder from './ImagePlaceholder';
import { DEFAULT_SLIDES } from '../lib/supabase';

export default function HeroSection({ settings, onTrackSubmit, onGetQuoteClick, onExploreServices }) {
  const [trackingInput, setTrackingInput] = useState('');
  const [currentSlide, setCurrentSlide] = useState(0);
  const [isPaused, setIsPaused] = useState(false);

  const slides = (settings?.hero_slides && settings.hero_slides.length > 0)
    ? settings.hero_slides
    : DEFAULT_SLIDES;

  // Auto-advance sliding images every 5 seconds unless hovered
  useEffect(() => {
    if (isPaused || slides.length <= 1) return;
    const interval = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % slides.length);
    }, 5000);
    return () => clearInterval(interval);
  }, [isPaused, slides.length]);

  const nextSlide = () => {
    setCurrentSlide((prev) => (prev + 1) % slides.length);
  };

  const prevSlide = () => {
    setCurrentSlide((prev) => (prev - 1 + slides.length) % slides.length);
  };

  const activeSlideData = slides[currentSlide] || slides[0];

  const handleTrack = (e) => {
    e.preventDefault();
    if (trackingInput.trim()) {
      onTrackSubmit(trackingInput.trim());
    }
  };

  return (
    <section 
      style={{
        position: 'relative',
        paddingTop: '36px',
        paddingBottom: '60px',
        background: 'linear-gradient(180deg, #FAF9FB 0%, #EAEBEE 100%)',
        overflow: 'hidden',
      }}
    >
      <div className="container">
        
        {/* Top Micro Telemetry Pill */}
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '20px' }}>
          <div 
            className="badge-pill" 
            style={{
              background: '#FFFFFF',
              boxShadow: '0 2px 10px rgba(8, 38, 88, 0.05)',
              borderColor: '#D5BFAF',
            }}
          >
            <Sparkles size={14} color="#FD7A02" />
            <span style={{ color: '#082658' }}>{activeSlideData.badge || settings?.hero_badge || '⚡ Next-Gen Express Logistics & Cold-Chain'}</span>
          </div>
        </div>

        {/* Minimalist Hero Headline */}
        <div style={{ textAlign: 'center', maxWidth: '780px', margin: '0 auto 30px' }}>
          <h1 
            style={{
              fontSize: 'clamp(32px, 4.2vw, 54px)',
              fontWeight: 800,
              lineHeight: 1.15,
              color: '#082658',
              letterSpacing: '-0.03em',
              marginBottom: '14px',
            }}
          >
            Fast, Reliable Logistics & <span style={{ color: '#FD7A02' }}>Same-Day Delivery</span>
          </h1>
          <p 
            style={{
              fontSize: '17px',
              color: '#4A5B78',
              lineHeight: 1.6,
              maxWidth: '620px',
              margin: '0 auto',
            }}
          >
            {activeSlideData.subtitle || settings?.hero_subtitle || 'Eliminate delayed dispatch and lost parcels. Intra-city express couriers, certified 2°C–8°C pharma cold chain, and automated 24-hour COD remittance across Nigeria.'}
          </p>
        </div>

        {/* Modern Interactive Quick Tracker */}
        <form 
          onSubmit={handleTrack}
          style={{
            maxWidth: '560px',
            margin: '0 auto 40px',
            background: '#FFFFFF',
            border: '2px solid #EAEBEE',
            borderRadius: 'var(--radius-full)',
            padding: '6px 6px 6px 20px',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            boxShadow: '0 8px 30px rgba(8, 38, 88, 0.08)',
            transition: 'border-color 0.2s ease',
          }}
          onFocus={(e) => e.currentTarget.style.borderColor = '#FD7A02'}
          onBlur={(e) => e.currentTarget.style.borderColor = '#EAEBEE'}
        >
          <Search size={18} color="#FD7A02" />
          <input
            type="text"
            placeholder="Track Waybill or Order # (e.g. NX-042969)"
            value={trackingInput}
            onChange={(e) => setTrackingInput(e.target.value)}
            style={{
              background: 'transparent',
              border: 'none',
              color: '#082658',
              fontSize: '15px',
              flex: 1,
              fontWeight: 500,
            }}
          />
          <button 
            type="submit"
            className="btn-primary"
            style={{
              padding: '10px 22px',
              borderRadius: 'var(--radius-full)',
              fontSize: '14px',
            }}
          >
            Track
          </button>
        </form>

        {/* Dynamic Image Slider Container */}
        <div 
          style={{
            position: 'relative',
            maxWidth: '1040px',
            margin: '0 auto',
            borderRadius: 'var(--radius-xl)',
            overflow: 'hidden',
            boxShadow: '0 20px 50px rgba(8, 38, 88, 0.15)',
            border: '4px solid #FFFFFF',
            background: '#082658',
          }}
          onMouseEnter={() => setIsPaused(true)}
          onMouseLeave={() => setIsPaused(false)}
        >
          {/* Main Slide Image */}
          <div style={{ position: 'relative', height: '480px', width: '100%', overflow: 'hidden' }}>
            <ImagePlaceholder
              src={activeSlideData.image}
              alt={activeSlideData.title}
              description={activeSlideData.placeholderDesc || 'NovaXpress logistics operations'}
              dimensions="1600 × 900 px"
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'cover',
                transition: 'opacity 0.6s ease',
              }}
            />

            {/* Subtle Gradient Vignette */}
            <div 
              style={{
                position: 'absolute',
                inset: 0,
                background: 'linear-gradient(to top, rgba(8, 38, 88, 0.85) 0%, rgba(8, 38, 88, 0.15) 50%, rgba(8, 38, 88, 0.4) 100%)',
                pointerEvents: 'none',
              }}
            />

            {/* In-Slide Floating Micro Elements */}
            
            {/* Micro Element 1: Top Left Pill */}
            <div 
              className="animate-micro-float"
              style={{
                position: 'absolute',
                top: '24px',
                left: '24px',
                background: 'rgba(255, 255, 255, 0.92)',
                backdropFilter: 'blur(8px)',
                padding: '8px 16px',
                borderRadius: 'var(--radius-full)',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                boxShadow: '0 4px 16px rgba(8, 38, 88, 0.18)',
                border: '1px solid #D5BFAF',
              }}
            >
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10B981', boxShadow: '0 0 8px #10B981' }} />
              <span style={{ fontSize: '13px', fontWeight: 700, color: '#082658' }}>
                {activeSlideData.statPill || 'Active Live Dispatch'}
              </span>
            </div>

            {/* Micro Element 2: Bottom Right Telemetry Card */}
            <div 
              className="animate-micro-float-delayed"
              style={{
                position: 'absolute',
                bottom: '28px',
                right: '28px',
                background: 'rgba(8, 38, 88, 0.92)',
                backdropFilter: 'blur(10px)',
                color: '#FFFFFF',
                padding: '14px 18px',
                borderRadius: 'var(--radius-md)',
                display: 'flex',
                alignItems: 'center',
                gap: '12px',
                border: '1px solid rgba(253, 122, 2, 0.4)',
                boxShadow: '0 10px 25px rgba(0, 0, 0, 0.35)',
              }}
            >
              <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(253, 122, 2, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Package size={18} color="#FD7A02" />
              </div>
              <div>
                <span style={{ fontSize: '10px', color: '#D5BFAF', textTransform: 'uppercase', letterSpacing: '0.06em', fontWeight: 700 }}>
                  Real-time SLA
                </span>
                <p style={{ fontSize: '14px', fontWeight: 700, color: '#FAF9FB', margin: 0 }}>
                  99.4% On-Time Proof of Delivery
                </p>
              </div>
            </div>

            {/* Slide Title Banner overlay */}
            <div 
              style={{
                position: 'absolute',
                bottom: '28px',
                left: '28px',
                maxWidth: '520px',
              }}
            >
              <h3 style={{ fontSize: 'clamp(20px, 3vw, 28px)', color: '#FFFFFF', fontWeight: 800, marginBottom: '8px', textShadow: '0 2px 8px rgba(0,0,0,0.5)' }}>
                {activeSlideData.title}
              </h3>
              <button
                onClick={onGetQuoteClick}
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  background: '#FD7A02',
                  color: '#FFFFFF',
                  padding: '8px 16px',
                  borderRadius: 'var(--radius-sm)',
                  fontSize: '13px',
                  fontWeight: 700,
                  boxShadow: '0 4px 14px rgba(253, 122, 2, 0.5)',
                }}
              >
                <span>{activeSlideData.ctaText || 'Get Started'}</span>
                <ArrowRight size={14} />
              </button>
            </div>

          </div>

          {/* Navigation Controls */}
          {slides.length > 1 && (
            <>
              {/* Left Arrow */}
              <button
                onClick={prevSlide}
                style={{
                  position: 'absolute',
                  left: '16px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  width: '40px',
                  height: '40px',
                  borderRadius: '50%',
                  background: 'rgba(255, 255, 255, 0.9)',
                  color: '#082658',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: '0 4px 12px rgba(8, 38, 88, 0.15)',
                  zIndex: 10,
                }}
                aria-label="Previous Slide"
              >
                <ChevronLeft size={20} />
              </button>

              {/* Right Arrow */}
              <button
                onClick={nextSlide}
                style={{
                  position: 'absolute',
                  right: '16px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  width: '40px',
                  height: '40px',
                  borderRadius: '50%',
                  background: 'rgba(255, 255, 255, 0.9)',
                  color: '#082658',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: '0 4px 12px rgba(8, 38, 88, 0.15)',
                  zIndex: 10,
                }}
                aria-label="Next Slide"
              >
                <ChevronRight size={20} />
              </button>

              {/* Dots Pagination */}
              <div 
                style={{
                  position: 'absolute',
                  bottom: '12px',
                  left: '50%',
                  transform: 'translateX(-50%)',
                  display: 'flex',
                  gap: '8px',
                  zIndex: 10,
                }}
              >
                {slides.map((_, idx) => (
                  <button
                    key={idx}
                    onClick={() => setCurrentSlide(idx)}
                    style={{
                      width: currentSlide === idx ? '24px' : '8px',
                      height: '8px',
                      borderRadius: '4px',
                      background: currentSlide === idx ? '#FD7A02' : 'rgba(255, 255, 255, 0.6)',
                      transition: 'all 0.3s ease',
                    }}
                    aria-label={`Go to slide ${idx + 1}`}
                  />
                ))}
              </div>
            </>
          )}

        </div>

      </div>
    </section>
  );
}
