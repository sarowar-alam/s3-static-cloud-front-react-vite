# Phase 2 — Static Site with Private S3 Bucket + CloudFront

Deploy the React + Vite site with:
- **Private S3 bucket** — no public access, CloudFront is the only entry point
- **CloudFront OAC** (Origin Access Control) — replaces the deprecated OAI
- **HTTPS enforced** with TLS 1.2 minimum
- **Custom domain** `batch11.ostaddevops.click` via Route 53
- **Security headers** via AWS managed `SecurityHeadersPolicy`
- **SPA routing** handled via CloudFront custom error responses

---

## Variables

| Name | Value |
|---|---|
| Bucket | `batch11-ostaddevops-site` |
| Region (S3) | `ap-south-1` |
| Region (ACM cert) | `us-east-1` ⚠️ required for CloudFront |
| AWS Profile | `sarowar-ostad` |
| Domain | `batch11.ostaddevops.click` |
| Hosted Zone | `ostaddevops.click` |
| CloudFront config | `infra/cloudfront-distribution.json` |
| Phase 2 policy | `infra/bucket-policy-phase2.json` |
| Deploy script | `deploy.ps1` |

---

## Choose Your Path

| | When to use |
|---|---|
| **Option 1 — Fresh Setup** | Starting from scratch, no Phase 1 bucket exists |
| **Option 2 — Migrate from Phase 1** | Phase 1 is already live, upgrading to private + HTTPS |

---

---

# Option 1 — Fresh Setup (No Prior Phase 1)

---

## Option 1A — AWS Console (GUI)

### Step 1 — Create Private S3 Bucket

1. Open [S3 Console](https://s3.console.aws.amazon.com/) → **Create bucket**
2. **Bucket name:** `batch11-ostaddevops-site`
3. **AWS Region:** `ap-south-1`
4. **Block Public Access:** leave all 4 checkboxes **ON** (default) ✅
5. **Bucket Versioning:** Enable
6. **Default encryption:** Enable — type **SSE-S3 (AES-256)**
7. Click **Create bucket**
8. ❌ Do **NOT** enable Static Website Hosting

---

### Step 2 — Request ACM Certificate

> ⚠️ **Must be done in region `us-east-1`** — this is a hard AWS requirement for CloudFront.

1. Switch the AWS Console region to **US East (N. Virginia) — us-east-1**
2. Open [ACM Console](https://console.aws.amazon.com/acm/) → **Request certificate**
3. Type: **Request a public certificate** → Next
4. **Fully qualified domain name:** `batch11.ostaddevops.click`
5. **Validation method:** DNS validation
6. Click **Request**
7. Open the pending certificate → click **Create records in Route 53**
   (this auto-adds the CNAME validation record to your hosted zone)
8. Wait **1–3 minutes** → Status changes to **Issued** ✅
9. 📋 Copy the **Certificate ARN** — needed for Step 4

---

### Step 3 — Create CloudFront Origin Access Control (OAC)

1. Open [CloudFront Console](https://console.aws.amazon.com/cloudfront/)
2. In the left sidebar → **Security** → **Origin access** → **Create control setting**
3. **Name:** `batch11-oac`
4. **Origin type:** S3
5. **Signing behavior:** Sign requests (recommended)
6. **Signing protocol:** SigV4
7. Click **Create**
8. 📋 Copy the **OAC ID** — needed for Step 4

---

### Step 4 — Create CloudFront Distribution

1. CloudFront → **Create distribution**
2. **Origin domain:** select `batch11-ostaddevops-site.s3.ap-south-1.amazonaws.com` from dropdown
   > ⚠️ Pick the **S3 REST endpoint** — NOT the `.s3-website.` URL
3. **Origin access:** select **Origin access control settings (recommended)**
   - Pick `batch11-oac` you just created
   - A banner appears saying the bucket policy needs updating — click **Copy policy** and save it, you'll use it in Step 6
4. **Viewer protocol policy:** Redirect HTTP to HTTPS
5. **Allowed HTTP methods:** GET, HEAD
6. **Cache policy:** CachingOptimized
7. **Response headers policy:** select **SecurityHeadersPolicy** (AWS managed)
   - This adds HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy automatically
8. **Default root object:** `index.html`
9. **Alternate domain names (CNAMEs):** `batch11.ostaddevops.click`
10. **Custom SSL certificate:** select the cert from Step 2
11. **Security policy:** `TLSv1.2_2021`
12. **Price class:** All edge locations (or your preference)
13. Click **Create distribution**
14. ⏳ Wait ~5 minutes → Status: **Deployed**
15. 📋 Copy the **Distribution ID** and **Distribution domain name** (e.g. `d1abc.cloudfront.net`)

---

### Step 5 — Add Custom Error Responses (SPA Routing)

> Private S3 buckets return **403** (not 404) for missing keys. Both must be mapped to `index.html`.

1. Open the distribution → **Error pages** tab → **Create custom error response**
2. First rule:
   - HTTP error code: **403**
   - Customize error response: **Yes**
   - Response page path: `/index.html`
   - HTTP response code: **200**
3. Click **Create custom error response**
4. Repeat for:
   - HTTP error code: **404** → `/index.html` → **200**

---

### Step 6 — Update S3 Bucket Policy (OAC access only)

1. Open S3 → `batch11-ostaddevops-site` → **Permissions** → **Bucket policy** → **Edit**
2. Open `infra/bucket-policy-phase2.json` and replace:
   - `ACCOUNT_ID` → your 12-digit AWS account ID (visible in the top-right corner of console)
   - `DISTRIBUTION_ID` → the CloudFront distribution ID from Step 4
3. Paste the updated JSON → **Save changes**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOACOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::batch11-ostaddevops-site/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::YOUR_ACCOUNT_ID:distribution/YOUR_DISTRIBUTION_ID"
        }
      }
    }
  ]
}
```

---

### Step 7 — Route 53 DNS Record

1. Open [Route 53 Console](https://console.aws.amazon.com/route53/) → **Hosted zones**
2. Click `ostaddevops.click`
3. Click **Create record**
4. **Record name:** `batch11`
5. **Record type:** A
6. Toggle **Alias** → ON
7. **Route traffic to:** Alias to CloudFront distribution
8. Select the distribution from the dropdown
9. Click **Create records**
10. ⏳ DNS propagation: 1–5 minutes

---

### Step 8 — Build & Deploy

```powershell
.\deploy.ps1 -DistributionId "REPLACE_WITH_YOUR_DISTRIBUTION_ID"
```

This script:
1. Runs `npm run build` inside `batch11-site/`
2. Syncs `dist/` to `s3://batch11-ostaddevops-site` with `--delete`
3. Runs `aws cloudfront create-invalidation --paths "/*"` to flush the CDN cache

---

---

## Option 1B — AWS CLI

Run all commands from the **project root** (`Class-02/`).

### Step 1 — Create Private S3 Bucket

```powershell
# Create bucket
aws s3api create-bucket `
  --bucket batch11-ostaddevops-site `
  --region ap-south-1 `
  --create-bucket-configuration LocationConstraint=ap-south-1 `
  --profile sarowar-ostad

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket batch11-ostaddevops-site `
  --versioning-configuration Status=Enabled `
  --profile sarowar-ostad

# Enable SSE-S3 encryption
aws s3api put-bucket-encryption `
  --bucket batch11-ostaddevops-site `
  --server-side-encryption-configuration '{
    "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]
  }' `
  --profile sarowar-ostad

# Confirm Block Public Access is ON
aws s3api put-public-access-block `
  --bucket batch11-ostaddevops-site `
  --public-access-block-configuration `
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true `
  --profile sarowar-ostad
```

---

### Step 2 — Request ACM Certificate (us-east-1)

```powershell
# Request certificate — MUST use --region us-east-1
aws acm request-certificate `
  --domain-name batch11.ostaddevops.click `
  --validation-method DNS `
  --region us-east-1 `
  --profile sarowar-ostad
# Output → save the CertificateArn value
```

Get the DNS validation record to add to Route 53:

```powershell
aws acm describe-certificate `
  --certificate-arn REPLACE_WITH_CERT_ARN `
  --region us-east-1 `
  --profile sarowar-ostad `
  --query "Certificate.DomainValidationOptions[0].ResourceRecord"
```

Get your Route 53 Hosted Zone ID:

```powershell
aws route53 list-hosted-zones-by-name `
  --dns-name ostaddevops.click `
  --profile sarowar-ostad `
  --query "HostedZones[0].Id" `
  --output text
# Output looks like: /hostedzone/Z1XXXXXXXXXX — use only the Z1XXXXXXXXXX part
```

Add the CNAME validation record (replace with values from `describe-certificate`):

```powershell
aws route53 change-resource-record-sets `
  --hosted-zone-id REPLACE_WITH_ZONE_ID `
  --change-batch '{
    "Changes":[{
      "Action":"CREATE",
      "ResourceRecordSet":{
        "Name":"REPLACE_WITH_CNAME_NAME_FROM_ACM",
        "Type":"CNAME",
        "TTL":300,
        "ResourceRecords":[{"Value":"REPLACE_WITH_CNAME_VALUE_FROM_ACM"}]
      }
    }]
  }' `
  --profile sarowar-ostad
```

Wait for certificate to be issued:

```powershell
aws acm wait certificate-validated `
  --certificate-arn REPLACE_WITH_CERT_ARN `
  --region us-east-1 `
  --profile sarowar-ostad
# Returns when status = ISSUED (1-3 min)
```

---

### Step 3 — Create CloudFront OAC

```powershell
aws cloudfront create-origin-access-control `
  --origin-access-control-config '{
    "Name":"batch11-oac",
    "Description":"OAC for batch11-ostaddevops-site",
    "SigningProtocol":"sigv4",
    "SigningBehavior":"always",
    "OriginAccessControlOriginType":"s3"
  }' `
  --profile sarowar-ostad
# Output → save the Id value (e.g. E1ABCDEF2GHIJK)
```

---

### Step 4 — Create CloudFront Distribution

Edit `infra/cloudfront-distribution.json`:
- Replace `REPLACE_WITH_OAC_ID` → OAC ID from Step 3
- Replace `REPLACE_WITH_ACM_ARN_IN_US_EAST_1` → Certificate ARN from Step 2

```powershell
aws cloudfront create-distribution `
  --distribution-config file://infra/cloudfront-distribution.json `
  --profile sarowar-ostad
# Output → save Id (Distribution ID) and DomainName (e.g. d1abc.cloudfront.net)
```

---

### Step 5 — Update S3 Bucket Policy

Get your account ID:

```powershell
aws sts get-caller-identity `
  --query Account `
  --output text `
  --profile sarowar-ostad
```

Edit `infra/bucket-policy-phase2.json`:
- Replace `ACCOUNT_ID` → 12-digit account ID
- Replace `DISTRIBUTION_ID` → Distribution ID from Step 4

Apply the policy:

```powershell
aws s3api put-bucket-policy `
  --bucket batch11-ostaddevops-site `
  --policy file://infra/bucket-policy-phase2.json `
  --profile sarowar-ostad
```

---

### Step 6 — Route 53 DNS — A Alias Record

> `Z2FDTNDATAQYW2` is the **fixed** hosted zone ID for all CloudFront distributions (AWS hardcoded value).

```powershell
aws route53 change-resource-record-sets `
  --hosted-zone-id REPLACE_WITH_ZONE_ID `
  --change-batch '{
    "Changes":[{
      "Action":"CREATE",
      "ResourceRecordSet":{
        "Name":"batch11.ostaddevops.click",
        "Type":"A",
        "AliasTarget":{
          "HostedZoneId":"Z2FDTNDATAQYW2",
          "DNSName":"REPLACE_WITH_CLOUDFRONT_DOMAIN",
          "EvaluateTargetHealth":false
        }
      }
    }]
  }' `
  --profile sarowar-ostad
```

---

### Step 7 — Wait for CloudFront to Deploy

```powershell
aws cloudfront wait distribution-deployed `
  --id REPLACE_WITH_DISTRIBUTION_ID `
  --profile sarowar-ostad
# Blocks until Status = Deployed (~5 min)
```

---

### Step 8 — Build & Deploy

```powershell
.\deploy.ps1 -DistributionId "REPLACE_WITH_DISTRIBUTION_ID"
```

---

---

# Option 2 — Migrate from Phase 1 (Public → Private)

> The bucket already exists with Phase 1's public policy and static website hosting.
> This upgrades it in-place — **same bucket, no re-upload required** after migration steps.

---

## Option 2A — AWS Console (GUI)

### Step 1 — Remove Public Access from the Bucket

1. S3 → `batch11-ostaddevops-site` → **Permissions** tab
2. **Bucket policy** → **Edit** → delete all content → **Save changes**
3. **Block public access** → **Edit** → check all 4 boxes → **Save changes** → **Confirm**

---

### Step 2 — Disable Static Website Hosting

1. **Properties** tab → **Static website hosting** → **Edit**
2. Select **Disable** → **Save changes**

---

### Step 3 — Enable Encryption & Versioning

1. **Properties** → **Default encryption** → **Edit** → **SSE-S3** → **Save changes**
2. **Properties** → **Bucket Versioning** → **Edit** → **Enable** → **Save changes**

---

### Steps 4–8 — Same as Option 1A Steps 2–8

Follow **Option 1A** from **Step 2 (ACM Certificate)** onwards — they are identical.

---

---

## Option 2B — AWS CLI

### Step 1 — Harden the Existing Bucket

```powershell
# Remove the public read policy
aws s3api delete-bucket-policy `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad

# Re-enable Block Public Access
aws s3api put-public-access-block `
  --bucket batch11-ostaddevops-site `
  --public-access-block-configuration `
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true `
  --profile sarowar-ostad

# Disable static website hosting
aws s3api delete-bucket-website `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket batch11-ostaddevops-site `
  --versioning-configuration Status=Enabled `
  --profile sarowar-ostad

# Enable SSE-S3 encryption
aws s3api put-bucket-encryption `
  --bucket batch11-ostaddevops-site `
  --server-side-encryption-configuration '{
    "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]
  }' `
  --profile sarowar-ostad

# Verify bucket is now private
aws s3api get-public-access-block `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad
# All four values should be: true
```

---

### Steps 2–8 — Same as Option 1B Steps 2–8

Follow **Option 1B** from **Step 2 (ACM Certificate)** onwards — they are identical.

At the end, also run:

```powershell
# Flush any cached Phase 1 content from CloudFront
aws cloudfront create-invalidation `
  --distribution-id REPLACE_WITH_DISTRIBUTION_ID `
  --paths "/*" `
  --profile sarowar-ostad
```

---

---

## Verification Checklist

| Check | Expected |
|---|---|
| Direct S3 REST URL returns | ✅ `403 Access Denied` — bucket is private |
| `https://batch11.ostaddevops.click` loads | ✅ Site renders correctly |
| `http://batch11.ostaddevops.click` | ✅ Redirects to `https://` |
| Refresh on `/modules` | ✅ Returns 200 (SPA routing works) |
| Browser padlock → certificate | ✅ Valid for `batch11.ostaddevops.click` |
| DevTools Response Headers | ✅ `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options` present |

---

## deploy.ps1 Usage

```powershell
# Build + sync + invalidate CloudFront in one command
.\deploy.ps1 -DistributionId "YOUR_DISTRIBUTION_ID"

# Example
.\deploy.ps1 -DistributionId "E3ABCDEF1GHIJK"
```

The script is at the project root: [`deploy.ps1`](deploy.ps1)

---

## Key Facts to Remember

| Fact | Why it matters |
|---|---|
| ACM certificate must be in `us-east-1` | Hard AWS requirement for CloudFront, regardless of bucket region |
| Use S3 REST endpoint (not `.s3-website.`) as origin | S3 website endpoint doesn't support OAC signing |
| Map both 403 AND 404 to `/index.html` | Private S3 returns 403 (not 404) for missing keys |
| OAC signing = SigV4 | Required for S3 buckets outside `us-east-1` |
| CloudFront hosted zone for alias = `Z2FDTNDATAQYW2` | Fixed AWS value for all CloudFront distributions globally |
| Bucket name ≠ domain name | Avoids bucket enumeration attacks |
