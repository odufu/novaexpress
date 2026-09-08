import React, { useState, useEffect } from 'react';
import TopHeader from './components/TopHeader';
import DeckController from './components/DeckController';
import HeroOverview from './components/HeroOverview';
import WorkflowsDiagrams from './components/WorkflowsDiagrams';
import MatrixAndRules from './components/MatrixAndRules';
import RoleArchitecture from './components/RoleArchitecture';
import PaymentEngineering from './components/PaymentEngineering';
import ServerCosting from './components/ServerCosting';
import ChallengesSolutions from './components/ChallengesSolutions';
import RoiCalculator from './components/RoiCalculator';
import TechnicalStack from './components/TechnicalStack';
import SearchModal from './components/SearchModal';
import { PRESENTATION_SLIDES } from './data/presentationData';

export default function App() {
  const [currentSlideIndex, setCurrentSlideIndex] = useState(0);
  const [viewMode, setViewMode] = useState('deck'); // 'deck' | 'workflows' | 'canvas' | 'calc' | 'rules' | 'challenges'
  const [isFullScreen, setIsFullScreen] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);

  const totalSlides = PRESENTATION_SLIDES.length;

  const nextSlide = () => {
    if (currentSlideIndex < totalSlides - 1) {
      setCurrentSlideIndex(prev => prev + 1);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  const prevSlide = () => {
    if (currentSlideIndex > 0) {
      setCurrentSlideIndex(prev => prev - 1);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  const goToSlide = (idx) => {
    if (idx >= 0 && idx < totalSlides) {
      setCurrentSlideIndex(idx);
      if (viewMode !== 'deck') setViewMode('deck');
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  const toggleFullScreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(err => console.log(err));
      setIsFullScreen(true);
    } else {
      if (document.exitFullscreen) document.exitFullscreen();
      setIsFullScreen(false);
    }
  };

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (isSearchOpen) {
        if (e.key === 'Escape') setIsSearchOpen(false);
        return;
      }

      if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown') {
        e.preventDefault();
        nextSlide();
      } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
        e.preventDefault();
        prevSlide();
      } else if (e.key === 'f' || e.key === 'F') {
        toggleFullScreen();
      } else if (e.key === 's' || e.key === 'S' || (e.ctrlKey && e.key === 'k')) {
        e.preventDefault();
        setIsSearchOpen(true);
      } else if (e.key >= '1' && e.key <= '9') {
        const num = parseInt(e.key, 10) - 1;
        goToSlide(num);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentSlideIndex, isSearchOpen, isFullScreen]);

  // Render slide content
  const renderSlideContent = (index) => {
    switch (index) {
      case 0:
        return <HeroOverview goToSlide={goToSlide} />;
      case 1:
        return <WorkflowsDiagrams />;
      case 2:
        return <MatrixAndRules />;
      case 3:
        return <RoleArchitecture />;
      case 4:
        return <PaymentEngineering />;
      case 5:
        return <ServerCosting />;
      case 6:
        return <ChallengesSolutions />;
      case 7:
        return <RoiCalculator />;
      case 8:
        return <TechnicalStack />;
      default:
        return <HeroOverview goToSlide={goToSlide} />;
    }
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', background: 'var(--bg-primary)' }}>
      {/* Top Header */}
      <TopHeader
        viewMode={viewMode}
        setViewMode={(mode) => {
          setViewMode(mode);
          if (mode === 'workflows') setCurrentSlideIndex(1);
          if (mode === 'calc') setCurrentSlideIndex(7);
          if (mode === 'rules') setCurrentSlideIndex(2);
          if (mode === 'challenges') setCurrentSlideIndex(6);
        }}
        isFullScreen={isFullScreen}
        toggleFullScreen={toggleFullScreen}
        setIsSearchOpen={setIsSearchOpen}
      />

      {/* Deck Controller (Shown in Deck Mode) */}
      {viewMode === 'deck' && (
        <DeckController
          currentSlideIndex={currentSlideIndex}
          totalSlides={totalSlides}
          nextSlide={nextSlide}
          prevSlide={prevSlide}
          goToSlide={goToSlide}
        />
      )}

      {/* Main Container */}
      <main style={{
        maxWidth: '1440px',
        width: '100%',
        margin: '0 auto',
        padding: '2rem',
        flex: 1,
      }}>
        {viewMode === 'deck' && renderSlideContent(currentSlideIndex)}

        {viewMode === 'workflows' && <WorkflowsDiagrams />}

        {viewMode === 'canvas' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4rem' }}>
            {PRESENTATION_SLIDES.map((slide, idx) => (
              <section key={slide.id} style={{ borderBottom: '1px solid var(--border-subtle)', paddingBottom: '3.5rem' }}>
                {renderSlideContent(idx)}
              </section>
            ))}
          </div>
        )}

        {viewMode === 'calc' && <RoiCalculator />}
        {viewMode === 'rules' && <MatrixAndRules />}
        {viewMode === 'challenges' && <ChallengesSolutions />}
      </main>

      {/* Global Search Modal */}
      <SearchModal
        isOpen={isSearchOpen}
        onClose={() => setIsSearchOpen(false)}
        goToSlide={goToSlide}
      />

      {/* Light Theme Brand Footer */}
      <footer style={{
        borderTop: '1px solid var(--border-subtle)',
        background: '#FFFFFF',
        padding: '1.25rem 2rem',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '1rem',
        fontSize: '0.82rem',
        color: 'var(--text-muted)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <img src="./square_logo.png" alt="NovaExpress" style={{ width: '22px', height: '22px', objectFit: 'contain' }} />
          <span>NovaExpress Logistics • React + Vite Interactive Master Deck • Confidential</span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
          <span>Shortcuts:</span>
          <span style={{ background: 'var(--bg-subtle)', padding: '2px 8px', borderRadius: '4px', fontFamily: 'var(--font-mono)', fontWeight: 700, border: '1px solid var(--border-subtle)' }}>← / →</span>
          <span>Slide</span>
          <span style={{ background: 'var(--bg-subtle)', padding: '2px 8px', borderRadius: '4px', fontFamily: 'var(--font-mono)', fontWeight: 700, border: '1px solid var(--border-subtle)' }}>Space</span>
          <span>Next</span>
          <span style={{ background: 'var(--bg-subtle)', padding: '2px 8px', borderRadius: '4px', fontFamily: 'var(--font-mono)', fontWeight: 700, border: '1px solid var(--border-subtle)' }}>F</span>
          <span>Fullscreen</span>
          <span style={{ background: 'var(--bg-subtle)', padding: '2px 8px', borderRadius: '4px', fontFamily: 'var(--font-mono)', fontWeight: 700, border: '1px solid var(--border-subtle)' }}>S</span>
          <span>Search</span>
        </div>
      </footer>
    </div>
  );
}
