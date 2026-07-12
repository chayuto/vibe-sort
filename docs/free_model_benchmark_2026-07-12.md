# Free-Tier Model Benchmark — 2026-07-12

An empirical snapshot of how free LLM tiers handle vibe-sort's sorting contract, gathered
while designing v0.4.0 (OpenRouter provider, key-format detection, `extra_params` —
see [v0.4.0_PLAN.md](v0.4.0_PLAN.md)). All requests used free models / free-tier quota only.

**TL;DR:** Google's current Gemini flash models all sort correctly through the gem's exact
payload, with `gemini-3.1-flash-lite` the clear free-tier pick. OpenRouter's `:free` pool was
too congested on a Saturday afternoon (AEST) to be usable — 14 of 17 tested models failed with
rate limits or upstream errors, and one burned 10 minutes and 20k tokens to return nothing.

---

## Methodology

- **Task:** sort `[42, "banana", 7, "Apple", 3.14, "cherry", 1]`
  → expected `[1, 3.14, 7, 42, "Apple", "banana", "cherry"]`
- **Payloads:** byte-for-byte what the gem sends — `Providers::OpenAI#build_payload` for
  OpenRouter (system prompt + `temperature: 0.0` + `response_format: {type: "json_object"}`),
  `Providers::Gemini#build_payload` for Gemini (`systemInstruction` +
  `generationConfig.responseMimeType: "application/json"`).
- **Success criteria:** HTTP 200, content parses as JSON with a `sorted_array` key
  (the gem's contract), array exactly matches the expected sort.
- **Fallbacks tried on rejection:** OpenRouter — retry without `response_format`;
  Gemini — retry with system prompt folded into the user turn and no JSON mime type.
- **Pacing/retries:** 3.5–8s between requests; 5xx retried up to 3×; 429 handling varied by
  pass (see Lessons). Plain Ruby `net/http`, no SDKs.
- **Cost:** $0. OpenRouter restricted to `$0`-priced models; Gemini restricted to
  free-tier models with non-zero quota.

---

## Gemini API (free tier)

7 models tested — every model whose free-tier quota is non-zero.

| Model | Outcome | Latency | Tokens in/out (+thinking) | Notes |
|---|---|---|---|---|
| gemini-3.1-flash-lite | ✅ correct | **2.08s** | 87/35 (+0) | Fastest; no thinking tokens; best quota (15 RPM / 500 RPD) |
| gemini-2.5-flash | ✅ correct | 2.66s | 87/49 (+247) | Gem's current `DEFAULT_MODEL` — still works |
| gemini-3.5-flash | ✅ correct | 5.98s | 87/50 (+418) | Most thinking tokens |
| gemini-3-flash-preview | ✅ correct | 24.14s | 87/49 (+321) | Correct but slow |
| gemma-4-26b-a4b-it | ❌ bad JSON | 28.6s | 87/49 (+318) | Ignored JSON mime type; replied with markdown reasoning; 1×500 on the way |
| gemma-4-31b-it | ❌ bad JSON | 9.8s | 87/30 (+256) | Same failure shape; also 1×500 |
| gemini-2.5-flash-lite | ❌ HTTP 404 | — | — | "No longer available to new users" (still listed by the models endpoint) |

### Observations

- **All four current Gemini-branded flash models pass the gem's contract as-is** — JSON mode
  honored, sort correct, numbers-before-strings and case-sensitivity respected.
- **Gemma models are incompatible with the gem today:** they accept the request but ignore
  `responseMimeType: "application/json"` and return reasoning-style markdown. They'd need
  `extra_params` surgery plus response post-processing — not worth it.
- **The 500s are real:** 2 of 7 models needed a 5xx retry on their very first request.
  Any Gemini integration should retry 5xx at least once.
- **429 retries are a trap on the free tier:** every retry counts against RPM *and* RPD, so a
  retry loop converts one throttled request into three consumed ones. After the daily caps
  (20 RPD on most flash models) tripped, throttling also turned intermittent — consecutive
  requests to the same model went 429, 429, 200. Policy that survives: never auto-retry a
  free-tier 429; skip and move on.
- An input-length scaling test (5/20/50/100 elements) was attempted but the RPD caps were
  exhausted before it could run. Future work, pending quota reset — only
  `gemini-3.1-flash-lite` (500 RPD) realistically supports this kind of testing for free.

---

## OpenRouter (free models)

26 models on openrouter.ai were $0-priced with text input (of 345 listed). 17 were tested
before the sweep was aborted; 9 were never reached. Tested on a Saturday afternoon AEST —
peak congestion for the shared free pool, which colours everything below.

| Model | Outcome | Notes |
|---|---|---|
| nvidia/nemotron-3-super-120b-a12b:free | ❌ empty content | **600s, 20,673 completion tokens, no answer** — presumably all reasoning |
| nvidia/nemotron-3.5-content-safety:free | ❌ bad JSON | Replied "User Safety: safe" — it's a classifier, not a chat model |
| nvidia/nemotron-nano-12b-v2-vl:free | ❌ upstream timeout | "Upstream idle timeout exceeded" after 121s |
| nvidia/nemotron-3-nano-30b-a3b:free | ❌ upstream error | NVIDIA "ResourceExhausted: worker limit reached" |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | ❌ upstream error | Same |
| nvidia/nemotron-3-ultra-550b-a55b:free | ❌ upstream error | Same |
| nvidia/nemotron-nano-9b-v2:free | ⏹ aborted | Stalled the sweep twice with a slow-drip connection (>20 min) |
| liquid/lfm-2.5-1.2b-instruct:free | ❌ HTTP 502 | Upstream down |
| liquid/lfm-2.5-1.2b-thinking:free | ❌ HTTP 502 | Upstream down |
| google/lyria-3-clip-preview | ❌ HTTP 400 | Music model; listed as $0 text-input but not a chat model |
| google/lyria-3-pro-preview | ❌ HTTP 400 | Same |
| cognitivecomputations/dolphin-mistral-24b-venice-edition:free | ❌ HTTP 429 | Free pool congested (retried in a 2nd pass ~1h later — still 429) |
| cohere/north-mini-code:free | ❌ HTTP 429 | Explicit "High demand" RPM-limit message |
| google/gemma-4-26b-a4b-it:free | ❌ HTTP 429 | Congested both passes |
| google/gemma-4-31b-it:free | ❌ HTTP 429 | Congested both passes |
| meta-llama/llama-3.2-3b-instruct:free | ❌ HTTP 429 | Congested both passes |
| meta-llama/llama-3.3-70b-instruct:free | ❌ HTTP 429 | Congested both passes |
| nousresearch/hermes-3-llama-3.1-405b:free | ❌ HTTP 429 | Congested both passes |
| openai/gpt-oss-120b:free, openai/gpt-oss-20b:free, openrouter/free, poolside/laguna-m.1:free, poolside/laguna-xs-2.1:free, qwen/qwen3-coder:free, qwen/qwen3-next-80b-a3b-instruct:free, tencent/hy3:free | ⏸ not tested | Sweep aborted before reaching them (blocked behind the stalling Nemotron) |

### Observations

- **Zero of 17 tested free models completed a correct sort** during this window. This is a
  statement about the free pool's availability on a weekend afternoon, not about the models —
  nearly every failure was infrastructure (429/5xx/upstream), not model output.
- **The transport layer of a vibe-sort OpenRouter adapter is validated**, though: auth,
  routing, the OpenAI-compatible payload, and OpenRouter's error shape
  (`error.message` — including passed-through upstream provider errors) all behaved exactly
  as `Providers::Base#extract_error_message` expects.
- **Free-model quirks to document:** `$0` pricing does not imply chat-usable (Lyria = music,
  content-safety = classifier); reasoning models can consume enormous token counts and still
  return empty content; per-request wall time is unbounded in practice (slow-drip responses
  blow through per-read timeouts), so an overall deadline is the only safe timeout.
- Free-model requests are also account-capped on OpenRouter (daily request limits tied to
  credit balance) — fine for smoke tests, unusable for CI.

---

## Implications for vibe-sort v0.4.0

1. **OpenRouter adapter: ship it.** The mechanics are proven even though the free pool was
   congested; with any paid model (or an off-peak free window) it should behave like the
   other OpenAI-compatible adapters. Don't default to a `:free` model — congestion would make
   the gem look broken.
2. **Gemini `DEFAULT_MODEL`:** `gemini-2.5-flash` still works, but Google has begun retiring
   2.5-era models for new users (2.5-flash-lite already 404s). `gemini-3.1-flash-lite` is
   faster here, spends no thinking tokens on this task, and has the widest free quota —
   a strong candidate for the next default.
3. **`extra_params` earns its place:** overriding `response_format`, capping `max_tokens` on
   reasoning models, and OpenRouter provider-routing preferences were all wanted during this
   exercise.
4. **Never auto-retry 429s against free tiers** in examples/docs; retries multiply quota
   consumption and prolong the lockout.

## Reproduction

Standalone Ruby scripts (plain `net/http`, no gem dependencies) sent the exact adapter
payloads; per-model raw results (latency, token usage, full error messages, returned arrays)
were captured as JSON. API keys were session-scoped test keys, not committed. Numbers above
are single-shot measurements on free tiers — directional, not statistical.
