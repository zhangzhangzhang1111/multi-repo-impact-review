---
id: code-review-common
scope: all repositories
---

# Common review knowledge

Verify interface compatibility, error propagation, untrusted input handling, resource lifetime, concurrency, configuration behavior, platform and encoding assumptions, and regression coverage. Keep severity, blast radius, confidence, and business criticality as separate fields.

Treat the code graph as a discovery index. Confirm every edge used in a final impact path against source or an independent semantic analyzer.
