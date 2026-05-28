# nanoteofficial.me v1.3.1 — Animation Polish Design Spec

**Status:** Approved  
**Author:** NaNote + Claude  
**Date:** 2026-05-28

---

## 1. Overview

Add subtle, professional CSS-only animations to the portfolio site: a staggered hero entrance, cascading section reveals, and hover effects on cards/badges. Zero JS libraries, zero bundle cost, full SSR compatibility. Respects `prefers-reduced-motion`.

Inspired by jaykay.design's motion language, adapted to NaNote's strategic/executive brand identity.

## 2. Motion Parameters

All animations use these shared values:

| Parameter | Value |
|-----------|-------|
| Translate distance | 20–30px |
| Duration | 300–500ms |
| Easing | `cubic-bezier(0.16, 1, 0.3, 1)` (ease-out-expo feel) |
| Stagger increment | 100–150ms between children |
| Hover transition | 200ms ease |
| Reduced motion | All animations collapse to instant opacity (no translate, no delay) |

## 3. Hero Entrance Animation

When the page loads, the hero content reveals in a staggered sequence. Each child has an increasing `animation-delay`.

| Element | Delay | Effect |
|---------|-------|--------|
| Location badge + available tag | 200ms | Fade in + slide up 20px |
| Name heading ("Saksit Jantila.") | 350ms | Fade in + slide up 24px |
| Headline (subtitle) | 500ms | Fade in + slide up 24px |
| Summary paragraph | 650ms | Fade in only (no translate) |
| CTA buttons | 800ms | Fade in + slide up 16px |
| Avatar image | 300ms | Fade in + scale from 0.95 to 1.0 |

### Implementation

Add a `@keyframes hero-up` animation in `globals.css`:

```
@keyframes hero-up {
  from { opacity: 0; transform: translateY(24px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes hero-fade {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes hero-scale {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}
```

Apply stagger classes (`.hero-stagger-1` through `.hero-stagger-5`) in `Hero.tsx` on each child element. Each class sets `opacity: 0`, `animation: hero-up 500ms <easing> <delay> forwards`.

The avatar uses `hero-scale` instead of `hero-up`.

## 4. Staggered Section Reveals

Upgrade the existing `data-reveal` scroll-triggered animation. Currently all content appears at once with a single fade-up. New behavior cascades through children.

### Current behavior
`Section` has `data-reveal` attribute. The existing system uses **CSS scroll-driven animations** (`animation-timeline: view()`) — no JavaScript IntersectionObserver. A `--reveal-d` CSS custom property controls per-element delay. Browsers without `animation-timeline` support (Firefox) gracefully degrade to fully visible sections.

The existing `@keyframes reveal-fade-up` animates from `opacity: 0; translateY(14px)` to visible.

### New behavior
Keep the same `data-reveal` + `animation-timeline: view()` mechanism. Add `data-reveal` to each child element individually (instead of only the parent section), with increasing `--reveal-d` values for stagger:

| Child | `--reveal-d` | Effect |
|-------|--------------|--------|
| Eyebrow `<p>` | 0 | Fade up 14px (existing keyframe) |
| Title `<h2>` | 80 | Fade up 14px, 80ms stagger |
| Description `<p>` | 160 | Fade up 14px, 160ms stagger |
| Content (children wrapper) | 240 | Fade up 14px, 240ms stagger |

### Implementation

In `Section.tsx`, move `data-reveal` from the parent `<section>` to each child element, with `style={{ '--reveal-d': N } as React.CSSProperties}` for stagger. The parent `<section>` keeps its `id` and `scroll-mt-20` but loses `data-reveal`.

No changes to `globals.css` for this feature — the existing animation system already supports `--reveal-d` delays.

## 5. Card/Badge Hover Effects

Pure Tailwind `hover:` utility classes. No new CSS needed.

Note: `globals.css` already has a `.card-hover` class that provides `translateY(-2px)` lift + brand-colored glow shadow on hover with 220ms transition. Reuse it where possible.

### 5.1 Roadmap Cards (`Roadmap.tsx`)

Current: cards have gradient background and border, no hover effect.

Add the existing `.card-hover` class to each roadmap card element.

### 5.2 Certification Badges (`Certifications.tsx`)

Current: badges have border and background, no hover effect.

The `.card-hover` lift effect is too strong for small badges. Instead add Tailwind utilities directly:
- `hover:scale-[1.03]`
- `hover:border-[var(--accent)]`
- `hover:shadow-[0_0_16px_-4px_var(--accent)]`
- `transition-all duration-200`

### 5.3 Project Items (`Projects.tsx`)

Current: project groups have background cards, no hover effect.

Add the existing `.card-hover` class to each project group card element.

## 6. Reduced Motion

The existing scroll-driven reveal is already wrapped in `@media (prefers-reduced-motion: no-preference)` — it only runs when the user hasn't opted out.

For the new hero entrance animations, wrap them in the same media query:

```css
@media (prefers-reduced-motion: no-preference) {
  .hero-stagger-1 { /* ... */ }
  /* etc. */
}
```

Without this media query active, hero elements render at full opacity with no animation — graceful degradation.

Hover effects (card-hover, cert badges) use short transitions (200ms) which are acceptable under reduced-motion guidelines — they are user-initiated and brief.

## 7. Dark Mode Compatibility

- Hero animations are opacity + transform based — no color dependency, works in both modes.
- Section reveals are the same — no mode-specific changes needed.
- Hover glow shadows use `var(--brand-accent)` and `var(--accent)` which already switch between light and dark mode via the existing CSS variable system.

## 8. Files Changed

| File | Change |
|------|--------|
| `src/app/globals.css` | Add `@keyframes` (hero-up, hero-fade, hero-scale), stagger classes, reveal-delay classes, reduced-motion override |
| `src/components/Hero.tsx` | Add stagger animation classes to each child element |
| `src/components/Section.tsx` | Add reveal-delay classes to eyebrow, title, description, children wrapper |
| `src/components/Roadmap.tsx` | Add hover lift + glow Tailwind classes to cards |
| `src/components/Certifications.tsx` | Add hover scale + glow Tailwind classes to badges |
| `src/components/Projects.tsx` | Add hover lift + shadow Tailwind classes to project items |

## 9. What This Does NOT Include

- No animation libraries (Framer Motion, GSAP, etc.)
- No new `"use client"` components
- No nav link animations
- No particle effects or cursor effects
- No loading/page-transition animations
- No scroll-linked parallax
