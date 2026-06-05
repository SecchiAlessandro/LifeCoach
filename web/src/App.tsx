// Routes between onboarding and the main three-tab shell (Section 6):
// Today · History · Settings. Port of RootView + MainTabView in
// FullEngagementApp.swift.

import { useEffect, useState } from "react";
import { useHasOnboarded } from "./store/useStore";
import { seedMockDataIfEmpty } from "./store/energyStore";
import { Dashboard } from "./views/Dashboard";
import { History } from "./views/History";
import { Settings } from "./views/Settings";
import { Onboarding } from "./views/Onboarding";

type Tab = "today" | "history" | "settings";

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: "today", label: "Today", icon: "◴" },
  { id: "history", label: "History", icon: "📈" },
  { id: "settings", label: "Settings", icon: "⚙️" },
];

export default function App() {
  const onboarded = useHasOnboarded();
  const [seeded, setSeeded] = useState(false);
  const [tab, setTab] = useState<Tab>("today");

  // Seed ~21 days of mock data on first load (like RootView), so the wheel and
  // charts have something to show.
  useEffect(() => {
    void seedMockDataIfEmpty().finally(() => setSeeded(true));
  }, []);

  if (onboarded === undefined || !seeded) {
    return <div className="min-h-screen bg-canvas" />;
  }

  if (!onboarded) {
    return <Onboarding onComplete={() => setTab("today")} />;
  }

  return (
    <div className="min-h-screen bg-canvas pb-20">
      {tab === "today" && <Dashboard />}
      {tab === "history" && <History />}
      {tab === "settings" && <Settings />}

      {/* Bottom tab bar */}
      <nav
        className="fixed inset-x-0 bottom-0 z-40 flex justify-around border-t pt-2 pb-6"
        style={{ background: "var(--surface)", borderColor: "var(--hairline)" }}
      >
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className="flex flex-col items-center gap-0.5 px-6 text-[11px] font-medium"
            style={{ color: tab === t.id ? "var(--color-accent)" : "var(--text-secondary)" }}
          >
            <span className="text-[18px] leading-none">{t.icon}</span>
            {t.label}
          </button>
        ))}
      </nav>
    </div>
  );
}
