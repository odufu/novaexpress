import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class ScanToCollectPage extends StatefulWidget {
  const ScanToCollectPage({super.key});

  @override
  State<ScanToCollectPage> createState() => _ScanToCollectPageState();
}

class _ScanToCollectPageState extends State<ScanToCollectPage> with SingleTickerProviderStateMixin {
  late AnimationController _scanAnimationController;
  final TextEditingController _manualController = TextEditingController();
  bool _isFlashlightOn = false;
  bool _isScanned = false;
  String _scannedTrackingNo = 'TRK-8924-NIG';

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _triggerSimulatedScan() {
    setState(() {
      _isScanned = true;
    });
  }

  void _showManualEntryDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          'Enter Tracking Number',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: _manualController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: const InputDecoration(
            hintText: 'e.g. TRK-8924-NIG',
            prefixIcon: Icon(Icons.qr_code_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () {
              if (_manualController.text.trim().isNotEmpty) {
                setState(() {
                  _scannedTrackingNo = _manualController.text.trim().toUpperCase();
                  _isScanned = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'SCAN CENTER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashlightOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: _isFlashlightOn ? AppColors.orange : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isFlashlightOn = !_isFlashlightOn;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Simulated Camera Reticle & Scanner
          Center(
            child: GestureDetector(
              onTap: _triggerSimulatedScan,
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  children: [
                    // Corner Brackets
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.orange, width: 4),
                            left: BorderSide(color: AppColors.orange, width: 4),
                          ),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.orange, width: 4),
                            right: BorderSide(color: AppColors.orange, width: 4),
                          ),
                          borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.orange, width: 4),
                            left: BorderSide(color: AppColors.orange, width: 4),
                          ),
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.orange, width: 4),
                            right: BorderSide(color: AppColors.orange, width: 4),
                          ),
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
                        ),
                      ),
                    ),

                    // Scanning Line Animation
                    AnimatedBuilder(
                      animation: _scanAnimationController,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanAnimationController.value * 276,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            color: AppColors.orange,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instruction Text
          const Positioned(
            bottom: 120,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(
                  'Align QR or Barcode',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap screen or scan automatically',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Manual Entry Button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3133),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showManualEntryDialog,
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('ENTER TRACKING NUMBER MANUALLY'),
              ),
            ),
          ),

          // Scanned Success Sheet Overlay
          if (_isScanned)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00522A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Package Scanned',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Verified & ready for DC intake',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TRACKING NUMBER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$_scannedTrackingNo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          context.pop();
                        },
                        child: const Text(
                          'CONFIRM INTAKE & RECEIVE STOCK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(color: theme.colorScheme.onSurfaceVariant, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isScanned = false;
                          });
                        },
                        child: const Text(
                          'RESCAN PACKAGE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
