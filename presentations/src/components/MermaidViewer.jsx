import React, { useEffect, useRef, useState } from 'react';
import mermaid from 'mermaid';

// Initialize mermaid with brand theme
mermaid.initialize({
  startOnLoad: false,
  theme: 'base',
  themeVariables: {
    primaryColor: '#E6F4EA',
    primaryTextColor: '#006C4C',
    primaryBorderColor: '#006C4C',
    lineColor: '#006C4C',
    secondaryColor: '#FFF4EB',
    tertiaryColor: '#F8FAFC',
    fontSize: '13px',
    fontFamily: 'Outfit, Plus Jakarta Sans, sans-serif',
    nodeBorder: '#006C4C',
    mainBkg: '#FFFFFF',
    edgeLabelBackground: '#FFFFFF',
    clusterBkg: '#F1F5F9',
    clusterBorder: '#CBD5E1',
  },
  securityLevel: 'loose',
  flowchart: {
    useMaxWidth: true,
    htmlLabels: true,
    curve: 'basis',
  },
  sequence: {
    diagramMarginX: 20,
    diagramMarginY: 20,
    actorMargin: 50,
    width: 140,
    height: 45,
    boxMargin: 10,
    boxTextMargin: 5,
    noteMargin: 10,
    messageMargin: 35,
    mirrorActors: false,
  },
});

export default function MermaidViewer({ chart, id = 'mermaid-diagram' }) {
  const containerRef = useRef(null);
  const [svgContent, setSvgContent] = useState('');
  const [error, setError] = useState(null);

  useEffect(() => {
    let isMounted = true;
    const uniqueId = `${id}-${Math.random().toString(36).substring(2, 9)}`;

    async function renderChart() {
      try {
        setError(null);
        const { svg } = await mermaid.render(uniqueId, chart);
        if (isMounted) {
          setSvgContent(svg);
        }
      } catch (err) {
        console.error('Mermaid render error:', err);
        if (isMounted) {
          setError(err.message || 'Failed to render diagram');
        }
      }
    }

    renderChart();

    return () => {
      isMounted = false;
      // Cleanup any dangling elements created by mermaid
      const dangling = document.getElementById(uniqueId);
      if (dangling) dangling.remove();
    };
  }, [chart, id]);

  if (error) {
    return (
      <div style={{
        background: '#FEF2F2',
        border: '1px solid #FCA5A5',
        borderRadius: '12px',
        padding: '1rem',
        color: '#991B1B',
        fontSize: '0.85rem',
        fontFamily: 'var(--font-mono)',
      }}>
        Diagram render note: {error}
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      style={{
        background: '#FFFFFF',
        border: '1px solid #E2E8F0',
        borderRadius: '16px',
        padding: '1.5rem',
        boxShadow: '0 4px 20px -2px rgba(0, 108, 76, 0.05)',
        overflowX: 'auto',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        minHeight: '220px',
      }}
      dangerouslySetInnerHTML={{ __html: svgContent }}
    />
  );
}
