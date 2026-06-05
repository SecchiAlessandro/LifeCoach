// The daily check-in (Section 6.3) — slider questions + optional note, then
// deterministic scoring → coach → upsert today's entry. Port of
// Views/CheckIn/CheckInView.swift.

import { useEffect, useMemo, useState } from "react";
import {
  bottleneck,
  questionEnergy,
  scoresFromRaw,
  type CheckInQuestion,
} from "../models/energy";
import { energyHex, BALANCE_ACCENT } from "../theme/theme";
import { coachFor } from "../coach";
import { prepareDailyQuestions } from "../coach/questions";
import { currentProfile, recentEntries, upsert } from "../store/energyStore";
import { PrimaryButton } from "../components/ui";

export function CheckIn({ onClose }: { onClose: () => void }) {
  const [questions, setQuestions] = useState<CheckInQuestion[]>([]);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [note, setNote] = useState("");
  const [purpose, setPurpose] = useState("");
  const [loading, setLoading] = useState(true);
  const [scoring, setScoring] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const [recent, profile] = await Promise.all([recentEntries(14), currentProfile()]);
      const qs = await prepareDailyQuestions(profile, recent);
      if (cancelled) return;
      setPurpose(profile?.purpose?.trim() ?? "");
      setQuestions(qs);
      setAnswers((prev) => {
        const next = { ...prev };
        for (const q of qs) if (next[q.id] === undefined) next[q.id] = 5;
        return next;
      });
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function submit() {
    setScoring(true);
    const rawAnswers: Record<string, number> = {};
    for (const [id, v] of Object.entries(answers)) rawAnswers[id] = Math.round(v);

    const scores = scoresFromRaw(rawAnswers);
    const profile = await currentProfile();
    const result = await coachFor(profile, scores, bottleneck(scores));

    await upsert({
      scores,
      coaching: result.coaching,
      ritualNudge: result.ritualNudge,
      coachSource: result.source,
      rawAnswers,
      note: note.trim() === "" ? undefined : note,
    });
    setScoring(false);
    onClose();
  }

  return (
    <div className="flex flex-col">
      <div className="flex items-center justify-between px-5 pt-5">
        <button className="text-secondary" onClick={onClose}>
          Cancel
        </button>
        <span className="text-[13px] font-semibold text-secondary">Check-in</span>
        <span className="w-12" />
      </div>

      <div className="flex flex-col gap-7 px-5 py-6">
        <div className="flex flex-col gap-1.5">
          <h1 className="font-display text-[26px] font-bold text-primary">How is your energy today?</h1>
          {purpose && (
            <p className="text-[13px] italic text-secondary">With your why in mind: “{purpose}”</p>
          )}
        </div>

        {loading ? (
          <p className="py-10 text-center text-secondary">Preparing your questions…</p>
        ) : (
          <>
            {questions.map((q) => (
              <QuestionRow
                key={q.id}
                question={q}
                value={answers[q.id] ?? 5}
                onChange={(v) => setAnswers((a) => ({ ...a, [q.id]: v }))}
              />
            ))}

            <div className="flex flex-col gap-2">
              <label className="text-[13px] font-bold text-secondary">Note (optional)</label>
              <textarea
                value={note}
                onChange={(e) => setNote(e.target.value)}
                rows={3}
                placeholder="Anything worth remembering about today…"
                className="w-full resize-none rounded-[12px] bg-surface p-3 text-[15px] text-primary outline-none"
              />
            </div>
          </>
        )}
      </div>

      <div className="sticky bottom-0 px-4 pb-5 pt-2" style={{ background: "var(--canvas)" }}>
        <PrimaryButton
          title={scoring ? "Scoring…" : "See my energy"}
          disabled={loading || scoring}
          onClick={submit}
        />
      </div>
    </div>
  );
}

function QuestionRow({
  question,
  value,
  onChange,
}: {
  question: CheckInQuestion;
  value: number;
  onChange: (v: number) => void;
}) {
  const energy = questionEnergy(question);
  const tint = useMemo(() => (energy ? energyHex(energy) : BALANCE_ACCENT), [energy]);

  return (
    <div className="flex flex-col gap-2.5 rounded-[18px] bg-surface p-4">
      <p className="text-[16px] font-medium text-primary">{question.text}</p>
      <input
        type="range"
        min={0}
        max={10}
        step={1}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        style={{ "--slider-tint": tint } as React.CSSProperties}
      />
      <div className="flex items-center justify-between text-[12px] text-secondary">
        <span>{question.lowLabel}</span>
        <span className="text-[13px] font-bold" style={{ color: tint }}>
          {Math.round(value)}
        </span>
        <span>{question.highLabel}</span>
      </div>
    </div>
  );
}
