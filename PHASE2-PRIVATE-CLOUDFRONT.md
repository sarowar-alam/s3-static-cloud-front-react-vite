# Phase 2 — Private S3 + CloudFront + HTTPS + Custom Domain

Deploy the React + Vite site with:
- **Private S3 bucket** — no public access, CloudFront is the only entry point
- **CloudFront OAC** (Origin Access Control, SigV4) — replaces the deprecated OAI
- **HTTPS enforced** with TLS 1.2 minimum
- **Custom domain** `master.ostaddevops.click` via Route 53
- **Security headers** via AWS managed `SecurityHeadersPolicy`
- **SPA routing** — CloudFront custom error responses map 403 + 404 → `/index.html` HTTP 200

> **Fully independent of Phase 1.**  
> Uses a separate bucket (`master-ostaddevops-site-private`).  
> Phase 1 bucket (`master-ostaddevops-site`) is never touched.

---

## Fixed Values

| Name | Value |
|---|---|
| Bucket | `master-ostaddevops-site-private` |
| Region (S3) | `ap-south-1` |
| Region (ACM / CloudFront) | `us-east-1` ⚠️ hard AWS requirement |
| AWS Profile | `sarowar-ostad` |
| Account ID | `388779989543` |
| Domain | `master.ostaddevops.click` |
| Hosted Zone | `ostaddevops.click` / `Z1019653XLWIJ02C53P5` |
| ACM Certificate ARN | `arn:aws:acm:us-east-1:388779989543:certificate/392fe338-b0b8-4aeb-ac2c-c930b219bb13` |
| OAC Name | `master-oac` |
| CloudFront config template | `infra/cloudfront-distribution.json` |
| Bucket policy template | `infra/bucket-policy-phase2.json` |
| State file | `.phase2-state.json` (auto-created, gitignored) |

---

---

## Option A — AWS Console (GUI)

---

### Step 1 — Create Private S3 Bucket

1. Open [S3 Console](https://s3.console.aws.amazon.com/) → **Create bucket**
2. **Bucket name:** `master-ostaddevops-site-private`
3. **AWS Region:** `ap-south-1` (Asia Pacific — Mumbai)
4. **Block Public Access:** leave all 4 checkboxes **ON** (default) ✅
5. **Bucket Versioning:** Enable
6. **Default encryption:** Enable — type **SSE-S3 (AES-256)**
7. Click **Create bucket**
8. ❌ Do **NOT** enable Static Website Hosting

---

### Step 2 — ACM Certificate (Already Issued)

The TLS certificate for `master.ostaddevops.click` is already imported in ACM (`us-east-1`):

```
arn:aws:acm:us-east-1:388779989543:certificate/392fe338-b0b8-4aeb-ac2c-c930b219bb13
```

No action needed — proceed to Step 3.

---

### Step 3 — Create CloudFront Origin Access Control (OAC)

1. Open [CloudFront Console](https://console.aws.amazon.com/cloudfront/)
2. Left sidebar → **Security** → **Origin access** → **Create control setting**
3. **Name:** `master-oac`
4. **Origin type:** S3
5. **Signing behavior:** Sign requests (recommended)
6. **Signing protocol:** SigV4
7. Click **Create**
8. 📋 Copy the **OAC ID** — needed for Step 4

---

### Step 4 — Create CloudFront Distribution

1. CloudFront → **Create distribution**
2. **Origin domain:** `master-ostaddevops-site-private.s3.ap-south-1.amazonaws.com`
   > ⚠️ Pick the **S3 REST endpoint** — NOT a `.s3-website.` URL
3. **Origin access:** select **Origin access control settings (recommended)** → pick `master-oac`
   - A banner appears → click **Copy policy** and save it for Step 6
4. **Viewer protocol policy:** Redirect HTTP to HTTPS
5. **Allowed HTTP methods:** GET, HEAD
6. **Cache policy:** CachingOptimized
7. **Response headers policy:** SecurityHeadersPolicy (AWS managed)
8. **Default root object:** `index.html`
9. **Alternate domain names (CNAMEs):** `master.ostaddevops.click`
10. **Custom SSL certificate:** select the cert from Step 2
11. **Security policy:** `TLSv1.2_2021`
12. Click **Create distribution**
13. 📋 Copy the **Distribution ID** and **Distribution domain name** (e.g. `d1abc.cloudfront.net`)
14. ⏳ Wait ~5-15 minutes → Status: **Deployed**

---

### Step 5 — Add Custom Error Responses (SPA Routing)

> Private S3 returns **403** (not 404) for missing keys — both must be mapped.

1. Open the distribution → **Error pages** tab → **Create custom error response**
2. Rule 1: HTTP error code **403** → Response page path `/index.html` → HTTP response code **200**
3. Rule 2: HTTP error code **404** → Response page path `/index.html` → HTTP response code **200**

---

### Step 6 — Update S3 Bucket Policy (OAC-only access)

1. Open S3 → `master-ostaddevops-site-private` → **Permissions** → **Bucket policy** → **Edit**
2. Open [`infra/bucket-policy-phase2.json`](infra/bucket-policy-phase2.json) and replace:
   - `ACCOUNT_ID` → `388779989543`
   - `DISTRIBUTION_ID` → the CloudFront distribution ID from Step 4
3. Paste the updated JSON → **Save changes**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOACOnly",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::master-ostaddevops-site-private/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::388779989543:distribution/YOUR_DISTRIBUTION_ID"
        }
      }
    }
  ]
}
```

---

### Step 7 — Route 53 DNS Record

1. Open [Route 53](https://console.aws.amazon.com/route53/) → **Hosted zones** → `ostaddevops.click`
2. Click **Create record**
3. **Record name:** `master`
4. **Record type:** A
5. Toggle **Alias** → ON
6. **Route traffic to:** Alias to CloudFront distribution → select the distribution
7. Click **Create records**
8. ⏳ DNS propagation: 1–5 minutes

---

### Step 8 — Build & Deploy

```powershell
cd master-site
npm install       # first time only
npm run build
cd ..
aws s3 sync master-site/dist/ s3://master-ostaddevops-site-private --delete --profile sarowar-ostad
aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*" --profile sarowar-ostad
```

---

---

## Option B — PowerShell Script (`setup-phase2.ps1`)

Run from the **project root**.

### Setup / Re-deploy

```powershell
.\setup-phase2.ps1
```

**First run** — detects no state file, provisions all infrastructure then deploys:

| Step | Action |
|---|---|
| 1/7 | Creates `master-ostaddevops-site-private` (skips if exists) — saves state |
| 1/7 | Hardens bucket: Block Public Access ON, versioning, SSE-S3 encryption |
| 2/7 | Creates CloudFront OAC (`master-oac`, SigV4) |
| 3/7 | Creates CloudFront distribution — patches OAC ID + CallerReference in-memory (template never modified on disk) |
| 4/7 | Applies OAC-only bucket policy — resolves `ACCOUNT_ID` + `DISTRIBUTION_ID` at runtime |
| 5/7 | Creates Route 53 A alias `master.ostaddevops.click` → CloudFront (UPSERT) |
| 6/7 | Waits for CloudFront to deploy (~5-15 min) |
| 7/7 | `npm install` (if needed) → `npm run build` → `aws s3 sync` → CloudFront invalidation |

**Subsequent runs** — detects existing `DistributionId` in `.phase2-state.json`, skips all infrastructure and goes straight to build + sync + invalidate.

Prints live URL, Distribution ID, and re-deploy hint on completion.

---

### Teardown

```powershell
.\setup-phase2.ps1 -Teardown
```

Shows what will be removed, asks for confirmation (`y/N`), then removes in order:

| Step | Action |
|---|---|
| 1/5 | Deletes Route 53 A alias |
| 2/5 | Disables CloudFront distribution → waits for propagation → deletes it |
| 3/5 | Deletes CloudFront OAC |
| 4/5 | **Bucket created by script** → deletes all object versions + delete markers (versioning-safe), then deletes bucket |
| 4/5 | **Bucket pre-existed** → removes bucket policy only; bucket and objects preserved |
| 5/5 | Removes `.phase2-state.json` |

> Each completed step is saved to state immediately — safe to re-run if interrupted mid-teardown.

---

## Verification Checklist

| Check | Expected |
|---|---|
| Direct S3 REST URL | ✅ `403 Access Denied` — bucket is private |
| `https://master.ostaddevops.click` | ✅ Site renders correctly |
| `http://master.ostaddevops.click` | ✅ Redirects to `https://` |
| Refresh on `/modules` | ✅ Returns 200 (SPA routing via custom error responses) |
| Browser padlock → certificate | ✅ Valid for `master.ostaddevops.click` |
| DevTools Response Headers | ✅ `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options` present |

---

## Key Facts

| Fact | Why it matters |
|---|---|
| ACM cert must be in `us-east-1` | Hard AWS requirement for CloudFront, regardless of bucket region |
| Use S3 REST endpoint as origin | `.s3-website.` endpoints don't support OAC SigV4 signing |
| Map both **403 AND 404** to `/index.html` | Private S3 returns 403 (not 404) for missing keys |
| Versioned bucket requires full version sweep on delete | `s3 rm --recursive` leaves versions behind — `delete-objects` on all versions is required |
| CloudFront alias hosted zone = `Z2FDTNDATAQYW2` | Fixed AWS constant — same for every CloudFront distribution globally |

---

## Project Lead

**MD Sarowar Alam**  
Lead DevOps Engineer, WPP Production  
📧 Email: [sarowar@hotmail.com](mailto:sarowar@hotmail.com)  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
