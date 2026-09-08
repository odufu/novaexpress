/// Centralized Asset Manifest for NovaXpress Presentation Architecture
/// Adheres strictly to Section 7, 8, and 9 of docs/presentation.md
class AppAssets {
  AppAssets._();

  // Branding
  static const String logo = 'assets/branding/novaxpress_logo.png';

  // Backgrounds
  static const String menuBackground = 'assets/backgrounds/menu_background_16x9.webp';
  static const String presentationBackground = 'assets/backgrounds/presentation_background_16x9.webp';

  // Core Command Center
  static const String centralCore = 'assets/core/central_core_transparent_1x1.png';

  // 3D Platform Bases
  static const String featurePlatform = 'assets/platforms/feature_platform_base_transparent_1x1.png';

  // Feature Icons
  static const String ordersIcon = 'assets/feature_icons/orders_icon_transparent_1x1.png';
  static const String scalingIcon = 'assets/feature_icons/scaling_icon_transparent_1x1.png';
  static const String structureIcon = 'assets/feature_icons/structure_icon_transparent_1x1.png';
  static const String paymentsIcon = 'assets/feature_icons/payments_icon_transparent_1x1.png';
  static const String remitanceIcon = 'assets/feature_icons/remitance_icon_transparent_1x1.png';
  static const String sockIcon = 'assets/feature_icons/sock_icon_transparent_1x1.png';

  // Hover & Ambient Particles
  static const String hoverGlow = 'assets/hover/hover_glow_transparent_1x1.png';
  static const String selectionRing = 'assets/hover/selection_ring_transparent_1x1.png';
  static const String particleOrange = 'assets/hover/particle_orange_transparent_1x1.png';

  // Presentation Heroes (16:9)
  static const String ordersHero = 'assets/heroes/orders_hero_transparent_16x9.png';
  static const String scalingHero = 'assets/heroes/scaling_hero_transparent_16x9.png';
  static const String structureHero = 'assets/heroes/structure_hero_transparent_16x9.png';
  static const String paymentsHero = 'assets/heroes/payments_hero_transparent_16x9.png';
  static const String remitanceHero = 'assets/heroes/remitance_hero_transparent_16x9.png';
  static const String sockHero = 'assets/heroes/sock_hero_transparent_16x9.png';

  // UI Elements
  static const String glassPanel = 'assets/ui/glass_panel_transparent_16x9.png';
  static const String arrowOrange = 'assets/ui/arrow_orange_transparent_1x1.png';

  /// Authoritative list of assets physically present on disk in this build.
  /// Any asset not present in this set will gracefully trigger the developer placeholder
  /// and report the exact semantic path required (Sections 8 & 29).
  static const Set<String> presentAssets = {
    logo,
    centralCore,
    featurePlatform,
    ordersIcon,
    scalingIcon,
    remitanceIcon,
    sockIcon,
    hoverGlow,
    particleOrange,
    glassPanel,
    arrowOrange,
  };

  /// Returns true if the asset file exists on disk and is ready for rendering
  static bool isAvailable(String assetPath) {
    return presentAssets.contains(assetPath);
  }
}
