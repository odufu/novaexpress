import React, { useState } from 'react';
import { Award, Lock, Mail, ArrowRight, ShieldCheck, Sparkles, CheckCircle2, ChevronRight, UserCheck } from 'lucide-react';
import { supabase } from '../lib/supabase';

export default function AuthPage({ onLoginSuccess, onNavigateVerify }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState(null);

  const handleLogin = async (e) => {
    if (e) e.preventDefault();
    if (!email.trim() || !password) return;

    setLoading(true);
    setErrorMsg(null);

    try {
      const cleanEmail = email.trim().toLowerCase();
      
      const { data, error } = await supabase.auth.signInWithPassword({
        email: cleanEmail,
        password: password,
      });

      if (error) {
        // Fallback for demo or hardcoded credentials
        if (password === '@EmeraldXpress2026' || password === 'Password123!' || password === 'Closer123!' || password === cleanEmail) {
          let role = 'closer';
          if (cleanEmail === 'emeraldcodelines@gmail.com') role = 'super_admin';
          else if (cleanEmail.includes('finance')) role = 'dc_finance_admin';
          else if (cleanEmail.includes('stock')) role = 'dc_stock_admin';
          else if (cleanEmail.includes('account')) role = 'accountant';
          else if (cleanEmail.includes('supervisor') || cleanEmail.includes('mgr')) role = 'dc_manager';
          else if (cleanEmail.includes('rider') || cleanEmail.includes('courier')) role = 'rider';

          onLoginSuccess({
            id: 'demo-user-id',
            email: cleanEmail,
            role: role,
            name: cleanEmail.split('@')[0].toUpperCase(),
          });
          return;
        }
        throw error;
      }

      if (data?.user) {
        const { data: profile } = await supabase
          .from('users')
          .select('*')
          .eq('id', data.user.id)
          .maybeSingle();

        const role = profile?.role || (cleanEmail === 'emeraldcodelines@gmail.com' ? 'super_admin' : 'closer');
        const name = profile ? `${profile.first_name || ''} ${profile.last_name || ''}`.trim() : cleanEmail.split('@')[0];

        onLoginSuccess({
          id: data.user.id,
          email: cleanEmail,
          role: role,
          name: name || 'Trainee',
        });
      }
    } catch (err) {
      console.error('Login error:', err);
      setErrorMsg(err.message || 'Invalid email or password. Please verify your credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickDemoLogin = (demoEmail, demoPw) => {
    setEmail(demoEmail);
    setPassword(demoPw);
  };

  const personas = [
    { label: 'Super Admin', email: 'emeraldcodelines@gmail.com', pw: '@EmeraldXpress2026', icon: '👑', badge: 'Admin Console' },
    { label: 'Sales Closer', email: 'prestige.godwin@novaxpress.net', pw: 'Closer123!', icon: '🎧', badge: 'Certified Sales' },
    { label: 'DC Finance', email: 'joelfinance@gmail.com', pw: 'joelfinance@gmail.com', icon: '💰', badge: 'Finance Ops' },
    { label: 'Field Courier', email: 'oladele.omowaye@novaxpress.ng', pw: 'omowaye123456', icon: '🛵', badge: 'Mobile Ops' },
  ];

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex flex-col justify-center items-center px-4 py-12 relative">
      
      {/* Background Subtle Accent Gradients */}
      <div className="absolute top-0 inset-x-0 h-80 bg-gradient-to-b from-[#082658]/5 to-transparent pointer-events-none" />

      {/* Main Container */}
      <div className="w-full max-w-lg relative z-10 space-y-6">
        
        {/* Brand Banner */}
        <div className="text-center space-y-3">
          <div className="inline-flex p-3 rounded-2xl bg-gradient-to-tr from-[#FD7A02] to-[#E06900] shadow-xl shadow-orange-500/25 mb-1">
            <Award className="w-10 h-10 text-white" />
          </div>
          <div className="flex items-center justify-center gap-2">
            <h1 className="text-2xl font-extrabold text-[#082658] tracking-tight">NovaXpress</h1>
            <span className="text-xs font-extrabold uppercase tracking-widest px-2.5 py-0.5 rounded-full bg-orange-50 text-[#FD7A02] border border-orange-200">
              Academy
            </span>
          </div>
          <p className="text-xs sm:text-sm text-slate-600 max-w-sm mx-auto font-medium">
            Professional role-based training, video curriculum, knowledge examinations, and accredited certifications.
          </p>
        </div>

        {/* Login Card */}
        <div className="rounded-3xl bg-white border border-slate-200/80 p-6 sm:p-8 shadow-xl space-y-6">
          <div className="border-b border-slate-100 pb-4">
            <h2 className="text-base font-extrabold text-[#082658]">Sign In to Your Learning Portal</h2>
            <p className="text-xs text-slate-500 mt-0.5">Enter your NovaXpress staff or operator credentials</p>
          </div>

          {errorMsg && (
            <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 text-xs font-semibold text-red-700">
              {errorMsg}
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="text-xs font-bold text-slate-700 block mb-1.5">Staff Email Address</label>
              <div className="relative">
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@novaxpressng.com"
                  required
                  className="w-full px-4 py-2.5 pl-10 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 placeholder:text-slate-400 focus:bg-white focus:border-[#FD7A02] focus:ring-2 focus:ring-orange-500/20 outline-none transition"
                />
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-3 pointer-events-none" />
              </div>
            </div>

            <div>
              <label className="text-xs font-bold text-slate-700 block mb-1.5">Access Password</label>
              <div className="relative">
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  required
                  className="w-full px-4 py-2.5 pl-10 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 placeholder:text-slate-400 focus:bg-white focus:border-[#FD7A02] focus:ring-2 focus:ring-orange-500/20 outline-none transition"
                />
                <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-3 pointer-events-none" />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 px-4 rounded-xl bg-[#FD7A02] hover:bg-[#E06900] text-white font-extrabold text-xs transition shadow-md shadow-orange-500/20 flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <span>Access Training Classroom</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {/* Quick Demo Personas */}
          <div className="pt-4 border-t border-slate-100 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                Quick Role Autofill:
              </span>
              <span className="text-[10px] text-slate-400 font-semibold">One-Click Testing</span>
            </div>

            <div className="grid grid-cols-2 gap-2">
              {personas.map((p, idx) => (
                <button
                  key={idx}
                  type="button"
                  onClick={() => handleQuickDemoLogin(p.email, p.pw)}
                  className="p-2.5 rounded-xl bg-slate-50 hover:bg-orange-50/80 border border-slate-200 hover:border-orange-300 transition text-left cursor-pointer group"
                >
                  <div className="flex items-center gap-2">
                    <span className="text-sm">{p.icon}</span>
                    <div className="min-w-0 flex-1">
                      <p className="text-xs font-bold text-[#082658] group-hover:text-[#FD7A02] truncate">
                        {p.label}
                      </p>
                      <p className="text-[10px] text-slate-500 font-medium truncate">
                        {p.badge}
                      </p>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

        </div>

        {/* Public Verification Footer */}
        <div className="text-center">
          <button
            onClick={onNavigateVerify}
            className="inline-flex items-center gap-2 text-xs font-bold text-slate-600 hover:text-[#FD7A02] transition cursor-pointer"
          >
            <ShieldCheck className="w-4 h-4 text-emerald-600" />
            <span>Have a Certificate ID? Check Public Authenticity</span>
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>

      </div>
    </div>
  );
}
