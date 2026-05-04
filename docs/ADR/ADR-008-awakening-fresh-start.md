# ADR-008: Awakening sends NO prior history

## Decision
When a new alter wakes (pod opens for the first time), the GM request that produces their first line ships ONLY the awakening prompt — no prior conversation history is included. The new alter sounds disoriented and just-emerged.

## Intent (manifesto tie-in)
The pod is a literal jar. The alter inside has been sealed. They shouldn't sound like they were eavesdropping while Goske talked to other alters across the room — that would dissolve both the agency of "I chose to wake them" and the disorientation of waking up.

Manifesto: structural, not cosmetic. The alter's lack of memory is a STRUCTURAL fact about the pod, not flavor.

## Note to future-me
If a freshly woken alter sounds like they know prior dialogue, this ADR is the fix to revisit:
- We had a turn where blue and green chatted, then we opened red. Red's first line referenced the prior conversation — clearly the model had read history.
- The bug was: `_request_alter_awakening` duplicated `history` and appended an awakening prompt. The GM saw everything and treated red as "always present, just hadn't spoken yet."
- The fix: ship only `[{role: "user", content: awakening_prompt}]`. No history. Ever. The awakening prompt itself states "they have NO knowledge of any conversation that came before."
- Once the alter is greeted, their lines DO go into history, and subsequent turns DO ship full history. Only the first call is naive.

If you want a future variant (e.g., an alter who DID hear prior conversation as part of the lore):
- That's a different mechanic. Don't shoehorn it into awakening. Add an `awakening_mode` parameter or new method.

## Considered, rejected
- Pass full history with a softer "they didn't pay attention to prior dialogue" instruction — leaked. The model still echoed what it read.
- Pass partial history (last N turns) — same problem.
- Have the awakening line be hand-authored fallback — boring, manifesto-violating (canned dialog).

## Result (code-side)
- `conversation.gd._request_alter_awakening`:
  - Builds `awakening_only = [{ role: "user", content: "[<id> alter has just woken up... NO knowledge of any conversation that came before. ONLY <id> should speak; first line should sound disoriented..."}]`.
  - Calls `gm.request_turn(awakening_only, _world_state(), _on_gm_turn)`.
- World state IS still passed (counts, trust, days_alone) — that's allowed because it's not dialogue, it's the alter looking at the world they wake into.
- After the awakening response is rendered, normal history takes over.
