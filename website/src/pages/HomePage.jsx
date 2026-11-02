import React from 'react';
import HeroSection from '../components/HeroSection';
import StatsBar from '../components/StatsBar';
import ServicesSection from '../components/ServicesSection';
import RateEstimator from '../components/RateEstimator';
import PortfolioSection from '../components/PortfolioSection';
import WhyChooseUs from '../components/WhyChooseUs';
import CoverageMap from '../components/CoverageMap';
import TestimonialsSection from '../components/TestimonialsSection';
import QuoteSection from '../components/QuoteSection';

export default function HomePage({ 
  settings, 
  services, 
  portfolio, 
  testimonials, 
  stats, 
  onTrackSubmit, 
  onNavigate,
  onBookEstimate,
  prefillQuoteData,
}) {
  return (
    <div>
      <HeroSection 
        settings={settings}
        onTrackSubmit={onTrackSubmit}
        onGetQuoteClick={() => onNavigate('contact')}
        onExploreServices={() => onNavigate('services')}
      />

      <StatsBar stats={stats} />

      <ServicesSection 
        services={services} 
        onSelectService={(svc) => {
          onBookEstimate({
            serviceType: svc.title,
            destination: 'Lagos State',
            origin: 'Ikeja Gateway Hub',
          });
          onNavigate('contact');
        }}
      />

      <RateEstimator 
        onBookEstimate={(data) => {
          onBookEstimate(data);
          onNavigate('contact');
        }}
      />

      <PortfolioSection 
        portfolio={portfolio} 
        onSelectProject={(proj) => {
          onBookEstimate({
            serviceType: proj.category,
            destination: 'Nationwide',
          });
          onNavigate('contact');
        }}
      />

      <WhyChooseUs onLearnMore={() => onNavigate('about')} />

      <CoverageMap />

      <TestimonialsSection testimonials={testimonials} />

      <QuoteSection settings={settings} prefillData={prefillQuoteData} />
    </div>
  );
}
