import React, { useState } from 'react';
import { Play, CheckCircle2, Clock, Volume2, ShieldCheck, Video } from 'lucide-react';

export default function VideoPlayer({ videoUrl, duration, title, onComplete, isCompleted }) {
  const [markedDone, setMarkedDone] = useState(isCompleted);

  const handleMarkComplete = () => {
    setMarkedDone(true);
    if (onComplete) onComplete();
  };

  const isYouTube = videoUrl && (videoUrl.includes('youtube.com') || videoUrl.includes('youtu.be'));
  const isVimeo = videoUrl && videoUrl.includes('vimeo.com');

  return (
    <div className="rounded-2xl bg-white border border-slate-200/80 overflow-hidden shadow-sm hover:shadow-md transition-shadow">
      
      {/* Video Viewport (16:9 Cinema Ratio) */}
      <div className="relative w-full aspect-video bg-slate-950 flex items-center justify-center overflow-hidden">
        {videoUrl ? (
          isYouTube || isVimeo ? (
            <iframe
              src={videoUrl}
              title={title || 'Module Training Video'}
              className="w-full h-full border-0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              allowFullScreen
            />
          ) : (
            <video
              src={videoUrl}
              controls
              className="w-full h-full object-contain"
              onEnded={handleMarkComplete}
            >
              Your browser does not support the video tag.
            </video>
          )
        ) : (
          /* High-End Video Placeholder */
          <div className="relative w-full h-full flex flex-col items-center justify-center p-6 text-center bg-gradient-to-b from-slate-900 to-[#082658]/90 text-white select-none">
            {/* Background Grid Pattern */}
            <div className="absolute inset-0 opacity-10 bg-[radial-gradient(#FD7A02_1px,transparent_1px)] [background-size:16px_16px] pointer-events-none" />
            
            <div className="relative z-10 max-w-md space-y-3">
              <div className="w-16 h-16 rounded-2xl bg-[#FD7A02] text-white mx-auto flex items-center justify-center shadow-xl shadow-orange-500/30 group hover:scale-105 transition cursor-pointer">
                <Play className="w-7 h-7 ml-1 fill-white" />
              </div>
              <div>
                <span className="text-[11px] font-extrabold uppercase tracking-widest text-orange-400 bg-orange-500/10 px-2.5 py-0.5 rounded-full border border-orange-500/20">
                  Interactive Training Module
                </span>
                <h4 className="text-base sm:text-lg font-bold text-white mt-1.5">{title}</h4>
                <p className="text-xs text-slate-300 mt-1 max-w-sm mx-auto leading-relaxed">
                  Video screen recording will stream here. Read through the core objectives and full transcript below, then complete the examination.
                </p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Video Sub-bar */}
      <div className="px-5 py-3.5 bg-slate-50 border-t border-slate-200/80 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <span className="flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white text-[#082658] text-xs font-bold border border-slate-200 shadow-2xs">
            <Clock className="w-3.5 h-3.5 text-[#FD7A02]" />
            {duration || '15 mins'}
          </span>
          <span className="text-xs text-slate-500 font-medium hidden sm:inline">
            Official NovaXpress Operational Standard
          </span>
        </div>

        <div>
          {markedDone ? (
            <div className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-bold">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              Lesson Viewed
            </div>
          ) : (
            <button
              onClick={handleMarkComplete}
              className="flex items-center gap-1.5 px-4 py-1.5 rounded-xl bg-[#FD7A02] hover:bg-[#E06900] text-white text-xs font-bold transition shadow-xs shadow-orange-500/20 cursor-pointer"
            >
              <CheckCircle2 className="w-4 h-4" />
              Mark Lesson as Watched
            </button>
          )}
        </div>
      </div>

    </div>
  );
}
