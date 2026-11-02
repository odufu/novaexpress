import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { Award, CheckCircle2, XCircle, ArrowRight, ArrowLeft, RotateCcw, X, HelpCircle, Check, Sparkles } from 'lucide-react';

export default function QuizModal({ module, questions, onPassExam, onClose }) {
  const [currentIdx, setCurrentIdx] = useState(0);
  const [selectedAnswers, setSelectedAnswers] = useState({}); // { [questionIndex]: optionIndex }
  const [submitted, setSubmitted] = useState(false);

  const passingScore = module.passing_score || 80;
  const totalQuestions = questions?.length || 0;

  if (!questions || totalQuestions === 0) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm">
        <div className="w-full max-w-md bg-white border border-slate-200 rounded-3xl p-6 text-center shadow-2xl">
          <div className="w-12 h-12 rounded-2xl bg-orange-50 text-[#FD7A02] flex items-center justify-center mx-auto mb-3 border border-orange-200">
            <HelpCircle className="w-6 h-6" />
          </div>
          <h3 className="text-lg font-bold text-[#082658]">No Examination Questions Yet</h3>
          <p className="text-xs text-slate-500 mt-2">
            The Super Admin has not yet configured objective questions for this module. You can mark this module as completed.
          </p>
          <div className="mt-6 flex gap-3">
            <button
              onClick={() => { onPassExam(100); onClose(); }}
              className="flex-1 py-2.5 rounded-xl bg-[#FD7A02] text-white font-bold text-xs hover:bg-[#E06900] shadow-md shadow-orange-500/20 cursor-pointer"
            >
              Acknowledge & Continue
            </button>
            <button
              onClick={onClose}
              className="py-2.5 px-4 rounded-xl bg-slate-100 text-slate-700 font-bold text-xs hover:bg-slate-200 cursor-pointer"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Calculate score
  let correctCount = 0;
  questions.forEach((q, idx) => {
    if (selectedAnswers[idx] === q.correct_option_index) {
      correctCount++;
    }
  });

  const scorePercentage = Math.round((correctCount / totalQuestions) * 100);
  const hasPassed = scorePercentage >= passingScore;

  const handleSelectOption = (optionIndex) => {
    if (submitted) return;
    setSelectedAnswers({
      ...selectedAnswers,
      [currentIdx]: optionIndex,
    });
  };

  const handleNext = () => {
    if (currentIdx < totalQuestions - 1) {
      setCurrentIdx(currentIdx + 1);
    }
  };

  const handlePrev = () => {
    if (currentIdx > 0) {
      setCurrentIdx(currentIdx - 1);
    }
  };

  const handleSubmit = () => {
    setSubmitted(true);
    if (hasPassed) {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 },
      });
      onPassExam(scorePercentage);
    }
  };

  const handleRetake = () => {
    setSelectedAnswers({});
    setSubmitted(false);
    setCurrentIdx(0);
  };

  const currentQuestion = questions[currentIdx];
  const isLastQuestion = currentIdx === totalQuestions - 1;
  const allAnswered = Object.keys(selectedAnswers).length === totalQuestions;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-sm overflow-y-auto">
      <div className="relative w-full max-w-2xl bg-white border border-slate-200/80 rounded-3xl p-6 sm:p-8 shadow-2xl my-8">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-100">
          <div>
            <div className="flex items-center gap-2">
              <span className="text-[10px] font-extrabold uppercase tracking-wider px-2 py-0.5 rounded-full bg-orange-50 text-[#FD7A02] border border-orange-200">
                Module Assessment
              </span>
              <span className="text-xs font-bold text-slate-500">
                Passing Mark: <strong className="text-[#082658]">{passingScore}%</strong>
              </span>
            </div>
            <h3 className="text-lg font-extrabold text-[#082658] mt-1">{module.title}</h3>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Progress Bar */}
        <div className="pt-4 space-y-1.5">
          <div className="flex items-center justify-between text-xs font-semibold text-slate-500">
            <span>Question {currentIdx + 1} of {totalQuestions}</span>
            <span>{Math.round(((currentIdx + 1) / totalQuestions) * 100)}% Answered</span>
          </div>
          <div className="w-full h-2 bg-slate-100 rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-orange-500 to-amber-500 transition-all duration-300 rounded-full"
              style={{ width: `${((currentIdx + 1) / totalQuestions) * 100}%` }}
            />
          </div>
        </div>

        {/* Submission Result Screen */}
        {submitted ? (
          <div className="py-6 space-y-6 text-center">
            <div className={`w-20 h-20 rounded-3xl mx-auto flex items-center justify-center shadow-lg ${
              hasPassed
                ? 'bg-emerald-100 text-emerald-600 border border-emerald-200'
                : 'bg-red-100 text-red-600 border border-red-200'
            }`}>
              {hasPassed ? <Sparkles className="w-10 h-10" /> : <XCircle className="w-10 h-10" />}
            </div>

            <div className="space-y-1">
              <h2 className={`text-2xl font-extrabold ${hasPassed ? 'text-emerald-700' : 'text-red-700'}`}>
                {hasPassed ? 'Assessment Passed!' : 'Assessment Not Passed'}
              </h2>
              <p className="text-sm text-slate-600">
                {hasPassed
                  ? `Outstanding achievement! You scored ${scorePercentage}% and proved your operational competence.`
                  : `You scored ${scorePercentage}%. You need at least ${passingScore}% to earn accreditation credit.`
                }
              </p>
            </div>

            {/* Score Metric Card */}
            <div className="max-w-xs mx-auto p-4 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-around">
              <div>
                <p className="text-[10px] font-bold uppercase text-slate-400">Your Score</p>
                <p className="text-2xl font-extrabold text-[#082658]">{scorePercentage}%</p>
              </div>
              <div className="h-8 w-px bg-slate-200" />
              <div>
                <p className="text-[10px] font-bold uppercase text-slate-400">Correct Answers</p>
                <p className="text-2xl font-extrabold text-emerald-600">{correctCount} / {totalQuestions}</p>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
              {hasPassed ? (
                <button
                  onClick={onClose}
                  className="w-full sm:w-auto px-8 py-3 rounded-xl bg-[#082658] hover:bg-[#05193B] text-white font-extrabold text-xs transition shadow-md cursor-pointer"
                >
                  Continue Course
                </button>
              ) : (
                <>
                  <button
                    onClick={handleRetake}
                    className="w-full sm:w-auto px-6 py-3 rounded-xl bg-[#FD7A02] hover:bg-[#E06900] text-white font-extrabold text-xs transition shadow-md flex items-center justify-center gap-2 cursor-pointer"
                  >
                    <RotateCcw className="w-4 h-4" /> Retake Examination
                  </button>
                  <button
                    onClick={onClose}
                    className="w-full sm:w-auto px-6 py-3 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-extrabold text-xs transition cursor-pointer"
                  >
                    Review Lesson Material
                  </button>
                </>
              )}
            </div>
          </div>
        ) : (
          /* Question Form */
          <div className="py-4 space-y-6">
            
            {/* Question Card */}
            <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200/80">
              <span className="text-[10px] font-extrabold uppercase tracking-wider text-slate-400 block mb-1">
                Question #{currentIdx + 1}
              </span>
              <p className="text-base font-bold text-[#082658] leading-relaxed">
                {currentQuestion.question_text}
              </p>
            </div>

            {/* Answer Options */}
            <div className="space-y-3">
              {currentQuestion.options.map((option, optIdx) => {
                const isSelected = selectedAnswers[currentIdx] === optIdx;

                return (
                  <button
                    key={optIdx}
                    onClick={() => handleSelectOption(optIdx)}
                    className={`w-full p-4 rounded-xl text-left transition flex items-center justify-between border cursor-pointer ${
                      isSelected
                        ? 'bg-orange-50/80 border-2 border-[#FD7A02] text-[#082658] shadow-xs'
                        : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <div className={`w-7 h-7 rounded-lg flex items-center justify-center text-xs font-bold ${
                        isSelected
                          ? 'bg-[#FD7A02] text-white'
                          : 'bg-slate-100 text-slate-500'
                      }`}>
                        {String.fromCharCode(65 + optIdx)}
                      </div>
                      <span className="text-xs sm:text-sm font-semibold">{option}</span>
                    </div>

                    <div className={`w-5 h-5 rounded-full border flex items-center justify-center ${
                      isSelected
                        ? 'border-[#FD7A02] bg-[#FD7A02] text-white'
                        : 'border-slate-300'
                    }`}>
                      {isSelected && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                    </div>
                  </button>
                );
              })}
            </div>

            {/* Navigation & Submit Bar */}
            <div className="pt-4 border-t border-slate-100 flex items-center justify-between gap-3">
              <button
                onClick={handlePrev}
                disabled={currentIdx === 0}
                className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-slate-100 text-slate-600 font-bold text-xs hover:bg-slate-200 disabled:opacity-40 disabled:cursor-not-allowed transition cursor-pointer"
              >
                <ArrowLeft className="w-4 h-4" /> Previous
              </button>

              {isLastQuestion ? (
                <button
                  onClick={handleSubmit}
                  disabled={!allAnswered}
                  className="flex items-center gap-2 px-6 py-2.5 rounded-xl bg-[#FD7A02] hover:bg-[#E06900] text-white font-extrabold text-xs transition shadow-md shadow-orange-500/20 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                >
                  <Award className="w-4 h-4" /> Submit Assessment
                </button>
              ) : (
                <button
                  onClick={handleNext}
                  className="flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-[#082658] hover:bg-[#05193B] text-white font-bold text-xs transition cursor-pointer"
                >
                  Next <ArrowRight className="w-4 h-4" />
                </button>
              )}
            </div>

          </div>
        )}

      </div>
    </div>
  );
}
