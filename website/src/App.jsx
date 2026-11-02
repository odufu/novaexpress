import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import AnnouncementBar from './components/AnnouncementBar';
import Footer from './components/Footer';
import TrackingModal from './components/TrackingModal';

import HomePage from './pages/HomePage';
import ServicesPage from './pages/ServicesPage';
import PortfolioPage from './pages/PortfolioPage';
import AboutPage from './pages/AboutPage';
import TrackingPage from './pages/TrackingPage';
import ContactPage from './pages/ContactPage';
import AdminPage from './pages/AdminPage';

import { 
  fetchWebsiteContent, 
  DEFAULT_SETTINGS, 
  DEFAULT_SERVICES, 
  DEFAULT_PORTFOLIO, 
  DEFAULT_TESTIMONIALS, 
  DEFAULT_STATS 
} from './lib/supabase';

export default function App() {
  const [activePage, setActivePage] = useState(() => {
    const hash = window.location.hash.replace('#', '');
    const pathname = window.location.pathname;
    if (pathname === '/xpress-admin' || pathname === '/admin' || hash === 'xpress-admin' || hash === 'admin') {
      return 'xpress-admin';
    }
    if (['home', 'services', 'portfolio', 'about', 'tracking', 'contact'].includes(hash)) {
      return hash;
    }
    return 'home';
  });

  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const [services, setServices] = useState(DEFAULT_SERVICES);
  const [portfolio, setPortfolio] = useState(DEFAULT_PORTFOLIO);
  const [testimonials, setTestimonials] = useState(DEFAULT_TESTIMONIALS);
  const [stats, setStats] = useState(DEFAULT_STATS);
  const [isLiveSupabase, setIsLiveSupabase] = useState(false);
  const [loading, setLoading] = useState(true);

  // Tracking Modal
  const [trackingModalOpen, setTrackingModalOpen] = useState(false);
  const [trackingInitialCode, setTrackingInitialCode] = useState('');

  // Prefill quote data from estimator or service click
  const [prefillQuoteData, setPrefillQuoteData] = useState(null);

  // Load Content from Live Supabase
  const loadData = async () => {
    try {
      const data = await fetchWebsiteContent();
      if (data) {
        setSettings(data.settings);
        setServices(data.services);
        setPortfolio(data.portfolio);
        setTestimonials(data.testimonials);
        setStats(data.stats);
        setIsLiveSupabase(data.isLiveSupabase);
      }
    } catch (err) {
      console.warn('Error loading website content:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Update hash when page changes
  useEffect(() => {
    window.location.hash = activePage;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }, [activePage]);

  // Handle URL hash changes from back/forward buttons
  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.replace('#', '');
      if (hash === 'xpress-admin' || hash === 'admin') {
        setActivePage('xpress-admin');
      } else if (['home', 'services', 'portfolio', 'about', 'tracking', 'contact'].includes(hash)) {
        setActivePage(hash);
      }
    };
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  const handleTrackCode = (code) => {
    setTrackingInitialCode(code);
    setTrackingModalOpen(true);
  };

  const handleSelectService = (service) => {
    setPrefillQuoteData({
      serviceType: service.title,
      destination: 'Lagos State Hub',
    });
    setActivePage('contact');
  };

  const handleSelectPortfolioProject = (project) => {
    setPrefillQuoteData({
      serviceType: project.category,
      destination: 'Nationwide',
      message: `Inquiring for a similar logistics solution to: ${project.title} (${project.client_name})`,
    });
    setActivePage('contact');
  };

  return (
    <div className="site-wrapper" style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      
      {/* Top Announcement Bar (hidden when on admin page) */}
      {activePage !== 'xpress-admin' && (
        <AnnouncementBar 
          settings={settings} 
          onActionClick={() => setActivePage('services')} 
        />
      )}

      {/* Main Sticky Navbar (hidden when on admin page to provide focused CMS experience) */}
      {activePage !== 'xpress-admin' && (
        <Navbar 
          activePage={activePage} 
          setActivePage={setActivePage} 
          settings={settings}
          onOpenTracking={() => {
            setTrackingInitialCode('');
            setTrackingModalOpen(true);
          }}
        />
      )}

      {/* Main View Router */}
      <main style={{ flex: 1 }}>
        {activePage === 'home' && (
          <HomePage 
            settings={settings}
            services={services}
            portfolio={portfolio}
            testimonials={testimonials}
            stats={stats}
            onTrackSubmit={handleTrackCode}
            onNavigate={setActivePage}
            onBookEstimate={(data) => {
              setPrefillQuoteData(data);
              setActivePage('contact');
            }}
            prefillQuoteData={prefillQuoteData}
          />
        )}

        {activePage === 'services' && (
          <ServicesPage 
            services={services} 
            onSelectService={handleSelectService} 
          />
        )}

        {activePage === 'portfolio' && (
          <PortfolioPage 
            portfolio={portfolio} 
            onSelectProject={handleSelectPortfolioProject} 
          />
        )}

        {activePage === 'about' && (
          <AboutPage 
            onGetInTouch={() => setActivePage('contact')} 
          />
        )}

        {activePage === 'tracking' && (
          <TrackingPage 
            onBookDispatch={() => setActivePage('contact')} 
          />
        )}

        {activePage === 'contact' && (
          <ContactPage 
            settings={settings}
            prefillData={prefillQuoteData}
            onBookEstimate={(data) => setPrefillQuoteData(data)}
          />
        )}

        {activePage === 'xpress-admin' && (
          <AdminPage 
            settings={settings}
            services={services}
            portfolio={portfolio}
            testimonials={testimonials}
            stats={stats}
            onRefreshData={loadData}
            onExitAdmin={() => setActivePage('home')}
          />
        )}
      </main>

      {/* Global Quick Tracking Modal */}
      <TrackingModal 
        isOpen={trackingModalOpen}
        onClose={() => setTrackingModalOpen(false)}
        initialCode={trackingInitialCode}
      />

      {/* Footer (hidden when in admin panel) */}
      {activePage !== 'xpress-admin' && (
        <Footer 
          settings={settings} 
          onNavClick={setActivePage} 
        />
      )}

    </div>
  );
}
