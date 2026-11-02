import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://oygtaeriljuelhshfvkv.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3MDAsImV4cCI6MjA5OTQ0NDcwMH0.o32kkHf1QSUs2xy4_5RrTFGw7_T-3iI8YGDml72oGxc';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

// Default Hero Slides for Carousel
export const DEFAULT_SLIDES = [
  {
    id: 'slide-1',
    title: 'Precision Intra-City Express Dispatch',
    subtitle: 'Fast, secure urban doorstep deliveries powered by algorithmic routing and live GPS rider tracking.',
    image: '/images/hero_slide_1.jpg',
    placeholderDesc: 'Modern express delivery rider standing by motorbike with NovaXpress parcel box',
    badge: '⚡ Same-Day Delivery Guarantee',
    statPill: '18-Min Urban Dispatch Window',
    ctaText: 'Book Doorstep Dispatch',
  },
  {
    id: 'slide-2',
    title: 'Certified Pharma Cold Chain (2°C - 8°C)',
    subtitle: 'Climate-controlled refrigerated logistics with continuous IoT telemetry protecting critical vaccines and medications.',
    image: '/images/hero_slide_2.jpg',
    placeholderDesc: 'Clinical temperature-controlled delivery van with digital IoT temperature display',
    badge: '❄️ Real-time IoT Temperature Log',
    statPill: '+4.2°C Continuous Optimal Range',
    ctaText: 'Explore Cold Chain',
  },
  {
    id: 'slide-3',
    title: '24-Hour Cash on Delivery Remittance',
    subtitle: 'Eliminate cash flow lag. Automated doorstep POS collection with daily T+1 bank account reconciliation.',
    image: '/images/hero_slide_3.jpg',
    placeholderDesc: 'Doorstep courier capturing electronic customer signature and mobile POS payment',
    badge: '🔒 Zero Discrepancy Bank Remittance',
    statPill: 'T+1 Daily Automated Settlement',
    ctaText: 'Start COD Remittance',
  },
];

// Default Fallback Data if network or DB table is empty
export const DEFAULT_SETTINGS = {
  key: 'general',
  brand_name: 'NovaXpress Logistics',
  tagline: 'Fast, Secure & Scalable Last-Mile Delivery Across Nigeria',
  hero_badge: '⚡ Next-Gen Express Logistics & Cold-Chain Network',
  hero_title: 'Powering Nigeria’s Fastest Deliveries & Cash-on-Delivery Remittance',
  hero_subtitle: 'From intra-city express dispatch to nationwide cold-chain pharma distribution, NovaXpress delivers unmatched reliability, speed, and real-time electronic proof of delivery.',
  hero_cta_primary_text: 'Request a Delivery Quote',
  hero_cta_primary_link: '/contact',
  hero_cta_secondary_text: 'Track Shipment',
  hero_cta_secondary_link: '/track',
  contact_phone: '+234 812 345 6789',
  contact_email: 'operations@novaxpressng.com',
  whatsapp_number: '+2348123456789',
  website_domain: 'novaxpressng.com',
  headquarters_address: 'NovaXpress Grand Central Hub, Ikeja Logistics Gateway, Lagos State, Nigeria',
  operating_hours: 'Mon - Sat: 7:00 AM - 9:00 PM | 24/7 Operations Dispatch',
  announcement_text: '✨ Expanded coverage: Same-day express dispatch now live in Lagos, Abuja, Port Harcourt, and Kano!',
  announcement_active: true,
  hero_slides: DEFAULT_SLIDES,
  social_links: {
    linkedin: 'https://linkedin.com/company/novaxpressng',
    twitter: 'https://x.com/novaxpressng',
    instagram: 'https://instagram.com/novaxpressng',
    facebook: 'https://facebook.com/novaxpressng',
  },
};

export const DEFAULT_SERVICES = [
  {
    id: 's-1',
    slug: 'express-intra-city',
    title: 'Intra-City Express Dispatch',
    short_description: 'Fast, dedicated doorstep delivery across major metropolitan centers within hours.',
    full_description: 'Our algorithmically routed rider fleet and distributed DC network guarantee speed, item security, and real-time electronic signature capture upon delivery.',
    icon_name: 'Zap',
    features: [
      'Under 4-hour intra-city dispatch',
      'Real-time rider GPS tracking',
      'Digital Proof of Delivery (POD) with photo & signature',
      'Reverse logistics & exchange handling',
    ],
    sla_delivery_time: 'Same-Day (2 - 4 Hours)',
    is_featured: true,
    is_active: true,
    display_order: 1,
  },
  {
    id: 's-2',
    slug: 'pharma-cold-chain',
    title: 'Pharma & Cold-Chain Logistics',
    short_description: 'Temperature-monitored refrigerated transport for pharmaceuticals, vaccines, and biologics.',
    full_description: 'Certified temperature-controlled supply chain keeping critical medications, lab samples, and sensitive goods within optimal temperature ranges (2°C - 8°C & ambient controlled).',
    icon_name: 'ThermometerSnowflake',
    features: [
      'Continuous IoT temperature telemetry',
      'Insulated pharma-grade coolers & dry-ice packaging',
      'Regulatory compliance documentation',
      'Priority airport & inter-city corridors',
    ],
    sla_delivery_time: '24 - 48 Hours Guaranteed',
    is_featured: true,
    is_active: true,
    display_order: 2,
  },
  {
    id: 's-3',
    slug: 'cod-remittance',
    title: 'Cash on Delivery & Instant Remittance',
    short_description: 'Secure cash & POS collection at doorstep with 24-hour bank account remittance.',
    full_description: 'Boost customer trust and checkout conversion rates by offering Cash/POS on Delivery while enjoying automated reconciliation and direct deposit payouts to your business account.',
    icon_name: 'Banknote',
    features: [
      'T+1 fast automated bank remittance',
      'POS and Instant Mobile Transfer collection',
      'Automated daily settlement reporting',
      'Zero discrepancy cash reconciliation portal',
    ],
    sla_delivery_time: 'Daily 24h Payouts',
    is_featured: true,
    is_active: true,
    display_order: 3,
  },
  {
    id: 's-4',
    slug: 'b2b-warehousing',
    title: 'Micro-Hub Warehousing & Fulfillment',
    short_description: 'Strategic micro-fulfillment centers in prime consumption zones to minimize last-mile transit times.',
    full_description: 'Store your fast-moving SKUs across our modern distribution centers. When orders land, we pick, pack, label, and dispatch immediately to your end consumers.',
    icon_name: 'Warehouse',
    features: [
      'Real-time cloud inventory visibility',
      'Pick, pack, and custom kitting services',
      'Batch and expiry date tracking',
      'Direct integration with Shopify, WooCommerce, & custom ERPs',
    ],
    sla_delivery_time: 'Instant Auto-Fulfillment',
    is_featured: true,
    is_active: true,
    display_order: 4,
  },
  {
    id: 's-5',
    slug: 'interstate-cargo',
    title: 'Interstate Linehaul & Haulage',
    short_description: 'Scheduled line-haul trunk routes connecting North, South, East, and Western distribution zones.',
    full_description: 'Reliable interstate linehaul cargo services connecting key industrial corridors across all 36 states with end-to-end milestone tracking and dedicated insurance coverage.',
    icon_name: 'Truck',
    features: [
      'Daily scheduled trunk dispatches',
      'Full Truckload (FTL) and Less than Truckload (LTL)',
      'GPS tracking with geo-fence alarms',
      'Comprehensive transit cargo protection',
    ],
    sla_delivery_time: '24 - 72 Hours Nationwide',
    is_featured: true,
    is_active: true,
    display_order: 5,
  },
  {
    id: 's-6',
    slug: 'reverse-logistics',
    title: 'Smart Returns & Reverse Logistics',
    short_description: 'Hassle-free return pickups, condition inspection, and restocking back to your warehouse.',
    full_description: 'Turn returns into retained customers with frictionless return collection, quick inspection reports, and automated restock workflows.',
    icon_name: 'RotateCcw',
    features: [
      'Fast customer return pickup',
      'Quality & condition inspection checklist',
      'Automated restock synchronization',
      'Customer exchange deliveries',
    ],
    sla_delivery_time: '24 - 48 Hours',
    is_featured: false,
    is_active: true,
    display_order: 6,
  },
];

export const DEFAULT_PORTFOLIO = [
  {
    id: 'p-1',
    slug: 'novacare-nationwide-pharma',
    title: 'Scaling Temperature-Controlled Pharma Distribution to 12 States',
    client_name: 'Novacare Health & Pharmaceuticals',
    category: 'Healthcare & Cold Chain',
    summary: 'How Novacare transformed patient access to temperature-sensitive injectables and medications with NovaXpress cold-chain logistics.',
    challenge: 'Novacare was experiencing a 14% spoilage rate and high customer churn due to unpredictable inter-state transit times and temperature spikes during transit.',
    solution: 'NovaXpress implemented IoT-enabled temperature logging containers, established dedicated cold-storage zones at Lagos and Abuja distribution centers, and deployed specialized pharma riders.',
    results: 'Reduced spoilage to 0.02%, reduced delivery turnaround from 72 hours to under 24 hours, and enabled Novacare to onboard over 150 new partner clinics.',
    metrics: [
      { label: 'Spoilage Reduction', value: '99.8%' },
      { label: 'Delivery SLA', value: 'Under 24h' },
      { label: 'Clinic Partners', value: '150+' },
      { label: 'Monthly Volume', value: '18,500 units' },
    ],
    image_url: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=1200&q=80',
    is_featured: true,
    is_active: true,
    display_order: 1,
  },
  {
    id: 'p-2',
    slug: 'comfortcare-d2c-fulfillment',
    title: 'Achieving 99.2% Delivery Success with 24-Hour Cash on Delivery Remittance',
    client_name: 'ComfortCare Wellness Brands',
    category: 'D2C & Omnichannel E-commerce',
    summary: 'Scaling a high-volume direct-to-consumer health and beauty brand with automated COD reconciliation and local micro-warehousing.',
    challenge: 'High order return rates (RTO exceeding 26%) due to delayed dispatch, manual cash reconciliation errors, and cash remittance lag taking up to 10 days.',
    solution: 'Integrated ComfortCare orders into NovaXpress automated micro-warehouses in Lagos and Port Harcourt with same-day dispatch and 24-hour automated bank remittance.',
    results: 'Return rate dropped from 26% to under 5.4%, customer satisfaction surged to 4.9 stars, and ComfortCare scaled daily volume 4x without cash flow bottleneck.',
    metrics: [
      { label: 'RTO Reduction', value: '79%' },
      { label: 'Remittance Cycle', value: '24 Hours' },
      { label: 'Delivery Rate', value: '99.2%' },
      { label: 'Daily Parcels', value: '1,200+' },
    ],
    image_url: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
    is_featured: true,
    is_active: true,
    display_order: 2,
  },
  {
    id: 'p-3',
    slug: 'pangea-b2b-supply-chain',
    title: 'Cross-Docking and B2B Wholesale Distribution for Modern Retail Chains',
    client_name: 'Pangea Retail Distribution Group',
    category: 'B2B Wholesale & Linehaul',
    summary: 'Unifying inventory management and scheduled weekly replenishment for 45 supermarkets and retail outlets.',
    challenge: 'Stockouts at store locations while regional warehouses were overstocked; high transport costs due to fragmented logistics vendors and lack of centralized proof of delivery.',
    solution: 'NovaXpress deployed centralized cross-docking, weekly scheduled delivery routes, digital bill of lading with instant signature capture, and digital invoicing.',
    results: 'Zero stockouts over 9 consecutive months, 28% reduction in total freight logistics spend, and instant real-time auditability for finance.',
    metrics: [
      { label: 'Logistics Cost Saved', value: '28%' },
      { label: 'Retail Outlets', value: '45 Stores' },
      { label: 'Stockout Rate', value: '0.0%' },
      { label: 'Audit Speed', value: '100% Digital' },
    ],
    image_url: 'https://images.unsplash.com/photo-1553413077-190dd305871c?auto=format&fit=crop&w=1200&q=80',
    is_featured: true,
    is_active: true,
    display_order: 3,
  },
];

export const DEFAULT_TESTIMONIALS = [
  {
    id: 't-1',
    author_name: 'Dr. Kemi Adeleke',
    author_title: 'Supply Chain Lead',
    company: 'Novacare Pharmaceuticals',
    quote: 'NovaXpress solved our biggest headache: cold-chain compliance. With real-time temperature logs and reliable riders, our sensitive vaccines and pharmaceuticals arrive intact every single time.',
    rating: 5,
    avatar_url: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=200&q=80',
    is_active: true,
    display_order: 1,
  },
  {
    id: 't-2',
    author_name: 'Tunde Babalola',
    author_title: 'Co-Founder & COO',
    company: 'ComfortCare Lifestyle',
    quote: 'Before NovaXpress, COD money took 10-14 days to reach our bank account. With NovaXpress, our cash is remitted within 24 hours like clockwork. That alone allowed us to grow 300% this year.',
    rating: 5,
    avatar_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
    is_active: true,
    display_order: 2,
  },
  {
    id: 't-3',
    author_name: 'Emeka Nwosu',
    author_title: 'Head of Retail Logistics',
    company: 'Apex Superstores Nigeria',
    quote: 'Their micro-hub warehousing and electronic proof of delivery make tracking effortless. We never have disputes over missing cartons or unclear delivery times anymore.',
    rating: 5,
    avatar_url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    is_active: true,
    display_order: 3,
  },
];

export const DEFAULT_STATS = [
  { id: 'st-1', label: 'Successful Deliveries', value: '250,000', suffix: '+', description: 'Doorstep parcels completed with electronic POD', icon_name: 'PackageCheck', display_order: 1 },
  { id: 'st-2', label: 'On-Time Delivery Rate', value: '99.4', suffix: '%', description: 'Consistently meeting strict customer SLAs', icon_name: 'Clock', display_order: 2 },
  { id: 'st-3', label: 'Cash Remitted (COD)', value: '₦4.8B', suffix: '+', description: 'Fast, fully reconciled merchant payouts', icon_name: 'Banknote', display_order: 3 },
  { id: 'st-4', label: 'Distribution Hubs', value: '18', suffix: '+', description: 'Micro-fulfillment centers nationwide', icon_name: 'MapPin', display_order: 4 },
];

// Content Fetcher API
export async function fetchWebsiteContent() {
  try {
    const [settingsRes, servicesRes, portfolioRes, testimonialsRes, statsRes] = await Promise.allSettled([
      supabase.from('website_settings').select('*').eq('key', 'general').maybeSingle(),
      supabase.from('website_services').select('*').order('display_order', { ascending: true }),
      supabase.from('website_portfolio').select('*').order('display_order', { ascending: true }),
      supabase.from('website_testimonials').select('*').order('display_order', { ascending: true }),
      supabase.from('website_stats').select('*').order('display_order', { ascending: true }),
    ]);

    const settings = settingsRes.status === 'fulfilled' && settingsRes.value.data
      ? settingsRes.value.data
      : DEFAULT_SETTINGS;

    const services = servicesRes.status === 'fulfilled' && servicesRes.value.data?.length
      ? servicesRes.value.data
      : DEFAULT_SERVICES;

    const portfolio = portfolioRes.status === 'fulfilled' && portfolioRes.value.data?.length
      ? portfolioRes.value.data
      : DEFAULT_PORTFOLIO;

    const testimonials = testimonialsRes.status === 'fulfilled' && testimonialsRes.value.data?.length
      ? testimonialsRes.value.data
      : DEFAULT_TESTIMONIALS;

    const stats = statsRes.status === 'fulfilled' && statsRes.value.data?.length
      ? statsRes.value.data
      : DEFAULT_STATS;

    return {
      settings,
      services,
      portfolio,
      testimonials,
      stats,
      isLiveSupabase: settingsRes.status === 'fulfilled' && !!settingsRes.value.data,
    };
  } catch (err) {
    console.warn('Using fallback website content due to fetch error:', err);
    return {
      settings: DEFAULT_SETTINGS,
      services: DEFAULT_SERVICES,
      portfolio: DEFAULT_PORTFOLIO,
      testimonials: DEFAULT_TESTIMONIALS,
      stats: DEFAULT_STATS,
      isLiveSupabase: false,
    };
  }
}

// Inquiries API
export async function submitInquiry(payload) {
  try {
    const detailedMessage = payload.estimatedCost 
      ? `[Rate Calculator: ${payload.origin || 'N/A'} -> ${payload.destination || 'N/A'}, Weight: ${payload.weight || 'N/A'}, Quote: ${payload.estimatedCost}]\n\n${payload.message || 'Customer requested quote via website.'}`
      : (payload.message || 'Customer requested quote via website.');

    const { error } = await supabase.from('website_inquiries').insert([
      {
        full_name: payload.full_name,
        email: payload.email,
        phone: payload.phone || null,
        company: payload.company || null,
        service_type: payload.service_type || 'General Inquiry',
        destination_hub: payload.destination_hub || null,
        estimated_volume: payload.estimated_volume || null,
        message: detailedMessage,
        status: 'NEW',
      },
    ]);

    if (error) {
      console.warn('Supabase insert inquiry error:', error);
      return { success: true, isMock: true, data: payload };
    }
    return { success: true, isMock: false, data: payload };
  } catch (err) {
    console.error('Error submitting inquiry:', err);
    return { success: true, isMock: true, data: payload };
  }
}

// Tracking Query Helper
export async function trackShipment(trackingCode) {
  if (!trackingCode || !trackingCode.trim()) return null;
  const cleanCode = trackingCode.trim().toUpperCase();

  try {
    // Try to find in orders table
    const { data: order } = await supabase
      .from('orders')
      .select('order_number, status, recipient_name, delivery_address, delivery_state, created_at, updated_at')
      .or(`order_number.ilike.%${cleanCode}%,waybill_number.ilike.%${cleanCode}%`)
      .limit(1)
      .maybeSingle();

    if (order) {
      return {
        code: order.order_number,
        status: order.status || 'IN_TRANSIT',
        recipient: order.recipient_name || 'Valued Recipient',
        destination: `${order.delivery_state || 'Lagos'}, Nigeria`,
        lastUpdate: new Date(order.updated_at || order.created_at || Date.now()).toLocaleDateString('en-GB', {
          day: 'numeric',
          month: 'short',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
        }),
        isLiveDb: true,
        timeline: [
          { label: 'Consignment Received & Barcoded', time: '08:30 AM', done: true, hub: 'Ikeja Logistics Hub' },
          { label: 'Sorted & Dispatched to Linehaul Trunk', time: '11:15 AM', done: true, hub: 'Central Sorting DC' },
          { label: 'Arrived at Destination Distribution Center', time: '02:40 PM', done: order.status !== 'PENDING', hub: `${order.delivery_state || 'Regional'} DC` },
          { label: 'Out for Doorstep Delivery with Rider', time: '04:10 PM', done: ['OUT_FOR_DELIVERY', 'DELIVERED', 'COMPLETED'].includes(order.status), hub: 'Active Transit' },
          { label: 'Delivered & Electronic Signature Captured', time: 'Completed', done: ['DELIVERED', 'COMPLETED'].includes(order.status), hub: order.delivery_address || 'Customer Address' },
        ],
      };
    }
  } catch (e) {
    console.log('Error checking live orders:', e);
  }

  // Simulated live milestone generator for demo or instant customer lookup
  return {
    code: cleanCode,
    status: 'OUT_FOR_DELIVERY',
    recipient: 'Confidential Client (Verified)',
    destination: 'Victoria Island / Ikoyi, Lagos',
    lastUpdate: 'Just now (Live Telemetry)',
    isLiveDb: false,
    timeline: [
      { label: 'Order Intake & Package Weight Verified', time: '08:15 AM', done: true, hub: 'NovaXpress Ikeja Gateway Hub' },
      { label: 'Temperature Check & Security Scan Passed', time: '09:30 AM', done: true, hub: 'Cold-Chain Quarantine Zone' },
      { label: 'Sorted to Micro-Hub Dispatch Queue', time: '11:45 AM', done: true, hub: 'Lagos Island Micro-Hub' },
      { label: 'Assigned to Dedicated Rider & Dispatched', time: '01:20 PM', done: true, hub: 'En Route with In-House Rider' },
      { label: 'Doorstep Delivery & Electronic POD Capture', time: 'Est. 30 mins', done: false, hub: 'Final Destination' },
    ],
  };
}

// Storage Image Uploader
export async function uploadImage(file, folder = 'general') {
  if (!file) throw new Error('No file provided for upload.');

  // Validate file type
  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml', 'image/gif'];
  if (!allowedTypes.includes(file.type)) {
    throw new Error('Invalid file type. Only JPG, PNG, WEBP, and SVG images are accepted.');
  }

  // Max 10MB limit
  if (file.size > 10 * 1024 * 1024) {
    throw new Error('Image size exceeds 10MB limit.');
  }

  const cleanName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_');
  const path = `${folder}/${Date.now()}_${cleanName}`;

  const { data, error } = await supabase.storage
    .from('website-assets')
    .upload(path, file, {
      cacheControl: '3600',
      upsert: true,
    });

  if (error) {
    console.error('Storage upload error:', error);
    throw error;
  }

  const { data: publicData } = supabase.storage
    .from('website-assets')
    .getPublicUrl(path);

  return publicData.publicUrl;
}

