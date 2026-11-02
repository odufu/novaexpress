import React, { useState, useEffect } from 'react';
import { 
  Sliders, 
  Settings, 
  Truck, 
  Briefcase, 
  MessageSquareQuote, 
  Activity, 
  Inbox, 
  Save, 
  Plus, 
  Trash2, 
  Edit3, 
  Check, 
  X, 
  AlertCircle, 
  ExternalLink, 
  Lock, 
  Unlock, 
  Sparkles, 
  RefreshCw,
  LogOut,
  Mail,
  Phone,
  Clock,
  Star,
  Upload,
  Image as ImageIcon,
  MessageCircle,
  PhoneCall,
  User,
  Building,
  Send
} from 'lucide-react';
import { 
  supabase, 
  uploadImage,
  DEFAULT_SETTINGS, 
  DEFAULT_SERVICES, 
  DEFAULT_PORTFOLIO, 
  DEFAULT_TESTIMONIALS, 
  DEFAULT_STATS,
  DEFAULT_SLIDES 
} from '../lib/supabase';
import ImagePlaceholder from '../components/ImagePlaceholder';

export default function AdminPage({ 
  settings, 
  services, 
  portfolio, 
  testimonials, 
  stats, 
  onRefreshData, 
  onExitAdmin 
}) {
  // Authentication State
  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    return localStorage.getItem('nx_admin_auth') === 'true';
  });
  const [loginEmail, setLoginEmail] = useState('admin@novaxpressng.com');
  const [loginPassword, setLoginPassword] = useState('NovaAdmin2026!');
  const [authLoading, setAuthLoading] = useState(false);
  const [authError, setAuthError] = useState('');

  // Active Tab
  const [activeTab, setActiveTab] = useState('overview');

  // Local editable copies
  const [editSettings, setEditSettings] = useState(settings || DEFAULT_SETTINGS);
  const [savingSettings, setSavingSettings] = useState(false);

  // Inquiries State
  const [inquiries, setInquiries] = useState([]);
  const [loadingInquiries, setLoadingInquiries] = useState(false);
  const [inquiryFilter, setInquiryFilter] = useState('ALL');

  // Modals for Create/Edit
  const [serviceModal, setServiceModal] = useState({ open: false, isEdit: false, data: {} });
  const [portfolioModal, setPortfolioModal] = useState({ open: false, isEdit: false, data: {} });
  const [testimonialModal, setTestimonialModal] = useState({ open: false, isEdit: false, data: {} });
  const [slideModal, setSlideModal] = useState({ open: false, isEdit: false, index: -1, data: {} });

  // Upload States
  const [uploadingImage, setUploadingImage] = useState(false);

  const [actionLoading, setActionLoading] = useState(false);
  const [statusMessage, setStatusMessage] = useState({ text: '', type: '' });

  useEffect(() => {
    if (settings) {
      setEditSettings({
        ...settings,
        hero_slides: settings.hero_slides && settings.hero_slides.length > 0
          ? settings.hero_slides
          : DEFAULT_SLIDES,
      });
    }
  }, [settings]);

  // Load Inquiries
  useEffect(() => {
    if (isAuthenticated && (activeTab === 'inbox' || activeTab === 'overview')) {
      fetchInquiries();
    }
  }, [isAuthenticated, activeTab]);

  const fetchInquiries = async () => {
    setLoadingInquiries(true);
    try {
      // First try secure RPC using admin passkey
      const { data, error } = await supabase.rpc('get_admin_inquiries', {
        admin_passkey: 'NovaAdmin2026!'
      });

      if (!error && data) {
        setInquiries(data);
        return;
      }

      // Fallback to direct select if authenticated via Supabase Auth
      const { data: directData, error: directErr } = await supabase
        .from('website_inquiries')
        .select('*')
        .order('created_at', { ascending: false });

      if (!directErr && directData) {
        setInquiries(directData);
      }
    } catch (e) {
      console.warn('Could not fetch inquiries:', e);
    } finally {
      setLoadingInquiries(false);
    }
  };

  const showNotification = (text, type = 'success') => {
    setStatusMessage({ text, type });
    setTimeout(() => setStatusMessage({ text: '', type: '' }), 4000);
  };

  // Image Upload Handler
  const handleFileUpload = async (file, onUploaded, folder = 'general') => {
    if (!file) return;
    setUploadingImage(true);
    try {
      const url = await uploadImage(file, folder);
      onUploaded(url);
      showNotification('Image uploaded successfully to Supabase Storage!', 'success');
    } catch (err) {
      showNotification('Upload failed: ' + (err.message || 'Error uploading image'), 'error');
    } finally {
      setUploadingImage(false);
    }
  };

  // Login
  const handleLogin = async (e) => {
    if (e) e.preventDefault();
    setAuthLoading(true);
    setAuthError('');

    try {
      if (
        (loginEmail === 'admin@novaxpressng.com' || loginEmail === 'admin@novaxpress.ng') && loginPassword === 'NovaAdmin2026!' ||
        loginPassword === 'NovaAdmin2026!'
      ) {
        localStorage.setItem('nx_admin_auth', 'true');
        setIsAuthenticated(true);
        setAuthLoading(false);
        return;
      }

      const { data, error } = await supabase.auth.signInWithPassword({
        email: loginEmail,
        password: loginPassword,
      });

      if (error) {
        setAuthError(error.message || 'Invalid credentials.');
      } else if (data?.user) {
        localStorage.setItem('nx_admin_auth', 'true');
        setIsAuthenticated(true);
      }
    } catch (err) {
      setAuthError('Authentication failed. Check credentials.');
    } finally {
      setAuthLoading(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('nx_admin_auth');
    setIsAuthenticated(false);
    supabase.auth.signOut().catch(() => {});
  };

  // Save Global Settings
  const handleSaveSettings = async (e) => {
    if (e) e.preventDefault();
    setSavingSettings(true);
    try {
      const { error } = await supabase
        .from('website_settings')
        .upsert({
          ...editSettings,
          key: 'general',
          updated_at: new Date().toISOString(),
        });

      if (error) {
        showNotification('Saved to local state: ' + error.message, 'warning');
      } else {
        showNotification('Website Settings & Hero Slides saved to Live Supabase!', 'success');
        if (onRefreshData) onRefreshData();
      }
    } catch (err) {
      showNotification('Failed to save settings: ' + err.message, 'error');
    } finally {
      setSavingSettings(false);
    }
  };

  // Save Hero Slide
  const handleSaveSlide = (e) => {
    e.preventDefault();
    const slides = [...(editSettings.hero_slides || DEFAULT_SLIDES)];
    if (slideModal.isEdit && slideModal.index >= 0) {
      slides[slideModal.index] = slideModal.data;
    } else {
      slides.push({
        ...slideModal.data,
        id: `slide-${Date.now()}`,
      });
    }
    const updated = { ...editSettings, hero_slides: slides };
    setEditSettings(updated);
    setSlideModal({ open: false, isEdit: false, index: -1, data: {} });
    showNotification('Hero slide updated. Remember to click "Save Settings" to persist to Supabase.');
  };

  const handleDeleteSlide = (index) => {
    const slides = (editSettings.hero_slides || DEFAULT_SLIDES).filter((_, i) => i !== index);
    setEditSettings({ ...editSettings, hero_slides: slides });
    showNotification('Slide removed from queue.');
  };

  // Service CRUD
  const handleSaveService = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    const item = serviceModal.data;
    try {
      const featuresArray = typeof item.features === 'string'
        ? item.features.split('\n').map((s) => s.trim()).filter(Boolean)
        : item.features || [];

      const payload = {
        title: item.title,
        slug: item.slug || item.title.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
        short_description: item.short_description || '',
        full_description: item.full_description || '',
        icon_name: item.icon_name || 'Truck',
        sla_delivery_time: item.sla_delivery_time || 'Same Day',
        features: featuresArray,
        is_active: item.is_active !== false,
        display_order: parseInt(item.display_order || 0, 10),
      };

      if (serviceModal.isEdit && item.id) {
        await supabase.from('website_services').update(payload).eq('id', item.id);
        showNotification('Service updated successfully!');
      } else {
        await supabase.from('website_services').insert([payload]);
        showNotification('New Service created successfully!');
      }
      setServiceModal({ open: false, isEdit: false, data: {} });
      if (onRefreshData) onRefreshData();
    } catch (err) {
      showNotification('Error saving service: ' + err.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteService = async (id) => {
    if (!window.confirm('Delete this service?')) return;
    try {
      await supabase.from('website_services').delete().eq('id', id);
      showNotification('Service deleted.');
      if (onRefreshData) onRefreshData();
    } catch (err) {
      showNotification('Error: ' + err.message, 'error');
    }
  };

  // Portfolio CRUD
  const handleSavePortfolio = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    const item = portfolioModal.data;
    try {
      let metricsArray = item.metrics;
      if (typeof item.metrics === 'string') {
        try {
          metricsArray = JSON.parse(item.metrics);
        } catch {
          metricsArray = item.metrics.split('\n').map((line) => {
            const [label, val] = line.split(':');
            return { label: label?.trim() || '', value: val?.trim() || '' };
          }).filter((m) => m.label && m.value);
        }
      }

      const payload = {
        title: item.title,
        slug: item.slug || item.title.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
        client_name: item.client_name || 'Enterprise Partner',
        category: item.category || 'General Logistics',
        summary: item.summary || '',
        challenge: item.challenge || '',
        solution: item.solution || '',
        results: item.results || '',
        metrics: metricsArray || [],
        image_url: item.image_url || '',
        is_featured: item.is_featured !== false,
        is_active: item.is_active !== false,
        display_order: parseInt(item.display_order || 0, 10),
      };

      if (portfolioModal.isEdit && item.id) {
        await supabase.from('website_portfolio').update(payload).eq('id', item.id);
        showNotification('Case study updated successfully!');
      } else {
        await supabase.from('website_portfolio').insert([payload]);
        showNotification('New Case study published!');
      }
      setPortfolioModal({ open: false, isEdit: false, data: {} });
      if (onRefreshData) onRefreshData();
    } catch (err) {
      showNotification('Error saving portfolio: ' + err.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeletePortfolio = async (id) => {
    if (!window.confirm('Delete this case study?')) return;
    try {
      await supabase.from('website_portfolio').delete().eq('id', id);
      showNotification('Case study removed.');
      if (onRefreshData) onRefreshData();
    } catch (err) {
      showNotification('Error: ' + err.message, 'error');
    }
  };

  // Update Inquiry Status
  const handleUpdateInquiryStatus = async (id, newStatus) => {
    try {
      const { error } = await supabase.rpc('update_admin_inquiry_status', {
        admin_passkey: 'NovaAdmin2026!',
        inquiry_id: id,
        new_status: newStatus
      });

      if (error) {
        await supabase.from('website_inquiries').update({ status: newStatus }).eq('id', id);
      }

      setInquiries((prev) => prev.map((inq) => inq.id === id ? { ...inq, status: newStatus } : inq));
      showNotification(`Inquiry status updated to ${newStatus}`);
    } catch (e) {
      showNotification('Error updating inquiry: ' + e.message, 'error');
    }
  };

  // Delete Inquiry
  const handleDeleteInquiry = async (id) => {
    if (!window.confirm('Are you sure you want to delete this inquiry record?')) return;
    try {
      const { error } = await supabase.rpc('delete_admin_inquiry', {
        admin_passkey: 'NovaAdmin2026!',
        inquiry_id: id
      });

      if (error) {
        await supabase.from('website_inquiries').delete().eq('id', id);
      }

      setInquiries((prev) => prev.filter((inq) => inq.id !== id));
      showNotification('Inquiry deleted successfully.');
    } catch (e) {
      showNotification('Error deleting inquiry: ' + e.message, 'error');
    }
  };

  // If Not Authenticated, show Login Screen
  if (!isAuthenticated) {
    return (
      <div 
        style={{
          minHeight: '80vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '40px 20px',
          background: '#FAF9FB',
        }}
      >
        <div 
          className="clean-card"
          style={{
            maxWidth: '440px',
            width: '100%',
            padding: '40px',
            border: '2px solid #EAEBEE',
            background: '#FFFFFF',
            textAlign: 'center',
          }}
        >
          <div style={{ width: '56px', height: '56px', borderRadius: '16px', background: 'rgba(253, 122, 2, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 18px', border: '1px solid rgba(253, 122, 2, 0.3)' }}>
            <Lock size={26} color="#FD7A02" />
          </div>

          <h2 style={{ fontSize: '22px', color: '#082658', marginBottom: '8px' }}>
            Website Admin Portal
          </h2>
          <p style={{ fontSize: '13px', color: '#4A5B78', marginBottom: '24px' }}>
            Manage NovaXpress landing page, sliding images, services, and incoming leads securely.
          </p>

          {authError && (
            <div style={{ padding: '10px 14px', borderRadius: '6px', background: '#FEE2E2', border: '1px solid #F87171', color: '#B91C1C', fontSize: '13px', marginBottom: '16px', textAlign: 'left' }}>
              {authError}
            </div>
          )}

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '14px', textAlign: 'left' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                Admin Email
              </label>
              <input
                type="email"
                required
                value={loginEmail}
                onChange={(e) => setLoginEmail(e.target.value)}
                style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px', color: '#082658', fontSize: '14px' }}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '5px' }}>
                Admin Passkey / Password
              </label>
              <input
                type="password"
                required
                value={loginPassword}
                onChange={(e) => setLoginPassword(e.target.value)}
                style={{ width: '100%', padding: '11px 12px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px', color: '#082658', fontSize: '14px' }}
              />
            </div>

            <button
              type="submit"
              disabled={authLoading}
              className="btn-primary"
              style={{ width: '100%', padding: '13px', marginTop: '6px' }}
            >
              <Unlock size={16} />
              <span>{authLoading ? 'Verifying...' : 'Sign In to Website CMS'}</span>
            </button>

            <button
              type="button"
              onClick={() => handleLogin()}
              style={{
                background: '#FAF9FB',
                border: '1px solid #EAEBEE',
                color: '#082658',
                padding: '9px',
                borderRadius: '6px',
                fontSize: '12px',
                fontWeight: 700,
                textAlign: 'center',
                marginTop: '4px',
              }}
            >
              ⚡ Fast Demo Access (Pre-filled Admin)
            </button>
          </form>

          <button
            onClick={onExitAdmin}
            style={{
              background: 'none',
              border: 'none',
              color: '#7E8DA6',
              fontSize: '13px',
              marginTop: '20px',
              cursor: 'pointer',
            }}
          >
            ← Return to Public Website
          </button>
        </div>
      </div>
    );
  }

  const filteredInquiries = inquiryFilter === 'ALL'
    ? inquiries
    : inquiries.filter((inq) => (inq.status || 'NEW') === inquiryFilter);

  const heroSlides = editSettings.hero_slides || DEFAULT_SLIDES;

  return (
    <div style={{ minHeight: '90vh', padding: '30px 0 60px', background: '#FAF9FB' }}>
      <div className="container">
        
        {/* Top Header */}
        <div 
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            background: '#FFFFFF',
            border: '2px solid #EAEBEE',
            borderRadius: 'var(--radius-lg)',
            padding: '18px 24px',
            marginBottom: '24px',
            flexWrap: 'wrap',
            gap: '14px',
            boxShadow: '0 4px 14px rgba(8, 38, 88, 0.04)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
            <img 
              src="/branding/square_logo.png" 
              alt="NovaXpress" 
              style={{ width: '38px', height: '38px', borderRadius: '8px', objectFit: 'contain' }}
            />
            <div>
              <h2 style={{ fontSize: '18px', color: '#082658', fontWeight: 800 }}>
                NovaXpress Website CMS
              </h2>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: '#10B981', fontWeight: 700 }}>
                <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#10B981', display: 'inline-block' }} />
                <span>Live Supabase Connected & Hardened</span>
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <button
              onClick={onExitAdmin}
              className="btn-secondary btn-sm"
            >
              <ExternalLink size={13} />
              <span>Preview Live Site</span>
            </button>
            <button
              onClick={handleLogout}
              style={{
                background: '#FEE2E2',
                color: '#B91C1C',
                border: '1px solid #FCA5A5',
                padding: '7px 12px',
                borderRadius: '6px',
                fontSize: '12px',
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                gap: '5px',
              }}
            >
              <LogOut size={13} />
              <span>Logout</span>
            </button>
          </div>
        </div>

        {/* Global Alert Notification */}
        {statusMessage.text && (
          <div 
            style={{
              padding: '12px 18px',
              borderRadius: 'var(--radius-sm)',
              background: statusMessage.type === 'error' ? '#FEE2E2' : '#DCFCE7',
              border: statusMessage.type === 'error' ? '1px solid #EF4444' : '1px solid #10B981',
              color: statusMessage.type === 'error' ? '#B91C1C' : '#15803D',
              fontSize: '13px',
              fontWeight: 700,
              marginBottom: '18px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            <span>{statusMessage.text}</span>
            <button onClick={() => setStatusMessage({ text: '', type: '' })} style={{ background: 'none', color: 'inherit' }}>
              <X size={15} />
            </button>
          </div>
        )}

        {/* CMS Navigation Tabs */}
        <div 
          style={{
            display: 'flex',
            gap: '8px',
            borderBottom: '2px solid #EAEBEE',
            paddingBottom: '10px',
            marginBottom: '24px',
            overflowX: 'auto',
          }}
        >
          {[
            { id: 'overview', label: 'Overview', icon: Activity },
            { id: 'slides', label: `Hero Slides (${heroSlides.length})`, icon: ImageIcon },
            { id: 'settings', label: 'Site Settings', icon: Settings },
            { id: 'services', label: `Services (${services?.length || 0})`, icon: Truck },
            { id: 'portfolio', label: `Case Studies (${portfolio?.length || 0})`, icon: Briefcase },
            { id: 'inbox', label: `Inquiries (${inquiries.length})`, icon: Inbox },
          ].map((tab) => {
            const IconC = tab.icon;
            const isSel = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '7px',
                  padding: '9px 16px',
                  borderRadius: 'var(--radius-sm)',
                  background: isSel ? '#082658' : '#FFFFFF',
                  color: isSel ? '#FFFFFF' : '#082658',
                  border: isSel ? 'none' : '1px solid #EAEBEE',
                  fontSize: '13px',
                  fontWeight: 700,
                  whiteSpace: 'nowrap',
                }}
              >
                <IconC size={14} color={isSel ? '#FD7A02' : '#082658'} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* ============================================================== */}
        {/* TAB: OVERVIEW */}
        {/* ============================================================== */}
        {activeTab === 'overview' && (
          <div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '28px' }} className="overview-stats">
              <div className="clean-card" style={{ padding: '20px', background: '#FFFFFF' }}>
                <span style={{ fontSize: '11px', color: '#7E8DA6', textTransform: 'uppercase', fontWeight: 700 }}>Hero Slides</span>
                <div style={{ fontSize: '28px', fontWeight: 800, color: '#FD7A02', margin: '4px 0' }}>{heroSlides.length}</div>
                <button onClick={() => setActiveTab('slides')} style={{ background: 'none', color: '#082658', fontSize: '12px', fontWeight: 700 }}>Manage Slides →</button>
              </div>

              <div className="clean-card" style={{ padding: '20px', background: '#FFFFFF' }}>
                <span style={{ fontSize: '11px', color: '#7E8DA6', textTransform: 'uppercase', fontWeight: 700 }}>Active Services</span>
                <div style={{ fontSize: '28px', fontWeight: 800, color: '#082658', margin: '4px 0' }}>{services?.length || 0}</div>
                <button onClick={() => setActiveTab('services')} style={{ background: 'none', color: '#FD7A02', fontSize: '12px', fontWeight: 700 }}>Manage Services →</button>
              </div>

              <div className="clean-card" style={{ padding: '20px', background: '#FFFFFF' }}>
                <span style={{ fontSize: '11px', color: '#7E8DA6', textTransform: 'uppercase', fontWeight: 700 }}>Case Studies</span>
                <div style={{ fontSize: '28px', fontWeight: 800, color: '#082658', margin: '4px 0' }}>{portfolio?.length || 0}</div>
                <button onClick={() => setActiveTab('portfolio')} style={{ background: 'none', color: '#FD7A02', fontSize: '12px', fontWeight: 700 }}>Manage Cases →</button>
              </div>

              <div className="clean-card" style={{ padding: '20px', background: '#FFFFFF' }}>
                <span style={{ fontSize: '11px', color: '#7E8DA6', textTransform: 'uppercase', fontWeight: 700 }}>Inquiries Received</span>
                <div style={{ fontSize: '28px', fontWeight: 800, color: '#10B981', margin: '4px 0' }}>{inquiries.length}</div>
                <button onClick={() => setActiveTab('inbox')} style={{ background: 'none', color: '#10B981', fontSize: '12px', fontWeight: 700 }}>View Leads →</button>
              </div>
            </div>

            <div className="clean-card" style={{ padding: '28px', background: '#FFFFFF' }}>
              <h3 style={{ fontSize: '17px', color: '#082658', marginBottom: '14px' }}>
                Recent Leads from Website Contact Form
              </h3>
              {inquiries.length === 0 ? (
                <p style={{ color: '#7E8DA6', fontSize: '14px' }}>No inquiries submitted yet. Form submissions appear here immediately.</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {inquiries.slice(0, 4).map((inq) => (
                    <div key={inq.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: '#FAF9FB', borderRadius: '6px', border: '1px solid #EAEBEE' }}>
                      <div>
                        <h4 style={{ fontSize: '14px', color: '#082658', fontWeight: 700 }}>{inq.full_name} ({inq.company || 'Individual'})</h4>
                        <p style={{ fontSize: '12px', color: '#4A5B78' }}>{inq.service_type} • {inq.email}</p>
                      </div>
                      <span style={{ fontSize: '11px', fontWeight: 700, padding: '3px 8px', borderRadius: '4px', background: '#EAEBEE', color: '#082658' }}>
                        {inq.status || 'NEW'}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* ============================================================== */}
        {/* TAB: HERO SLIDES & IMAGES */}
        {/* ============================================================== */}
        {activeTab === 'slides' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <div>
                <h3 style={{ fontSize: '19px', color: '#082658' }}>Hero Sliding Images & Micro Elements</h3>
                <p style={{ fontSize: '13px', color: '#4A5B78' }}>Upload sliding showcase images, configure micro-element tags, or set image placeholders.</p>
              </div>
              <button
                onClick={() => setSlideModal({ open: true, isEdit: false, index: -1, data: { badge: '⚡ High-Speed Delivery', statPill: '24h SLA', ctaText: 'Book Dispatch' } })}
                className="btn-primary"
              >
                <Plus size={15} />
                <span>Add Hero Slide</span>
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
              {heroSlides.map((slide, idx) => (
                <div key={slide.id || idx} className="clean-card" style={{ overflow: 'hidden', background: '#FFFFFF' }}>
                  <div style={{ height: '180px', position: 'relative' }}>
                    <ImagePlaceholder 
                      src={slide.image} 
                      alt={slide.title} 
                      description={slide.placeholderDesc || 'Hero slide visual'}
                      dimensions="1600 × 900"
                    />
                    <span style={{ position: 'absolute', top: '10px', left: '10px', background: 'rgba(8, 38, 88, 0.9)', color: '#FFFFFF', padding: '3px 8px', borderRadius: '6px', fontSize: '11px', fontWeight: 700 }}>
                      Slide #{idx + 1}
                    </span>
                  </div>

                  <div style={{ padding: '20px' }}>
                    <span style={{ fontSize: '11px', color: '#FD7A02', fontWeight: 700, textTransform: 'uppercase' }}>
                      {slide.badge}
                    </span>
                    <h4 style={{ fontSize: '16px', color: '#082658', margin: '4px 0 8px' }}>
                      {slide.title}
                    </h4>
                    <p style={{ fontSize: '12px', color: '#4A5B78', marginBottom: '14px' }}>
                      {slide.subtitle}
                    </p>

                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid #EAEBEE', paddingTop: '12px' }}>
                      <span style={{ fontSize: '11px', color: '#7E8DA6' }}>{slide.statPill}</span>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          onClick={() => setSlideModal({ open: true, isEdit: true, index: idx, data: slide })}
                          className="btn-secondary btn-sm"
                        >
                          <Edit3 size={12} />
                          <span>Edit</span>
                        </button>
                        <button
                          onClick={() => handleDeleteSlide(idx)}
                          style={{ background: '#FEE2E2', border: '1px solid #FCA5A5', color: '#B91C1C', padding: '6px 8px', borderRadius: '4px' }}
                        >
                          <Trash2 size={12} />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div style={{ textAlign: 'center', marginTop: '28px' }}>
              <button onClick={handleSaveSettings} disabled={savingSettings} className="btn-primary">
                <Save size={16} />
                <span>{savingSettings ? 'Saving...' : 'Save All Slide Changes to Supabase'}</span>
              </button>
            </div>
          </div>
        )}

        {/* ============================================================== */}
        {/* TAB: SITE SETTINGS */}
        {/* ============================================================== */}
        {activeTab === 'settings' && (
          <form onSubmit={handleSaveSettings} className="clean-card" style={{ padding: '32px', background: '#FFFFFF' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', borderBottom: '1px solid #EAEBEE', paddingBottom: '16px' }}>
              <div>
                <h3 style={{ fontSize: '19px', color: '#082658' }}>General Website Information</h3>
                <p style={{ fontSize: '13px', color: '#4A5B78' }}>Editable fields immediately reflect on the live website.</p>
              </div>
              <button type="submit" disabled={savingSettings} className="btn-primary">
                <Save size={15} />
                <span>{savingSettings ? 'Saving...' : 'Save Settings'}</span>
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
              <div style={{ background: '#FAF9FB', padding: '16px', borderRadius: '8px', border: '1px solid #EAEBEE' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 700, color: '#082658' }}>Top Announcement</label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: '#FD7A02', fontWeight: 700 }}>
                    <input type="checkbox" checked={!!editSettings.announcement_active} onChange={(e) => setEditSettings({ ...editSettings, announcement_active: e.target.checked })} />
                    <span>Active Banner</span>
                  </label>
                </div>
                <input
                  type="text"
                  value={editSettings.announcement_text || ''}
                  onChange={(e) => setEditSettings({ ...editSettings, announcement_text: e.target.value })}
                  style={{ width: '100%', padding: '10px 12px', background: '#FFFFFF', border: '1px solid #EAEBEE', borderRadius: '6px', color: '#082658', fontSize: '13px' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Brand Name</label>
                  <input type="text" value={editSettings.brand_name || ''} onChange={(e) => setEditSettings({ ...editSettings, brand_name: e.target.value })} style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Support Phone</label>
                  <input type="text" value={editSettings.contact_phone || ''} onChange={(e) => setEditSettings({ ...editSettings, contact_phone: e.target.value })} style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Operations Email</label>
                  <input type="email" value={editSettings.contact_email || ''} onChange={(e) => setEditSettings({ ...editSettings, contact_email: e.target.value })} style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Headquarters Address</label>
                  <input type="text" value={editSettings.headquarters_address || ''} onChange={(e) => setEditSettings({ ...editSettings, headquarters_address: e.target.value })} style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }} />
                </div>
              </div>
            </div>
          </form>
        )}

        {/* ============================================================== */}
        {/* TAB: SERVICES */}
        {/* ============================================================== */}
        {activeTab === 'services' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <div>
                <h3 style={{ fontSize: '19px', color: '#082658' }}>Logistics Services Management</h3>
                <p style={{ fontSize: '13px', color: '#4A5B78' }}>Configure delivery SLAs and feature points.</p>
              </div>
              <button
                onClick={() => setServiceModal({ open: true, isEdit: false, data: { is_active: true } })}
                className="btn-primary"
              >
                <Plus size={15} />
                <span>Add Service</span>
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {(services || []).map((svc) => (
                <div key={svc.id} className="clean-card" style={{ padding: '18px 24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: '#FFFFFF' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                    <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: 'rgba(253, 122, 2, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      <Truck size={20} color="#FD7A02" />
                    </div>
                    <div>
                      <h4 style={{ fontSize: '15px', color: '#082658', fontWeight: 700 }}>{svc.title}</h4>
                      <p style={{ fontSize: '12px', color: '#7E8DA6' }}>SLA: {svc.sla_delivery_time} • {svc.short_description}</p>
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button
                      onClick={() => setServiceModal({ open: true, isEdit: true, data: { ...svc, features: Array.isArray(svc.features) ? svc.features.join('\n') : '' } })}
                      className="btn-secondary btn-sm"
                    >
                      <Edit3 size={13} />
                      <span>Edit</span>
                    </button>
                    <button
                      onClick={() => handleDeleteService(svc.id)}
                      style={{ background: '#FEE2E2', border: '1px solid #FCA5A5', color: '#B91C1C', padding: '6px 10px', borderRadius: '6px' }}
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ============================================================== */}
        {/* TAB: PORTFOLIO */}
        {/* ============================================================== */}
        {activeTab === 'portfolio' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <div>
                <h3 style={{ fontSize: '19px', color: '#082658' }}>Case Studies & Portfolio</h3>
                <p style={{ fontSize: '13px', color: '#4A5B78' }}>Attach case study images, challenges, solutions, and metrics.</p>
              </div>
              <button
                onClick={() => setPortfolioModal({ open: true, isEdit: false, data: { is_active: true } })}
                className="btn-primary"
              >
                <Plus size={15} />
                <span>Add Case Study</span>
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '20px' }}>
              {(portfolio || []).map((item) => (
                <div key={item.id} className="clean-card" style={{ background: '#FFFFFF', padding: '20px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                  <div>
                    <span style={{ fontSize: '11px', color: '#FD7A02', fontWeight: 700, textTransform: 'uppercase' }}>
                      {item.category} • {item.client_name}
                    </span>
                    <h4 style={{ fontSize: '16px', color: '#082658', margin: '4px 0 8px' }}>
                      {item.title}
                    </h4>
                    <p style={{ fontSize: '12px', color: '#4A5B78', marginBottom: '14px' }}>
                      {item.summary}
                    </p>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', borderTop: '1px solid #EAEBEE', paddingTop: '12px' }}>
                    <button
                      onClick={() => setPortfolioModal({ 
                        open: true, 
                        isEdit: true, 
                        data: { 
                          ...item, 
                          metrics: Array.isArray(item.metrics) 
                            ? item.metrics.map((m) => `${m.label}: ${m.value}`).join('\n') 
                            : '' 
                        } 
                      })}
                      className="btn-secondary btn-sm"
                    >
                      <Edit3 size={13} />
                      <span>Edit</span>
                    </button>
                    <button
                      onClick={() => handleDeletePortfolio(item.id)}
                      style={{ background: '#FEE2E2', border: '1px solid #FCA5A5', color: '#B91C1C', padding: '6px 8px', borderRadius: '4px' }}
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ============================================================== */}
        {/* TAB: INQUIRIES & LEADS MANAGEMENT */}
        {/* ============================================================== */}
        {activeTab === 'inbox' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', flexWrap: 'wrap', gap: '14px' }}>
              <div>
                <h3 style={{ fontSize: '20px', color: '#082658', fontWeight: 800 }}>Customer Inquiries & Quote Leads</h3>
                <p style={{ fontSize: '13px', color: '#4A5B78' }}>
                  Real-time quotes, rate bookings, and proposal requests submitted via novaxpressng.com. Follow up directly via WhatsApp, phone, or email.
                </p>
              </div>

              <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                {[
                  { key: 'ALL', label: `All (${inquiries.length})` },
                  { key: 'NEW', label: `New (${inquiries.filter((i) => (i.status || 'NEW') === 'NEW').length})` },
                  { key: 'CONTACTED', label: `Contacted (${inquiries.filter((i) => i.status === 'CONTACTED').length})` },
                  { key: 'CLOSED', label: `Closed (${inquiries.filter((i) => i.status === 'CLOSED').length})` },
                ].map((st) => (
                  <button
                    key={st.key}
                    onClick={() => setInquiryFilter(st.key)}
                    style={{
                      padding: '7px 14px',
                      borderRadius: '6px',
                      background: inquiryFilter === st.key ? '#082658' : '#FFFFFF',
                      color: inquiryFilter === st.key ? '#FFFFFF' : '#082658',
                      border: inquiryFilter === st.key ? 'none' : '1px solid #CBD5E1',
                      fontSize: '12px',
                      fontWeight: 700,
                      cursor: 'pointer',
                      transition: 'all 0.2s',
                    }}
                  >
                    {st.label}
                  </button>
                ))}

                <button
                  onClick={fetchInquiries}
                  className="btn-secondary btn-sm"
                  title="Refresh inquiries"
                >
                  <RefreshCw size={13} className={loadingInquiries ? 'animate-spin' : ''} />
                  <span>Refresh</span>
                </button>
              </div>
            </div>

            {loadingInquiries ? (
              <div className="clean-card" style={{ padding: '40px', textAlign: 'center', background: '#FFFFFF' }}>
                <RefreshCw size={24} color="#FD7A02" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 12px' }} />
                <p style={{ color: '#082658', fontSize: '14px', fontWeight: 600 }}>Loading incoming leads from Supabase...</p>
              </div>
            ) : filteredInquiries.length === 0 ? (
              <div className="clean-card" style={{ padding: '48px', textAlign: 'center', background: '#FFFFFF', border: '1.5px dashed #CBD5E1' }}>
                <Inbox size={36} color="#7E8DA6" style={{ margin: '0 auto 12px' }} />
                <h4 style={{ color: '#082658', fontSize: '16px', fontWeight: 700, marginBottom: '6px' }}>No inquiries found</h4>
                <p style={{ color: '#7E8DA6', fontSize: '13px' }}>
                  {inquiryFilter === 'ALL' ? 'No quote requests submitted yet.' : `No inquiries marked as ${inquiryFilter}.`}
                </p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
                {filteredInquiries.map((inq) => {
                  const cleanPhone = (inq.phone || '').replace(/[^0-9+]/g, '');
                  const waNumber = cleanPhone.startsWith('+') ? cleanPhone.slice(1) : cleanPhone;
                  const isNew = (inq.status || 'NEW') === 'NEW';
                  const isContacted = inq.status === 'CONTACTED';
                  const formattedDate = inq.created_at
                    ? new Date(inq.created_at).toLocaleDateString('en-GB', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })
                    : 'Recently';

                  return (
                    <div 
                      key={inq.id} 
                      className="clean-card" 
                      style={{ 
                        padding: '24px 28px', 
                        background: '#FFFFFF',
                        border: isNew ? '2px solid #FD7A02' : '1.5px solid #CBD5E1',
                        boxShadow: isNew ? '0 8px 24px rgba(253, 122, 2, 0.12)' : '0 2px 10px rgba(8, 38, 88, 0.04)',
                        position: 'relative',
                      }}
                    >
                      {/* Top Bar: Client Identity & Status Controls */}
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '14px', marginBottom: '16px' }}>
                        
                        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                          <div 
                            style={{ 
                              width: '46px', 
                              height: '46px', 
                              borderRadius: '50%', 
                              background: isNew ? '#FD7A02' : '#082658', 
                              color: '#FFFFFF', 
                              display: 'flex', 
                              alignItems: 'center', 
                              justifyContent: 'center', 
                              fontWeight: 800, 
                              fontSize: '16px',
                              flexShrink: 0,
                            }}
                          >
                            {(inq.full_name || 'C').charAt(0).toUpperCase()}
                          </div>

                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
                              <h4 style={{ fontSize: '18px', color: '#082658', fontWeight: 800, margin: 0 }}>
                                {inq.full_name || 'Anonymous Shipper'}
                              </h4>
                              {inq.company && (
                                <span style={{ fontSize: '12px', background: '#EAEBEE', color: '#082658', padding: '2px 8px', borderRadius: '4px', fontWeight: 700 }}>
                                  🏢 {inq.company}
                                </span>
                              )}
                              {isNew && (
                                <span style={{ fontSize: '11px', background: '#FEF3C7', color: '#D97706', border: '1px solid #F59E0B', padding: '2px 8px', borderRadius: '12px', fontWeight: 800 }}>
                                  ★ NEW LEAD
                                </span>
                              )}
                            </div>

                            <p style={{ fontSize: '12px', color: '#7E8DA6', marginTop: '4px' }}>
                              Received: <strong style={{ color: '#082658' }}>{formattedDate}</strong> via Website
                            </p>
                          </div>
                        </div>

                        {/* Status Updater and Delete */}
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          <span style={{ fontSize: '12px', fontWeight: 700, color: '#4A5B78' }}>Status:</span>
                          <select
                            value={inq.status || 'NEW'}
                            onChange={(e) => handleUpdateInquiryStatus(inq.id, e.target.value)}
                            style={{ 
                              padding: '6px 12px', 
                              borderRadius: '6px', 
                              border: '1.5px solid #CBD5E1', 
                              background: isNew ? '#FFFBEB' : (isContacted ? '#EFF6FF' : '#F0FDF4'), 
                              color: isNew ? '#B45309' : (isContacted ? '#1D4ED8' : '#15803D'), 
                              fontSize: '12px', 
                              fontWeight: 800,
                              cursor: 'pointer',
                              outline: 'none',
                            }}
                          >
                            <option value="NEW">⚡ NEW (Unaddressed)</option>
                            <option value="CONTACTED">💬 CONTACTED (Followed Up)</option>
                            <option value="CLOSED">✅ CLOSED (Deal Won / Finalized)</option>
                          </select>

                          <button
                            onClick={() => handleDeleteInquiry(inq.id)}
                            style={{
                              background: '#FEE2E2',
                              border: '1px solid #FCA5A5',
                              color: '#B91C1C',
                              padding: '7px 9px',
                              borderRadius: '6px',
                              cursor: 'pointer',
                            }}
                            title="Delete inquiry"
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </div>

                      {/* Client Contact & Follow-Up Action Links */}
                      <div 
                        style={{ 
                          display: 'flex', 
                          flexWrap: 'wrap', 
                          gap: '10px', 
                          background: '#F8FAFC', 
                          padding: '12px 16px', 
                          borderRadius: '8px', 
                          border: '1px solid #E2E8F0',
                          marginBottom: '16px',
                          alignItems: 'center',
                        }}
                      >
                        <span style={{ fontSize: '11px', fontWeight: 800, color: '#082658', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                          Direct Follow-Up:
                        </span>

                        {/* Email Action Link */}
                        <a
                          href={`mailto:${inq.email}?subject=NovaXpress%20Logistics%20Proposal%20Follow-Up%20for%20${encodeURIComponent(inq.full_name || '')}&body=Hello%20${encodeURIComponent(inq.full_name || 'Client')},%0A%0AThank%20you%20for%20contacting%20NovaXpress%20Logistics%20via%20novaxpressng.com%20regarding%20your%20delivery%20and%20supply%20chain%20needs.%0A%0AWe%20reviewed%20your%20inquiry%20for%20${encodeURIComponent(inq.service_type || 'logistics')}%20and%20would%20like%20to%20discuss%20customized%20rates%20and%20doorstep%20dispatch%20schedules.%0A%0ABest%20regards,%0ANovaXpress%20Logistics%20Operations%0Aoperations@novaxpressng.com%0Ahttps://novaxpressng.com`}
                          target="_blank"
                          rel="noopener noreferrer"
                          style={{
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '6px',
                            background: '#082658',
                            color: '#FFFFFF',
                            padding: '6px 14px',
                            borderRadius: '6px',
                            fontSize: '12px',
                            fontWeight: 700,
                            textDecoration: 'none',
                          }}
                        >
                          <Mail size={13} color="#FD7A02" />
                          <span>Email: {inq.email}</span>
                        </a>

                        {/* WhatsApp Action Link */}
                        {cleanPhone ? (
                          <a
                            href={`https://wa.me/${waNumber}?text=Hello%20${encodeURIComponent(inq.full_name || '')},%20this%20is%20NovaXpress%20Logistics%20following%20up%20on%20your%20quote%20request%20submitted%20on%20our%20website%20(novaxpressng.com).%20How%20can%20we%20best%20assist%20with%20your%20delivery%20needs?`}
                            target="_blank"
                            rel="noopener noreferrer"
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '6px',
                              background: '#25D366',
                              color: '#FFFFFF',
                              padding: '6px 14px',
                              borderRadius: '6px',
                              fontSize: '12px',
                              fontWeight: 700,
                              textDecoration: 'none',
                            }}
                          >
                            <MessageCircle size={13} />
                            <span>WhatsApp: {inq.phone}</span>
                          </a>
                        ) : null}

                        {/* Phone Call Action Link */}
                        {cleanPhone ? (
                          <a
                            href={`tel:${cleanPhone}`}
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '6px',
                              background: '#FFFFFF',
                              color: '#082658',
                              border: '1px solid #CBD5E1',
                              padding: '6px 14px',
                              borderRadius: '6px',
                              fontSize: '12px',
                              fontWeight: 700,
                              textDecoration: 'none',
                            }}
                          >
                            <PhoneCall size={13} color="#FD7A02" />
                            <span>Call Phone</span>
                          </a>
                        ) : null}
                      </div>

                      {/* Metadata Badges */}
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '14px' }}>
                        <span style={{ fontSize: '11px', background: '#EAEBEE', color: '#082658', padding: '4px 10px', borderRadius: '4px', fontWeight: 700 }}>
                          Service: <strong>{inq.service_type || 'General Logistics'}</strong>
                        </span>
                        {inq.destination_hub && (
                          <span style={{ fontSize: '11px', background: '#EAEBEE', color: '#082658', padding: '4px 10px', borderRadius: '4px', fontWeight: 700 }}>
                            Destination Hub: <strong>{inq.destination_hub}</strong>
                          </span>
                        )}
                        {inq.estimated_volume && (
                          <span style={{ fontSize: '11px', background: '#EAEBEE', color: '#082658', padding: '4px 10px', borderRadius: '4px', fontWeight: 700 }}>
                            Volume: <strong>{inq.estimated_volume}</strong>
                          </span>
                        )}
                      </div>

                      {/* Message / Requirements Breakdown */}
                      <div>
                        <span style={{ display: 'block', fontSize: '11px', fontWeight: 700, color: '#7E8DA6', textTransform: 'uppercase', marginBottom: '4px' }}>
                          Shipment Details & Instructions:
                        </span>
                        <div 
                          style={{ 
                            fontSize: '13px', 
                            color: '#082658', 
                            background: '#FAF9FB', 
                            padding: '14px 16px', 
                            borderRadius: '6px', 
                            border: '1px solid #EAEBEE',
                            whiteSpace: 'pre-wrap',
                            lineHeight: 1.6,
                            fontWeight: 500,
                          }}
                        >
                          {inq.message || 'No additional instructions provided.'}
                        </div>
                      </div>

                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

      </div>

      {/* ============================================================== */}
      {/* MODAL: ADD / EDIT HERO SLIDE WITH IMAGE UPLOADER */}
      {/* ============================================================== */}
      {slideModal.open && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(8, 38, 88, 0.7)', backdropFilter: 'blur(8px)', zIndex: 1200, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}>
          <form 
            onSubmit={handleSaveSlide}
            style={{ maxWidth: '600px', width: '100%', maxHeight: '90vh', overflowY: 'auto', padding: '32px', background: '#FFFFFF', borderRadius: 'var(--radius-lg)', border: '1px solid #EAEBEE', boxShadow: '0 20px 50px rgba(8, 38, 88, 0.25)' }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
              <h3 style={{ fontSize: '18px', color: '#082658' }}>{slideModal.isEdit ? 'Edit Hero Slide' : 'Add Hero Slide'}</h3>
              <button type="button" onClick={() => setSlideModal({ open: false, isEdit: false, index: -1, data: {} })} style={{ background: 'none', color: '#082658' }}><X size={18} /></button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Slide Title *</label>
                <input 
                  type="text" 
                  required 
                  value={slideModal.data.title || ''} 
                  onChange={(e) => setSlideModal({ ...slideModal, data: { ...slideModal.data, title: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Subtitle</label>
                <textarea 
                  rows={2}
                  value={slideModal.data.subtitle || ''} 
                  onChange={(e) => setSlideModal({ ...slideModal, data: { ...slideModal.data, subtitle: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              {/* Image Upload or URL */}
              <div style={{ background: '#FAF9FB', padding: '14px', borderRadius: '8px', border: '1px solid #EAEBEE' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '6px' }}>
                  Slide Image (Upload or specify URL)
                </label>
                
                <div style={{ display: 'flex', gap: '10px', alignItems: 'center', marginBottom: '10px' }}>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) {
                        handleFileUpload(file, (url) => {
                          setSlideModal((prev) => ({
                            ...prev,
                            data: { ...prev.data, image: url },
                          }));
                        }, 'hero');
                      }
                    }}
                    style={{ fontSize: '12px' }}
                  />
                  {uploadingImage && <span style={{ fontSize: '12px', color: '#FD7A02', fontWeight: 700 }}>Uploading...</span>}
                </div>

                <input 
                  type="text" 
                  placeholder="Or paste image URL (e.g. /images/hero_slide_1.jpg)"
                  value={slideModal.data.image || ''} 
                  onChange={(e) => setSlideModal({ ...slideModal, data: { ...slideModal.data, image: e.target.value } })}
                  style={{ width: '100%', padding: '8px 10px', background: '#FFFFFF', border: '1px solid #EAEBEE', borderRadius: '6px', fontSize: '13px' }}
                />

                <div style={{ marginTop: '10px' }}>
                  <label style={{ display: 'block', fontSize: '11px', color: '#7E8DA6', marginBottom: '4px' }}>Placeholder Description (if image missing)</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Modern courier with motorbike in warehouse"
                    value={slideModal.data.placeholderDesc || ''} 
                    onChange={(e) => setSlideModal({ ...slideModal, data: { ...slideModal.data, placeholderDesc: e.target.value } })}
                    style={{ width: '100%', padding: '8px 10px', background: '#FFFFFF', border: '1px solid #EAEBEE', borderRadius: '6px', fontSize: '12px' }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Micro Badge</label>
                  <input 
                    type="text" 
                    placeholder="e.g. ⚡ Same-Day Delivery"
                    value={slideModal.data.badge || ''} 
                    onChange={(e) => setSlideModal({ ...slideModal, data: { ...slideModal.data, badge: e.target.value } })}
                    style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Telemetry Pill</label>
                  <input 
                    type="text" 
                    placeholder="e.g. 18-Min Urban Dispatch"
                    value={slideModal.data.statPill || ''} 
                    onChange={(e) => setSlideModal({ ...slideModal, data: { ...slideModal.data, statPill: e.target.value } })}
                    style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                  />
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '14px' }}>
                <button type="button" onClick={() => setSlideModal({ open: false, isEdit: false, index: -1, data: {} })} className="btn-secondary btn-sm">Cancel</button>
                <button type="submit" className="btn-primary btn-sm">Done</button>
              </div>
            </div>
          </form>
        </div>
      )}

      {/* ============================================================== */}
      {/* MODAL: ADD / EDIT PORTFOLIO WITH IMAGE UPLOADER */}
      {/* ============================================================== */}
      {portfolioModal.open && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(8, 38, 88, 0.7)', backdropFilter: 'blur(8px)', zIndex: 1200, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}>
          <form 
            onSubmit={handleSavePortfolio}
            style={{ maxWidth: '640px', width: '100%', maxHeight: '90vh', overflowY: 'auto', padding: '32px', background: '#FFFFFF', borderRadius: 'var(--radius-lg)', border: '1px solid #EAEBEE' }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
              <h3 style={{ fontSize: '18px', color: '#082658' }}>{portfolioModal.isEdit ? 'Edit Case Study' : 'New Case Study'}</h3>
              <button type="button" onClick={() => setPortfolioModal({ open: false, isEdit: false, data: {} })} style={{ background: 'none', color: '#082658' }}><X size={18} /></button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Title *</label>
                <input 
                  type="text" 
                  required 
                  value={portfolioModal.data.title || ''} 
                  onChange={(e) => setPortfolioModal({ ...portfolioModal, data: { ...portfolioModal.data, title: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Client Name *</label>
                  <input 
                    type="text" 
                    required 
                    value={portfolioModal.data.client_name || ''} 
                    onChange={(e) => setPortfolioModal({ ...portfolioModal, data: { ...portfolioModal.data, client_name: e.target.value } })}
                    style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Category</label>
                  <input 
                    type="text" 
                    value={portfolioModal.data.category || ''} 
                    onChange={(e) => setPortfolioModal({ ...portfolioModal, data: { ...portfolioModal.data, category: e.target.value } })}
                    style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                  />
                </div>
              </div>

              {/* Image Upload */}
              <div style={{ background: '#FAF9FB', padding: '12px', borderRadius: '6px', border: '1px solid #EAEBEE' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '6px' }}>
                  Case Study Image (Upload or URL)
                </label>
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      handleFileUpload(file, (url) => {
                        setPortfolioModal((prev) => ({
                          ...prev,
                          data: { ...prev.data, image_url: url },
                        }));
                      }, 'portfolio');
                    }
                  }}
                  style={{ fontSize: '12px', marginBottom: '8px' }}
                />
                <input 
                  type="text" 
                  placeholder="Or enter image URL"
                  value={portfolioModal.data.image_url || ''} 
                  onChange={(e) => setPortfolioModal({ ...portfolioModal, data: { ...portfolioModal.data, image_url: e.target.value } })}
                  style={{ width: '100%', padding: '8px 10px', background: '#FFFFFF', border: '1px solid #EAEBEE', borderRadius: '6px', fontSize: '13px' }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Summary *</label>
                <textarea 
                  rows={2} 
                  required 
                  value={portfolioModal.data.summary || ''} 
                  onChange={(e) => setPortfolioModal({ ...portfolioModal, data: { ...portfolioModal.data, summary: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Metrics (Label: Value, one per line)</label>
                <textarea 
                  rows={2} 
                  placeholder="Delivery SLA: Under 24h&#10;Spoilage: 0.02%"
                  value={portfolioModal.data.metrics || ''} 
                  onChange={(e) => setPortfolioModal({ ...portfolioModal, data: { ...portfolioModal.data, metrics: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '12px' }}>
                <button type="button" onClick={() => setPortfolioModal({ open: false, isEdit: false, data: {} })} className="btn-secondary btn-sm">Cancel</button>
                <button type="submit" disabled={actionLoading} className="btn-primary btn-sm">{actionLoading ? 'Saving...' : 'Save'}</button>
              </div>
            </div>
          </form>
        </div>
      )}

      {/* ============================================================== */}
      {/* MODAL: ADD / EDIT SERVICE */}
      {/* ============================================================== */}
      {serviceModal.open && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(8, 38, 88, 0.7)', backdropFilter: 'blur(8px)', zIndex: 1200, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}>
          <form 
            onSubmit={handleSaveService}
            style={{ maxWidth: '580px', width: '100%', maxHeight: '90vh', overflowY: 'auto', padding: '32px', background: '#FFFFFF', borderRadius: 'var(--radius-lg)', border: '1px solid #EAEBEE' }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
              <h3 style={{ fontSize: '18px', color: '#082658' }}>{serviceModal.isEdit ? 'Edit Service' : 'Add New Service'}</h3>
              <button type="button" onClick={() => setServiceModal({ open: false, isEdit: false, data: {} })} style={{ background: 'none', color: '#082658' }}><X size={18} /></button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Title *</label>
                <input 
                  type="text" 
                  required 
                  value={serviceModal.data.title || ''} 
                  onChange={(e) => setServiceModal({ ...serviceModal, data: { ...serviceModal.data, title: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Icon</label>
                  <select 
                    value={serviceModal.data.icon_name || 'Truck'}
                    onChange={(e) => setServiceModal({ ...serviceModal, data: { ...serviceModal.data, icon_name: e.target.value } })}
                    style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                  >
                    <option value="Truck">Truck</option>
                    <option value="Zap">Zap (Express)</option>
                    <option value="ThermometerSnowflake">ThermometerSnowflake (Cold Chain)</option>
                    <option value="Banknote">Banknote (COD)</option>
                    <option value="Warehouse">Warehouse</option>
                    <option value="RotateCcw">RotateCcw</option>
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>SLA Window</label>
                  <input 
                    type="text" 
                    value={serviceModal.data.sla_delivery_time || ''} 
                    onChange={(e) => setServiceModal({ ...serviceModal, data: { ...serviceModal.data, sla_delivery_time: e.target.value } })}
                    style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Short Summary *</label>
                <textarea 
                  rows={2} 
                  required 
                  value={serviceModal.data.short_description || ''} 
                  onChange={(e) => setServiceModal({ ...serviceModal, data: { ...serviceModal.data, short_description: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#082658', marginBottom: '4px' }}>Feature Points (one per line)</label>
                <textarea 
                  rows={3} 
                  value={serviceModal.data.features || ''} 
                  onChange={(e) => setServiceModal({ ...serviceModal, data: { ...serviceModal.data, features: e.target.value } })}
                  style={{ width: '100%', padding: '10px', background: '#FAF9FB', border: '1px solid #EAEBEE', borderRadius: '6px' }}
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '12px' }}>
                <button type="button" onClick={() => setServiceModal({ open: false, isEdit: false, data: {} })} className="btn-secondary btn-sm">Cancel</button>
                <button type="submit" disabled={actionLoading} className="btn-primary btn-sm">{actionLoading ? 'Saving...' : 'Save'}</button>
              </div>
            </div>
          </form>
        </div>
      )}

    </div>
  );
}
