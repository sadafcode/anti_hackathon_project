---
name: Service Concierge Aesthetic
colors:
  surface: '#fbf8ff'
  surface-dim: '#dbd9e1'
  surface-bright: '#fbf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f2fb'
  surface-container: '#efecf5'
  surface-container-high: '#eae7ef'
  surface-container-highest: '#e4e1ea'
  on-surface: '#1b1b21'
  on-surface-variant: '#454652'
  inverse-surface: '#303036'
  inverse-on-surface: '#f2eff8'
  outline: '#767683'
  outline-variant: '#c6c5d4'
  surface-tint: '#4c56af'
  primary: '#000666'
  on-primary: '#ffffff'
  primary-container: '#1a237e'
  on-primary-container: '#8690ee'
  inverse-primary: '#bdc2ff'
  secondary: '#006c4e'
  on-secondary: '#ffffff'
  secondary-container: '#83f5c6'
  on-secondary-container: '#007151'
  tertiary: '#2c1600'
  on-tertiary: '#ffffff'
  tertiary-container: '#492800'
  on-tertiary-container: '#dc8200'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e0e0ff'
  primary-fixed-dim: '#bdc2ff'
  on-primary-fixed: '#000767'
  on-primary-fixed-variant: '#343d96'
  secondary-fixed: '#86f8c9'
  secondary-fixed-dim: '#68dbae'
  on-secondary-fixed: '#002115'
  on-secondary-fixed-variant: '#00513a'
  tertiary-fixed: '#ffdcbe'
  tertiary-fixed-dim: '#ffb870'
  on-tertiary-fixed: '#2c1600'
  on-tertiary-fixed-variant: '#693c00'
  background: '#fbf8ff'
  on-background: '#1b1b21'
  surface-variant: '#e4e1ea'
typography:
  headline-xl:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 80px
  gutter: 24px
  margin-mobile: 20px
  margin-desktop: 64px
---

## Brand & Style

The design system is built on a foundation of **Corporate Modern** professionalism infused with **soft, approachable tech** elements. It is designed to evoke a sense of reliability and seamlessness, bridging the gap between automated efficiency and human care.

The visual language targets both service providers and consumers, necessitating a balance between a "pro-tool" utility and a welcoming consumer interface. We achieve this through the use of spacious layouts, a friendly but authoritative color palette, and high-quality 3D-inspired iconography that adds depth and personality to the digital experience.

## Colors

The color palette is anchored by a deep **Dark Navy**, providing a stable, professional base. **Growth Green** and **Action Orange** serve as high-visibility accents for conversion and status indicators.

The background utilizes a soft **Lavender Gradient** to move away from sterile whites, creating a more premium and calming environment. Neutral tones should be derived from the Navy primary (tinted greys) rather than pure black to maintain visual harmony with the lavender background.

## Typography

This design system uses **Manrope** for its modern, geometric construction that remains highly legible at small sizes. 

Headings are intentionally heavy (Bold to ExtraBold) to establish a clear information hierarchy and a confident brand voice. Body text maintains a comfortable line height of 1.5x for readability, while labels use slightly increased letter spacing and medium weights to ensure they stand out in dense UI sections.

## Layout & Spacing

The system employs a **Fluid Grid** model. On desktop, a 12-column grid is used with generous margins to focus the user's attention. Mobile layouts transition to a single-column stack with a 20px safe area.

Spacing follows a strict 8px rhythmic scale. We prioritize "breathability"—using the `xl` spacing for section breaks and `md` for internal card padding. Elements should be grouped using proximity; related items (like an icon and its label) should use `xs` or `sm` increments.

## Elevation & Depth

Hierarchy is established through **Ambient Shadows** and tonal layering. Surfaces should feel like they are floating slightly above the lavender background.

Shadows must be soft and diffused, utilizing a hint of the primary Navy color (`rgba(26, 35, 126, 0.08)`) rather than pure black to keep the UI clean. Use three distinct levels:
1.  **Low:** For standard cards and input fields.
2.  **Medium:** For hover states and dropdown menus.
3.  **High:** For floating action buttons and modal windows.

## Shapes

The shape language is defined by **Roundedness Level 2**. This creates a friendly, modern feel without appearing overly juvenile. 

Standard UI components like inputs and small buttons use a 0.5rem radius. Feature cards and major containers utilize a more pronounced 1rem radius (`rounded-lg`) to create distinct content blocks. Interactive elements that function as triggers (like "Next" or "Chat") often take a fully circular (pill) form to emphasize their "clickability."

## Components

### Buttons
Primary buttons are **circular or pill-shaped**. They should feature high-contrast text and, where applicable, a directional icon (e.g., an arrow) to signify progression. Secondary buttons utilize the "Ghost" style with a 1.5px border in the primary navy color.

### Cards
Cards are the primary container for content. They feature a white background with a 1rem corner radius and a "Low" ambient shadow. For specific bot-related interactions, cards may take on a Dark Navy background with white text to signify a "Primary Action" or "Bot State."

### Icon-based Badges
Status indicators and category markers should use circular containers with centered glyphs. These badges use a 10% opacity tint of their respective semantic color (Green for "Verified," Orange for "Pending") to keep the UI light.

### Input Fields
Inputs should be clean and spacious with a 0.5rem radius. The focus state is indicated by a 2px solid border in Dark Navy. Labels should always sit above the input field, never inside as placeholder text, to maintain accessibility.

### Progress Indicators
Use soft, rounded bars. For step-based flows, use circular nodes connected by thin, 2px lines in a muted version of the Navy primary.