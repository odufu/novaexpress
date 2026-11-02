import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://oygtaeriljuelhshfvkv.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95Z3RhZXJpbGp1ZWxoc2hmdmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3MDAsImV4cCI6MjA5OTQ0NDcwMH0.o32kkHf1QSUs2xy4_5RrTFGw7_T-3iI8YGDml72oGxc';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

// Helper to normalize user role to an official certification pathway
export function mapRoleToCourseKey(role) {
  if (!role) return 'closer';
  const clean = role.toLowerCase().trim();
  if (clean === 'super_admin' || clean.includes('admin')) return 'super_admin';
  if (clean === 'accountant' || clean === 'general_accountant' || clean.includes('finance_director')) return 'accountant';
  if (clean === 'dc_finance_admin' || clean === 'dc_finance' || clean.includes('remittance')) return 'dc_finance_admin';
  if (clean === 'dc_stock_admin' || clean === 'dc_stock' || clean.includes('inventory')) return 'dc_stock_admin';
  if (clean === 'dc_operations' || clean === 'operations_officer' || clean.includes('dispatcher')) return 'dc_operations';
  if (clean === 'rider' || clean === 'delivery_agent' || clean.includes('courier')) return 'rider';
  if (clean === 'closer' || clean === 'sales_rep' || clean === 'sales_supervisor') return 'closer';
  if (clean === 'dc_manager' || clean === 'dc_supervisor') return 'dc_manager';
  return 'closer';
}

// Generate unique verifiable certificate code
export function generateCertificateCode() {
  const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  let randomPart = '';
  for (let i = 0; i < 5; i++) {
    randomPart += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  const year = new Date().getFullYear();
  return `NX-CERT-${year}-${randomPart}`;
}

