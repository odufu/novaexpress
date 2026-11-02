import React from 'react';
import QuoteSection from '../components/QuoteSection';
import RateEstimator from '../components/RateEstimator';

export default function ContactPage({ settings, prefillData, onBookEstimate }) {
  return (
    <div style={{ paddingTop: '20px' }}>
      <RateEstimator onBookEstimate={onBookEstimate} />
      <QuoteSection settings={settings} prefillData={prefillData} />
    </div>
  );
}
