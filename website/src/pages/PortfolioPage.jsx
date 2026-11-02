import React, { useState } from 'react';
import { Briefcase, ArrowUpRight, TrendingUp, CheckCircle, X, Sparkles } from 'lucide-react';
import PortfolioSection from '../components/PortfolioSection';

export default function PortfolioPage({ portfolio, onSelectProject }) {
  return (
    <div style={{ paddingTop: '20px' }}>
      <div className="container" style={{ textAlign: 'center', maxWidth: '750px', margin: '40px auto 20px' }}>
        <div className="badge-pill" style={{ marginBottom: '16px' }}>
          <Sparkles size={14} color="#60A5FA" />
          <span>Case Studies & Track Record</span>
        </div>
        <h1 style={{ fontSize: 'clamp(32px, 4vw, 50px)', marginBottom: '18px' }}>
          Real Impact, Measurable <span className="gradient-text">Success Stories</span>
        </h1>
        <p style={{ fontSize: '16px', color: 'var(--text-muted)' }}>
          Explore how NovaXpress partners with top-tier healthcare providers, fast-scaling D2C brands, and retail chains to eliminate delivery friction and accelerate cash remittance.
        </p>
      </div>

      <PortfolioSection portfolio={portfolio} onSelectProject={onSelectProject} />
    </div>
  );
}
