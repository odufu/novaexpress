import React, { useState } from 'react';
import { Sparkles, X, ChevronRight } from 'lucide-react';

export default function AnnouncementBar({ settings, onActionClick }) {
  const [dismissed, setDismissed] = useState(false);

  if (dismissed || !settings?.announcement_active || !settings?.announcement_text) {
    return null;
  }

  return (
    <div 
      style={{
        background: 'linear-gradient(90deg, #1E1B4B 0%, #172554 50%, #082F49 100%)',
        borderBottom: '1px solid rgba(59, 130, 246, 0.25)',
        color: '#E0F2FE',
        padding: '10px 16px',
        fontSize: '13px',
        fontWeight: 500,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        position: 'relative',
        zIndex: 110,
      }}
    >
      <div 
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          cursor: 'pointer',
        }}
        onClick={onActionClick}
      >
        <span style={{ display: 'inline-flex', padding: '2px 8px', borderRadius: '12px', background: 'rgba(59, 130, 246, 0.3)', color: '#93C5FD', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Notice
        </span>
        <span>{settings.announcement_text}</span>
        <ChevronRight size={14} color="#93C5FD" />
      </div>

      <button
        onClick={() => setDismissed(true)}
        style={{
          position: 'absolute',
          right: '16px',
          background: 'transparent',
          color: '#94A3B8',
          display: 'flex',
          alignItems: 'center',
          padding: '4px',
          borderRadius: '4px',
        }}
        aria-label="Dismiss announcement"
      >
        <X size={15} />
      </button>
    </div>
  );
}
