// WebLLM worker — runs WebGPU inference off the main thread so the UI stays
// responsive during generation. Paired with CreateWebWorkerMLCEngine in
// aiCoach.ts.

import { WebWorkerMLCEngineHandler } from "@mlc-ai/web-llm";

const handler = new WebWorkerMLCEngineHandler();
self.onmessage = (msg: MessageEvent) => handler.onmessage(msg);
