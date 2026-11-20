/home/user-name/project-name/mddocs
├── README.md
├── SUMMARY.md
├── book.toml
├── management
│   ├── README.md
│   ├── activity
│   │   ├── README.md
│   │   └── daily
│   │       ├── <year>
│   │       │   ├── <month> 
│   │       │   │   ├── <year-month-day>.md
│   │       │   │   └── README.md
│   │       │   └── README.md
│   │       └── README.md
│   ├── agentic
│   │   └── README.md
│   ├── architecture
│   │   ├── README.md
│   │   └── team-workspace-boundaries.md
│   ├── audits
│   │   ├── README.md
│   │   └── evidence
│   │       ├── documentation-mcp-20261022
│   │       │   ├── handshake-repair.json
│   │       │   └── registration.json
│   │       ├── mdbook-search-level2-2026-11-03
│   │       │   └── comparison.json
│   │       ├── mdbook-taxonomy-coverage-20261022
│   │       │   ├── coverage.json
│   │       │   ├── link-repair-scope.json
│   │       │   ├── link-repair-validation.json
│   │       │   └── navigation-reconciliation.json
│   │       ├── navigation-reconciliation-2026-11-02
│   │       │   ├── link-repair-validation.json
│   │       │   └── validation.json
│   │       ├── project-merge-20261028T171213Z
│   │       │   ├── merge-receipt.json
│   │       │   └── validation.json
│   │       ├── stepwise-approval-20261023
│   │       │   └── amendment.json
│   │       └── taxonomy-navigation-20261023T212209Z
│   │           └── navigation.json
│   ├── delivery
│   │   ├── README.md
│   │   ├── SOURCE_PROVENANCE.json
│   │   ├── artifact-management.md
│   │   ├── branch-and-pr-flow.md
│   │   ├── ci-cd-controls.md
│   │   ├── ci-secret-scanning-plan.md
│   │   ├── configuration-management.md
│   │   ├── customer-project-onboarding.md
│   │   ├── deployment-provenance.md
│   │   ├── environment-promotion.md
│   │   ├── rollback-and-recovery.md
│   │   ├── team-first-run-adoption.md
│   │   ├── team-python-environment.md
│   │   └── template-creation.md
│   ├── governance
│   │   ├── README.md
│   │   ├── controls
│   │   │   ├── README.md
│   │   │   ├── configuration-change-backup.md
│   │   │   ├── git-commit-guardrail.md
│   │   │   ├── independent-review-and-document-quality.md
│   │   │   └── stepwise-operator-approval.md
│   │   ├── decisions
│   │   │   ├── ADR-000X-<ADR document name>.md
│   │   │   ├── ...
│   │   │   └── README.md
│   │   ├── exceptions
│   │   │   ├── README.md
│   │   │   ├── WAV-000X-Waiver document name>.md
│   │   │   └── waiver-log.md
│   │   ├── ownership
│   │   │   └── README.md
│   │   └── policies
│   │       ├── README.md
│   │       ├── adr-and-waiver-governance.md
│   │       ├── document-taxonomy.md
│   │       └── mission-evidence-and-review.md
│   ├── mcp
│   │   ├── README.md
│   │   └── docs_mcp
│   │       ├── docs_root.py
│   │       ├── docs_server.py
│   │       ├── mcp_protocol.py
│   │       └── test_docs_mcp.py
│   ├── reports
│   │   ├── README.md
│   │   ├── <Report document name>.md
│   ├── runbooks
│   │   ├── README.md
│   │   ├── codex-startup.md
│   │   ├── configuration-recovery.md
│   │   ├── documentation-mcp.md
│   │   ├── documentation-tooling.md
│   │   ├── team-readiness.md
│   │   └── template-deployment.md
│   ├── telemetry
│   │   └── README.md
│   └── tooling
│       ├── README.md
│       ├── git-hooks
│       │   ├── README.md
│       │   ├── pre-commit
│       │   └── test_pre_commit.py
│       ├── mddoc-assets
│       │   ├── collapsible-sidebar.css
│       │   ├── collapsible-sidebar.js
│       │   ├── external-links.js
│       │   ├── mermaid-init.js
│       │   └── mermaid.min.js
│       ├── project_protection
│       │   ├── profile.schema.json
│       │   ├── requirements-test.txt
│       │   └── test_profile_schema.py
│       ├── python
│       │   └── requirements
│       │       ├── runtime-linux-x86_64-cpython313.lock
│       │       ├── test-linux-x86_64-cpython313.lock
│       │       └── verified-target.json
│       └── scripts
│           ├── adoption_state.py
│           ├── build.sh
│           ├── create_venv.py
│           ├── install_dependencies.py
│           ├── receipt_check.py
│           ├── team-adopt.sh
│           ├── template-deploy.sh
│           ├── test_adoption_state.py
│           ├── test_create_venv.py
│           ├── test_install_dependencies.py
│           ├── test_receipt_check.py
│           ├── test_team_adopt.py
│           ├── test_template_deploy.py
│           └── validate_book.py
└── projects
    ├── <Project Name>
    │   ├── README.md
    │   ├── activities
    │   │   ├── README.md
    │   │   └── <Activity Name>
    │   │       ├── README.md
    │   │       ├── docs
    │   │       │   ├── 01-<document name>.md
    │   │       │   ├── ...
    │   │       └── templates
    │   │           ├── PROJECT_DESCRIPTION.md
    │   │           ├── PROJECT_README.md
    │   │           ├── REPOSITORY_README.md
    │   │           └── RESEARCH_EXPERIMENT_ISSUE.md
    │   ├── activity
    │   │   └── daily
    │   │       └── <year>
    │   │           └── <month>
    │   │               └── <year-month-day>.md
    │   └── runbooks
    │       ├── README.md
    │       ├── <Runbook document name>.md
    │       └── ...
    └── ...
