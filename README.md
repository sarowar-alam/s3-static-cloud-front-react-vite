# batch11.ostaddevops.click

Course landing page for **Mastering DevOps: From Fundamentals to Advanced Practices — Batch 11**, hosted on [ostad.app](https://ostad.app/).

**Live URL (Phase 2):** https://batch11.ostaddevops.click  
**Instructor:** MD Sarowar Alam — Lead DevOps Engineer, WPPProduction

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Repository Structure](#2-repository-structure)
3. [Prerequisites](#3-prerequisites)
4. [Local Development](#4-local-development)
5. [Infrastructure — Phase 1 (Public S3)](#5-infrastructure--phase-1-public-s3)
6. [Infrastructure — Phase 2 (Private S3 + CloudFront)](#6-infrastructure--phase-2-private-s3--cloudfront)
7. [Deployment](#7-deployment)
8. [Operational Tasks](#8-operational-tasks)
9. [Introducing Changes](#9-introducing-changes)
10. [Design Decisions](#10-design-decisions)
11. [Troubleshooting](#11-troubleshooting)
12. [Key Reference Values](#12-key-reference-values)

---

## 1. Architecture Overview

```
Browser
   │
   ▼
Route 53  (A alias record — batch11.ostaddevops.click)
   │
   ▼
CloudFront Distribution  (HTTPS, TLSv1.2_2021, SecurityHeadersPolicy)
   │  ├─ OAC (Origin Access Control, SigV4 signing)
   │  ├─ Default root object: index.html
   │  ├─ Error 403 → /index.html  HTTP 200  (SPA routing)
   │  └─ Error 404 → /index.html  HTTP 200  (SPA routing)
   │
   ▼
S3 Bucket  (batch11-ostaddevops-site, ap-south-1)
   ├─ Private — no public access
   ├─ SSE-S3 encryption at rest
   ├─ Versioning enabled
   └─ dist/  ← React + Vite production build
```

### Two-Phase Deployment Model

The infrastructure is deliberately designed in two phases — both use the **same S3 bucket**, reconfigured between phases. No resources are wasted or duplicated.

| | Phase 1 | Phase 2 |
|---|---|---|
| Purpose | Learning, quick iteration | Production, custom domain |
| Bucket access | Public (required for S3 website hosting) | Private (OAC only) |
| HTTPS | ❌ | ✅ (ACM + CloudFront) |
| Custom domain | ❌ | ✅ `batch11.ostaddevops.click` |
| Security headers | ❌ | ✅ AWS SecurityHeadersPolicy |
| Deploy command | `.\deploy.ps1 -SkipInvalidation` | `.\deploy.ps1 -DistributionId "..."` |

---

## 2. Repository Structure

```
Class-02/
├── batch11-site/               # React + Vite frontend application
│   ├── index.html              # HTML shell — Vite entry point
│   ├── vite.config.js          # Vite config — React + Tailwind CSS plugins
│   ├── package.json            # Dependencies (React 19, React Router v7, Tailwind v4)
│   └── src/
│       ├── main.jsx            # React root — BrowserRouter wraps the app
│       ├── App.jsx             # Route definitions (/, /about, /modules, /contact)
│       ├── index.css           # @import "tailwindcss" — single directive
│       ├── components/
│       │   ├── Navbar.jsx      # Sticky responsive navigation with mobile menu
│       │   └── Footer.jsx      # Footer with links, socials, copyright
│       └── pages/
│           ├── Home.jsx        # Hero, stats, features, tools, phase journey, CTA
│           ├── About.jsx       # Program info, learning objectives, instructor
│           ├── Modules.jsx     # All 12 course modules with live class breakdowns
│           └── Contact.jsx     # Contact cards, enroll CTA, FAQ accordion
│
├── infra/
│   ├── bucket-policy-phase1.json       # Public read policy (Phase 1 only)
│   ├── bucket-policy-phase2.json       # OAC-scoped private policy (Phase 2)
│   └── cloudfront-distribution.json   # CloudFront distribution config template
│
├── deploy.ps1                  # One-command deploy: build → S3 sync → CF invalidate
├── .gitignore                  # Excludes dist/, node_modules/, .env files
├── PHASE1-PUBLIC-S3.md         # Step-by-step Phase 1 guide (Console + CLI)
└── PHASE2-PRIVATE-CLOUDFRONT.md  # Step-by-step Phase 2 guide (Console + CLI, 2 paths)
```

> `batch11-site/dist/` and `batch11-site/node_modules/` are **not committed**. They are generated locally.

---

## 3. Prerequisites

### Required on your machine

| Tool | Minimum version | Install |
|---|---|---|
| Node.js | 18 LTS or later | https://nodejs.org |
| npm | 9 or later | Included with Node.js |
| AWS CLI | v2 | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| Git | Any recent | https://git-scm.com |
| PowerShell | 5.1+ (Windows built-in) | Built into Windows 11 |

Verify your setup:

```powershell
node --version       # v18+
npm --version        # 9+
aws --version        # aws-cli/2.x
git --version
```

### AWS Named Profile

All AWS CLI commands use the named profile `sarowar-ostad`. Ensure it is configured:

```powershell
aws configure --profile sarowar-ostad
```

You will be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `ap-south-1`
- Default output format: `json`

Verify the profile works:

```powershell
aws sts get-caller-identity --profile sarowar-ostad
```

### AWS Permissions Required

The IAM user/role behind `sarowar-ostad` needs these permissions:

| Service | Actions needed |
|---|---|
| S3 | `s3:CreateBucket`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`, `s3:GetBucketWebsite`, `s3:PutBucketWebsite`, `s3:PutBucketPolicy`, `s3:DeleteBucketPolicy`, `s3:PutBucketVersioning`, `s3:PutEncryptionConfiguration`, `s3:PutPublicAccessBlock` |
| CloudFront | `cloudfront:CreateDistribution`, `cloudfront:UpdateDistribution`, `cloudfront:CreateInvalidation`, `cloudfront:CreateOriginAccessControl` |
| ACM | `acm:RequestCertificate`, `acm:DescribeCertificate`, `acm:ListCertificates` (region: us-east-1) |
| Route 53 | `route53:ChangeResourceRecordSets`, `route53:ListHostedZones` |
| STS | `sts:GetCallerIdentity` |

---

## 4. Local Development

### First-time setup

```powershell
# Clone the repository
git clone <repo-url>
cd "Class-02"

# Install frontend dependencies
cd batch11-site
npm install
```

### Start the dev server

```powershell
# From inside batch11-site/
npm run dev
```

Opens at **http://localhost:5173** with hot-module replacement (HMR).

All four routes are accessible locally:

| Route | Page |
|---|---|
| `/` | Home |
| `/about` | About |
| `/modules` | Modules |
| `/contact` | Contact |

> The dev server handles SPA routing automatically. You do not need to configure anything extra.

### Build for production (dry-run)

```powershell
# From inside batch11-site/
npm run build
```

Output lands in `batch11-site/dist/`. Inspect it:

```powershell
ls dist/
ls dist/assets/
```

### Preview the production build locally

```powershell
npm run preview
```

Serves the `dist/` folder at **http://localhost:4173** — identical to what S3/CloudFront will serve.

---

## 5. Infrastructure — Phase 1 (Public S3)

> Full step-by-step guide (Console + CLI): see [PHASE1-PUBLIC-S3.md](PHASE1-PUBLIC-S3.md)

**Summary of CLI commands:**

```powershell
# Run from project root (Class-02/)

# 1. Create bucket
aws s3api create-bucket `
  --bucket batch11-ostaddevops-site `
  --region ap-south-1 `
  --create-bucket-configuration LocationConstraint=ap-south-1 `
  --profile sarowar-ostad

# 2. Remove Block Public Access
aws s3api delete-public-access-block `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad

# 3. Enable static website hosting
aws s3 website s3://batch11-ostaddevops-site/ `
  --index-document index.html `
  --error-document index.html `
  --profile sarowar-ostad

# 4. Apply public read policy
aws s3api put-bucket-policy `
  --bucket batch11-ostaddevops-site `
  --policy file://infra/bucket-policy-phase1.json `
  --profile sarowar-ostad

# 5. Build and deploy
.\deploy.ps1 -SkipInvalidation
```

**Test URL:**
```
http://batch11-ostaddevops-site.s3-website.ap-south-1.amazonaws.com
```

---

## 6. Infrastructure — Phase 2 (Private S3 + CloudFront)

> Full step-by-step guide (Console + CLI, two paths): see [PHASE2-PRIVATE-CLOUDFRONT.md](PHASE2-PRIVATE-CLOUDFRONT.md)

Two paths are documented:
- **Option 1** — Fresh setup (no Phase 1 done)
- **Option 2** — Migrate from Phase 1 (bucket already exists)

### Prerequisites for Phase 2

Before running Phase 2 CLI commands, you need two values. Record them:

```powershell
# Your AWS Account ID
aws sts get-caller-identity --query Account --output text --profile sarowar-ostad

# Your Route 53 Hosted Zone ID for ostaddevops.click
aws route53 list-hosted-zones-by-name `
  --dns-name ostaddevops.click `
  --query "HostedZones[0].Id" `
  --output text `
  --profile sarowar-ostad
# Strip the /hostedzone/ prefix — keep only the ID (e.g. Z1XXXXXXXX)
```

### Critical constraints

| Constraint | Why |
|---|---|
| ACM certificate **must** be requested in `us-east-1` | Hard AWS requirement for CloudFront — regardless of your S3 bucket region |
| CloudFront origin must be the **S3 REST endpoint**, not the website endpoint | S3 website endpoint does not support OAC signing |
| Map **both 403 and 404** to `/index.html` in CloudFront custom error responses | A private S3 bucket returns `403` (not `404`) for missing object keys — both must be handled for SPA routing |
| OAC signing protocol must be **SigV4** | Required for cross-region S3 buckets (bucket is in ap-south-1) |
| CloudFront Route 53 alias hosted zone ID is always **`Z2FDTNDATAQYW2`** | This is a fixed AWS global value for all CloudFront distributions |

### After Phase 2 infra is created — fill in the templates

Before deploying, update the two placeholder files:

**`infra/bucket-policy-phase2.json`** — replace:
- `ACCOUNT_ID` → your 12-digit AWS account ID
- `DISTRIBUTION_ID` → your CloudFront distribution ID

**`infra/cloudfront-distribution.json`** — replace:
- `REPLACE_WITH_OAC_ID` → your OAC ID
- `REPLACE_WITH_ACM_ARN_IN_US_EAST_1` → your ACM certificate ARN

---

## 7. Deployment

### deploy.ps1

`deploy.ps1` is the single deploy entrypoint. It:
1. Runs `npm run build` inside `batch11-site/`
2. Syncs `dist/` to `s3://batch11-ostaddevops-site` using `aws s3 sync --delete`
3. Optionally invalidates the CloudFront cache

**Phase 1 deploy:**

```powershell
# From project root (Class-02/)
.\deploy.ps1 -SkipInvalidation
```

**Phase 2 deploy (after CloudFront is created):**

```powershell
.\deploy.ps1 -DistributionId "YOUR_DISTRIBUTION_ID"
```

The `--delete` flag on `aws s3 sync` removes files from S3 that no longer exist in `dist/` — ensures the bucket stays in sync with the build output.

### What deploy.ps1 does NOT do

- Does not run tests (none configured yet)
- Does not tag releases in git
- Does not roll back on CloudFront invalidation failure

### Cache behaviour

After deploy, CloudFront serves cached content until an invalidation completes (~30–60 seconds). `deploy.ps1` automatically runs `aws cloudfront create-invalidation --paths "/*"` in Phase 2. You do not need to do this manually.

---

## 8. Operational Tasks

### View what's currently in S3

```powershell
aws s3 ls s3://batch11-ostaddevops-site --recursive --profile sarowar-ostad
```

### Check CloudFront distribution status

```powershell
aws cloudfront list-distributions `
  --query "DistributionList.Items[*].{Id:Id,Domain:DomainName,Status:Status}" `
  --output table `
  --profile sarowar-ostad
```

### Manually invalidate CloudFront cache

```powershell
aws cloudfront create-invalidation `
  --distribution-id YOUR_DISTRIBUTION_ID `
  --paths "/*" `
  --profile sarowar-ostad
```

### Check ACM certificate status

```powershell
aws acm list-certificates `
  --region us-east-1 `
  --profile sarowar-ostad `
  --query "CertificateSummaryList[*].{Domain:DomainName,Status:Status}" `
  --output table
```

### Verify bucket is private (Phase 2)

```powershell
aws s3api get-public-access-block `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad
# All four values must be: true
```

### Verify bucket policy is in place

```powershell
aws s3api get-bucket-policy `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad
```

### Roll back to a previous version

S3 versioning is enabled in Phase 2. To restore a previous `index.html`:

```powershell
# List versions
aws s3api list-object-versions `
  --bucket batch11-ostaddevops-site `
  --prefix index.html `
  --profile sarowar-ostad

# Restore a specific version
aws s3api copy-object `
  --bucket batch11-ostaddevops-site `
  --copy-source "batch11-ostaddevops-site/index.html?versionId=REPLACE_VERSION_ID" `
  --key index.html `
  --profile sarowar-ostad

# Then invalidate CloudFront
aws cloudfront create-invalidation `
  --distribution-id YOUR_DISTRIBUTION_ID `
  --paths "/*" `
  --profile sarowar-ostad
```

---

## 9. Introducing Changes

### Changing site content (pages, copy, styling)

1. Edit files under `batch11-site/src/`
2. Test locally: `npm run dev` (hot reload)
3. Preview production build: `npm run build && npm run preview`
4. Commit: `git add . && git commit -m "feat: describe your change"`
5. Deploy:
   - Phase 1: `.\deploy.ps1 -SkipInvalidation`
   - Phase 2: `.\deploy.ps1 -DistributionId "YOUR_DISTRIBUTION_ID"`

### Adding a new page

1. Create `batch11-site/src/pages/NewPage.jsx`
2. Import and add a `<Route>` in [batch11-site/src/App.jsx](batch11-site/src/App.jsx)
3. Add a `<NavLink>` entry in [batch11-site/src/components/Navbar.jsx](batch11-site/src/components/Navbar.jsx)
4. Add to the `links` array in [batch11-site/src/components/Footer.jsx](batch11-site/src/components/Footer.jsx)
5. Test, build, deploy

### Adding a npm dependency

```powershell
cd batch11-site
npm install <package-name>   # runtime dependency
npm install -D <package-name> # dev-only dependency
```

Commit the updated `package.json` and `package-lock.json`. Do not commit `node_modules/`.

### Changing AWS infrastructure

- **S3 bucket policy changes:** edit `infra/bucket-policy-phase2.json`, re-apply with `aws s3api put-bucket-policy`
- **CloudFront changes:** use Console or `aws cloudfront update-distribution`. Most changes require a new deployment to take effect (~5 min)
- **DNS changes:** use Route 53 Console or `aws route53 change-resource-record-sets`. TTL propagation: 1–5 minutes

### Things to never change

| Item | Risk |
|---|---|
| Bucket name `batch11-ostaddevops-site` | S3 bucket names are globally unique and permanent. Renaming requires creating a new bucket and re-deploying. |
| ACM certificate region (`us-east-1`) | Moving it to another region breaks CloudFront. |
| CloudFront `Z2FDTNDATAQYW2` hosted zone ID | This is an AWS-hardcoded global constant. Do not replace it. |

---

## 10. Design Decisions

### Why Vite over Create React App?

Vite v6 is significantly faster for both dev server startup and production builds. CRA is no longer maintained.

### Why Tailwind CSS v4?

Tailwind v4 uses a native CSS `@import "tailwindcss"` directive — no `tailwind.config.js` required. Integrated as a Vite plugin, no PostCSS pipeline needed.

### Why BrowserRouter (client-side routing)?

The site is a Single Page Application. React Router's `<BrowserRouter>` handles routing in the browser. Edge case: on page refresh, the server (S3/CloudFront) must return `index.html` regardless of path — this is configured via:
- Phase 1: S3 error document set to `index.html`
- Phase 2: CloudFront custom error responses (403 and 404 → `index.html` with HTTP 200)

### Why OAC instead of OAI?

AWS deprecated Origin Access Identity (OAI). Origin Access Control (OAC) with SigV4 signing is the current recommended approach and is required for S3 buckets outside `us-east-1`.

### Why is the bucket name not the domain name?

Using the domain name as the bucket name (`batch11.ostaddevops.click`) would make the bucket enumerable by anyone who knows the domain. A non-guessable name (`batch11-ostaddevops-site`) reduces the attack surface.

### Why is `deploy.ps1` not a CI/CD pipeline?

This project is scoped to Module 1 of the course — demonstrating manual and semi-automated deployments. CI/CD automation with GitHub Actions is covered in Module 5. The `deploy.ps1` script is structured to be easy to wrap inside a GitHub Actions workflow later.

---

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `NoSuchBucket` during deploy | Bucket not created yet | Run Phase 1 or Phase 2 setup steps first |
| `AccessDenied` during S3 sync | Wrong AWS profile or missing IAM permissions | Check `aws sts get-caller-identity --profile sarowar-ostad` |
| S3 website URL returns `403 Access Denied` | Public bucket policy not applied | Re-run `aws s3api put-bucket-policy` with `bucket-policy-phase1.json` |
| CloudFront URL returns `403` | OAC bucket policy not applied, or `ACCOUNT_ID`/`DISTRIBUTION_ID` not replaced | Update `bucket-policy-phase2.json` and re-apply |
| Page refresh on `/modules` returns error | Custom error responses not configured on CloudFront | Add 403→`/index.html` and 404→`/index.html` custom error responses |
| `https://` not working | ACM cert not issued, or cert not in `us-east-1` | Check `aws acm list-certificates --region us-east-1` |
| Old content showing after deploy | CloudFront cache not invalidated | Run `aws cloudfront create-invalidation --paths "/*"` |
| `npm run build` fails | Missing `node_modules` | Run `npm install` from inside `batch11-site/` |
| `deploy.ps1` reports `S3 sync failed` | Build step failed or wrong working directory | Run script from project root (`Class-02/`), not from inside `batch11-site/` |

---

## 12. Key Reference Values

| Name | Value |
|---|---|
| S3 bucket | `batch11-ostaddevops-site` |
| S3 region | `ap-south-1` |
| S3 website endpoint | `http://batch11-ostaddevops-site.s3-website.ap-south-1.amazonaws.com` |
| ACM certificate region | `us-east-1` (required for CloudFront) |
| Custom domain | `batch11.ostaddevops.click` |
| Hosted zone apex | `ostaddevops.click` |
| CloudFront Route 53 hosted zone ID | `Z2FDTNDATAQYW2` (AWS global constant) |
| AWS CLI profile | `sarowar-ostad` |
| Course platform | https://ostad.app/ |
| Instructor | MD Sarowar Alam — Lead DevOps Engineer, WPPProduction |

---

## 🧑‍💻 Author

*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/
