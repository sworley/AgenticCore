{
  "_comment": "AgenticCore documentation policy. Injected into docs-engineer and lead-engineer agent bodies by sync-agents.sh.",
  "rules": [
    "All documentation lives in mddocs/ and builds via mdbook",
    "ADRs are forward-only, append-only — never edit an accepted ADR, create a superseding one",
    "SUMMARY.md must be updated for every new or modified doc",
    "Run mdbook clean && mdbook build after any mddocs/ change; zero errors required",
    "Code belongs in fenced code blocks, not raw file copies",
    "Images are thumbnails only; large images live outside mddocs/",
    "Use Mermaid diagrams only when they supplement or simplify the message",
    "Keep node labels short (2-4 words); prefer graph LR; limit to 4-6 nodes",
    "No customer data, internal URLs, or hardcoded credentials in documentation",
    "Links must resolve — verify before marking branch_ready"
  ]
}
