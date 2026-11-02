import React, { useState } from 'react';
import { Award, CheckCircle, Copy, Download, Printer, Share2, ShieldCheck, X, QrCode } from 'lucide-react';

export default function CertificateModal({ cert, onClose }) {
  const [copied, setCopied] = useState(false);

  if (!cert) return null;

  const verificationUrl = `${window.location.origin}/verify/${cert.certificate_code}`;

  const copyLink = () => {
    navigator.clipboard.writeText(verificationUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  };

  const handlePrint = () => {
    window.print();
  };

  const formattedDate = cert.issued_at
    ? new Date(cert.issued_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })
    : '28 October 2026';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/70 backdrop-blur-sm overflow-y-auto">
      <div className="relative w-full max-w-4xl bg-white border border-slate-200/80 rounded-3xl p-4 sm:p-8 shadow-2xl my-8">
        
        {/* Top Action Bar */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-200 no-print">
          <div className="flex items-center gap-2.5">
            <span className="p-2 rounded-xl bg-orange-50 text-[#FD7A02] border border-orange-200">
              <Award className="w-5 h-5" />
            </span>
            <div>
              <h2 className="text-base font-extrabold text-[#082658]">Official NovaXpress Credential</h2>
              <p className="text-xs text-slate-500">Tamper-evident verifiable digital accreditation</p>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <button
              onClick={handlePrint}
              className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold rounded-xl bg-slate-100 text-[#082658] border border-slate-200 hover:bg-slate-200 transition cursor-pointer"
            >
              <Printer className="w-4 h-4 text-[#FD7A02]" />
              <span className="hidden sm:inline">Print / Save PDF</span>
            </button>
            <button
              onClick={copyLink}
              className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold rounded-xl bg-[#FD7A02] text-white hover:bg-[#E06900] transition shadow-md shadow-orange-500/20 cursor-pointer"
            >
              {copied ? <CheckCircle className="w-4 h-4 text-white" /> : <Copy className="w-4 h-4" />}
              <span>{copied ? 'Link Copied!' : 'Copy Verification URL'}</span>
            </button>
            <button
              onClick={onClose}
              className="p-2 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Certificate Printable Canvas */}
        <div 
          id="certificate-print-area"
          className="mt-6 p-8 sm:p-12 rounded-2xl bg-white border-8 border-double border-[#082658] relative overflow-hidden text-center shadow-lg"
        >
          {/* Subtle Watermark Background */}
          <div className="absolute inset-0 flex items-center justify-center opacity-[0.03] pointer-events-none">
            <Award className="w-96 h-96 text-[#082658]" />
          </div>

          {/* Certificate Header */}
          <div className="relative z-10 flex flex-col items-center">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-[#FD7A02] to-[#E06900] flex items-center justify-center shadow-xl shadow-orange-500/20 mb-3">
              <Award className="w-8 h-8 text-white" />
            </div>
            
            <p className="text-xs uppercase tracking-[0.25em] font-extrabold text-[#FD7A02]">
              NovaXpress Logistics Platform
            </p>
            <h1 className="text-2xl sm:text-4xl font-extrabold text-[#082658] mt-1 tracking-tight">
              Certificate of Professional Competency
            </h1>
            <p className="text-xs sm:text-sm text-slate-600 mt-2 max-w-xl">
              This officially certifies that the named logistics candidate has successfully fulfilled all technical prerequisites, practical course modules, and passing examination requirements.
            </p>
          </div>

          {/* Recipient Name */}
          <div className="relative z-10 my-8 py-5 border-y-2 border-slate-200">
            <p className="text-xs font-bold uppercase tracking-wider text-slate-400">Awarded With Honors To</p>
            <h2 className="text-3xl sm:text-5xl font-extrabold text-[#082658] mt-2 tracking-wide font-serif">
              {cert.recipient_name}
            </h2>
            <p className="text-xs text-slate-500 font-mono mt-1">{cert.user_email}</p>
          </div>

          {/* Accreditation Role Title */}
          <div className="relative z-10 flex flex-col items-center">
            <div className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-orange-50 border border-orange-200 text-[#FD7A02] text-sm sm:text-base font-extrabold tracking-wide">
              <ShieldCheck className="w-5 h-5 text-[#FD7A02]" />
              {cert.certification_title}
            </div>
            <p className="text-xs text-slate-500 mt-3 max-w-lg">
              Authorized pursuant to the operational training standards of NovaXpress Delivery & Warehousing Network, Nigeria.
            </p>
          </div>

          {/* Footer Metadata & Dual Signatures */}
          <div className="relative z-10 mt-10 pt-6 border-t border-slate-200 grid grid-cols-1 sm:grid-cols-3 gap-6 items-end">
            
            {/* Signature 1 */}
            <div className="text-center sm:text-left">
              <div className="w-36 h-10 mx-auto sm:mx-0 border-b border-slate-400 flex items-center justify-center italic text-slate-600 font-serif text-sm">
                A. Babatunde
              </div>
              <p className="text-xs font-bold text-[#082658] mt-1.5">Director of Training</p>
              <p className="text-[10px] text-slate-400">NovaXpress Academy</p>
            </div>

            {/* Certificate ID & QR Code */}
            <div className="flex flex-col items-center justify-center p-3 rounded-xl bg-slate-50 border border-slate-200">
              <div className="w-12 h-12 bg-white rounded-lg border border-slate-200 p-1 flex items-center justify-center mb-1">
                <QrCode className="w-9 h-9 text-[#082658]" />
              </div>
              <p className="text-[10px] font-bold uppercase text-slate-400">Certificate ID</p>
              <p className="text-xs font-mono font-extrabold text-[#FD7A02] tracking-wider">
                {cert.certificate_code}
              </p>
              <p className="text-[9px] text-slate-400 mt-0.5">Issued: {formattedDate}</p>
            </div>

            {/* Signature 2 */}
            <div className="text-center sm:text-right">
              <div className="w-36 h-10 mx-auto sm:ml-auto border-b border-slate-400 flex items-center justify-center italic text-slate-600 font-serif text-sm">
                J. Odufu
              </div>
              <p className="text-xs font-bold text-[#082658] mt-1.5">Managing Director</p>
              <p className="text-[10px] text-slate-400">NovaXpress Logistics</p>
            </div>

          </div>

        </div>

      </div>
    </div>
  );
}
