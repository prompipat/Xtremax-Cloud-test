# Submission format check

Applicant: **Prompipat Thongtub**.

Source: the recruiter-provided `Cloud_Engineer_-_Technical_Test_-_Xtremax.pdf` (four pages). The PDF defines the requested deliverables; the development plan is supporting guidance. Checked on 1 November 2026 (Asia/Bangkok).

| PDF requirement | Location in the submission |
|---|---|
| Page 1: report within four days after receiving the test | Confirm the receipt date and deadline against the recruiter email; neither is inferred from the report date |
| Page 3: Terraform scripts inside a ZIP | Attach `terraform-source.zip` |
| Page 3: architecture, configuration and security documentation | Attach `report.pdf`; Markdown source and focused documents are also in the ZIP |
| Page 3: test plan and results | `docs/test-plan.md`, `docs/test-results.md` and sanitized `evidence/` in the ZIP; results summarized in the report |
| Page 3: system diagram | Report section 3 and `docs/architecture.svg` in the ZIP |
| Page 4: module structure diagram | Report section 4 and `docs/module-structure.svg` in the ZIP |
| Page 4: describe modules and their inputs/outputs, with root file examples | Report sections 4 and 5; individual `modules/*/README.md`; `terraform.tfvars.example` supplies safe sample input values in place of private real tfvars |
| Page 4 FAQ: a Terraform plan may be provided instead of real provisioning | Sanitized real plan in `evidence/terraform-plan.txt`; no deployment or runtime success claimed |
| Page 4 FAQ: all deliverables in one email | Attach both ZIP and PDF to the same email; GitHub is an additional convenience link |

The PDF does not prescribe an attachment filename, email subject, report font or exact heading template. The supplied PDF report and descriptive email subject are presentation choices. The report follows the requested content and includes both diagrams. It is written in English.

Before sending:

1. Confirm the recruiter recipient and the four-day deadline from the original email.
2. Use `submission/submission-email.txt`; the applicant name is filled in. Optional contact details may be added to the signature.
3. Attach `submission/terraform-source.zip` and `submission/report.pdf` together. The ZIP includes the report, diagrams, module contracts, tests and evidence.
4. Keep the plan-only and placeholder-domain disclosures. Runtime WordPress, certificate issuance, HTTPS and real 30-minute scaling tests remain NOT RUN.
5. Do not attach real tfvars, state, credentials or private saved plans.

No email has been sent by the preparation or packaging scripts.
