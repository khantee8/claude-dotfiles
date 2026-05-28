# nanoteofficial.me v1.3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "My Company" section to the portfolio homepage with a live iframe of company.nanoteofficial.me, showing the isometric AI office in real-time.

**Architecture:** New server component `Company.tsx` renders a styled iframe. The section slots between About and Experience. CSP changes on both sites enable cross-origin framing. No client JS, no API calls, no data fetching from the main site.

**Tech Stack:** Next.js 16, React 19, TypeScript, Tailwind v4 (both repos already use this stack)

---

## File Structure

| File | Repo | Action | Responsibility |
|------|------|--------|----------------|
| `next.config.ts` | company.nanoteofficial.me | Modify | Allow framing by nanoteofficial.me |
| `src/lib/i18n.ts` | nanoteofficial.me | Modify | Add 5 new bilingual keys |
| `src/components/Company.tsx` | nanoteofficial.me | Create | iframe embed + CTA link |
| `src/components/Header.tsx` | nanoteofficial.me | Modify | Add "Company" nav item |
| `src/app/page.tsx` | nanoteofficial.me | Modify | Insert Company section |
| `next.config.ts` | nanoteofficial.me | Modify | Add `frame-src` to CSP |
| `CLAUDE.md` | nanoteofficial.me | Modify | Update scroll-spy docs |

---

### Task 1: Allow framing on company.nanoteofficial.me

**Files:**
- Modify: `/project/src/company.nanoteofficial.me/next.config.ts`

This must be deployed first — the iframe won't work until the company site permits framing.

- [ ] **Step 1: Update X-Frame-Options and CSP frame-ancestors**

Replace the current `X-Frame-Options: DENY` header and `frame-ancestors 'none'` CSP directive to allow embedding from `*.nanoteofficial.me` only.

```typescript
// /project/src/company.nanoteofficial.me/next.config.ts
import type { NextConfig } from "next";

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob:",
      "font-src 'self'",
      "connect-src 'self'",
      "frame-ancestors 'self' https://nanoteofficial.me https://*.nanoteofficial.me",
    ].join("; "),
  },
];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
```

Changes from the original:
- Removed `X-Frame-Options: DENY` entirely (CSP `frame-ancestors` supersedes it in all modern browsers)
- Changed `frame-ancestors 'none'` → `frame-ancestors 'self' https://nanoteofficial.me https://*.nanoteofficial.me`

- [ ] **Step 2: Build and type-check**

Run from `/project/src/company.nanoteofficial.me`:
```bash
npx tsc --noEmit && npm run build
```
Expected: Clean build, no errors.

- [ ] **Step 3: Commit**

```bash
cd /project/src/company.nanoteofficial.me
git add next.config.ts
git commit -m "security: allow framing by nanoteofficial.me (CSP frame-ancestors)"
```

- [ ] **Step 4: Push to deploy**

```bash
git push origin main
```

This deploys to Vercel automatically. The company site must be live with the new headers before Task 6 verification will work.

---

### Task 2: Add i18n keys

**Files:**
- Modify: `/project/src/nanoteofficial.me/src/lib/i18n.ts`

- [ ] **Step 1: Add keys to the UiKey union**

Add these 5 keys to the `UiKey` type union in `src/lib/i18n.ts`, after the existing `nav.*` keys:

```typescript
  | "nav.company"
  | "section.company.eyebrow"
  | "section.company.title"
  | "section.company.description"
  | "section.company.cta"
```

- [ ] **Step 2: Add entries to the dict object**

Add these entries to the `dict` record, after the `"nav.projects"` entry:

```typescript
  "nav.company": { en: "Company", th: "บริษัท" },
  "section.company.eyebrow": { en: "NaNote Corp", th: "NaNote Corp" },
  "section.company.title": { en: "Meet the team.", th: "พบกับทีมงาน" },
  "section.company.description": {
    en: "NaNote Corp is a digital company powered by 5 AI department heads — CEO, Marketing, R&D, Operations, and Finance — managing real operations around the clock.",
    th: "NaNote Corp คือบริษัทดิจิทัลที่ขับเคลื่อนด้วยหัวหน้าแผนก AI 5 ตำแหน่ง — CEO, Marketing, R&D, Operations และ Finance — บริหารงานจริงตลอด 24 ชั่วโมง",
  },
  "section.company.cta": { en: "Visit NaNote Corp →", th: "เยี่ยมชม NaNote Corp →" },
```

- [ ] **Step 3: Type-check**

Run from `/project/src/nanoteofficial.me`:
```bash
npx tsc --noEmit
```
Expected: No errors. TypeScript will error if any `UiKey` is missing from `dict` or vice versa.

- [ ] **Step 4: Commit**

```bash
git add src/lib/i18n.ts
git commit -m "feat(i18n): add Company section bilingual keys"
```

---

### Task 3: Create Company component

**Files:**
- Create: `/project/src/nanoteofficial.me/src/components/Company.tsx`

- [ ] **Step 1: Create the component**

```typescript
// src/components/Company.tsx
import { t, type Lang } from "@/lib/i18n";

export function Company({ lang }: { lang: Lang }) {
  return (
    <>
      <div className="overflow-hidden rounded-xl border border-[var(--border)] shadow-[0_0_40px_-12px_var(--brand-accent)]">
        <iframe
          src="https://company.nanoteofficial.me"
          title="NaNote Corp — AI Company Simulator"
          loading="lazy"
          sandbox="allow-scripts allow-same-origin"
          className="w-full h-[300px] md:h-[520px] border-0"
        />
      </div>
      <p className="mt-4 text-center">
        <a
          href="https://company.nanoteofficial.me"
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-[var(--muted)] hover:text-[var(--accent)] transition-colors"
        >
          {t("section.company.cta", lang)}
        </a>
      </p>
    </>
  );
}
```

This is a server component (no `"use client"` directive). It renders:
- A rounded iframe container with a subtle brand glow shadow
- 300px tall on mobile, 520px on md+ breakpoint
- A centered CTA link below that opens the full site in a new tab

- [ ] **Step 2: Type-check**

```bash
npx tsc --noEmit
```
Expected: No errors. The `t()` calls reference keys added in Task 2.

- [ ] **Step 3: Commit**

```bash
git add src/components/Company.tsx
git commit -m "feat: add Company component with live iframe embed"
```

---

### Task 4: Add Company to navigation and page

**Files:**
- Modify: `/project/src/nanoteofficial.me/src/components/Header.tsx`
- Modify: `/project/src/nanoteofficial.me/src/app/page.tsx`

- [ ] **Step 1: Add nav item in Header.tsx**

In `src/components/Header.tsx`, add the Company nav item between About and Experience in the `items` array (line ~15):

```typescript
  const items: NavItem[] = [
    { href: "/#about", id: "about", label: t("nav.about", lang) },
    { href: "/#company", id: "company", label: t("nav.company", lang) },
    { href: "/#experience", id: "experience", label: t("nav.experience", lang) },
    { href: "/#projects", id: "projects", label: t("nav.projects", lang) },
    { href: "/#roadmap", id: "roadmap", label: t("nav.roadmap", lang) },
    { href: "/#contact", id: "contact", label: t("nav.contact", lang) },
  ];
```

- [ ] **Step 2: Add Company section in page.tsx**

In `src/app/page.tsx`, add the import at the top:

```typescript
import { Company } from "@/components/Company";
```

Then insert the Company section between the About and Experience sections:

```tsx
      <Section
        id="company"
        eyebrow={t("section.company.eyebrow", lang)}
        title={t("section.company.title", lang)}
        description={t("section.company.description", lang)}
      >
        <Company lang={lang} />
      </Section>
```

The full section order in the JSX should now be:
```
Hero → About → Company → Experience → Projects → Education → HardSkills → Skills → Certs → Roadmap → Contact
```

- [ ] **Step 3: Type-check and lint**

```bash
npx tsc --noEmit && npm run lint
```
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add src/components/Header.tsx src/app/page.tsx
git commit -m "feat: add Company section to homepage and navigation"
```

---

### Task 5: Update CSP on nanoteofficial.me

**Files:**
- Modify: `/project/src/nanoteofficial.me/next.config.ts`

- [ ] **Step 1: Add frame-src directive to CSP**

In `next.config.ts`, add `frame-src https://company.nanoteofficial.me` to the CSP value array. Insert it after the `connect-src` line:

Current:
```typescript
      "connect-src 'self' https://api.resend.com",
      "frame-ancestors 'none'",
```

New:
```typescript
      "connect-src 'self' https://api.resend.com",
      "frame-src https://company.nanoteofficial.me",
      "frame-ancestors 'none'",
```

- [ ] **Step 2: Build**

```bash
npm run build
```
Expected: Clean build, no errors. This also validates that the config is syntactically correct.

- [ ] **Step 3: Commit**

```bash
git add next.config.ts
git commit -m "security: add frame-src for company.nanoteofficial.me iframe"
```

---

### Task 6: Update CLAUDE.md

**Files:**
- Modify: `/project/src/nanoteofficial.me/CLAUDE.md`

- [ ] **Step 1: Update scroll-spy section list**

Find the line (around line 68):
```
- The scroll-spy IntersectionObserver in `HeaderNav.tsx` only watches sections that exist on the homepage (`about`, `experience`, `projects`, `roadmap`, `contact`) — it has no effect on subdomain pages.
```

Replace with:
```
- The scroll-spy IntersectionObserver in `HeaderNav.tsx` only watches sections that exist on the homepage (`about`, `company`, `experience`, `projects`, `roadmap`, `contact`) — it has no effect on subdomain pages.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add company to scroll-spy section list in CLAUDE.md"
```

---

### Task 7: Verification & compatibility checks

**Files:** None — read-only verification.

- [ ] **Step 1: Start dev server**

```bash
cd /project/src/nanoteofficial.me
npm run dev
```

- [ ] **Step 2: Verify section placement**

Open `http://localhost:3000` in a browser. Scroll down and confirm:
- About section appears first
- Company section appears second (between About and Experience)
- Experience section appears third
- The iframe container is visible with rounded border and glow shadow

- [ ] **Step 3: Verify navigation**

Check the header nav bar shows: About | Company | Experience | Projects | Roadmap | Contact

Scroll through the page and confirm scroll-spy highlights "Company" when the section is in view.

- [ ] **Step 4: Verify mobile**

Resize browser to mobile width (~375px). Confirm:
- iframe height shrinks to ~300px
- Mobile nav sheet includes "Company" item
- Section text is readable and not clipped

- [ ] **Step 5: Verify dark mode**

Toggle dark mode. Confirm:
- The iframe container border looks correct in both light and dark modes
- The company site's dark theme inside the iframe doesn't clash with the portfolio's light mode border

- [ ] **Step 6: Verify language toggle**

Switch to Thai. Confirm:
- Nav shows "บริษัท"
- Section eyebrow shows "NaNote Corp"
- Section title shows "พบกับทีมงาน"
- CTA shows "เยี่ยมชม NaNote Corp →"

Switch back to English and verify English strings.

- [ ] **Step 7: Verify iframe loads on production domain**

The iframe `src` points to `https://company.nanoteofficial.me`. In local dev this will load the production company site (requires internet). Confirm the iframe content loads — if Task 1 has been deployed, the office should render inside the frame.

If Task 1 hasn't deployed yet, expect the iframe to be blocked — that's correct. It will work once the company site CSP change is live.

- [ ] **Step 8: Verify CTA link**

Click the "Visit NaNote Corp →" link. Confirm it opens `https://company.nanoteofficial.me` in a new tab.

---

### Task 8: Code review & security review

**Files:** None — review only.

- [ ] **Step 1: Review the full diff**

```bash
git diff main...HEAD
```

Check against this list:
- No `dangerouslySetInnerHTML` usage anywhere
- No new `"use client"` directives (Company.tsx should be RSC)
- All 5 i18n keys have both `en` and `th` values
- `frame-src` in CSP points to exactly `https://company.nanoteofficial.me`
- iframe has `sandbox="allow-scripts allow-same-origin"` (minimum required)
- iframe has `loading="lazy"` for performance
- iframe has `title` attribute for accessibility
- External link has `rel="noopener noreferrer"` and `target="_blank"`
- No new API routes or data fetching

- [ ] **Step 2: Security review**

Verify these security properties:
- CSP `frame-src` is scoped to a single trusted origin (not wildcard)
- CSP `frame-ancestors` on company site is scoped to `*.nanoteofficial.me` (not wildcard)
- `X-Frame-Options: DENY` was removed from company site only (nanoteofficial.me still has `frame-ancestors 'none'`)
- HSTS, X-Content-Type-Options, Referrer-Policy, Permissions-Policy headers are unchanged on both sites
- `sandbox` attribute restricts the iframe to `allow-scripts allow-same-origin` only — no `allow-forms`, `allow-popups`, `allow-top-navigation`
- No user input is involved anywhere in this change

---

### Task 9: Deploy nanoteofficial.me v1.3

Use the **base-deployment** skill.

- [ ] **Step 1: Final build check**

```bash
cd /project/src/nanoteofficial.me
npx tsc --noEmit && npm run build && npm run lint
```
Expected: All clean.

- [ ] **Step 2: Push to deploy**

```bash
git push origin main
```

Vercel auto-deploys from `main`.

- [ ] **Step 3: Verify production**

Once deployed, open `https://nanoteofficial.me` and:
- Scroll to the Company section
- Confirm the iframe loads company.nanoteofficial.me inside it
- Confirm agents are visible and moving
- Check both light/dark mode
- Check both EN/TH languages
- Click the CTA link — confirm it opens the full site

---

### Task 10: Update root CLAUDE.md

**Files:**
- Modify: `/project/CLAUDE.md`

- [ ] **Step 1: Update nanoteofficial.me description**

In the nanoteofficial.me section of the root CLAUDE.md, note that v1.3 adds the Company section with live iframe. Find the line that describes the site and append a mention of the Company section.

- [ ] **Step 2: Commit in dotfiles repo**

```bash
cd /project
git add CLAUDE.md
git commit -m "docs: note nanoteofficial.me v1.3 Company section in root CLAUDE.md"
```
