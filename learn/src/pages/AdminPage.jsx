import React, { useState } from 'react';
import { Award, BookOpen, CheckCircle, Edit3, Eye, FileText, Plus, ShieldCheck, Trash2, Users, Search, Clock, Save, Sparkles, X } from 'lucide-react';
import CertificateModal from '../components/CertificateModal';

export default function AdminPage({ allCourses, onSaveModule, onDeleteModule, trainees, certifications, onIssueCert }) {
  const [activeTab, setActiveTab] = useState('curriculum'); // 'curriculum' | 'trainees' | 'certificates'
  const [selectedCourseKey, setSelectedCourseKey] = useState(allCourses[0]?.role_key || 'closer');
  const [editingModule, setEditingModule] = useState(null); // module object or null
  const [previewCert, setPreviewCert] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');

  const activeCourse = allCourses.find(c => c.role_key === selectedCourseKey) || allCourses[0];

  // Helper to open new module modal
  const handleAddNewModule = () => {
    setEditingModule({
      id: `mod-${Date.now()}`,
      course_id: activeCourse?.id,
      module_order: (activeCourse?.modules?.length || 0) + 1,
      title: '',
      video_url: '',
      video_duration: '15 mins',
      objectives: [''],
      transcript: '',
      summary_markdown: '',
      passing_score: 80,
      questions: [
        {
          id: `q-${Date.now()}`,
          question_text: '',
          options: ['', '', '', ''],
          correct_option_index: 0,
          explanation: '',
        }
      ]
    });
  };

  const handleSaveModuleForm = (e) => {
    e.preventDefault();
    if (!editingModule.title.trim()) return;
    onSaveModule(selectedCourseKey, editingModule);
    setEditingModule(null);
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      
      {/* Top Banner */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-6 sm:p-7 rounded-2xl bg-white border border-slate-200/80 shadow-xs">
        <div>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-orange-50 text-[#FD7A02] text-xs font-bold border border-orange-200 mb-2">
            <ShieldCheck className="w-3.5 h-3.5" />
            Super Admin Studio
          </div>
          <h1 className="text-2xl font-extrabold text-[#082658] tracking-tight">Curriculum Studio & Trainee Progress</h1>
          <p className="text-xs text-slate-500 mt-1">
            Author role modules, embed training video recordings, configure objective exams, and audit live certifications.
          </p>
        </div>

        {/* Tab Buttons */}
        <div className="flex items-center gap-1.5 p-1 rounded-xl bg-slate-100 border border-slate-200">
          <button
            onClick={() => setActiveTab('curriculum')}
            className={`px-3.5 py-2 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer ${
              activeTab === 'curriculum'
                ? 'bg-[#082658] text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <BookOpen className="w-4 h-4 text-[#FD7A02]" /> Curriculum Studio
          </button>
          <button
            onClick={() => setActiveTab('trainees')}
            className={`px-3.5 py-2 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer ${
              activeTab === 'trainees'
                ? 'bg-[#082658] text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Users className="w-4 h-4 text-[#FD7A02]" /> Trainee Roster
          </button>
          <button
            onClick={() => setActiveTab('certificates')}
            className={`px-3.5 py-2 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer ${
              activeTab === 'certificates'
                ? 'bg-[#082658] text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Award className="w-4 h-4 text-[#FD7A02]" /> Issued Certs ({certifications?.length || 0})
          </button>
        </div>
      </div>

      {/* Tab 1: Curriculum Studio */}
      {activeTab === 'curriculum' && (
        <div className="space-y-6">
          
          {/* Course Selector Tabs */}
          <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none">
            {allCourses.map((c) => (
              <button
                key={c.role_key}
                onClick={() => setSelectedCourseKey(c.role_key)}
                className={`px-4 py-2.5 rounded-xl text-xs font-extrabold whitespace-nowrap border transition cursor-pointer ${
                  selectedCourseKey === c.role_key
                    ? 'bg-[#082658] border-[#082658] text-white shadow-xs'
                    : 'bg-white border-slate-200 text-slate-700 hover:bg-slate-50'
                }`}
              >
                {c.certification_name} ({c.role_title})
              </button>
            ))}
          </div>

          {/* Active Course Card & Module Management */}
          <div className="p-6 sm:p-7 rounded-2xl bg-white border border-slate-200/80 shadow-xs space-y-6">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 pb-4 border-b border-slate-100">
              <div>
                <span className="text-[11px] font-bold uppercase tracking-wider text-[#FD7A02]">
                  Target Role: {activeCourse?.role_title}
                </span>
                <h2 className="text-xl font-extrabold text-[#082658] mt-0.5">{activeCourse?.certification_name}</h2>
                <p className="text-xs text-slate-500 mt-1 max-w-xl">{activeCourse?.description}</p>
              </div>

              <button
                onClick={handleAddNewModule}
                className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-xs font-extrabold bg-[#FD7A02] hover:bg-[#E06900] text-white transition shadow-md shadow-orange-500/20 cursor-pointer"
              >
                <Plus className="w-4 h-4" /> Add Training Module
              </button>
            </div>

            {/* Modules List Cards */}
            <div className="space-y-3">
              {activeCourse?.modules?.length > 0 ? (
                activeCourse.modules.map((m, idx) => (
                  <div
                    key={m.id || idx}
                    className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 flex flex-col md:flex-row items-start md:items-center justify-between gap-4 hover:border-slate-300 transition"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-xl bg-orange-100 text-[#FD7A02] font-extrabold flex items-center justify-center text-sm border border-orange-200">
                        {m.module_order || idx + 1}
                      </div>
                      <div>
                        <h4 className="text-sm font-bold text-[#082658]">{m.title}</h4>
                        <div className="flex items-center gap-3 text-xs text-slate-500 mt-0.5">
                          <span>{m.video_duration || '15 mins'}</span>
                          <span>•</span>
                          <span>{m.objectives?.length || 0} Objectives</span>
                          <span>•</span>
                          <span>{m.questions?.length || 0} Exam Questions</span>
                          <span>•</span>
                          <span className="text-emerald-700 font-semibold">Pass: {m.passing_score || 80}%</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setEditingModule(JSON.parse(JSON.stringify(m)))}
                        className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-white text-slate-700 border border-slate-200 hover:bg-slate-100 text-xs font-semibold shadow-2xs cursor-pointer"
                      >
                        <Edit3 className="w-3.5 h-3.5 text-[#FD7A02]" /> Edit Module
                      </button>
                      <button
                        onClick={() => onDeleteModule(selectedCourseKey, m.id)}
                        className="p-1.5 rounded-lg bg-red-50 text-red-600 border border-red-200 hover:bg-red-100 text-xs cursor-pointer"
                        title="Delete Module"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-8 text-center text-slate-500 border border-dashed border-slate-200 rounded-xl">
                  <BookOpen className="w-8 h-8 text-slate-400 mx-auto mb-2" />
                  <p className="text-xs">No modules created yet for this track. Click "+ Add Training Module" above.</p>
                </div>
              )}
            </div>

          </div>

        </div>
      )}

      {/* Tab 2: Trainee Roster */}
      {activeTab === 'trainees' && (
        <div className="p-6 sm:p-7 rounded-2xl bg-white border border-slate-200/80 shadow-xs space-y-4">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div>
              <h2 className="text-lg font-extrabold text-[#082658]">Active Trainee Candidates</h2>
              <p className="text-xs text-slate-500">Team members undergoing role certification across all operational consoles</p>
            </div>
            <div className="relative w-full sm:w-72">
              <Search className="w-4 h-4 absolute left-3 top-3 text-slate-400" />
              <input
                type="text"
                placeholder="Search candidate by name or email..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-9 pr-3 py-2 text-xs text-slate-800 placeholder-slate-400 outline-none focus:border-[#FD7A02] focus:bg-white"
              />
            </div>
          </div>

          <div className="overflow-x-auto border border-slate-200 rounded-xl">
            <table className="w-full text-left text-xs text-slate-700">
              <thead className="bg-slate-50 text-[11px] uppercase font-bold text-slate-500 border-b border-slate-200">
                <tr>
                  <th className="p-3">Candidate</th>
                  <th className="p-3">Role Track</th>
                  <th className="p-3">Certification Target</th>
                  <th className="p-3">Progress</th>
                  <th className="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {trainees && trainees.length > 0 ? (
                  trainees
                    .filter(t => !searchQuery || t.name?.toLowerCase().includes(searchQuery.toLowerCase()) || t.email?.toLowerCase().includes(searchQuery.toLowerCase()))
                    .map((t, i) => (
                      <tr key={i} className="hover:bg-slate-50 transition">
                        <td className="p-3">
                          <p className="font-bold text-[#082658]">{t.name || 'Staff Member'}</p>
                          <p className="text-[11px] text-slate-500 font-mono">{t.email}</p>
                        </td>
                        <td className="p-3">
                          <span className="px-2 py-0.5 rounded bg-orange-50 text-[#FD7A02] border border-orange-200 font-semibold uppercase text-[10px]">
                            {t.role}
                          </span>
                        </td>
                        <td className="p-3 font-semibold text-slate-700">
                          {t.targetCertification || 'Certified Sales Person'}
                        </td>
                        <td className="p-3">
                          <div className="flex items-center gap-2">
                            <div className="w-24 h-2 bg-slate-100 rounded-full overflow-hidden">
                              <div
                                className="h-full bg-gradient-to-r from-orange-500 to-amber-500 rounded-full"
                                style={{ width: `${t.progress || 0}%` }}
                              />
                            </div>
                            <span className="font-bold text-[#082658] text-[11px]">{t.progress || 0}%</span>
                          </div>
                        </td>
                        <td className="p-3 text-right">
                          {t.certCode ? (
                            <button
                              onClick={() => setPreviewCert({
                                certificate_code: t.certCode,
                                recipient_name: t.name,
                                user_email: t.email,
                                certification_title: t.targetCertification,
                                overall_score: 100,
                                issued_at: new Date().toISOString()
                              })}
                              className="px-2.5 py-1 rounded-lg bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-bold hover:bg-emerald-100 cursor-pointer"
                            >
                              View Cert
                            </button>
                          ) : (
                            <button
                              onClick={() => onIssueCert(t)}
                              className="px-2.5 py-1 rounded-lg bg-[#082658] text-white hover:bg-[#05193B] text-xs font-semibold cursor-pointer shadow-2xs"
                            >
                              Grant Cert
                            </button>
                          )}
                        </td>
                      </tr>
                    ))
                ) : (
                  <tr>
                    <td colSpan="5" className="p-8 text-center text-slate-500">
                      No candidate activity recorded yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

        </div>
      )}

      {/* Tab 3: Issued Certificates Registry */}
      {activeTab === 'certificates' && (
        <div className="p-6 sm:p-7 rounded-2xl bg-white border border-slate-200/80 shadow-xs space-y-4">
          <h2 className="text-lg font-extrabold text-[#082658]">Official Certificate Verification Registry</h2>
          <p className="text-xs text-slate-500">Cryptographically verifiable certification credentials issued by NovaXpress</p>

          <div className="overflow-x-auto border border-slate-200 rounded-xl">
            <table className="w-full text-left text-xs text-slate-700">
              <thead className="bg-slate-50 text-[11px] uppercase font-bold text-slate-500 border-b border-slate-200">
                <tr>
                  <th className="p-3">Verification ID</th>
                  <th className="p-3">Recipient</th>
                  <th className="p-3">Certification Title</th>
                  <th className="p-3">Score</th>
                  <th className="p-3">Date Issued</th>
                  <th className="p-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {certifications && certifications.length > 0 ? (
                  certifications.map((c, i) => (
                    <tr key={i} className="hover:bg-slate-50 transition">
                      <td className="p-3 font-mono font-extrabold text-[#FD7A02]">{c.certificate_code}</td>
                      <td className="p-3">
                        <p className="font-bold text-[#082658]">{c.recipient_name}</p>
                        <p className="text-[11px] text-slate-500">{c.user_email}</p>
                      </td>
                      <td className="p-3 font-bold text-slate-700">{c.certification_title || c.certification_name}</td>
                      <td className="p-3 text-emerald-700 font-extrabold">{c.overall_score}%</td>
                      <td className="p-3 text-slate-500">
                        {new Date(c.issued_at || Date.now()).toLocaleDateString()}
                      </td>
                      <td className="p-3 text-right">
                        <button
                          onClick={() => setPreviewCert(c)}
                          className="px-3 py-1 rounded-lg bg-orange-50 text-[#FD7A02] border border-orange-200 text-xs font-bold hover:bg-orange-100 cursor-pointer"
                        >
                          View Document
                        </button>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan="6" className="p-8 text-center text-slate-500">
                      No certificates recorded in registry yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Editing Module Modal */}
      {editingModule && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/70 backdrop-blur-sm overflow-y-auto">
          <div className="relative w-full max-w-3xl bg-white border border-slate-200 rounded-3xl p-6 sm:p-8 shadow-2xl my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 mb-6">
              <h3 className="text-xl font-extrabold text-[#082658]">
                {editingModule.id ? 'Edit Training Module' : 'Create New Training Module'}
              </h3>
              <button
                onClick={() => setEditingModule(null)}
                className="p-2 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveModuleForm} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="md:col-span-2">
                  <label className="text-xs font-bold text-slate-700 block mb-1">Module Title</label>
                  <input
                    type="text"
                    required
                    value={editingModule.title}
                    onChange={(e) => setEditingModule({ ...editingModule, title: e.target.value })}
                    placeholder="e.g. Lead Intake & Address Geo-Normalization"
                    className="w-full p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 outline-none focus:border-[#FD7A02] focus:bg-white"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold text-slate-700 block mb-1">Video Duration</label>
                  <input
                    type="text"
                    value={editingModule.video_duration}
                    onChange={(e) => setEditingModule({ ...editingModule, video_duration: e.target.value })}
                    placeholder="e.g. 15 mins"
                    className="w-full p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 outline-none focus:border-[#FD7A02] focus:bg-white"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1">Video Stream Embed URL (YouTube, Vimeo, MP4)</label>
                <input
                  type="text"
                  value={editingModule.video_url}
                  onChange={(e) => setEditingModule({ ...editingModule, video_url: e.target.value })}
                  placeholder="https://www.youtube-nocookie.com/embed/..."
                  className="w-full p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 outline-none focus:border-[#FD7A02] focus:bg-white"
                />
              </div>

              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1">Learning Objectives (1 per line)</label>
                <textarea
                  rows="3"
                  value={editingModule.objectives?.join('\n') || ''}
                  onChange={(e) => setEditingModule({ ...editingModule, objectives: e.target.value.split('\n').filter(Boolean) })}
                  placeholder="Verify customer phone number&#10;Record recognizable landmark"
                  className="w-full p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 outline-none focus:border-[#FD7A02] focus:bg-white"
                />
              </div>

              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1">Full Transcript</label>
                <textarea
                  rows="4"
                  value={editingModule.transcript || ''}
                  onChange={(e) => setEditingModule({ ...editingModule, transcript: e.target.value })}
                  placeholder="Paste or write the complete spoken training transcript here..."
                  className="w-full p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 outline-none focus:border-[#FD7A02] focus:bg-white"
                />
              </div>

              <div>
                <label className="text-xs font-bold text-slate-700 block mb-1">Summary & Best Practice SOP Checklist</label>
                <textarea
                  rows="3"
                  value={editingModule.summary_markdown || ''}
                  onChange={(e) => setEditingModule({ ...editingModule, summary_markdown: e.target.value })}
                  placeholder="Key rules, checklists, and critical mistakes to avoid..."
                  className="w-full p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-900 outline-none focus:border-[#FD7A02] focus:bg-white"
                />
              </div>

              {/* Questions Section */}
              <div className="pt-4 border-t border-slate-100">
                <div className="flex items-center justify-between mb-3">
                  <h4 className="text-sm font-extrabold text-[#082658]">Objective Examination Questions ({editingModule.questions?.length || 0})</h4>
                  <button
                    type="button"
                    onClick={() => setEditingModule({
                      ...editingModule,
                      questions: [
                        ...(editingModule.questions || []),
                        {
                          id: `q-${Date.now()}`,
                          question_text: '',
                          options: ['', '', '', ''],
                          correct_option_index: 0,
                          explanation: ''
                        }
                      ]
                    })}
                    className="text-xs font-bold text-[#FD7A02] hover:text-[#E06900] cursor-pointer"
                  >
                    + Add Question
                  </button>
                </div>

                <div className="space-y-4 max-h-56 overflow-y-auto pr-2">
                  {editingModule.questions?.map((q, qIdx) => (
                    <div key={qIdx} className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-[#FD7A02]">Question {qIdx + 1}</span>
                        {editingModule.questions.length > 1 && (
                          <button
                            type="button"
                            onClick={() => {
                              const updated = editingModule.questions.filter((_, idx) => idx !== qIdx);
                              setEditingModule({ ...editingModule, questions: updated });
                            }}
                            className="text-[11px] text-red-600 hover:text-red-700 cursor-pointer"
                          >
                            Remove
                          </button>
                        )}
                      </div>

                      <input
                        type="text"
                        placeholder="Enter the examination question text..."
                        value={q.question_text}
                        onChange={(e) => {
                          const updated = [...editingModule.questions];
                          updated[qIdx].question_text = e.target.value;
                          setEditingModule({ ...editingModule, questions: updated });
                        }}
                        className="w-full p-2 rounded-lg bg-white border border-slate-200 text-slate-800 text-xs outline-none focus:border-[#FD7A02]"
                      />

                      <div className="grid grid-cols-2 gap-2">
                        {q.options.map((opt, optIdx) => (
                          <div key={optIdx} className="flex items-center gap-1.5">
                            <input
                              type="radio"
                              name={`correct-opt-${qIdx}`}
                              checked={q.correct_option_index === optIdx}
                              onChange={() => {
                                const updated = [...editingModule.questions];
                                updated[qIdx].correct_option_index = optIdx;
                                setEditingModule({ ...editingModule, questions: updated });
                              }}
                              className="accent-orange-500 cursor-pointer"
                            />
                            <input
                              type="text"
                              placeholder={`Option ${String.fromCharCode(65 + optIdx)}`}
                              value={opt}
                              onChange={(e) => {
                                const updated = [...editingModule.questions];
                                updated[qIdx].options[optIdx] = e.target.value;
                                setEditingModule({ ...editingModule, questions: updated });
                              }}
                              className="w-full p-1.5 rounded-lg bg-white border border-slate-200 text-slate-800 text-xs outline-none focus:border-[#FD7A02]"
                            />
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Form Buttons */}
              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setEditingModule(null)}
                  className="px-5 py-2.5 rounded-xl bg-slate-100 text-slate-700 text-xs font-bold hover:bg-slate-200 transition cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-6 py-2.5 rounded-xl bg-[#FD7A02] hover:bg-[#E06900] text-white text-xs font-extrabold transition shadow-md shadow-orange-500/20 cursor-pointer"
                >
                  Save Training Module
                </button>
              </div>

            </form>
          </div>
        </div>
      )}

      {/* Preview Certificate Modal */}
      {previewCert && (
        <CertificateModal
          cert={previewCert}
          onClose={() => setPreviewCert(null)}
        />
      )}

    </div>
  );
}
