// React hook exposing the live AI-coach load status (idle/loading/ready/error).

import { useEffect, useState } from "react";
import { aiCoach, type CoachStatus } from "./aiCoach";

export function useAICoachStatus(): CoachStatus {
  const [status, setStatus] = useState<CoachStatus>(aiCoach.status);
  useEffect(() => aiCoach.subscribe(setStatus), []);
  return status;
}
