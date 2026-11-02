import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import ClassroomPage from './pages/ClassroomPage';
import AdminPage from './pages/AdminPage';
import VerifyPage from './pages/VerifyPage';
import AuthPage from './pages/AuthPage';
import CertificateModal from './components/CertificateModal';
import { DEFAULT_COURSES } from './data/defaultCurriculum';
import { supabase, mapRoleToCourseKey, generateCertificateCode } from './lib/supabase';

export default function App() {
  const [user, setUser] = useState(null);
  const [role, setRole] = useState(null);
  const [currentPage, setCurrentPage] = useState('classroom'); // 'classroom' | 'admin' | 'verify'
  const [allCourses, setAllCourses] = useState(DEFAULT_COURSES);
  const [activeCourse, setActiveCourse] = useState(DEFAULT_COURSES[0]);
  const [userProgress, setUserProgress] = useState({}); // { [moduleId]: { is_video_completed, quiz_passed, quiz_score } }
  const [certifications, setCertifications] = useState([]);
  const [existingCert, setExistingCert] = useState(null);
  const [verifyCodeFromUrl, setVerifyCodeFromUrl] = useState(null);
  const [trainees, setTrainees] = useState([
    { name: 'Prestige Godwin Uto', email: 'prestige.godwin@novaxpress.net', role: 'closer', targetCertification: 'Certified Sales Person', progress: 50, certCode: null },
    { name: 'Joel Finance', email: 'joelfinance@gmail.com', role: 'dc_finance_admin', targetCertification: 'Certified Finance Operations', progress: 100, certCode: 'NX-CERT-2026-F9821' },
    { name: 'Joel Stock', email: 'joelstock@novaxpress.ng', role: 'dc_stock_admin', targetCertification: 'Certified Inventory Manager', progress: 0, certCode: null },
    { name: 'Oladele Omowaye', email: 'oladele.omowaye@novaxpress.ng', role: 'rider', targetCertification: 'Certified Mobile Operations', progress: 100, certCode: 'NX-CERT-2026-R4102' },
    { name: 'Abigail Kooyon', email: 'abigail.kooyon@novaxpress.net', role: 'dc_operations', targetCertification: 'Certified Dispatch Operations', progress: 50, certCode: null },
    { name: 'Joel Account', email: 'joelaccount@gmail.com', role: 'accountant', targetCertification: 'Certified Accountant', progress: 100, certCode: 'NX-CERT-2026-A2201' },
    { name: 'Ahmed Bello', email: 'dc.supervisor@novaxpress.ng', role: 'dc_manager', targetCertification: 'Certified Logistics Manager', progress: 50, certCode: null },
  ]);

  // Check URL path on mount (e.g. /verify/NX-CERT-2026-X8921)
  useEffect(() => {
    const pathname = window.location.pathname;
    if (pathname.startsWith('/verify')) {
      const parts = pathname.split('/').filter(Boolean);
      if (parts[1]) {
        setVerifyCodeFromUrl(parts[1]);
      }
      setCurrentPage('verify');
    }
  }, []);

  // Fetch or synchronize courses from Supabase DB
  useEffect(() => {
    async function loadDbData() {
      try {
        const { data: dbCourses } = await supabase
          .from('lms_courses')
          .select('*, lms_modules(*, lms_questions(*))');

        if (dbCourses && dbCourses.length > 0) {
          const merged = DEFAULT_COURSES.map(dc => {
            const remote = dbCourses.find(rc => rc.role_key === dc.role_key);
            if (remote && remote.lms_modules?.length > 0) {
              return {
                ...dc,
                ...remote,
                modules: remote.lms_modules.map(rm => ({
                  ...rm,
                  questions: rm.lms_questions || []
                }))
              };
            }
            return dc;
          });
          setAllCourses(merged);
        }

        const { data: dbCerts } = await supabase
          .from('lms_certifications')
          .select('*')
          .order('issued_at', { ascending: false });

        if (dbCerts) {
          setCertifications(dbCerts);
        }
      } catch (err) {
        console.warn('DB sync notice (using bundled curriculum):', err);
      }
    }
    loadDbData();
  }, []);

  // Set default active course based on user's role
  const handleUserLoggedIn = (userData) => {
    setUser(userData);
    setRole(userData.role);

    const targetKey = mapRoleToCourseKey(userData.role);
    const matched = allCourses.find(c => c.role_key === targetKey) || allCourses[0];
    setActiveCourse(matched);

    if (userData.role === 'super_admin') {
      setCurrentPage('admin');
    } else {
      setCurrentPage('classroom');
    }
  };

  const handleUpdateProgress = (moduleId, progressData) => {
    setUserProgress(prev => ({
      ...prev,
      [moduleId]: progressData,
    }));
  };

  const handleGenerateCertificate = async () => {
    const code = generateCertificateCode();
    const newCert = {
      certificate_code: code,
      user_id: user?.id || 'trainee-id',
      user_email: user?.email || 'trainee@novaxpress.ng',
      recipient_name: user?.name || user?.email?.split('@')[0] || 'Certified Operator',
      role_key: activeCourse?.role_key || 'closer',
      certification_title: activeCourse?.certification_name || 'Certified Professional',
      overall_score: 95,
      issued_at: new Date().toISOString(),
      is_valid: true,
    };

    setExistingCert(newCert);
    setCertifications(prev => [newCert, ...prev]);

    // Save to Supabase
    try {
      await supabase.from('lms_certifications').insert([newCert]);
    } catch (e) {
      console.warn('Certificate local save notice:', e);
    }
  };

  const handleSaveModule = (courseKey, moduleData) => {
    setAllCourses(prev => prev.map(c => {
      if (c.role_key === courseKey) {
        const existingIdx = c.modules?.findIndex(m => m.id === moduleData.id);
        let updatedModules = [...(c.modules || [])];
        if (existingIdx >= 0) {
          updatedModules[existingIdx] = moduleData;
        } else {
          updatedModules.push(moduleData);
        }
        return { ...c, modules: updatedModules };
      }
      return c;
    }));
  };

  const handleDeleteModule = (courseKey, moduleId) => {
    setAllCourses(prev => prev.map(c => {
      if (c.role_key === courseKey) {
        return {
          ...c,
          modules: c.modules.filter(m => m.id !== moduleId)
        };
      }
      return c;
    }));
  };

  const handleAdminIssueCert = (trainee) => {
    const code = generateCertificateCode();
    const cert = {
      certificate_code: code,
      recipient_name: trainee.name,
      user_email: trainee.email,
      role_key: trainee.role,
      certification_title: trainee.targetCertification,
      overall_score: 100,
      issued_at: new Date().toISOString(),
      is_valid: true,
    };
    setCertifications(prev => [cert, ...prev]);
    setTrainees(prev => prev.map(t => t.email === trainee.email ? { ...t, progress: 100, certCode: code } : t));
  };

  // If not logged in and not verifying, show Auth Page
  if (!user && currentPage !== 'verify') {
    return (
      <AuthPage
        onLoginSuccess={handleUserLoggedIn}
        onNavigateVerify={() => setCurrentPage('verify')}
      />
    );
  }

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex flex-col text-slate-800">
      
      {/* Top Global Navigation Bar */}
      <Navbar
        user={user}
        role={role}
        activeCourse={activeCourse}
        onSelectCourse={setActiveCourse}
        allCourses={allCourses}
        onViewCert={() => setExistingCert(existingCert)}
        onLogout={() => { setUser(null); setRole(null); setCurrentPage('classroom'); }}
        onNavigate={setCurrentPage}
        currentPage={currentPage}
      />

      {/* Main Routed Content View */}
      <main className="flex-1 pb-16">
        {currentPage === 'classroom' && (
          <ClassroomPage
            course={activeCourse}
            userProgress={userProgress}
            onUpdateProgress={handleUpdateProgress}
            onGenerateCert={handleGenerateCertificate}
            existingCert={existingCert}
          />
        )}

        {currentPage === 'admin' && (
          <AdminPage
            allCourses={allCourses}
            onSaveModule={handleSaveModule}
            onDeleteModule={handleDeleteModule}
            trainees={trainees}
            certifications={certifications}
            onIssueCert={handleAdminIssueCert}
          />
        )}

        {currentPage === 'verify' && (
          <VerifyPage
            initialCode={verifyCodeFromUrl}
            onBack={user ? () => setCurrentPage('classroom') : null}
          />
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-200 py-6 text-center text-xs text-slate-500 bg-white no-print">
        <p className="font-semibold text-slate-700">© 2026 NovaXpress Logistics Platform. All Rights Reserved.</p>
        <p className="mt-1 text-[11px] text-slate-500">
          Official Verifiable Training & Accreditation System • <span className="font-mono text-[#FD7A02]">learn.novaxpressng.com</span>
        </p>
      </footer>

    </div>
  );
}
