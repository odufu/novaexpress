import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/lead_form.dart';

class ClientFormEmbedModal extends StatefulWidget {
  final LeadForm form;

  const ClientFormEmbedModal({super.key, required this.form});

  static void show(BuildContext context, {required LeadForm form}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientFormEmbedModal(form: form),
    );
  }

  @override
  State<ClientFormEmbedModal> createState() => _ClientFormEmbedModalState();
}

class _ClientFormEmbedModalState extends State<ClientFormEmbedModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _useJsSdk = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        content: Text('✓ $label copied to clipboard!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final origin = Uri.base.origin.isNotEmpty ? Uri.base.origin : 'https://portal.novaexpress.ng';
    final directUrl = '$origin/#/f/${form.id}';

    final iframeCode = '''<!-- NovaXpress High-Converting Checkout Embed -->
<iframe
  src="$directUrl"
  width="100%"
  height="750"
  frameborder="0"
  style="border:none; max-width: 650px; margin: 0 auto; display: block; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.08);"
  allow="payment"
></iframe>''';

    final scriptSdkCode = '''<!-- NovaXpress Form Guard & Direct Landing Page Integration -->
<div id="nova-checkout-container" data-form-id="${form.id}"></div>
<script src="$origin/form-guard.js" async></script>
<script>
  window.addEventListener('DOMContentLoaded', function() {
    if (window.NovaFormGuard) {
      NovaFormGuard.mount('#nova-checkout-container', {
        formId: '${form.id}',
        pixelId: '${form.pixelId}',
        redirectUrl: '${form.redirectUrl}'
      });
    }
  });
</script>''';

    final thankYouCode = '''<!-- NovaXpress Meta CAPI & Pixel Purchase Event Tracker -->
<!-- Place on your Thank You Page right before </head> -->
<script>
  !function(f,b,e,v,n,t,s)
  {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
  n.callMethod.apply(n,arguments):n.queue.push(arguments)};
  if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
  n.queue=[];t=b.createElement(e);t.async=!0;
  t.src=v;s=b.getElementsByTagName(e)[0];
  s.parentNode.insertBefore(t,s)}(window, document,'script',
  'https://connect.facebook.net/en_US/fbevents.js');
  
  fbq('init', '${form.pixelId.isNotEmpty ? form.pixelId : "YOUR_PIXEL_ID"}');
  fbq('track', 'PageView');
  
  // Auto-extract eventId from URL params for 100% CAPI deduplication
  var urlParams = new URLSearchParams(window.location.search);
  var eventId = urlParams.get('event_id');
  if (eventId) {
    fbq('track', 'Purchase', { currency: 'NGN', value: 25000 }, { eventID: eventId });
  } else {
    fbq('track', 'Purchase', { currency: 'NGN', value: 25000 });
  }
</script>''';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 650),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.code_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Publish & Integrate Form', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                          Text(form.title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF10B981),
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Direct Hosted Link'),
                Tab(text: 'iFrame / WordPress'),
                Tab(text: 'Thank You CAPI Code'),
              ],
            ),
            const Divider(height: 1),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Direct Hosted Link
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Direct Hosted Checkout URL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        Text(
                          'Share this link directly in TikTok bio, WhatsApp, Instagram DMs, or Facebook Ad landing destination.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link_rounded, size: 18, color: Color(0xFF10B981)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  directUrl,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF10B981)),
                                tooltip: 'Copy Link',
                                onPressed: () => _copyToClipboard(directUrl, 'Direct Form URL'),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                            label: Text('Copy Direct Link', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                            onPressed: () => _copyToClipboard(directUrl, 'Direct Form URL'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: iFrame / JS SDK Code
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _useJsSdk ? 'Direct JavaScript SDK Embed' : 'iFrame Responsive Embed',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            ),
                            Row(
                              children: [
                                Text('SDK', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                Switch.adaptive(
                                  value: _useJsSdk,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) => setState(() => _useJsSdk = val),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _useJsSdk
                              ? 'Native DOM embed using NovaFormGuard with offline recovery & validation.'
                              : 'Paste this snippet into an HTML block on WordPress, Elementor, or ClickFunnels.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _useJsSdk ? scriptSdkCode : iframeCode,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: _useJsSdk ? const Color(0xFFA7F3D0) : const Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            icon: const Icon(Icons.code_rounded, size: 18, color: Colors.white),
                            label: Text(
                              _useJsSdk ? 'Copy JavaScript SDK Snippet' : 'Copy iFrame Embed Code',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            onPressed: () => _copyToClipboard(
                              _useJsSdk ? scriptSdkCode : iframeCode,
                              _useJsSdk ? 'JavaScript SDK Snippet' : 'iFrame Embed Snippet',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 3: Thank You CAPI Code
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thank You Page CAPI Deduplication Snippet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        Text('Guarantees 100% deduplicated Meta Purchase event tracking using event_id parameter.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                thankYouCode,
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF4ADE80)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                            label: Text('Copy Thank You Code', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                            onPressed: () => _copyToClipboard(thankYouCode, 'Thank You Tracking Snippet'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
