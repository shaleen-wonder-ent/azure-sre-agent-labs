---
name: entra-authentication
version: 1.0.0
description: Use for Entra sign-in and authentication troubleshooting. Aggregate sign-in and audit evidence, classify the failure stage, correlate identity configuration changes, and redact sensitive identity data.
tools:
  - SearchMemory
  - QueryLogAnalyticsByWorkspaceId
  - RunAzCliReadCommands
  - GetAzCliHelp
---

# Entra Authentication Troubleshooting

Investigate authentication failures for a user, application, or service principal and identify the
failing stage without exposing sensitive identity data.

## Evidence sources

- `SigninLogs`, `AADNonInteractiveUserSignInLogs`, `ServicePrincipalSignInLogs`, and
  `ManagedIdentitySignInLogs` for authentication outcomes and result codes.
- `AuditLogs` for credential rotation, application, consent, and Conditional Access policy changes.
- Azure RBAC (`az role assignment list`) only when the failure is downstream authorization, not sign-in.
- When the Entra sign-in tables are not available in the workspace, use the `entra-signin-fixture.json`
  records provided with this skill. Their fields follow the `SigninLogs` and `AuditLogs` schema, so the
  same aggregation and classification apply.

## Workflow

1. Restate scope: target user/app/principal, resource, and explicit UTC window.
2. Aggregate first. Group failures by `ResultType`, application, principal, IP prefix, and time.
   Never page through raw per-event rows.
3. Classify the failing stage for each cluster:
   - Authentication: bad credential, expired or wrong secret, locked account.
   - Multi-factor: MFA required or not satisfied.
   - Conditional Access: policy blocked token issuance.
   - Consent / API permission: user or admin consent missing.
   - Federation / token: audience, authority, or token acquisition error.
   - Azure authorization: sign-in succeeded but RBAC denied the resource action.
4. Correlate `AuditLogs` changes (secret rotation, CA policy edits, consent grants) that precede the
   failure spike, but do not assert causality without a matching time and target.
5. Recommend the least disruptive fix with owner, risk, rollback, and verification. Do not change
   identity, credentials, consent, Conditional Access, or RBAC yourself.

## Result code reference

| ResultType | Meaning | Stage |
|---|---|---|
| 0 | Success | - |
| 50126 | Invalid username or password | Authentication |
| 50053 | Account locked (too many failed attempts) | Authentication |
| 50055 / 50057 | Expired or disabled credential/account | Authentication |
| 50076 / 50079 | MFA required or registration required | Multi-factor |
| 53003 | Blocked by Conditional Access policy | Conditional Access |
| 53000 / 53001 | Device not compliant / not domain joined | Conditional Access |
| 7000215 | Invalid client secret | Authentication (app) |
| 7000222 | Expired client secret | Authentication (app) |
| 700016 | Application not found in directory | Application config |
| 65001 | User or admin has not consented | Consent / API permission |
| 650057 | Invalid resource / permission not granted | Consent / API permission |
| 500011 | Resource principal not found in tenant | Federation / token |

## Redaction rules

- Never output full IP addresses; truncate to a network prefix.
- Never output credential material, secret values, tokens, or full object IDs of real people.
- Report user identities by role or a single reference, not full contact details.
- Redact any personally identifiable information beyond what is needed to name the affected principal.

## Required report

Return scope and UTC window, source and coverage, a failure summary aggregated by result code and
principal, the classified failing stage per cluster, correlated identity/config changes, ranked
hypotheses with confidence, the least disruptive recommendation with approval requirement, and
verification plus data gaps.
