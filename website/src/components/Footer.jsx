import { ShieldCheck, Mail, Phone, MapPin } from 'lucide-react';

export default function Footer({ settings, onNavClick }) {
  return (
    <footer 
      style={{
        background: '#082658',
        color: '#FAF9FB',
        borderTop: '1px solid rgba(255, 255, 255, 0.1)',
        paddingTop: '56px',
        paddingBottom: '28px',
      }}
    >
      <div className="container">
        <div 
          style={{
            display: 'grid',
            gridTemplateColumns: '1.5fr 1fr 1fr 1.2fr',
            gap: '36px',
            marginBottom: '40px',
          }}
          className="footer-grid"
        >
          
          {/* Col 1: Brand Info with square_logo */}
          <div>
            <div 
              onClick={() => onNavClick('home')}
              style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px', cursor: 'pointer' }}
            >
              <img 
                src="/branding/square_logo.png" 
                alt="NovaXpress Logo" 
                style={{ width: '38px', height: '38px', borderRadius: '8px', objectFit: 'contain' }}
              />
              <span style={{ fontWeight: 800, fontSize: '20px', letterSpacing: '-0.02em', color: '#FFFFFF' }}>
                Nova<span style={{ color: '#FD7A02' }}>Xpress</span>
              </span>
            </div>

            <p style={{ fontSize: '13px', color: '#D5BFAF', lineHeight: 1.6, marginBottom: '16px', maxWidth: '320px' }}>
              {settings?.tagline || 'Next-Gen Last-Mile Delivery, Cold-Chain Logistics, and Automated Cash on Delivery Remittance Across Nigeria.'}
            </p>

            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '12px', color: '#FD7A02', fontWeight: 600 }}>
              <ShieldCheck size={16} />
              <span>Certified Nationwide Logistics Network</span>
            </div>
          </div>

          {/* Col 2: Services */}
          <div>
            <h4 style={{ fontSize: '13px', fontWeight: 700, color: '#FFFFFF', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '14px' }}>
              Solutions
            </h4>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '13px', color: '#D5BFAF' }}>
              <li><button onClick={() => onNavClick('services')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Intra-City Express</button></li>
              <li><button onClick={() => onNavClick('services')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Pharma Cold Chain (2°C - 8°C)</button></li>
              <li><button onClick={() => onNavClick('services')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Cash on Delivery Remittance</button></li>
              <li><button onClick={() => onNavClick('services')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Micro-Hub Warehousing</button></li>
              <li><button onClick={() => onNavClick('services')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Interstate Trunk Cargo</button></li>
            </ul>
          </div>

          {/* Col 3: Navigation */}
          <div>
            <h4 style={{ fontSize: '13px', fontWeight: 700, color: '#FFFFFF', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '14px' }}>
              Quick Links
            </h4>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '13px', color: '#D5BFAF' }}>
              <li><button onClick={() => onNavClick('about')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Distribution Hubs</button></li>
              <li><button onClick={() => onNavClick('portfolio')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Case Studies</button></li>
              <li><button onClick={() => onNavClick('tracking')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Consignment Tracking</button></li>
              <li><button onClick={() => onNavClick('contact')} style={{ background: 'none', color: 'inherit', textAlign: 'left' }}>Request Rate Quotation</button></li>
            </ul>
          </div>

          {/* Col 4: Contact */}
          <div>
            <h4 style={{ fontSize: '13px', fontWeight: 700, color: '#FFFFFF', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '14px' }}>
              Operations Support
            </h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '13px', color: '#D5BFAF' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Phone size={15} color="#FD7A02" />
                <span>{settings?.contact_phone || '+234 812 345 6789'}</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Mail size={15} color="#FD7A02" />
                <span>{settings?.contact_email || 'operations@novaxpressng.com'}</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '10px' }}>
                <MapPin size={15} color="#FD7A02" style={{ marginTop: '3px', flexShrink: 0 }} />
                <span>{settings?.headquarters_address || 'NovaXpress Gateway Hub, Ikeja, Lagos, Nigeria'}</span>
              </div>
            </div>
          </div>

        </div>

        {/* Bottom Line */}
        <div 
          style={{
            borderTop: '1px solid rgba(255, 255, 255, 0.08)',
            paddingTop: '20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            fontSize: '12px',
            color: '#D5BFAF',
          }}
          className="footer-bottom"
        >
          <p>© {new Date().getFullYear()} {settings?.brand_name || 'NovaXpress Logistics Ltd'}. All rights reserved.</p>
          <div style={{ display: 'flex', gap: '18px' }}>
            <span>Privacy Policy</span>
            <span>Terms of Service</span>
            <span>NAFDAC & Transit Insurance</span>
          </div>
        </div>

      </div>

      <style>{`
        @media (max-width: 900px) {
          .footer-grid {
            grid-template-columns: 1fr 1fr !important;
          }
        }
        @media (max-width: 550px) {
          .footer-grid {
            grid-template-columns: 1fr !important;
          }
          .footer-bottom {
            flex-direction: column;
            gap: 10px;
            text-align: center;
          }
        }
      `}</style>
    </footer>
  );
}
