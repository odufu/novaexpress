# NovaXpress Logistics - Interactive 3D Presentation Specification

You are the lead Flutter engineer, creative technologist, interaction designer, and motion designer for a premium NovaXpress Logistics product presentation application.

Your task is to build a highly interactive, cinematic, modern 3D-style feature navigation experience in Flutter.

This is NOT a conventional dashboard.

It should feel like an interactive product showcase / technology presentation with a premium logistics-tech aesthetic.

==================================================
1. PRODUCT
==================================================

Brand:
NovaXpress Logistics

The application presents six major NovaXpress capabilities:

1. Orders
2. Scaling
3. Structure
4. Payments
5. Remitance
6. Sock

IMPORTANT:
Use the exact visible feature labels above for now.

However, make the internal feature configuration data-driven so that "Remitance" can later be changed to "Remittance" and "Sock" can later be changed to "Stock" without changing the architecture.

The NovaXpress logo supplied in the assets folder is the authoritative brand logo.

Do NOT recreate, redraw, reinterpret, distort, or generate a replacement logo.

==================================================
2. PRIMARY EXPERIENCE
==================================================

The application begins on an immersive feature ecosystem screen.

The screen contains:

- cinematic logistics-tech background
- central NovaXpress command core
- six floating feature platforms
- 3D-style feature icons
- subtle glowing connection/orbit paths
- ambient particles
- depth-of-field simulation
- subtle platform floating animations

The central NovaXpress core is NOT another menu item.

It is the visual command center / brand anchor.

The six feature platforms orbit around it.

The visual hierarchy must always be:

1. selected feature
2. central NovaXpress core
3. surrounding features
4. background environment

==================================================
3. VISUAL STYLE
==================================================

Design language:

Premium enterprise technology.

Not a gaming UI.

Not a generic SaaS dashboard.

Not a cyberpunk interface.

Not overly neon.

The aesthetic should feel:

- sophisticated
- cinematic
- futuristic
- clean
- premium
- trustworthy
- technological
- logistics-oriented

Brand palette:

Primary navy:
#071A3D

Deep navy:
#031126

NovaXpress orange:
#FF7A00

Bright orange:
#FF9800

White:
#FFFFFF

Cool glass:
rgba(255,255,255,0.08)

Use orange primarily for:

- active states
- glowing edges
- connection paths
- CTA buttons
- selected feature
- highlights

Use navy for:

- platforms
- panels
- cards
- shadows
- navigation

Avoid excessive orange.

==================================================
4. MENU SCREEN
==================================================

Create a responsive immersive menu screen.

Desktop / large screen:

The central NovaXpress core sits approximately in the center.

Six feature platforms surround it.

Suggested initial arrangement:

                ORDERS

        SCALING         STRUCTURE


                 CORE


        PAYMENTS       REMITANCE

                  SOCK

The exact positions should be calculated responsively rather than hardcoded to one screen resolution.

Use a responsive coordinate/layout system.

The composition should maintain visual balance across:

- 16:9 desktop
- 16:10 desktop
- tablet landscape

Do not simply use six Expanded widgets.

The positions should feel spatial and cinematic.

==================================================
5. CENTRAL CORE
==================================================

Create a dedicated CentralCore widget.

The core should:

- use the supplied NovaXpress core asset
- appear slightly larger than all feature platforms
- have subtle continuous breathing animation
- have subtle orange ambient glow
- have subtle vertical floating movement
- remain visually stable
- act as the visual anchor

The core must NOT compete with the selected feature.

When a feature is selected:

- core slightly dims
- core moves slightly backward
- surrounding environment becomes softer
- selected feature becomes dominant

==================================================
6. FEATURE PLATFORM
==================================================

Create a reusable FeaturePlatform widget.

Do not create six independent widgets.

Use one reusable component driven by configuration.

Each platform has:

- 3D-style platform image
- feature icon
- feature title
- subtle orange rim glow
- shadow
- depth scaling
- hover animation
- selected animation
- tooltip
- click interaction

Feature configuration should look conceptually like:

FeatureItem(
  id: 'orders',
  title: 'Orders',
  iconAsset: ...,
  description: ...,
  heroAsset: ...,
)

Do not duplicate feature UI logic.

==================================================
7. ASSET ARCHITECTURE
==================================================

Use this exact folder structure:

assets/
  branding/
    novaxpress_logo.png

  backgrounds/
    menu_background_16x9.webp
    presentation_background_16x9.webp

  core/
    central_core_transparent_1x1.png

  platforms/
    feature_platform_base_transparent_1x1.png

  feature_icons/
    orders_icon_transparent_1x1.png
    scaling_icon_transparent_1x1.png
    structure_icon_transparent_1x1.png
    payments_icon_transparent_1x1.png
    remitance_icon_transparent_1x1.png
    sock_icon_transparent_1x1.png

  hover/
    hover_glow_transparent_1x1.png
    selection_ring_transparent_1x1.png
    particle_orange_transparent_1x1.png

  heroes/
    orders_hero_transparent_16x9.png
    scaling_hero_transparent_16x9.png
    structure_hero_transparent_16x9.png
    payments_hero_transparent_16x9.png
    remitance_hero_transparent_16x9.png
    sock_hero_transparent_16x9.png

  ui/
    glass_panel_transparent_16x9.png
    arrow_orange_transparent_1x1.png

All asset references must come from a centralized asset manifest/configuration.

Do not scatter raw asset paths throughout widgets.

==================================================
8. ASSET NAMING RULES
==================================================

Never use names such as:

image1.png
image2.png
final.png
final2.png
new.png
asset.png

Use semantic names.

Naming convention:

<feature>_<purpose>_<background>_<aspectratio>.<extension>

Examples:

orders_icon_transparent_1x1.png

orders_hero_transparent_16x9.png

feature_platform_base_transparent_1x1.png

menu_background_16x9.webp

central_core_transparent_1x1.png

This is important because additional visual assets will be added to the project later.

If an expected asset is missing:

DO NOT invent a replacement.

Instead:

1. identify the missing asset
2. create a clearly visible placeholder only during development
3. report the exact expected filename
4. continue implementing everything else

==================================================
9. ASSET MANIFEST
==================================================

Create:

lib/config/assets.dart

Centralize all asset paths.

Example:

class AppAssets {
  static const logo =
      'assets/branding/novaxpress_logo.png';

  static const menuBackground =
      'assets/backgrounds/menu_background_16x9.webp';

  static const centralCore =
      'assets/core/central_core_transparent_1x1.png';

  static const featurePlatform =
      'assets/platforms/feature_platform_base_transparent_1x1.png';

  static const ordersIcon =
      'assets/feature_icons/orders_icon_transparent_1x1.png';

  ...
}

Never hardcode paths elsewhere.

==================================================
10. HOVER EXPERIENCE
==================================================

Hover is one of the most important parts of the application.

Use MouseRegion / PointerRegion interaction for desktop/web.

When the pointer enters a feature:

1. platform smoothly scales up
2. platform moves slightly toward the camera
3. icon rises slightly
4. orange glow becomes stronger
5. feature becomes sharper
6. surrounding features become slightly smaller/dimmer
7. surrounding features receive subtle blur
8. tooltip card appears
9. connection line to the feature becomes brighter
10. selected feature receives visual focus

Animation should feel cinematic.

Avoid abrupt state changes.

Recommended animation duration:

250–500ms depending on animation type.

Use curves such as:

Curves.easeOutCubic
Curves.easeInOutCubic
Curves.easeOutBack

Do not overuse bounce effects.

==================================================
11. HOVER CARD
==================================================

Do NOT generate feature descriptions as images.

Build tooltip cards natively in Flutter.

Each card should be:

- glassmorphic
- dark translucent navy
- subtle border
- soft shadow
- orange accent
- rounded corners
- readable typography

Animation:

opacity:
0 -> 1

scale:
0.92 -> 1

translation:
slightly upward/downward -> neutral

blur:
slightly blurred -> sharp

The card should dynamically position itself relative to the feature.

It must not overflow the viewport.

==================================================
12. DEPTH OF FIELD
==================================================

Simulate cinematic camera depth.

Flutter does not need to use a full 3D engine.

Use:

- Transform
- Matrix4
- perspective
- scale
- opacity
- BackdropFilter
- ImageFilter.blur
- z-order
- animated translation

The visual rule is:

far:
small + dim + blurred

middle:
normal + slightly softened

hovered:
larger + bright + sharp

selected:
largest + sharp + dominant

Do not apply excessive blur.

The interface should remain usable.

==================================================
13. 3D TRANSFORM SYSTEM
==================================================

Build reusable spatial transformation logic.

Create something like:

FeatureTransformController

It should calculate:

- scale
- x position
- y position
- z/depth
- rotationX
- rotationY
- opacity
- blur amount
- glow intensity

Do not manually calculate these independently inside every widget.

Use a centralized spatial/depth model.

==================================================
14. CAMERA / SELECTION TRANSITION
==================================================

Clicking a feature must NOT instantly navigate to another page.

Instead create a cinematic transition.

Example:

User clicks Orders.

Phase 1:
- Orders enlarges
- Orders moves toward camera
- Orders becomes extremely sharp
- orange glow increases

Phase 2:
- other features move backward
- other features fade
- other features blur
- central core recedes

Phase 3:
- background subtly zooms
- camera/perspective shifts toward selected feature

Phase 4:
- selected feature expands beyond the normal menu bounds

Phase 5:
- presentation screen fades/slides into view

The transition should feel like the camera is moving through the feature.

Target duration:

800–1400ms.

Do not use a basic MaterialPageRoute alone.

==================================================
15. PRESENTATION SCREEN
==================================================

Every feature gets a reusable presentation layout.

Structure:

TOP NAVIGATION

NovaXpress logo on left.

Feature navigation across top:

Orders
Scaling
Structure
Payments
Remitance
Sock

Current feature receives:

- orange underline
- brighter text
- icon glow

Main content:

LEFT:

Feature title
Description
Feature benefits
CTA

RIGHT:

large 3D generated hero asset

The presentation screen should feel like a premium product reveal.

==================================================
16. PRESENTATION HEROES
==================================================

Heroes are image assets.

Flutter positions and animates them.

Example:

Orders hero:

- package
- tracking
- logistics
- warehouse context

Scaling hero:

- growth
- logistics network
- expansion
- rising performance

Structure hero:

- warehouse
- inventory
- infrastructure

Payments hero:

- payment technology
- card
- security
- transaction

Remitance hero:

- global transfer
- globe
- international logistics

Sock hero:

- use the final approved meaning and visual direction of this feature

Hero assets must support transparent compositing whenever possible.

==================================================
17. PRESENTATION SCREEN ANIMATION
==================================================

When presentation screen opens:

Hero asset:

opacity:
0 -> 1

scale:
0.85 -> 1

translation:
slightly right/down -> neutral

Text:

opacity:
0 -> 1

translation:
30px -> 0

Feature cards:

staggered entrance.

Do not animate every element simultaneously.

Use staggered cinematic timing.

==================================================
18. NAVIGATION
==================================================

The presentation screen must support:

- click navigation
- keyboard navigation
- swipe navigation on touch devices

Desktop:

Arrow Left / Arrow Right

should switch feature.

Escape:

returns to the ecosystem menu.

The browser back button should also behave sensibly if using Flutter web routing.

==================================================
19. TOUCH SUPPORT
==================================================

Hover does not exist on touch.

Therefore:

tap on a feature:

first tap:
focuses feature

second tap OR CTA:
opens presentation

Alternatively, if the interaction can remain intuitive:

tap:
focus + open after a short cinematic focus transition.

Do not rely exclusively on hover.

==================================================
20. KEYBOARD ACCESSIBILITY
==================================================

Support:

Tab
Arrow Left
Arrow Right
Enter
Escape

Provide semantic labels.

The experience can be visually cinematic while remaining accessible.

==================================================
21. RESPONSIVENESS
==================================================

Optimize primarily for:

Desktop web
Large tablets
Presentation displays

Support:

1920x1080
1600x900
1440x900
1280x800
1024x768

Do not assume 1920x1080.

Create responsive breakpoints.

At smaller widths:

reduce the number of visible surrounding platforms

or switch to a controlled spatial carousel.

Do not allow feature cards or platforms to overlap critical content.

==================================================
22. PERFORMANCE
==================================================

This is an animation-heavy experience.

Optimize carefully.

Use:

- RepaintBoundary
- const widgets where appropriate
- cached images
- precacheImage
- minimal rebuilds
- centralized animation controllers where practical
- avoid unnecessary opacity layers
- avoid excessive BackdropFilter usage
- avoid continuously rebuilding large widget trees

Do not create six independent animation loops if one controller can drive the ecosystem.

Target smooth 60fps.

Where supported, optimize for higher refresh rates.

==================================================
23. STATE MANAGEMENT
==================================================

Do not introduce heavy state management unless needed.

The initial implementation can use:

ValueNotifier
ChangeNotifier
AnimationController

or another lightweight solution.

Create a clear:

EcosystemState

containing:

hoveredFeature
focusedFeature
selectedFeature
isTransitioning
presentationFeature

==================================================
24. ARCHITECTURE
==================================================

Recommended structure:

lib/

  main.dart

  app/
    app.dart
    routes.dart
    theme.dart

  config/
    assets.dart
    features.dart
    constants.dart

  models/
    feature_item.dart

  screens/
    ecosystem_screen.dart
    feature_presentation_screen.dart

  widgets/
    central_core.dart
    feature_platform.dart
    feature_tooltip.dart
    orbit_layer.dart
    depth_layer.dart
    glass_panel.dart
    hero_scene.dart
    feature_navigation.dart

  animation/
    ecosystem_animation.dart
    feature_transition.dart
    depth_controller.dart

  painters/
    orbit_painter.dart
    particle_painter.dart

==================================================
25. FEATURE CONFIGURATION
==================================================

Create a single source of truth.

For example:

FeatureItem(
  id: 'orders',
  title: 'Orders',
  description: 'Create, track and manage your shipments easily.',
  iconAsset: AppAssets.ordersIcon,
  heroAsset: AppAssets.ordersHero,
)

Do the same for all six features.

Do not duplicate feature definitions across screens.

==================================================
26. VISUAL POLISH
==================================================

Pay particular attention to:

- spacing
- hierarchy
- shadows
- glow
- perspective
- easing
- depth
- typography
- visual rhythm

The application should not feel like Flutter widgets placed on top of a background.

It should feel like one cohesive spatial environment.

==================================================
27. IMPORTANT: DO NOT OVERBUILD
==================================================

Do NOT introduce:

- Unity
- Unreal
- Flame
- a full 3D game engine

unless absolutely necessary.

First achieve the visual experience using Flutter:

Stack
Transform
Matrix4
CustomPainter
BackdropFilter
ImageFilter
AnimationController
MouseRegion
GestureDetector
Hero
AnimatedBuilder

Use generated visual assets for complex 3D objects.

Use Flutter for interaction and animation.

==================================================
28. DEVELOPMENT PROCESS
==================================================

Do not immediately start generating arbitrary code.

First:

1. Inspect the existing Flutter project.
2. Inspect all files in assets/.
3. Identify which assets already exist.
4. Create the proposed architecture.
5. Create an implementation plan.
6. Confirm that asset paths are valid.
7. Implement the ecosystem screen.
8. Run the Flutter application.
9. Use browser verification where available.
10. Inspect the rendered result.
11. Fix layout problems.
12. Fix animation problems.
13. Test hover interactions.
14. Test click transitions.
15. Test keyboard navigation.
16. Test responsive layouts.
17. Test presentation navigation.

Use Antigravity's browser capabilities to visually verify the running application rather than relying only on compilation.

Create an artifact/report summarizing:

- what was implemented
- files changed
- assets detected
- missing assets
- tests performed
- remaining visual issues

==================================================
29. ASSET FALLBACK POLICY
==================================================

Never silently substitute generated placeholders for final visual assets.

If an asset is missing, clearly report:

MISSING ASSET:
assets/feature_icons/orders_icon_transparent_1x1.png

Then continue development using a simple temporary placeholder.

The final project must make it obvious which placeholders remain.

==================================================
30. DESIGN REFERENCE
==================================================

The provided reference images represent the desired visual direction.

The first reference demonstrates the original spatial concept.

The NovaXpress logo reference is the authoritative branding source.

The generated concept references demonstrate:

- floating platforms
- central brand core
- cinematic depth
- navy/orange palette
- 3D logistics objects
- glassmorphism
- glowing orange accents
- spatial navigation
- premium presentation style

Do not copy the generated images literally.

Reconstruct the interaction system using reusable Flutter components.

==================================================
31. FINAL EXPERIENCE
==================================================

The finished experience should feel like:

"NovaXpress Command Center"

A user enters the application.

They see the NovaXpress core.

Six capabilities float around it.

They move the cursor.

The environment responds.

The selected platform comes forward.

The others recede.

A glass information card appears.

The user clicks.

The camera transitions through the selected capability.

The feature presentation opens.

The user can navigate between capabilities.

Escape returns them to the ecosystem.

The entire experience should feel fluid, intentional, premium and cinematic.

Do not settle for a static dashboard.

Build an actual interactive spatial presentation.
