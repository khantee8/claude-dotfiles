# nanoteofficial.me v1.3.1 Animation Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add subtle CSS-only animations — staggered hero entrance, cascading section reveals, and card/badge hover effects — to polish the portfolio site.

**Architecture:** Pure CSS keyframes + Tailwind utilities. No animation libraries, no new client components. Hero uses `@keyframes` with `animation-delay` for stagger. Section reveals reuse the existing `data-reveal` + `animation-timeline: view()` system with per-child `--reveal-d` delays. Hover effects use the existing `.card-hover` class plus Tailwind utilities for cert badges.

**Tech Stack:** CSS keyframes, Tailwind v4, existing `data-reveal` scroll-driven animation system

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src/app/globals.css` | Modify | Add hero keyframes + stagger classes |
| `src/components/Hero.tsx` | Modify | Apply stagger classes to children |
| `src/components/Section.tsx` | Modify | Move `data-reveal` to individual children with stagger delays |
| `src/components/Certifications.tsx` | Modify | Replace `card-hover` with cert-specific hover utilities |
| `src/components/Projects.tsx` | Modify | Add `card-hover` class to project cards |

---

### Task 1: Add hero animation keyframes and stagger classes

**Files:**
- Modify: `/project/src/nanoteofficial.me/src/app/globals.css`

- [ ] **Step 1: Add hero keyframes and stagger classes**

Add the following CSS at the end of `globals.css`, before the closing (after the `reveal-fade-up` keyframe block):

```css
/* Hero entrance — staggered fade-up on page load */
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

@media (prefers-reduced-motion: no-preference) {
  .hero-up {
    opacity: 0;
    animation: hero-up 500ms cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: var(--hero-d, 0ms);
  }
  .hero-fade {
    opacity: 0;
    animation: hero-fade 500ms cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: var(--hero-d, 0ms);
  }
  .hero-scale {
    opacity: 0;
    animation: hero-scale 500ms cubic-bezier(0.16, 1, 0.3, 1) forwards;
    animation-delay: var(--hero-d, 0ms);
  }
}
```

Each class uses a `--hero-d` CSS variable for the delay, set per-element in the component.

- [ ] **Step 2: Build to verify CSS is valid**

```bash
cd /project/src/nanoteofficial.me
npm run build
```
Expected: Clean build, no errors.

- [ ] **Step 3: Commit**

```bash
git add src/app/globals.css
git commit -m "feat: add hero entrance animation keyframes and stagger classes"
```

---

### Task 2: Apply hero stagger animations to Hero.tsx

**Files:**
- Modify: `/project/src/nanoteofficial.me/src/components/Hero.tsx`

- [ ] **Step 1: Add stagger classes to hero children**

The current `Hero.tsx` has these children in order:
1. Location badge `<p>` (line 13)
2. Name heading `<h1>` (line 19)
3. Headline `<span>` (inside h1, line 21)
4. Summary `<p>` (line 25)
5. CTA buttons `<div>` (line 28)
6. Avatar `<Avatar>` wrapper `<div>` (line 44)

Apply the stagger classes with `--hero-d` delays. Replace the full component:

```tsx
import Link from "next/link";
import { profile, pick } from "@/lib/profile";
import { t, type Lang } from "@/lib/i18n";
import { Avatar } from "@/components/Avatar";

export function Hero({ lang }: { lang: Lang }) {
  return (
    <section className="relative overflow-hidden">
      <div aria-hidden className="absolute inset-0 bg-grid opacity-[0.35]" />
      <div className="relative mx-auto max-w-6xl px-6 pt-20 pb-20 md:pt-28 md:pb-28">
        <div className="flex flex-col-reverse md:flex-row md:items-start md:gap-12 lg:gap-16">
          <div className="flex-1 min-w-0">
            <p
              className="hero-up font-mono text-xs uppercase tracking-[0.2em] text-[var(--accent)] mb-5"
              style={{ "--hero-d": "200ms" } as React.CSSProperties}
            >
              <span className="inline-flex items-center gap-2">
                <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                {pick(profile.location, lang)} &middot; {t("hero.available", lang)}
              </span>
            </p>
            <h1
              className="hero-up text-4xl md:text-6xl font-semibold tracking-tight leading-[1.05] max-w-3xl"
              style={{ "--hero-d": "350ms" } as React.CSSProperties}
            >
              {pick(profile.name, lang)}.
              <span
                className="hero-up block text-[var(--muted)] mt-2 text-2xl md:text-3xl font-medium"
                style={{ "--hero-d": "500ms" } as React.CSSProperties}
              >
                {pick(profile.headline, lang)}.
              </span>
            </h1>
            <p
              className="hero-fade mt-8 max-w-2xl text-lg text-[var(--muted)] leading-relaxed"
              style={{ "--hero-d": "650ms" } as React.CSSProperties}
            >
              {pick(profile.summary, lang)}
            </p>
            <div
              className="hero-up mt-10 flex flex-wrap gap-3"
              style={{ "--hero-d": "800ms" } as React.CSSProperties}
            >
              <Link
                href="/#roadmap"
                className="inline-flex items-center gap-2 rounded-full bg-[var(--brand-accent)] text-white px-5 py-2.5 text-sm font-semibold shadow-[0_2px_10px_color-mix(in_oklab,var(--brand-accent)_30%,transparent)] hover:brightness-110 transition-all"
              >
                {t("cta.roadmap", lang)}
                <span aria-hidden>→</span>
              </Link>
              <a
                href={`mailto:${profile.email}`}
                className="inline-flex items-center gap-2 rounded-full border border-[var(--border)] bg-[var(--surface)] text-[var(--foreground)] px-5 py-2.5 text-sm font-medium hover:border-[var(--brand-accent)] hover:text-[var(--brand-accent)] transition-colors"
              >
                {t("cta.contact", lang)}
              </a>
            </div>
          </div>
          <div
            className="hero-scale mb-8 md:mb-0 md:pt-2"
            style={{ "--hero-d": "300ms" } as React.CSSProperties}
          >
            <Avatar size={220} lang={lang} />
          </div>
        </div>
      </div>
    </section>
  );
}
```

Key changes:
- Location badge: `hero-up` with `--hero-d: 200ms`
- Name h1: `hero-up` with `--hero-d: 350ms`
- Headline span: `hero-up` with `--hero-d: 500ms` (separate from parent h1)
- Summary: `hero-fade` with `--hero-d: 650ms` (fade only, no translate)
- CTAs: `hero-up` with `--hero-d: 800ms`
- Avatar wrapper: `hero-scale` with `--hero-d: 300ms`

- [ ] **Step 2: Type-check**

```bash
npx tsc --noEmit
```
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add src/components/Hero.tsx
git commit -m "feat: add staggered entrance animation to Hero"
```

---

### Task 3: Stagger section reveals in Section.tsx

**Files:**
- Modify: `/project/src/nanoteofficial.me/src/components/Section.tsx`

- [ ] **Step 1: Move data-reveal to individual children**

Replace the full `Section.tsx` with staggered reveal on each child:

```tsx
import { type ReactNode } from "react";

export function Section({
  id,
  eyebrow,
  title,
  description,
  children,
}: {
  id?: string;
  eyebrow?: string;
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <section
      id={id}
      className="mx-auto max-w-6xl px-6 py-20 md:py-24 scroll-mt-20"
    >
      <div className="max-w-2xl mb-10">
        {eyebrow && (
          <p
            data-reveal
            style={{ "--reveal-d": 0 } as React.CSSProperties}
            className="text-xs uppercase tracking-[0.18em] text-[var(--accent)] font-mono mb-3"
          >
            {eyebrow}
          </p>
        )}
        <h2
          data-reveal
          style={{ "--reveal-d": 80 } as React.CSSProperties}
          className="text-3xl md:text-4xl font-semibold tracking-tight"
        >
          {title}
        </h2>
        {description && (
          <p
            data-reveal
            style={{ "--reveal-d": 160 } as React.CSSProperties}
            className="mt-4 text-[var(--muted)] leading-relaxed"
          >
            {description}
          </p>
        )}
      </div>
      <div
        data-reveal
        style={{ "--reveal-d": 240 } as React.CSSProperties}
      >
        {children}
      </div>
    </section>
  );
}
```

Changes from original:
- Removed `data-reveal` from the parent `<section>`
- Added `data-reveal` + `--reveal-d` to eyebrow (0), title (80), description (160), and children wrapper (240)
- Wrapped `{children}` in a `<div>` with its own `data-reveal`

- [ ] **Step 2: Type-check and build**

```bash
npx tsc --noEmit && npm run build
```
Expected: Clean build. The existing `@supports (animation-timeline: view())` CSS rule targets all `[data-reveal]` elements, so the stagger will work automatically.

- [ ] **Step 3: Commit**

```bash
git add src/components/Section.tsx
git commit -m "feat: stagger section reveal cascade (eyebrow → title → desc → content)"
```

---

### Task 4: Add hover effects to cert badges

**Files:**
- Modify: `/project/src/nanoteofficial.me/src/components/Certifications.tsx`

- [ ] **Step 1: Replace card-hover with cert-specific hover**

In `Certifications.tsx`, find the cert badge `<div>` className on line 30:

```
className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4 flex items-center gap-3 relative overflow-hidden group card-hover"
```

Replace with:

```
className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4 flex items-center gap-3 relative overflow-hidden group transition-all duration-200 hover:scale-[1.03] hover:border-[var(--accent)] hover:shadow-[0_0_16px_-4px_var(--accent)]"
```

This replaces the generic `card-hover` (which does translateY, too strong for small badges) with cert-specific hover: slight scale, accent border, and soft glow.

- [ ] **Step 2: Type-check**

```bash
npx tsc --noEmit
```
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add src/components/Certifications.tsx
git commit -m "feat: add hover scale + glow effect to certification badges"
```

---

### Task 5: Add hover effects to project cards

**Files:**
- Modify: `/project/src/nanoteofficial.me/src/components/Projects.tsx`

- [ ] **Step 1: Add card-hover class to project cards**

In `Projects.tsx`, find the project card `<div>` className on line 11:

```
className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-6"
```

Replace with:

```
className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-6 card-hover"
```

- [ ] **Step 2: Type-check**

```bash
npx tsc --noEmit
```
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add src/components/Projects.tsx
git commit -m "feat: add hover lift + glow effect to project cards"
```

---

### Task 6: Verify and deploy

- [ ] **Step 1: Final build**

```bash
cd /project/src/nanoteofficial.me
npx tsc --noEmit && npm run build && npm run lint
```
Expected: All clean (except pre-existing ThemeToggle lint warning).

- [ ] **Step 2: Start dev server and verify**

```bash
PORT=3001 npm run dev
```

Open `http://localhost:3001` in a browser. Verify:
- Hero: text staggers in on page load (location → name → headline → summary → CTAs, avatar scales)
- Sections: scroll down and each section's eyebrow/title/description/content cascade in sequence
- Roadmap cards: hover shows lift + glow (already had `card-hover`)
- Cert badges: hover shows slight scale + accent border glow
- Project cards: hover shows lift + glow
- Dark mode: all effects work, glow colors adapt
- Reduced motion: disable animations in OS settings, hero renders instantly with no motion

- [ ] **Step 3: Push to deploy**

```bash
git push origin main
```

- [ ] **Step 4: Verify production**

Open `https://nanoteofficial.me`. Confirm hero entrance, section staggers, and hover effects work on production.
