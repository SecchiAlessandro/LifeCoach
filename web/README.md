# Full Engagement — Web

A browser translation of the **Full Engagement** SwiftUI app (`../FullEngagement`):
a daily ~2-minute energy check-in → four energies on a single **energy wheel** →
warm, balance-focused coaching. Grounded in Loehr & Schwartz's *The Power of Full
Engagement*.

This is an **independent codebase** from the iOS app — they share the design and
spec, not runtime code. Like the iOS app, it is **local-first and private**: all
data stays in the browser (IndexedDB), there is no server, and **scoring is always
deterministic**.

## Stack

- **React + Vite + TypeScript** (single-page app, no backend)
- **Tailwind CSS v4** with CSS-variable design tokens (light/dark follow the OS)
- **Dexie / IndexedDB** for on-device persistence
- **Recharts** for the history trend charts
- **WebLLM (MLC) + WebGPU** for the optional in-browser AI coach

## Run

```bash
cd web
npm install
npm run dev      # open the printed localhost URL
```

Other scripts: `npm run build` (typecheck + production build), `npm run preview`
(serve the build), `npm run typecheck`.

First load seeds ~21 days of mock check-ins (like the iOS `seedMockDataIfEmpty`) so
the wheel and charts are populated, then routes through the 3-step onboarding.

## Structure

```
src/
├── models/energy.ts        # Energy, EnergyScores, Scoring, QuestionBank  (← EnergyDomain.swift)
├── coach/ruleBasedCoach.ts # balance-band coaching templates              (← RuleBasedCoach.swift)
├── store/                  # Dexie schema + store ops + live hooks        (← EnergyStore.swift)
├── theme/theme.ts          # JS color tokens for SVG/charts               (← Theme.swift)
├── index.css               # Tailwind + CSS-variable design tokens        (← Theme.swift)
├── components/             # Card, buttons, EnergyWheel, charts, Modal     (← Components.swift, EnergyWheel.swift)
└── views/                  # Onboarding, Dashboard, CheckIn, History, Settings (← Views/*)
```

## Parity notes

- The deterministic core (balance = `100 − (max − min)`, bottleneck with pyramid
  tie-break, `physicalFloorCapping`, the 9-question bank, daily-set selection, and
  the three coaching bands) is a line-for-line port — same numbers, same copy.
- The energy wheel uses the same screen-angle quadrant convention as SwiftUI
  (spiritual BR, emotional BL, physical TL, mental TR) and the same hex colors.
- **On-device AI coach:** ported via **WebLLM + WebGPU** running an open-source
  model (**Qwen2.5-0.5B-Instruct**, Apache-2.0 — the same model the iOS app lists)
  entirely in the browser. Enable it in **Settings → Coaching** (one-time ~350MB
  download, cached). Like iOS, it only *enhances prose*; scoring stays
  deterministic and the rule-based coach is the always-available fallback. The
  coach runs in a Web Worker (`src/coach/llm.worker.ts`) and needs WebGPU
  (Chrome/Edge or Safari 18+; not Firefox by default).
- **Future cloud sync:** to add the CloudKit equivalent (cross-device sync), put a
  backend (e.g. Supabase) behind `store/energyStore.ts` — the views and hooks read
  through that module, so the surface to change is small.
```
