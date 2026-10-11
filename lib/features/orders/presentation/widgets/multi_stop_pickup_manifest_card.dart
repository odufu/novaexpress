import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/client_package_pickup.dart';

class MultiStopPickupManifestCard extends StatefulWidget {
  final OrderEntity order;
  final VoidCallback onOrderDelivered;

  const MultiStopPickupManifestCard({
    super.key,
    required this.order,
    required this.onOrderDelivered,
  });

  @override
  State<MultiStopPickupManifestCard> createState() => _MultiStopPickupManifestCardState();
}

class _MultiStopPickupManifestCardState extends State<MultiStopPickupManifestCard> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<ClientPackagePickupEntity> _stops = [];

  @override
  void initState() {
    super.initState();
    _fetchPickupStops();
  }

  Future<void> _fetchPickupStops() async {
    try {
      final res = await _supabase
          .from('client_package_pickups')
          .select()
          .eq('order_id', widget.order.id)
          .order('stop_sequence', ascending: true);

      if (mounted) {
        setState(() {
          _stops = (res as List)
              .map((row) => ClientPackagePickupEntity.fromMap(Map<String, dynamic>.from(row)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openBarcodeScanDialog(ClientPackagePickupEntity stop) async {
    final barcodeController = TextEditingController(text: stop.sealedBagRef);
    bool isVerifying = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFF334155), width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scan Sealed Bag Barcode',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location: ${stop.locationName}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expected Bag Reference: ${stop.sealedBagRef}',
                    style: GoogleFonts.firaCode(fontSize: 12, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: barcodeController,
                    style: GoogleFonts.firaCode(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Scanned Bag Barcode / QR',
                      labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                      hintText: 'e.g. BAG-CC-99014-A',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(errorMessage!, style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final scannedCode = barcodeController.text.trim();
                          if (scannedCode.isEmpty) return;

                          setDialogState(() {
                            isVerifying = true;
                            errorMessage = null;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final res = await _supabase.rpc('fn_verify_pickup_bag_scan', params: {
                              'p_pickup_id': stop.id,
                              'p_scanned_bag_ref': scannedCode,
                            });

                            if (res['success'] == true) {
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              await _fetchPickupStops();
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Bag verified and marked collected!', style: GoogleFonts.inter(color: Colors.white)),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                isVerifying = false;
                                errorMessage = res['message']?.toString() ?? 'Barcode verification failed.';
                              });
                            }
                          } catch (err) {
                            setDialogState(() {
                              isVerifying = false;
                              errorMessage = 'Error: $err';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Verify Bag', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openOtpVerificationDialog() async {
    final otpController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFF334155), width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recipient WhatsApp OTP',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask recipient (${widget.order.customerName}) for the 4-digit handover OTP sent to their WhatsApp line.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.firaCode(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: GoogleFonts.firaCode(color: const Color(0xFF64748B), fontSize: 24, letterSpacing: 8),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final enteredOtp = otpController.text.trim();
                          if (enteredOtp.length < 4) return;

                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final res = await _supabase.rpc('fn_verify_delivery_otp_and_complete', params: {
                              'p_order_id': widget.order.id,
                              'p_entered_otp': enteredOtp,
                              'p_agent_id': widget.order.deliveryAgentId ?? 'b1111111-1111-4111-8111-111111111111',
                            });

                            if (res['success'] == true) {
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              widget.onOrderDelivered();
                              if (mounted) {
                                final allowance = res['rider_credited_amount'] ?? 0;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Delivery verified! ₦$allowance credited to your wallet.', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                errorText = res['message']?.toString() ?? 'Invalid OTP code.';
                              });
                            }
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = 'Verification failed: $err';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Confirm Handover', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (_stops.isEmpty) return const SizedBox.shrink();

    final allCollected = _stops.every((s) => s.isCollected);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Multi-Stop Sourcing Itinerary',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_stops.length} Pickup Stops',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sequential Itinerary Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stops.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final stop = _stops[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: stop.isCollected ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: stop.isCollected ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: stop.isCollected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '${stop.stopSequence}',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stop.locationName,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stop.pickupAddress,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        if (stop.isCollected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'COLLECTED',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => _openBarcodeScanDialog(stop),
                            icon: const Icon(Icons.qr_code_scanner, size: 14),
                            label: Text('Scan Bag', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              elevation: 0,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Contact & WhatsApp row
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(stop.contactPerson, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1))),
                        const Spacer(),
                        if (stop.contactWhatsapp != null) ...[
                          InkWell(
                            onTap: () {
                              final phone = stop.contactWhatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
                              launchUrl(Uri.parse('https://wa.me/$phone'));
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.chat_rounded, size: 13, color: Color(0xFF25D366)),
                                const SizedBox(width: 4),
                                Text('WhatsApp', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF25D366), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Final Doorstep Action Button
          if (allCollected) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openOtpVerificationDialog,
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: Text('Verify Recipient OTP & Complete Delivery', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scan all dispensary sealed bags before heading to the recipient doorstep.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
