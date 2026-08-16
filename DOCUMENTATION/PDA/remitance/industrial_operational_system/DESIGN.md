---
name: Industrial Operational System
colors:
  surface: '#f7fafc'
  surface-dim: '#d7dadc'
  surface-bright: '#f7fafc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f4f6'
  surface-container: '#ebeef0'
  surface-container-high: '#e5e9eb'
  surface-container-highest: '#e0e3e5'
  on-surface: '#181c1e'
  on-surface-variant: '#44474d'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eef1f3'
  outline: '#75777e'
  outline-variant: '#c5c6ce'
  surface-tint: '#4e5f7e'
  primary: '#031632'
  on-primary: '#ffffff'
  primary-container: '#1a2b48'
  on-primary-container: '#8293b5'
  inverse-primary: '#b6c7eb'
  secondary: '#964900'
  on-secondary: '#ffffff'
  secondary-container: '#ff8928'
  on-secondary-container: '#642f00'
  tertiary: '#001c0a'
  on-tertiary: '#ffffff'
  tertiary-container: '#003318'
  on-tertiary-container: '#4ea36b'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d7e2ff'
  primary-fixed-dim: '#b6c7eb'
  on-primary-fixed: '#081b38'
  on-primary-fixed-variant: '#374765'
  secondary-fixed: '#ffdcc6'
  secondary-fixed-dim: '#ffb786'
  on-secondary-fixed: '#311300'
  on-secondary-fixed-variant: '#723600'
  tertiary-fixed: '#9ef6b6'
  tertiary-fixed-dim: '#83d99c'
  on-tertiary-fixed: '#00210e'
  on-tertiary-fixed-variant: '#00522a'
  background: '#f7fafc'
  on-background: '#181c1e'
  surface-variant: '#e0e3e5'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  currency-xl:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-bold:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  status-badge:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
  touch-target: 48px
---

## Brand & Style

The design system is engineered for the high-stakes, fast-paced logistics environment of the Nigerian market. It adopts an **Industrial-Modern** aesthetic that prioritizes utility, clarity, and reliability above all else. The brand personality is authoritative yet accessible—built to function as a dependable tool for drivers, warehouse managers, and administrative staff.

The visual direction utilizes a high-contrast framework to ensure maximum legibility under the harsh Nigerian sun. It blends **Corporate Modern** structures with **Tactile** cues, such as heavy-weighted stroke lines and distinct interactive zones, to minimize input errors in mobile-first operational environments.

Key attributes:
- **Resilience:** Design elements feel solid and grounded.
- **Urgency without Anxiety:** High-visibility accents guide the eye to critical actions.
- **Local Context:** Direct integration of the ₦ (Naira) symbol and logistics-specific iconography.

## Colors

The palette is anchored by **Reliable Navy Blue (#1A2B48)**, conveying trust and institutional stability. **Professional Forest Green (#006837)** is utilized strategically for "Success" states and completed delivery flows.

**High-visibility Orange (#F58220)** serves as the primary action color. It is reserved exclusively for interactive elements like primary buttons, pending alerts, and critical navigation paths to ensure they are instantly recognizable against the deeper primary tones.

Surface colors utilize a range of cool greys to reduce glare. Backgrounds are kept at a very light grey (#F4F7F9) rather than pure white to prevent eye strain during extended outdoor use.

## Typography

This design system uses **Inter** for all primary communication due to its exceptional tall x-height and readability on mobile screens. For technical data, tracking numbers, and specific logistics identifiers, **JetBrains Mono** is used to provide a "data-driven" industrial feel and prevent character confusion (e.g., 0 vs O).

**Numeric Guidelines:**
- All currency displays must include the **₦** symbol.
- Use `currency-xl` for total amounts to ensure drivers can verify payments at a glance.
- Tracking numbers should always use the monospaced `label-bold` style.

## Layout & Spacing

The layout follows a **Fluid Grid** model optimized for rugged mobile devices. It utilizes a 4px baseline shift to ensure all elements are mathematically aligned.

**Breakpoints:**
- **Mobile (default):** 4 columns, 16px margins. Primary focus for drivers.
- **Tablet:** 8 columns, 24px margins. Used for warehouse inventory views.
- **Desktop:** 12 columns, 32px margins. Used for administrative dispatch and analytics.

All interactive elements (buttons, checkboxes, inputs) must maintain a minimum **48px touch target** to accommodate use in outdoor environments or while wearing gloves. Vertical spacing between card elements should be a consistent 16px (`stack-md`) to ensure clear separation of delivery tasks.

## Elevation & Depth

This design system avoids complex shadows in favor of **Tonal Layers** and **Low-Contrast Outlines**. This "Flat-Industrial" approach ensures that information remains visible even when screen brightness is maxed out or when viewed at an angle.

- **Level 0 (Background):** #F4F7F9.
- **Level 1 (Cards/Containers):** Pure #FFFFFF with a 1px solid border (#D1D5DB).
- **Level 2 (Active/Modals):** Pure #FFFFFF with a 2px solid border (#1A2B48) and a subtle 4px blur shadow to indicate priority.
- **Separators:** 1px solid lines using #E5E7EB. Avoid using shadows to separate list items.

## Shapes

The shape language is **Soft (0.25rem)**. This provides a professional, "tool-like" feel that is more approachable than sharp corners but more serious than highly rounded "consumer" apps.

- **Buttons & Inputs:** 4px (0.25rem) radius.
- **Status Badges:** 2px radius or sharp for a more "tag-like" appearance.
- **Cards:** 8px (0.5rem) radius to create a distinct container for delivery data.

## Components

### Buttons
- **Primary:** High-visibility Orange (#F58220) background with White text. Bold weight.
- **Secondary:** Navy Blue (#1A2B48) outline, 2px stroke, Navy text.
- **Destructive:** Red (#D32F2F) for "Cancel Shipment" or "Report Issue."

### Status Badges
Status badges use high-contrast combinations:
- **Delivered:** Forest Green background (#006837) / White text.
- **Pending:** Orange background (#F58220) / White text.
- **Failed/Return:** Dark Grey background (#374151) / White text.
- **In Transit:** Navy Blue background (#1A2B48) / White text.

### Input Fields
Large-format inputs are required for operational efficiency.
- **Currency Input:** Must prefix with ₦ in a fixed-position container.
- **Numeric Pad:** Custom large-button numeric overlay for price/quantity entry on mobile.
- **Focus State:** 2px solid Navy Blue border.

### Cards (Task/Delivery)
- Cards must feature a "Primary Action" button at the bottom (e.g., "Start Navigation" or "Confirm Pickup").
- Header of the card should display the tracking number in monospaced font.
- Body should use high-contrast iconography (Truck icon for vehicle type, Box icon for parcel count).

### Navigation
- Bottom bar navigation for mobile with 4 clear icons: Tasks, Map, Wallet (₦), Profile.
- Use solid-fill icons for active states to ensure they are visible in sunlight.