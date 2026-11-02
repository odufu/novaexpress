import React, { useState } from 'react';
import { Award, BookOpen, CheckCircle, CheckCircle2, Clock, FileText, Lock, Play, ShieldAlert, ShieldCheck, Sparkles, Target, Trophy, ChevronRight } from 'lucide-react';
import VideoPlayer from '../components/VideoPlayer';
import QuizModal from '../components/QuizModal';
import CertificateModal from '../components/CertificateModal';

export default function ClassroomPage({ course, userProgress, onUpdateProgress, onGenerateCert, existingCert }) {
  const [activeModuleIdx, setActiveModuleIdx] = useState(0);
  const [activeTab, setActiveTab] = useState('objectives'); // 'objectives' | 'transcript' | 'summary'
  const [showQuiz, setShowQuiz] = useState(false);
  const [showCertModal, setShowCertModal] = useState(false);

  const modules = course?.modules || [];
  const currentModule = modules[activeModuleIdx] || modules[0];

  // Calculate overall course progress
  const totalModules = modules.length;
  const passedModulesCount = modules.filter(m => userProgress[m.id]?.quiz_passed).length;
  const progressPercent = totalModules > 0 ? Math.round((passedModulesCount / totalModules) * 100) : 0;
  const isCourseGraduated = passedModulesCount === totalModules && totalModules > 0;

  const currentModuleProgress = userProgress[currentModule?.id] || {};
  const isCurrentModulePassed = currentModuleProgress.quiz_passed;

  const handleVideoCompleted = () => {
    onUpdateProgress(currentModule.id, {
      ...currentModuleProgress,
      is_video_completed: true,
    });
  };

  const handlePassExam = (score) => {
    onUpdateProgress(currentModule.id, {
      ...currentModuleProgress,
      quiz_passed: true,
      quiz_score: score,
      completed_at: new Date().toISOString(),
    });

    if (passedModulesCount + 1 >= totalModules) {
      setTimeout(() => {
        onGenerateCert();
        setShowCertModal(true);
      }, 800);
    }
  };

  if (!course) {
    return (
      <div className="max-w-4xl mx-auto my-16 p-12 text-center bg-white rounded-2xl border border-slate-200 shadow-xs">
        <Award className="w-12 h-12 text-slate-300 mx-auto mb-3" />
        <h3 className="text-lg font-bold text-[#082658]">No certification track selected</h3>
        <p className="text-xs text-slate-500 mt-1">Please pick a role curriculum from the top navigation.</p>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      
      {/* Top Header / Track Overview Card */}
      <div className="rounded-2xl bg-white border border-slate-200/80 p-6 sm:p-8 shadow-xs">
        <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6">
          
          {/* Left Course Details */}
          <div className="max-w-3xl space-y-2.5">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-[11px] font-extrabold uppercase tracking-widest px-2.5 py-0.5 rounded-full bg-orange-50 text-[#FD7A02] border border-orange-200/60">
                Official Accreditation Track
              </span>
              <span className="text-xs font-semibold text-slate-500">
                Target Role: <strong className="text-[#082658]">{course.role_title}</strong>
              </span>
            </div>

            <h1 className="text-2xl sm:text-3xl font-extrabold text-[#082658] tracking-tight">
              {course.certification_name}
            </h1>
            
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-2xl">
              {course.description}
            </p>

            <div className="flex flex-wrap items-center gap-3 pt-1 text-xs font-semibold text-slate-600">
              <span className="flex items-center gap-1.5 px-3 py-1 rounded-lg bg-slate-50 border border-slate-200 text-[#082658]">
                <Clock className="w-3.5 h-3.5 text-[#FD7A02]" /> {course.estimated_duration || '2.5 Hours'}
              </span>
              <span className="flex items-center gap-1.5 px-3 py-1 rounded-lg bg-slate-50 border border-slate-200 text-[#082658]">
                <BookOpen className="w-3.5 h-3.5 text-[#FD7A02]" /> {modules.length} Modules & Practical Exams
              </span>
              <span className="flex items-center gap-1.5 px-3 py-1 rounded-lg bg-emerald-50 border border-emerald-200 text-emerald-800">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" /> Verifiable National Accreditation
              </span>
            </div>
          </div>

          {/* Right Progress Card */}
          <div className="w-full lg:w-72 p-5 rounded-2xl bg-slate-50 border border-slate-200/80 flex flex-col items-center text-center space-y-3">
            <div className="w-12 h-12 rounded-xl bg-gradient-to-tr from-[#FD7A02] to-[#E06900] flex items-center justify-center shadow-md shadow-orange-500/20">
              <Award className="w-7 h-7 text-white" />
            </div>

            <div>
              <p className="text-[10px] font-bold uppercase tracking-wider text-slate-500">Accreditation Progress</p>
              <p className="text-xl font-extrabold text-[#082658]">{isCourseGraduated ? 'Accredited' : `${progressPercent}% Completed`}</p>
              <p className="text-xs text-[#FD7A02] font-semibold mt-0.5">
                {passedModulesCount} of {totalModules} Modules Passed
              </p>
            </div>

            {/* Progress Bar */}
            <div className="w-full h-2 bg-slate-200 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-orange-500 to-amber-500 transition-all duration-500 rounded-full"
                style={{ width: `${progressPercent}%` }}
              />
            </div>

            {/* Action button */}
            {isCourseGraduated || existingCert ? (
              <button
                onClick={() => setShowCertModal(true)}
                className="w-full py-2.5 px-4 rounded-xl text-xs font-extrabold bg-[#082658] hover:bg-[#05193B] text-white transition shadow-md flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <Trophy className="w-4 h-4 text-amber-400" /> View Verified Certificate
              </button>
            ) : (
              <p className="text-[10px] text-slate-500 leading-tight">
                Pass all module exams with 80%+ to unlock your verifiable credential.
              </p>
            )}
          </div>

        </div>
      </div>

      {/* Main 2-Column Classroom Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        
        {/* Left Column: Lesson Workspace (8 Cols) */}
        <div className="lg:col-span-8 space-y-6">
          
          {/* Active Lesson Header Card */}
          <div className="flex flex-wrap items-center justify-between gap-3 p-5 rounded-2xl bg-white border border-slate-200/80 shadow-xs">
            <div>
              <span className="text-xs font-extrabold uppercase tracking-wider text-[#FD7A02]">
                Module {currentModule?.module_order} of {modules.length}
              </span>
              <h2 className="text-xl font-extrabold text-[#082658] mt-0.5">
                {currentModule?.title}
              </h2>
            </div>

            {isCurrentModulePassed ? (
              <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-bold">
                <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                Passed with {currentModuleProgress.quiz_score || 100}%
              </div>
            ) : (
              <span className="text-xs font-semibold text-slate-500 bg-slate-50 px-3 py-1 rounded-lg border border-slate-200">
                Passing Score: <strong className="text-[#082658]">{currentModule?.passing_score || 80}%</strong>
              </span>
            )}
          </div>

          {/* Video Player */}
          {currentModule && (
            <VideoPlayer
              videoUrl={currentModule.video_url}
              duration={currentModule.video_duration}
              title={currentModule.title}
              onComplete={handleVideoCompleted}
              isCompleted={currentModuleProgress.is_video_completed}
            />
          )}

          {/* Lesson Details Tabs */}
          <div className="rounded-2xl bg-white border border-slate-200/80 p-6 space-y-6 shadow-xs">
            
            {/* Modern Segmented Tab Navigation */}
            <div className="flex items-center gap-2 border-b border-slate-100 pb-3 overflow-x-auto">
              <button
                onClick={() => setActiveTab('objectives')}
                className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition whitespace-nowrap cursor-pointer ${
                  activeTab === 'objectives'
                    ? 'bg-[#082658] text-white shadow-xs'
                    : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
                }`}
              >
                <Target className="w-4 h-4 text-[#FD7A02]" />
                Objectives & Competencies
              </button>

              <button
                onClick={() => setActiveTab('transcript')}
                className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition whitespace-nowrap cursor-pointer ${
                  activeTab === 'transcript'
                    ? 'bg-[#082658] text-white shadow-xs'
                    : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
                }`}
              >
                <FileText className="w-4 h-4 text-[#FD7A02]" />
                Full Transcript
              </button>

              <button
                onClick={() => setActiveTab('summary')}
                className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition whitespace-nowrap cursor-pointer ${
                  activeTab === 'summary'
                    ? 'bg-[#082658] text-white shadow-xs'
                    : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
                }`}
              >
                <BookOpen className="w-4 h-4 text-[#FD7A02]" />
                Key Summary & SOP
              </button>
            </div>

            {/* Tab 1: Objectives */}
            {activeTab === 'objectives' && (
              <div className="space-y-4">
                <h4 className="text-xs font-extrabold uppercase tracking-wider text-slate-500">
                  Required Competencies & Learning Goals:
                </h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {currentModule?.objectives?.map((obj, i) => (
                    <div key={i} className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 flex items-start gap-3">
                      <div className="w-5 h-5 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center text-xs font-bold flex-shrink-0 mt-0.5">
                        ✓
                      </div>
                      <p className="text-xs text-slate-700 leading-relaxed font-medium">{obj}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Tab 2: Transcript */}
            {activeTab === 'transcript' && (
              <div className="space-y-3">
                <h4 className="text-xs font-extrabold uppercase tracking-wider text-slate-500">
                  Spoken Recording Transcript:
                </h4>
                <div className="p-5 rounded-xl bg-slate-50 border border-slate-200/80 text-xs text-slate-700 leading-relaxed whitespace-pre-line max-h-96 overflow-y-auto pr-3">
                  {currentModule?.transcript || 'No transcript text available for this module.'}
                </div>
              </div>
            )}

            {/* Tab 3: Summary */}
            {activeTab === 'summary' && (
              <div className="space-y-3">
                <h4 className="text-xs font-extrabold uppercase tracking-wider text-slate-500">
                  Operational SOP Cheat Sheet:
                </h4>
                <div className="p-5 rounded-xl bg-slate-50 border border-slate-200/80 text-xs text-slate-700 leading-relaxed whitespace-pre-line">
                  {currentModule?.summary_markdown || 'No summary notes available for this module.'}
                </div>
              </div>
            )}

            {/* Examination Bar */}
            <div className="pt-6 border-t border-slate-100 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
              <div>
                <p className="text-sm font-extrabold text-[#082658]">Module Examination</p>
                <p className="text-xs text-slate-500 mt-0.5">
                  Answer objective multiple-choice questions to prove knowledge and earn accreditation credit.
                </p>
              </div>

              <button
                onClick={() => setShowQuiz(true)}
                className={`w-full sm:w-auto px-6 py-3 rounded-xl text-xs font-extrabold flex items-center justify-center gap-2 transition shadow-md cursor-pointer ${
                  isCurrentModulePassed
                    ? 'bg-slate-100 text-[#082658] border border-slate-200 hover:bg-slate-200'
                    : 'bg-[#FD7A02] hover:bg-[#E06900] text-white shadow-orange-500/20'
                }`}
              >
                <Award className="w-4 h-4" />
                {isCurrentModulePassed ? 'Retake Examination' : 'Start Examination'}
              </button>
            </div>

          </div>

        </div>

        {/* Right Column: Sticky Course Curriculum Playlist (4 Cols) */}
        <div className="lg:col-span-4 sticky top-24 space-y-4">
          <div className="rounded-2xl bg-white border border-slate-200/80 p-5 space-y-4 shadow-xs">
            <div className="flex items-center justify-between">
              <h3 className="text-xs font-extrabold uppercase tracking-wider text-[#082658]">
                Course Curriculum ({modules.length} Modules)
              </h3>
              <span className="text-xs font-bold text-[#FD7A02]">{progressPercent}% Done</span>
            </div>

            {/* Module Item Cards */}
            <div className="space-y-2.5">
              {modules.map((m, idx) => {
                const isPassed = userProgress[m.id]?.quiz_passed;
                const isCurrent = idx === activeModuleIdx;

                return (
                  <button
                    key={m.id}
                    onClick={() => setActiveModuleIdx(idx)}
                    className={`w-full p-4 rounded-xl border text-left transition flex items-center justify-between cursor-pointer ${
                      isCurrent
                        ? 'bg-orange-50/60 border-orange-400 text-[#082658] shadow-xs'
                        : isPassed
                        ? 'bg-white border-emerald-200 text-slate-700 hover:bg-slate-50'
                        : 'bg-white border-slate-200/80 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-xs font-extrabold ${
                        isPassed
                          ? 'bg-emerald-100 text-emerald-700 border border-emerald-200'
                          : isCurrent
                          ? 'bg-[#FD7A02] text-white shadow-xs'
                          : 'bg-slate-100 text-slate-500'
                      }`}>
                        {isPassed ? <CheckCircle className="w-4 h-4" /> : m.module_order}
                      </div>

                      <div>
                        <p className={`text-xs font-bold line-clamp-1 ${isCurrent ? 'text-[#082658]' : 'text-slate-800'}`}>
                          {m.title}
                        </p>
                        <p className="text-[11px] text-slate-500 mt-0.5">
                          {m.video_duration || '15 mins'} • {m.questions?.length || 0} Questions
                        </p>
                      </div>
                    </div>

                    <div>
                      {isPassed ? (
                        <span className="text-[10px] font-extrabold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                          Passed
                        </span>
                      ) : isCurrent ? (
                        <span className="text-[10px] font-extrabold text-[#FD7A02] bg-orange-50 px-2 py-0.5 rounded-full border border-orange-200">
                          Active
                        </span>
                      ) : (
                        <ChevronRight className="w-4 h-4 text-slate-400" />
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </div>

      </div>

      {/* Examination Modal */}
      {showQuiz && currentModule && (
        <QuizModal
          module={currentModule}
          questions={currentModule.questions}
          onPassExam={handlePassExam}
          onClose={() => setShowQuiz(false)}
        />
      )}

      {/* Certificate Modal */}
      {showCertModal && existingCert && (
        <CertificateModal
          cert={existingCert}
          onClose={() => setShowCertModal(false)}
        />
      )}

    </div>
  );
}
