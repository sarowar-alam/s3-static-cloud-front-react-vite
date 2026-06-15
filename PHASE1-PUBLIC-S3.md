# Phase 1 — Static Site with Public S3 Bucket

Deploy the React + Vite site using S3 Static Website Hosting with a public bucket.

> ⚠️ **The bucket is publicly readable — anyone with the URL can access the files directly.**
> This is a known limitation of S3 Static Website Hosting. Phase 2 removes this.

---

## Variables

| Name | Value |
|---|---|
| Bucket | `master-ostaddevops-site` |
| Region | `ap-south-1` |
| AWS Profile | `sarowar-ostad` |
| Policy file | `infra/bucket-policy-phase1.json` |

---

## Option A — AWS Console (GUI)

### Step 1 — Create S3 Bucket

1. Open [S3 Console](https://s3.console.aws.amazon.com/) → **Create bucket**
2. **Bucket name:** `master-ostaddevops-site`
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
         "Resource": "arn:aws:s3:::master-ostaddevops-site/*"
       }
     ]
   }
   ```
4. Click **Save changes**

---

### Step 4 — Build the Site

In your VS Code terminal:

```powershell
cd master-site
npm run build
```

This creates the `master-site/dist/` folder with production-ready files.

---

### Step 5 — Upload Files to S3

1. Open the bucket → **Objects** tab → click **Upload**
2. Click **Add files** — select all files directly inside `master-site/dist/`
3. Click **Add folder** — select the `assets/` folder inside `master-site/dist/`
4. Click **Upload**

> **Tip:** Make sure `index.html` is uploaded at the **root** of the bucket, not inside a subfolder.

---

### Step 6 — Test

Open the **Bucket website endpoint** URL from Step 2 in your browser.

```
http://master-ostaddevops-site.s3-website.ap-south-1.amazonaws.com
```

✅ You should see your site loaded over `http://`.

---

---

## Option B — AWS CLI

Run all commands from the **project root** (`Class-02/`).

### Step 1 — Create S3 Bucket

```powershell
aws s3api create-bucket `
  --bucket master-ostaddevops-site `
  --region ap-south-1 `
  --create-bucket-configuration LocationConstraint=ap-south-1 `
  --profile sarowar-ostad
```

---

### Step 2 — Remove Block Public Access

```powershell
aws s3api delete-public-access-block `
  --bucket master-ostaddevops-site `
  --profile sarowar-ostad
```

Verify it worked:

```powershell
aws s3api get-public-access-block `
  --bucket master-ostaddevops-site `
  --profile sarowar-ostad
```

All four values should be `false`.

---

### Step 3 — Enable Static Website Hosting

```powershell
aws s3 website s3://master-ostaddevops-site/ `
  --index-document index.html `
  --error-document index.html `
  --profile sarowar-ostad
```

---

### Step 4 — Apply Public Read Bucket Policy

```powershell
aws s3api put-bucket-policy `
  --bucket master-ostaddevops-site `
  --policy file://infra/bucket-policy-phase1.json `
  --profile sarowar-ostad
```

---

### Step 5 — Build & Deploy

```powershell
cd master-site
npm install       # first time only
npm run build
cd ..
aws s3 sync master-site/dist/ s3://master-ostaddevops-site --delete --profile sarowar-ostad
```

---

### Step 6 — Get the Website Endpoint URL

```powershell
aws s3api get-bucket-website `
  --bucket master-ostaddevops-site `
  --profile sarowar-ostad
```

Or construct it directly:

```
http://master-ostaddevops-site.s3-website.ap-south-1.amazonaws.com
```

---

## Option C — PowerShell Script (Automated)

Runs all Option B steps in one command. Must be executed from the **project root**.

### Setup

```powershell
.\setup-phase1.ps1
```

Performs all 5 steps automatically:
1. Creates the S3 bucket (skips if it already exists) — saves state immediately either way
2. Removes Block Public Access
3. Enables static website hosting
4. Applies `infra/bucket-policy-phase1.json`
5. Runs `npm install` if `node_modules` is missing, builds the React app, and syncs `dist/` to S3

Prints the live test URL on completion.

### Teardown

```powershell
.\setup-phase1.ps1 -Teardown
```

Asks for confirmation, then reverses Phase 1:
- If the bucket **was created by the script** → empties and deletes it entirely
- If the bucket **pre-existed** → only removes the policy and website config; bucket and its contents are preserved

> State is tracked in `.phase1-state.json` (auto-created, gitignored). It records whether the bucket was created by this script or pre-existed. Do not delete it between setup and teardown — teardown uses it to decide whether to delete the bucket or only remove its config.

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

When you're ready to add HTTPS and a custom domain (`master.ostaddevops.click`),
follow **PHASE2-PRIVATE-CLOUDFRONT.md** — either starting fresh or migrating from this setup.

---

## Project Lead

**MD Sarowar Alam**  
Lead DevOps Engineer, WPP Production  
📧 Email: [sarowar@hotmail.com](mailto:sarowar@hotmail.com)  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
