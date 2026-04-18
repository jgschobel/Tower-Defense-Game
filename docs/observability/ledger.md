# Workflow Observability Ledger

Human-readable log of every scheduled/triggered workflow run. Workflows
append here so the chat-session Claude (with no direct Actions API
access) can `Read` this file and see what's been happening.

Format: one entry per run, newest first. Truncated to last ~100 entries
by a daily cron pruner.

---
- 2026-04-18T21:13:19Z · deploy-web · ok · run=24613993701 · sha=2add9d7
