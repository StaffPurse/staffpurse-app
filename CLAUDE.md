# CLAUDE.md

@AGENTS.md

This file exists only because Claude Code looks for `CLAUDE.md` specifically and does not
natively read `AGENTS.md` (confirmed as of Claude Code 2.1.201, mid-2026 — worth re-checking
if you're reading this much later, Anthropic may have added native support since). The `@`
import line above pulls in the full instruction set from `AGENTS.md`, which is the canonical
file — edit that one, not this one, when project instructions change. If the import syntax
above ever stops working in your Claude Code version, the fallback is a symlink:
`ln -s AGENTS.md CLAUDE.md` (won't work identically on Windows without WSL or a dev-mode
symlink permission — the `@` import is the more portable option).

## Claude-Code-specific notes (not covered by AGENTS.md, which is tool-agnostic)

- If you run `/init` in this repo, Claude Code will try to generate its own CLAUDE.md from
  the codebase — don't let it overwrite this file. If it already exists with real content,
  `/init` should incorporate rather than replace it, but check the diff before accepting.
- Given how much of this project depends on BMONI API specifics that are only partially
  verified (see AGENTS.md → "still genuinely unverified"), prefer running with approval
  required on file writes and shell commands over full-autonomy mode, at least until the
  onboarding + card-issuance flow (Prompt 2 / Prompt 3 in PROMPT.md) is working end-to-end
  against the sandbox once.
