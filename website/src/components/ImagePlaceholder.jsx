import React, { useState } from 'react';
import { Image as ImageIcon, UploadCloud } from 'lucide-react';

export default function ImagePlaceholder({ 
  src, 
  alt, 
  description = 'High-resolution logistics visual', 
  dimensions = '1200 × 800', 
  className = '', 
  style = {},
  aspectRatio = '16/9'
}) {
  const [imageError, setImageError] = useState(false);

  if (src && !imageError) {
    return (
      <img
        src={src}
        alt={alt || description}
        onError={() => setImageError(true)}
        className={className}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          display: 'block',
          borderRadius: 'inherit',
          ...style,
        }}
      />
    );
  }

  return (
    <div
      className={`image-placeholder-box ${className}`}
      style={{
        width: '100%',
        minHeight: '220px',
        aspectRatio,
        position: 'relative',
        ...style,
      }}
    >
      <div 
        style={{
          width: '44px',
          height: '44px',
          borderRadius: '12px',
          background: 'rgba(8, 38, 88, 0.08)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: '12px',
        }}
      >
        <ImageIcon size={22} color="#082658" />
      </div>

      <span 
        style={{
          fontSize: '11px',
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.06em',
          color: '#FD7A02',
          background: 'rgba(253, 122, 2, 0.12)',
          padding: '3px 10px',
          borderRadius: '12px',
          marginBottom: '8px',
        }}
      >
        Image Placeholder
      </span>

      <p style={{ fontSize: '13px', fontWeight: 600, color: '#082658', maxWidth: '320px', lineHeight: 1.4, margin: '0 auto 6px' }}>
        {description}
      </p>

      <span style={{ fontSize: '11px', color: '#7E8DA6', fontFamily: 'var(--font-mono)' }}>
        Suggested Spec: {dimensions}
      </span>
    </div>
  );
}
