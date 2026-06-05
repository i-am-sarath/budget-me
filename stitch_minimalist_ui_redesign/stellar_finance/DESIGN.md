---
name: Stellar Finance
colors:
  surface: '#f8f9ff'
  surface-dim: '#ccdbf4'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d4e4fc'
  on-surface: '#0d1c2e'
  on-surface-variant: '#43474e'
  inverse-surface: '#223144'
  inverse-on-surface: '#eaf1ff'
  outline: '#74777f'
  outline-variant: '#c4c6cf'
  surface-tint: '#455f88'
  primary: '#002045'
  on-primary: '#ffffff'
  primary-container: '#1a365d'
  on-primary-container: '#86a0cd'
  inverse-primary: '#adc7f7'
  secondary: '#0a6c44'
  on-secondary: '#ffffff'
  secondary-container: '#9ff5c1'
  on-secondary-container: '#167249'
  tertiary: '#321b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#4f2e00'
  on-tertiary-container: '#c6955e'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#adc7f7'
  on-primary-fixed: '#001b3c'
  on-primary-fixed-variant: '#2d476f'
  secondary-fixed: '#9ff5c1'
  secondary-fixed-dim: '#83d8a6'
  on-secondary-fixed: '#002111'
  on-secondary-fixed-variant: '#005231'
  tertiary-fixed: '#ffddba'
  tertiary-fixed-dim: '#f2bc82'
  on-tertiary-fixed: '#2b1700'
  on-tertiary-fixed-variant: '#633f0f'
  background: '#f8f9ff'
  on-background: '#0d1c2e'
  surface-variant: '#d4e4fc'
typography:
  display-lg:
    fontFamily: Hanken Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-md:
    fontFamily: Hanken Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 8px
  container-max: 1200px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 40px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style

The design system is anchored in the principles of **Corporate Modernism** and **Universal Accessibility**. It is designed to evoke a sense of serenity, order, and absolute reliability. The target audience spans from students managing their first accounts to high-net-worth professionals, requiring a UI that feels both sophisticated and effortless to navigate.

The aesthetic prioritizes clarity through a "White-Space First" philosophy. By utilizing a pure white background, we maximize the perceived "air" in the interface, reducing cognitive load during complex financial tasks. The visual language is lean, avoiding unnecessary decorative elements in favor of functional clarity and high-contrast precision.

## Colors

The palette is restricted to high-confidence tones that meet WCAG 2.1 AA/AAA standards. 

- **Primary (Deep Royal):** Used for navigation, primary actions, and branding. It represents stability and institutional trust.
- **Success (Green):** Reserved strictly for positive growth, completed transactions, and upward trends.
- **Alert (Red):** Used for critical errors, overdraft warnings, or negative market movement.
- **Neutrals:** A scale of cool grays used for secondary text and subtle borders. 
- **Surface:** Pure white (#FFFFFF) is the base for all screens to ensure maximum contrast and a contemporary, clean feel.

## Typography

This design system utilizes **Hanken Grotesk** for its exceptional legibility and contemporary geometric construction. The typeface scales effectively from large data displays to tiny micro-copy.

- **Weight Usage:** Bold and Semibold weights are reserved for hierarchy and headers. Regular weight is used for all transactional data to maintain a clean appearance.
- **Data Display:** For currency amounts, use the `title-md` or `headline-lg` styles to ensure numbers are the most prominent feature of the layout.
- **Accessibility:** Never use a font size smaller than 12px. Ensure a contrast ratio of at least 4.5:1 for all body text against the white background.

## Layout & Spacing

The design system employs a **8px soft-grid system** to ensure mathematical harmony across all components.

- **Desktop:** A 12-column fixed grid centered in a 1200px max-container.
- **Mobile:** A fluid single-column layout with 16px side margins. 
- **Rhythm:** Vertical spacing between cards and sections should follow the `stack` tokens. Use `stack-lg` (32px) to separate distinct functional areas (e.g., separating "Account Balance" from "Recent Transactions").
- **Alignment:** All data columns in tables should be right-aligned for currency and left-aligned for descriptive text to aid quick scanning.

## Elevation & Depth

Depth is handled with extreme restraint to prevent the UI from feeling cluttered. We use a **Tonal Layering** approach combined with **Ambient Shadows**.

1.  **Level 0 (Base):** Pure white background (#FFFFFF).
2.  **Level 1 (Cards/Containers):** Pure white surface with a subtle 1px border (#E2E8F0) and a soft, highly diffused shadow (0px 4px 12px rgba(0, 0, 0, 0.05)).
3.  **Level 2 (Modals/Popovers):** Pure white surface with a more pronounced shadow (0px 10px 25px rgba(0, 0, 0, 0.1)) to indicate a clear break from the primary canvas.

Avoid heavy dark shadows or complex gradients. The goal is "perceptible separation," not physical realism.

## Shapes

The shape language is **Soft (0.25rem / 4px base)**. This provides a professional, "stable" feel that avoids the playfulness of highly rounded "pill" shapes while feeling more modern than sharp 0px corners.

- **Buttons & Inputs:** Use the standard 4px radius.
- **Cards & Sections:** Use `rounded-lg` (8px) to provide a soft container for grouped information.
- **Selection Indicators:** Small indicators (like active tab underlines) should have slightly rounded ends to match the overall system.

## Components

### Buttons
- **Primary:** Solid Primary Color (#1A365D) with White text.
- **Secondary:** White background with 1px Primary Color border and Primary Color text.
- **Sizing:** Large touch targets (min 44px height) for all mobile interactions.

### Input Fields
- **Default State:** 1px border (#CBD5E0), White background.
- **Focus State:** 2px border Primary Color (#1A365D) with a subtle outer glow.
- **Labels:** Always visible above the input field; never use placeholder text as the only label.

### Cards
- The primary vehicle for information. Use white cards with a subtle border and shadow (see Elevation). Group related data (e.g., Credit Card info + Balance) within a single card.

### Chips & Status Indicators
- Used for transaction categories (e.g., "Food," "Rent"). Use light neutral backgrounds with dark gray text to keep them secondary to the primary financial figures.

### Progress Bars
- Used for savings goals. Use Secondary Success Green (#2F855A) for the fill and a very light gray for the track.