import React, { useState } from 'react';
import { Award, LogOut, BookOpen, ShieldCheck, CheckCircle2, Menu, X, ExternalLink, Sparkles, ChevronDown, User } from 'lucide-react';

export default function Navbar({ user, role, activeCourse, onSelectCourse, allCourses, onViewCert, onLogout, onNavigate, currentPage }) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const isSuperAdmin = role === 'super_admin' || user?.email === 'emeraldcodelines@gmail.com';

  return (
    <header className="sticky top-0 z-50 bg-white/90 backdrop-blur-md border-b border-slate-200/80 shadow-xs">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          
          {/* Brand Logo */}
          <div 
            className="flex items-center gap-3 cursor-pointer group" 
            onClick={() => onNavigate('classroom')}
          >
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-[#FD7A02] to-[#E06900] flex items-center justify-center shadow-md shadow-orange-500/20 group-hover:scale-105 transition-transform">
              <Award className="w-5 h-5 text-white" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="font-extrabold text-base tracking-tight text-[#082658]">NovaXpress</span>
                <span className="text-[10px] font-extrabold uppercase tracking-widest px-2 py-0.5 rounded-full bg-orange-500/10 text-[#FD7A02] border border-orange-500/20">
                  Academy
                </span>
              </div>
              <p className="text-[11px] text-slate-500 font-medium hidden sm:block">Role Certification & E-Learning</p>
            </div>
          </div>

          {/* Desktop Navigation Links */}
          <div className="hidden lg:flex items-center gap-3">
            
            {/* Active Pathway Dropdown Selector */}
            {allCourses && allCourses.length > 0 && (
              <div className="relative">
                <select
                  aria-label="Certification Track"
                  value={activeCourse?.role_key || ''}
                  onChange={(e) => {
                    const found = allCourses.find(c => c.role_key === e.target.value);
                    if (found) onSelectCourse(found);
                  }}
                  className="appearance-none bg-slate-50 hover:bg-slate-100 text-xs font-bold text-[#082658] border border-slate-200 hover:border-slate-300 rounded-xl pl-3.5 pr-8 py-2 outline-none cursor-pointer transition focus:border-orange-500 shadow-2xs"
                >
                  {allCourses.map((c) => (
                    <option key={c.role_key} value={c.role_key} className="bg-white text-slate-900">
                      Track: {c.certification_name} ({c.role_title})
                    </option>
                  ))}
                </select>
                <ChevronDown className="w-3.5 h-3.5 text-slate-500 absolute right-2.5 top-3 pointer-events-none" />
              </div>
            )}

            {/* Super Admin Studio Toggle */}
            {isSuperAdmin && (
              <button
                onClick={() => onNavigate(currentPage === 'admin' ? 'classroom' : 'admin')}
                className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold rounded-xl border transition cursor-pointer ${
                  currentPage === 'admin'
                    ? 'bg-[#082658] text-white border-[#082658] shadow-xs'
                    : 'bg-orange-50 text-[#FD7A02] border-orange-200 hover:bg-orange-100'
                }`}
              >
                <ShieldCheck className="w-4 h-4" />
                {currentPage === 'admin' ? 'Classroom' : 'Curriculum Studio'}
              </button>
            )}

            {/* Verify Certificate Link */}
            <button
              onClick={() => onNavigate('verify')}
              className={`flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold rounded-xl border transition cursor-pointer ${
                currentPage === 'verify'
                  ? 'bg-slate-900 text-white border-slate-900'
                  : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
              }`}
            >
              <CheckCircle2 className="w-4 h-4 text-emerald-500" />
              Verify Cert
            </button>

            {/* User Profile & Logout */}
            <div className="flex items-center gap-3 pl-3 border-l border-slate-200">
              <div className="text-right">
                <p className="text-xs font-bold text-[#082658] truncate max-w-[140px]">{user?.email || 'Trainee'}</p>
                <span className="inline-block text-[10px] text-[#FD7A02] font-extrabold uppercase tracking-wide bg-orange-50 px-2 py-0.2 rounded-md border border-orange-200/60">
                  {role || 'Candidate'}
                </span>
              </div>
              <button
                onClick={onLogout}
                title="Sign Out"
                className="p-2 rounded-xl bg-slate-50 text-slate-400 hover:text-red-600 hover:bg-red-50 border border-slate-200 transition cursor-pointer"
              >
                <LogOut className="w-4 h-4" />
              </button>
            </div>

          </div>

          {/* Mobile Actions */}
          <div className="lg:hidden flex items-center gap-2">
            <button
              onClick={() => onNavigate('verify')}
              className="px-2.5 py-1.5 rounded-lg bg-slate-100 text-xs font-bold text-slate-700 border border-slate-200"
            >
              Verify
            </button>
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="p-2 rounded-lg bg-slate-100 text-slate-700 border border-slate-200"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>

        </div>
      </div>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div className="lg:hidden border-t border-slate-200 bg-white px-4 pt-3 pb-6 space-y-3 shadow-lg">
          {allCourses && allCourses.length > 0 && (
            <div>
              <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">
                Select Certification Track:
              </label>
              <select
                value={activeCourse?.role_key || ''}
                onChange={(e) => {
                  const found = allCourses.find(c => c.role_key === e.target.value);
                  if (found) {
                    onSelectCourse(found);
                    setMobileMenuOpen(false);
                  }
                }}
                className="w-full bg-slate-50 text-xs font-bold text-[#082658] border border-slate-200 rounded-xl p-2.5 outline-none"
              >
                {allCourses.map((c) => (
                  <option key={c.role_key} value={c.role_key}>
                    {c.certification_name} ({c.role_title})
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="grid grid-cols-2 gap-2 pt-2">
            {isSuperAdmin && (
              <button
                onClick={() => {
                  onNavigate(currentPage === 'admin' ? 'classroom' : 'admin');
                  setMobileMenuOpen(false);
                }}
                className="flex items-center justify-center gap-1.5 p-2.5 rounded-xl bg-orange-50 text-[#FD7A02] border border-orange-200 text-xs font-bold"
              >
                <ShieldCheck className="w-4 h-4" />
                {currentPage === 'admin' ? 'Classroom' : 'Curriculum Studio'}
              </button>
            )}

            <button
              onClick={() => {
                onNavigate('verify');
                setMobileMenuOpen(false);
              }}
              className="flex items-center justify-center gap-1.5 p-2.5 rounded-xl bg-slate-50 text-slate-700 border border-slate-200 text-xs font-bold"
            >
              <CheckCircle2 className="w-4 h-4 text-emerald-500" />
              Verify Cert
            </button>
          </div>

          <div className="pt-3 border-t border-slate-200 flex items-center justify-between">
            <div>
              <p className="text-xs font-bold text-[#082658] truncate">{user?.email}</p>
              <p className="text-[10px] text-[#FD7A02] font-bold uppercase">{role}</p>
            </div>
            <button
              onClick={onLogout}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-red-50 text-red-600 text-xs font-bold border border-red-200"
            >
              <LogOut className="w-3.5 h-3.5" /> Sign Out
            </button>
          </div>
        </div>
      )}
    </header>
  );
}
