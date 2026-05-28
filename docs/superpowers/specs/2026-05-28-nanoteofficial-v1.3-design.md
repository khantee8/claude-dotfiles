# nanoteofficial.me v1.3 — Design Spec

**Status:** Approved  
**Author:** NaNote + Claude  
**Date:** 2026-05-28

---

## 1. Overview

Add a "My Company" section to the portfolio homepage that embeds a **live iframe** of `company.nanoteofficial.me`, showing the isometric pixel-art AI office in real-time. This positions NaNote Corp as a professional AI use-case directly on the portfolio — visitors see 5 autonomous agents working without leaving the page.

No advanced features. View-only embed with bilingual section text and a CTA link.

## 2. Section Placement

Insert the new section between **About** (id=`about`) and **Experience** (id=`experience`) in `src/app/page.tsx`.

Current order:
```
Hero → About → Experience → Projects → Education → ...
```

New order:
```
Hero → About → Company → Experience → Projects → Education → ...
```

## 3. Navigation

Add "Company" to the header nav array in `src/components/Header.tsx`:

```
About → Company → Experience → Projects → Roadmap → Contact
```

The scroll-spy `IntersectionObserver` in `HeaderNav.tsx` already watches all items in the `items` array — adding the new entry is sufficient. Update the CLAUDE.md comment about watched sections.

## 4. Section Content

### 4.1 Eyebrow / Title / Description

| Field | English | Thai |
|-------|---------|------|
| Eyebrow | NaNote Corp | NaNote Corp |
| Title | Meet the team. | พบกับทีมงาน |
| Description | NaNote Corp is a digital company powered by 5 AI department heads — CEO, Marketing, R&D, Operations, and Finance — managing real operations around the clock. | NaNote Corp คือบริษัทดิจิทัลที่ขับเคลื่อนด้วยหัวหน้าแผนก AI 5 ตำแหน่ง — CEO, Marketing, R&D, Operations และ Finance — บริหารงานจริงตลอด 24 ชั่วโมง |

### 4.2 iframe Embed

- **Source:** `https://company.nanoteofficial.me`
- **Desktop height:** 520px
- **Mobile height:** 300px (responsive via Tailwind breakpoint)
- **Width:** Full section width (`max-w-6xl`, matching other sections)
- **Border:** Rounded corners (`rounded-xl`), subtle border (`border border-[var(--border)]`), optional brand glow shadow
- **Attributes:** `loading="lazy"`, `sandbox="allow-scripts allow-same-origin"`, `title="NaNote Corp — AI Company Simulator"` for accessibility
- **No scrolling on the iframe itself** — the office app handles its own viewport

### 4.3 CTA Below iframe

A link below the iframe:
- English: "Visit NaNote Corp →"
- Thai: "เยี่ยมชม NaNote Corp →"
- Opens `https://company.nanoteofficial.me` in a new tab with `rel="noopener noreferrer"`
- Styled as a subtle text link with arrow, not a loud button (keeps focus on the iframe)

## 5. New Component

### `src/components/Company.tsx`

A **server component** (no client JS needed). Receives `lang: Lang` prop. Renders:

1. The iframe inside a styled container div
2. The CTA link below

The `<Section>` wrapper is applied in `page.tsx` (consistent with all other sections).

## 6. i18n Keys

Add to `UiKey` union and `dict` in `src/lib/i18n.ts`:

| Key | English | Thai |
|-----|---------|------|
| `nav.company` | Company | บริษัท |
| `section.company.eyebrow` | NaNote Corp | NaNote Corp |
| `section.company.title` | Meet the team. | พบกับทีมงาน |
| `section.company.description` | (see §4.1) | (see §4.1) |
| `section.company.cta` | Visit NaNote Corp → | เยี่ยมชม NaNote Corp → |

## 7. Security Changes

### 7.1 company.nanoteofficial.me — Allow Framing

The company site currently sends `X-Frame-Options: DENY` (Next.js default or explicit header). Update `next.config.ts` to:

- **Remove** `X-Frame-Options: DENY` (or change to `SAMEORIGIN`)
- **Add** CSP `frame-ancestors` directive: `frame-ancestors 'self' https://nanoteofficial.me https://*.nanoteofficial.me`

This allows the company site to be embedded only by the portfolio site and its subdomains. All other sites are blocked.

### 7.2 nanoteofficial.me — Allow iframe Source

Update CSP in `next.config.ts` to add:

- `frame-src https://company.nanoteofficial.me` — permits the iframe to load the company site

Current CSP does not include `frame-src`, so it falls back to `default-src 'self'` which would block the cross-origin iframe.

## 8. Compatibility Checks

Before deploying, verify:

- **Dark mode:** The iframe renders the company site's own dark theme. The portfolio's dark mode toggle should not affect iframe content (iframes are isolated). Confirm the company site's dark background doesn't clash with the portfolio's light mode border.
- **Mobile:** iframe at 300px height is usable — the company site's `OfficeCanvas` auto-resizes to available space. Sidebar may be cut off but the office view remains visible.
- **Scroll-spy:** Adding `company` to the nav items array means the observer watches `#company`. Verify all 6 nav items highlight correctly.
- **Performance:** `loading="lazy"` on the iframe defers loading until the section is near-viewport. No impact on initial page load metrics.

## 9. Code Review Scope

Review the full diff for v1.3 against `main`:

- No `dangerouslySetInnerHTML` usage
- CSP changes are minimal and correctly scoped
- iframe `sandbox` attribute restricts capabilities appropriately
- All new i18n keys have both `en` and `th` values
- No new client components introduced (Company.tsx is RSC)
- External link has `rel="noopener noreferrer"` and `target="_blank"`

## 10. Security Review Scope

- CSP `frame-src` is limited to a single trusted origin
- CSP `frame-ancestors` on company site is limited to `*.nanoteofficial.me`
- iframe `sandbox` permits only `allow-scripts allow-same-origin` (minimum needed for the canvas app)
- No user input involved — section is fully static
- No new API routes or data fetching from main site
- HSTS, X-Content-Type-Options, Referrer-Policy headers remain unchanged

## 11. Files Changed

| File | Repo | Change |
|------|------|--------|
| `src/app/page.tsx` | nanoteofficial.me | Add Company section between About and Experience |
| `src/components/Company.tsx` | nanoteofficial.me | **New** — iframe embed component |
| `src/components/Header.tsx` | nanoteofficial.me | Add `nav.company` item to nav array |
| `src/lib/i18n.ts` | nanoteofficial.me | Add 5 new i18n keys |
| `next.config.ts` | nanoteofficial.me | Add `frame-src` to CSP |
| `CLAUDE.md` | nanoteofficial.me | Update scroll-spy section list |
| `next.config.ts` | company.nanoteofficial.me | Update `X-Frame-Options` + add `frame-ancestors` to CSP |

## 12. Deployment

Use **base-deployment** skill:

1. Build & type-check both repos
2. Commit company.nanoteofficial.me CSP change first (must be live before iframe works)
3. Commit nanoteofficial.me v1.3 changes
4. Both auto-deploy to Vercel from `main`
5. Verify iframe loads on production
