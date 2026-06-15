# Static Site Deployment on AWS — S3 + CloudFront + HTTPS + Custom Domain

**Course:** Mastering DevOps — Module 3 (AWS Static Site Hosting)  
**Author:** MD Sarowar Alam · Lead DevOps Engineer, WPP Production  
**Live URL:** https://master.ostaddevops.click  
**Domain:** `master.ostaddevops.click` (Route 53 → CloudFront)

---

## 1. Project Overview

This repository demonstrates two progressive deployment strategies for a React + Vite single-page application (SPA) on AWS, starting from the simplest possible approach and evolving to a production-grade architecture:

| | Phase 1 | Phase 2 |
|---|---|---|
| **Goal** | Fastest path to a live static site | Production-grade with HTTPS + private origin |
| **Bucket access** | Public (S3 website hosting) | Private (CloudFront OAC only) |
| **HTTPS** | ❌ HTTP only | ✅ TLS 1.2+ via ACM |
| **Custom domain** | ❌ | ✅ `master.ostaddevops.click` |
| **CDN** | ❌ | ✅ CloudFront (global edge) |
| **Security headers** | ❌ | ✅ AWS `SecurityHeadersPolicy` |
| **SPA routing** | ✅ via S3 error document | ✅ via CloudFront custom error responses |
| **Setup script** | `.\setup-phase1.ps1` | `.\setup-phase2.ps1` |

Both phases are **fully independent** — they use separate S3 buckets and can coexist.

---

## 2. Architecture Overview

### Phase 1 — Public S3 Static Website

```
Browser ──HTTP──► S3 Static Website Endpoint
                  (master-ostaddevops-site, ap-south-1)
                  Public read policy applied
                  SPA routing: error doc = index.html
```

### Phase 2 — Private S3 + CloudFront + HTTPS

```
Browser
  │
  ├─HTTPS─► Route 53 (A alias)
  │          master.ostaddevops.click
  │          └─► CloudFront Distribution
  │               ├─ ACM cert (us-east-1, TLS 1.2+)
  │               ├─ OAC SigV4 signing
  │               ├─ SecurityHeadersPolicy (HSTS, X-Frame, X-Content-Type)
  │               ├─ CachingOptimized policy
  │               ├─ 403 → /index.html (200)  ← SPA routing
  │               ├─ 404 → /index.html (200)  ← SPA routing
  │               └─► S3 REST Endpoint (private)
  │                    master-ostaddevops-site-private
  │                    ap-south-1
  │                    Block Public Access: ON
  │                    Versioning: enabled
  │                    Encryption: SSE-S3 (AES-256)
  │                    Bucket policy: OAC source ARN only
  └─HTTP──► CloudFront redirects to HTTPS
```

**Data flow:**
1. Browser resolves `master.ostaddevops.click` → CloudFront IP via Route 53 A alias
2. CloudFront terminates TLS, checks cache
3. On cache miss: CloudFront signs request with SigV4 OAC and fetches from private S3
4. CloudFront adds security headers and returns response to browser
5. React Router handles client-side navigation; unknown paths return `index.html` (200) for SPA routing

---

## 3. Technology Stack

| Layer | Technology | Version | Purpose |
|---|---|---|---|
| Frontend | React | 19.1.0 | UI framework |
| Frontend | React Router DOM | 7.5.0 | Client-side SPA routing (`BrowserRouter`) |
| Frontend | Tailwind CSS | 4.1.3 | Utility-first CSS (via Vite plugin) |
| Build tool | Vite | 6.3.1 | Dev server + production bundler |
| CDN | AWS CloudFront | — | Global edge delivery, HTTPS termination |
| Object storage | AWS S3 | — | Static asset hosting (private in Phase 2) |
| DNS | AWS Route 53 | — | A alias record → CloudFront |
| TLS | AWS ACM | — | Free managed certificate (`us-east-1`) |
| TLS issuance | Let's Encrypt + Certbot | 5.6.0 | Certificate issuance via DNS-01 challenge |
| Certbot plugin | `certbot-dns-route53` | — | Automated DNS validation via Route 53 |
| CLI | AWS CLI | v2 | Infrastructure provisioning |
| Scripting | PowerShell | 5.1+ | Automation scripts (`setup-phase1/2.ps1`) |
| Scripting | Bash | — | Certificate script (`certbot-import.sh`) |
| Runtime (cert) | Python | 3.11+ | Certbot runtime |

---

## 4. Repository Structure

```
.
├── master-site/                        # React + Vite SPA source
│   ├── index.html                      # HTML shell (Vite entry point)
│   ├── vite.config.js                  # Vite: React + Tailwind CSS plugins
│   ├── package.json                    # Node dependencies
│   └── src/
│       ├── main.jsx                    # React root — BrowserRouter wrapper
│       ├── App.jsx                     # Route definitions (/, /about, /modules, /contact)
│       ├── index.css                   # @import "tailwindcss"
│       ├── components/
│       │   ├── Navbar.jsx              # Responsive sticky navigation
│       │   └── Footer.jsx              # Footer with links and socials
│       └── pages/
│           ├── Home.jsx                # Hero, features, phase journey, CTA
│           ├── About.jsx               # Program info and instructor
│           ├── Modules.jsx             # 12 course modules with breakdowns
│           └── Contact.jsx             # Contact cards, FAQ accordion
│
├── infra/
│   ├── bucket-policy-phase1.json       # S3 public read policy (Phase 1)
│   ├── bucket-policy-phase2.json       # S3 OAC-scoped private policy (Phase 2)
│   └── cloudfront-distribution.json   # CloudFront distribution config template
│
├── setup-phase1.ps1                    # Phase 1 full automation: setup + teardown
├── setup-phase2.ps1                    # Phase 2 full automation: setup + teardown
├── certbot-import.sh                   # Let's Encrypt cert issuance + ACM import
├── PHASE1-PUBLIC-S3.md                 # Phase 1 step-by-step guide (GUI + script)
├── PHASE2-PRIVATE-CLOUDFRONT.md        # Phase 2 step-by-step guide (GUI + script)
├── .gitignore                          # Excludes dist/, node_modules/, state files
└── README.md                           # This file
```

**Not committed (gitignored):**
- `master-site/dist/` — Vite production build output
- `master-site/node_modules/` — npm dependencies
- `.phase1-state.json` / `.phase2-state.json` — local setup state (teardown tracking)
- `.env`, `.env.local` — environment secrets

---

## 5. Application Routes

| Path | Component | Description |
|---|---|---|
| `/` | `Home.jsx` | Hero section, features, tools, phase journey, CTA |
| `/about` | `About.jsx` | Program overview, learning objectives, instructor |
| `/modules` | `Modules.jsx` | All 12 DevOps course modules with live class breakdowns |
| `/contact` | `Contact.jsx` | Contact cards, enrolment CTA, FAQ accordion |

All routes are client-side (React Router `BrowserRouter`). Direct URL access and page refresh work because CloudFront is configured to return `index.html` with HTTP 200 for both 403 and 404 errors.

---

## 6. Infrastructure

### AWS Resources — Phase 1

| Resource | Name / Value |
|---|---|
| S3 Bucket | `master-ostaddevops-site` (ap-south-1) |
| Bucket access | Public (Block Public Access OFF) |
| Website hosting | Enabled — index doc: `index.html`, error doc: `index.html` |
| Bucket policy | `infra/bucket-policy-phase1.json` (public `s3:GetObject`) |
| Endpoint | `http://master-ostaddevops-site.s3-website.ap-south-1.amazonaws.com` |

### AWS Resources — Phase 2

| Resource | Name / Value |
|---|---|
| S3 Bucket | `master-ostaddevops-site-private` (ap-south-1) |
| Bucket access | Private (Block Public Access ON) |
| Versioning | Enabled |
| Encryption | SSE-S3 (AES-256) |
| Bucket policy | `infra/bucket-policy-phase2.json` (OAC source ARN only) |
| OAC | `master-oac` (SigV4, always-sign, S3 type) |
| CloudFront | Alias: `master.ostaddevops.click`, HTTP/2, IPv6 |
| Cache policy | `658327ea-f89d-4fab-a63d-7e88639e58f6` (CachingOptimized) |
| Response headers | `67f7725c-6f97-4210-82d7-5512b31e9d03` (SecurityHeadersPolicy) |
| ACM Certificate | `us-east-1` (required for CloudFront) — Let's Encrypt via Certbot |
| Route 53 | A alias: `master.ostaddevops.click` → CloudFront (`Z2FDTNDATAQYW2`) |
| Hosted Zone | `ostaddevops.click` / `Z1019653XLWIJ02C53P5` |

### Infrastructure Templates

| File | Purpose | Placeholders |
|---|---|---|
| `infra/bucket-policy-phase1.json` | Public read — Phase 1 | None |
| `infra/bucket-policy-phase2.json` | OAC-only access — Phase 2 | `ACCOUNT_ID`, `DISTRIBUTION_ID` (resolved at runtime by script) |
| `infra/cloudfront-distribution.json` | CloudFront distribution config | `REPLACE_WITH_OAC_ID` (patched in-memory by script, file never modified) |

---

## 7. Automation Scripts

### `setup-phase1.ps1`

Self-contained Phase 1 automation. No external dependencies.

```powershell
.\setup-phase1.ps1           # Setup: create bucket + configure + build + deploy
.\setup-phase1.ps1 -Teardown # Teardown: reverse all Phase 1 changes
```

**Setup steps (1–5):**
1. Create `master-ostaddevops-site` bucket (idempotent; saves `BucketCreatedByUs` to state)
2. Remove Block Public Access
3. Enable static website hosting (`index.html` / `index.html`)
4. Apply `infra/bucket-policy-phase1.json`
5. `npm install` (if missing) → `npm run build` → `aws s3 sync --delete`

**Teardown behaviour:**
- Bucket created by script → empties and deletes it
- Bucket pre-existed → removes policy + website config + restores Block Public Access only

State: `.phase1-state.json` (gitignored)

---

### `setup-phase2.ps1`

Self-contained Phase 2 automation. Fully independent of Phase 1.

```powershell
.\setup-phase2.ps1           # First run: full infra + deploy. Subsequent runs: re-deploy only
.\setup-phase2.ps1 -Teardown # Teardown: reverse all Phase 2 changes
```

**Setup steps (1–7):**
1. Create `master-ostaddevops-site-private` (idempotent); harden: Block Public Access ON, versioning, SSE-S3
2. Create CloudFront OAC (`master-oac`, SigV4)
3. Create CloudFront distribution (patches template in-memory — template file never modified on disk)
4. Apply OAC-only bucket policy (`ACCOUNT_ID` + `DISTRIBUTION_ID` resolved at runtime)
5. Create Route 53 A alias UPSERT → CloudFront
6. Wait for CloudFront to deploy (~5–15 min)
7. `npm install` (if missing) → `npm run build` → `aws s3 sync --delete` → CloudFront invalidation

**Re-deploy (subsequent runs):** detects `DistributionId` in `.phase2-state.json`, skips infra, runs build + sync + invalidation only.

**Teardown behaviour (5 steps, reverse order):**
1. Delete Route 53 A alias
2. Disable CloudFront → wait → delete distribution
3. Delete OAC
4. Bucket created by script → delete all object versions + delete markers (versioning-safe) → delete bucket
5. Remove `.phase2-state.json`

State: `.phase2-state.json` (gitignored)

---

### `certbot-import.sh`

Issues or renews a Let's Encrypt certificate via DNS-01 challenge (Route 53) and imports it into AWS ACM.

```bash
# Run from Git Bash as Administrator
./certbot-import.sh -d master.ostaddevops.click -e sarowar@hotmail.com -p sarowar-ostad

# Options
./certbot-import.sh -d DOMAIN -e EMAIL [-r REGION] [-p AWS_PROFILE]
```

**Behaviour:**
- If cert already exists in ACM → re-imports with same ARN (`--certificate-arn`)
- If new domain → fresh import, captures new ARN
- Default region: `us-east-1` (required for CloudFront)

**Requirements:** Git Bash (Admin), Python 3.11+, `pip install certbot certbot-dns-route53`, AWS CLI v2

---

## 8. Prerequisites

| Tool | Minimum Version | Install |
|---|---|---|
| Node.js | 18+ | https://nodejs.org |
| npm | 9+ | Bundled with Node.js |
| AWS CLI | v2 | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| PowerShell | 5.1+ | Built-in on Windows; `winget install Microsoft.PowerShell` for v7 |
| Git Bash (cert only) | — | https://gitforwindows.org (run as Administrator for Certbot) |
| Python (cert only) | 3.11+ | https://www.python.org/downloads/ |
| certbot (cert only) | 5.6+ | `pip install certbot certbot-dns-route53` |

**AWS configuration:**

```powershell
aws configure --profile sarowar-ostad
# Enter: Access Key ID, Secret Access Key, default region (ap-south-1), output (json)
```

**Required IAM permissions:**

| Service | Actions |
|---|---|
| S3 | `s3:CreateBucket`, `s3:DeleteBucket`, `s3:PutObject`, `s3:DeleteObject`, `s3:PutBucketPolicy`, `s3:DeleteBucketPolicy`, `s3:PutBucketWebsite`, `s3:PutPublicAccessBlock`, `s3:PutBucketVersioning`, `s3:PutEncryptionConfiguration`, `s3:ListBucketVersions`, `s3:DeleteObjectVersion` |
| CloudFront | `cloudfront:CreateDistribution`, `cloudfront:UpdateDistribution`, `cloudfront:DeleteDistribution`, `cloudfront:CreateOriginAccessControl`, `cloudfront:DeleteOriginAccessControl`, `cloudfront:CreateInvalidation` |
| Route 53 | `route53:ChangeResourceRecordSets`, `route53:ListHostedZones`, `route53:GetChange` |
| ACM | `acm:ImportCertificate`, `acm:ListCertificates`, `acm:DescribeCertificate` |
| STS | `sts:GetCallerIdentity` |

---

## 9. Local Development Setup

```powershell
# 1. Clone the repository
git clone <repo-url>
cd s3-static-cloud-front-react-vite

# 2. Install frontend dependencies
cd master-site
npm install

# 3. Start development server (hot reload)
npm run dev
# → http://localhost:5173
```

No environment variables are required for local development. The app is a fully static SPA with no backend API calls.

---

## 10. Build

```powershell
cd master-site
npm run build
# Output: master-site/dist/
#   index.html          (~0.72 kB)
#   assets/index-*.css  (~35 kB, gzip ~6 kB)
#   assets/index-*.js   (~266 kB, gzip ~83 kB)
#   favicon.svg
```

Preview the production build locally:

```powershell
npm run preview
# → http://localhost:4173
```

---

## 11. Deployment

### Phase 1 — First run (creates infrastructure + deploys)

```powershell
# From project root
.\setup-phase1.ps1
```

### Phase 1 — Re-deploy after code changes

```powershell
.\setup-phase1.ps1
# State file present → skips bucket creation, runs build + sync directly
```

### Phase 2 — First run (creates full infrastructure + deploys, ~15 min)

```powershell
.\setup-phase2.ps1
```

### Phase 2 — Re-deploy after code changes

```powershell
.\setup-phase2.ps1
# DistributionId present in .phase2-state.json → build + sync + invalidation only
```

### Phase 1 — Teardown

```powershell
.\setup-phase1.ps1 -Teardown
```

### Phase 2 — Teardown

```powershell
.\setup-phase2.ps1 -Teardown
# Disabling CloudFront before deletion takes ~5-15 min
```

---

## 12. Certificate Management

The TLS certificate for `master.ostaddevops.click` is managed by Let's Encrypt and imported into ACM (`us-east-1`).

**Current certificate ARN:**
```
arn:aws:acm:us-east-1:388779989543:certificate/392fe338-b0b8-4aeb-ac2c-c930b219bb13
```

**To renew or re-issue** (run from Git Bash as Administrator):

```bash
./certbot-import.sh -d master.ostaddevops.click -e sarowar@hotmail.com -p sarowar-ostad
```

The script detects the existing ACM certificate and re-imports it with the same ARN — no CloudFront update needed.

**Certificate validity:** Let's Encrypt certificates are valid for 90 days. Renew before expiry.

---

## 13. Security Controls

| Control | Implementation |
|---|---|
| Private S3 origin | Block Public Access ON; bucket policy restricts to CloudFront OAC source ARN only |
| OAC SigV4 signing | Every CloudFront→S3 request is signed; unsigned requests are rejected by S3 |
| HTTPS enforcement | CloudFront viewer policy: redirect HTTP → HTTPS |
| TLS minimum version | `TLSv1.2_2021` |
| Security headers | AWS managed `SecurityHeadersPolicy` — adds HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` automatically |
| S3 versioning | Enabled on Phase 2 bucket — retains file history |
| S3 encryption | SSE-S3 (AES-256) at rest |
| Secrets management | No secrets in code; AWS credentials via named profile (`sarowar-ostad`); state files gitignored |
| Certificate | Let's Encrypt (free, automated DNS-01 validation via Route 53) |

---

## 14. Testing

No automated test suite is currently configured.

**Manual verification checklist:**

| Check | Phase 1 | Phase 2 |
|---|---|---|
| Site loads | `http://master-ostaddevops-site.s3-website.ap-south-1.amazonaws.com` | `https://master.ostaddevops.click` |
| HTTP → HTTPS redirect | N/A | ✅ |
| Client-side navigation | ✅ navbar links | ✅ navbar links |
| Page refresh on `/modules` | ✅ returns site (error doc) | ✅ returns 200 (custom error response) |
| Direct S3 URL | ✅ publicly accessible | ✅ returns 403 |
| Security headers | N/A | DevTools → Network → Response Headers |
| TLS certificate | N/A | Browser padlock → valid for `master.ostaddevops.click` |

---

## 15. Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `AccessDenied` during S3 sync | Wrong AWS profile or missing IAM permissions | `aws sts get-caller-identity --profile sarowar-ostad` |
| `BucketNotEmpty` on delete | Versioning enabled — versions remain after `s3 rm` | `setup-phase2.ps1 -Teardown` handles this via `list-object-versions` + `delete-objects` |
| S3 website URL returns `403` | Public bucket policy not applied | Re-run `setup-phase1.ps1` — step 4 re-applies the policy |
| CloudFront URL returns `403` | OAC bucket policy missing or has wrong ARN | Re-run `setup-phase2.ps1` — step 4 re-applies the policy with correct values |
| Page refresh returns error | Custom error responses not configured | Phase 2 script sets these at distribution creation time |
| `https://` not working | ACM cert not in `us-east-1` | Cert must be in `us-east-1` — run `certbot-import.sh` with `-r us-east-1` |
| Old content after deploy | CloudFront cache not invalidated | Phase 2 script always invalidates; Phase 1 has no CloudFront |
| `npm run build` fails | Missing `node_modules` | Both setup scripts auto-run `npm install` when `node_modules` is absent |
| `S3 sync failed` | Wrong working directory | Run setup scripts from project root, not from inside `master-site/` |
| AWS CLI error (exit 252) | Function named `$Args` / `param([string[]]$Args)` conflict | Fixed — scripts use `$AwsArgs` / no-param-block pattern |
| CloudFront still showing old cert | ACM import preserved same ARN | No action needed — `certbot-import.sh` re-imports with `--certificate-arn` |

---

## 16. Key Reference Values

| Name | Value |
|---|---|
| Phase 1 bucket | `master-ostaddevops-site` (ap-south-1) |
| Phase 2 bucket | `master-ostaddevops-site-private` (ap-south-1) |
| Domain | `master.ostaddevops.click` |
| Hosted zone | `ostaddevops.click` / `Z1019653XLWIJ02C53P5` |
| AWS account ID | `388779989543` |
| AWS profile | `sarowar-ostad` |
| ACM cert ARN | `arn:aws:acm:us-east-1:388779989543:certificate/392fe338-b0b8-4aeb-ac2c-c930b219bb13` |
| CloudFront alias zone | `Z2FDTNDATAQYW2` (fixed AWS constant for all CloudFront distributions) |
| CachingOptimized policy | `658327ea-f89d-4fab-a63d-7e88639e58f6` |
| SecurityHeadersPolicy | `67f7725c-6f97-4210-82d7-5512b31e9d03` |

---

## 17. Future Improvements

| Area | Suggestion |
|---|---|
| CI/CD | GitHub Actions workflow: push to `main` → build → S3 sync → CloudFront invalidation |
| Certificate renewal | AWS Lambda + EventBridge scheduled rule to auto-renew via `certbot-import.sh` before 30-day expiry |
| Monitoring | CloudWatch alarm on `5xxErrorRate` for the CloudFront distribution |
| WAF | Attach AWS WAF to CloudFront distribution (rate limiting, geo-blocking) |
| Multi-environment | Separate `dev` / `staging` / `prod` buckets + distributions with environment-scoped state files |
| S3 access logging | Enable S3 server access logging to a separate bucket for audit trail |
| CloudFront logging | Enable CloudFront standard logs to S3 for traffic analysis |
| IaC | Migrate `infra/` templates to Terraform or AWS CDK for full state management |
| Testing | Add Playwright or Cypress E2E tests; run in CI before deploy |

---

## 18. Operational Notes

### Changing site content

```powershell
# 1. Edit files under master-site/src/
# 2. Test locally
cd master-site && npm run dev

# 3. Deploy
cd ..
.\setup-phase1.ps1      # Phase 1
.\setup-phase2.ps1      # Phase 2 (build + sync + invalidation only on re-run)
```

### Adding a new page

1. Create `master-site/src/pages/NewPage.jsx`
2. Add `<Route path="/new" element={<NewPage />} />` in `App.jsx`
3. Add `<NavLink>` in `Navbar.jsx`
4. Add link in `Footer.jsx`
5. Deploy

### Checking what is in S3

```powershell
# Phase 1 bucket
aws s3 ls s3://master-ostaddevops-site --recursive --profile sarowar-ostad

# Phase 2 bucket
aws s3 ls s3://master-ostaddevops-site-private --recursive --profile sarowar-ostad
```

### Forcing a full CloudFront cache flush

```powershell
aws cloudfront create-invalidation `
  --distribution-id YOUR_DIST_ID `
  --paths "/*" `
  --profile sarowar-ostad
```

---

## 19. License

License information not currently defined.

---

## 20. Project Lead

**MD Sarowar Alam**  
Lead DevOps Engineer, WPP Production  
📧 Email: [sarowar@hotmail.com](mailto:sarowar@hotmail.com)  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

*Part of the Mastering DevOps course — Module 3: AWS Static Site Hosting*
