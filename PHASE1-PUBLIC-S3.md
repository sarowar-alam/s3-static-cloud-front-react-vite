# Phase 1 — Static Site with Public S3 Bucket

Deploy the React + Vite site using S3 Static Website Hosting with a public bucket.

> ⚠️ **The bucket is publicly readable — anyone with the URL can access the files directly.**
> This is a known limitation of S3 Static Website Hosting. Phase 2 removes this.

---

## Variables

| Name | Value |
|---|---|
| Bucket | `batch11-ostaddevops-site` |
| Region | `ap-south-1` |
| AWS Profile | `sarowar-ostad` |
| Policy file | `infra/bucket-policy-phase1.json` |
| Deploy script | `deploy.ps1` |

---

## Option A — AWS Console (GUI)

### Step 1 — Create S3 Bucket

1. Open [S3 Console](https://s3.console.aws.amazon.com/) → **Create bucket**
2. **Bucket name:** `batch11-ostaddevops-site`
3. **AWS Region:** `ap-south-1` (Asia Pacific — Mumbai)
4. Under **Block Public Access settings:**
   - **Uncheck** `Block all public access`
   - Check the acknowledgement checkbox that appears
5. Leave everything else as default
6. Click **Create bucket**

---

### Step 2 — Enable Static Website Hosting

1. Open the bucket → **Properties** tab
2. Scroll to **Static website hosting** → click **Edit**
3. Enable: ✅ **Enable**
4. Hosting type: **Host a static website**
5. Index document: `index.html`
6. Error document: `index.html`
7. Click **Save changes**
8. 📋 Copy the **Bucket website endpoint** URL shown at the bottom — you'll use it to test

---

### Step 3 — Apply Public Read Bucket Policy

1. Open the bucket → **Permissions** tab
2. Scroll to **Bucket policy** → click **Edit**
3. Paste the contents of [`infra/bucket-policy-phase1.json`](infra/bucket-policy-phase1.json):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "PublicReadGetObject",
         "Effect": "Allow",
         "Principal": "*",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::batch11-ostaddevops-site/*"
       }
     ]
   }
   ```
4. Click **Save changes**

---

### Step 4 — Build the Site

In your VS Code terminal:

```powershell
cd batch11-site
npm run build
```

This creates the `batch11-site/dist/` folder with production-ready files.

---

### Step 5 — Upload Files to S3

1. Open the bucket → **Objects** tab → click **Upload**
2. Click **Add files** — select all files directly inside `batch11-site/dist/`
3. Click **Add folder** — select the `assets/` folder inside `batch11-site/dist/`
4. Click **Upload**

> **Tip:** Make sure `index.html` is uploaded at the **root** of the bucket, not inside a subfolder.

---

### Step 6 — Test

Open the **Bucket website endpoint** URL from Step 2 in your browser.

```
http://batch11-ostaddevops-site.s3-website.ap-south-1.amazonaws.com
```

✅ You should see your site loaded over `http://`.

---

---

## Option B — AWS CLI

Run all commands from the **project root** (`Class-02/`).

### Step 1 — Create S3 Bucket

```powershell
aws s3api create-bucket `
  --bucket batch11-ostaddevops-site `
  --region ap-south-1 `
  --create-bucket-configuration LocationConstraint=ap-south-1 `
  --profile sarowar-ostad
```

---

### Step 2 — Remove Block Public Access

```powershell
aws s3api delete-public-access-block `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad
```

Verify it worked:

```powershell
aws s3api get-public-access-block `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad
```

All four values should be `false`.

---

### Step 3 — Enable Static Website Hosting

```powershell
aws s3 website s3://batch11-ostaddevops-site/ `
  --index-document index.html `
  --error-document index.html `
  --profile sarowar-ostad
```

---

### Step 4 — Apply Public Read Bucket Policy

```powershell
aws s3api put-bucket-policy `
  --bucket batch11-ostaddevops-site `
  --policy file://infra/bucket-policy-phase1.json `
  --profile sarowar-ostad
```

---

### Step 5 — Build & Deploy with deploy.ps1

```powershell
.\deploy.ps1 -SkipInvalidation
```

This script:
1. Runs `npm run build` inside `batch11-site/`
2. Syncs `dist/` to `s3://batch11-ostaddevops-site` with `--delete`
3. Skips CloudFront invalidation (not needed in Phase 1)

---

### Step 6 — Get the Website Endpoint URL

```powershell
aws s3api get-bucket-website `
  --bucket batch11-ostaddevops-site `
  --profile sarowar-ostad
```

Or construct it directly:

```
http://batch11-ostaddevops-site.s3-website.ap-south-1.amazonaws.com
```

---

## Verification Checklist

| Check | Expected |
|---|---|
| S3 website URL loads | ✅ Site renders |
| Clicking navbar links works | ✅ Navigation works |
| Refresh on `/modules` | ✅ Returns `index.html` (error doc) |
| Direct S3 object URL | ✅ File is publicly accessible |

---

## What's Next?

When you're ready to add HTTPS and a custom domain (`batch11.ostaddevops.click`),
follow **PHASE2-PRIVATE-CLOUDFRONT.md** — either starting fresh or migrating from this setup.
