<#
.SYNOPSIS
  Phase 1 — Public S3 Static Site: setup or teardown.

.DESCRIPTION
  Setup  (default): Creates the S3 bucket, enables static website hosting,
                    applies the public-read policy, builds and deploys the site.
  Teardown (-Teardown): Reverses everything this script created. Will NOT delete
                        a bucket that existed before this script ran.

.PARAMETER Teardown
  Switch to tear down Phase 1 resources instead of setting them up.

.EXAMPLE
  # Setup Phase 1
  .\setup-phase1.ps1

  # Teardown Phase 1
  .\setup-phase1.ps1 -Teardown
#>
param(
    [switch]$Teardown
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Config ────────────────────────────────────────────────────────────────────
$BucketName   = "master-ostaddevops-site"
$Region       = "ap-south-1"
$AwsProfile   = "sarowar-ostad"
$PolicyFile   = Join-Path $PSScriptRoot "infra\bucket-policy-phase1.json"
$StateFile    = Join-Path $PSScriptRoot ".phase1-state.json"
$SiteDir      = Join-Path $PSScriptRoot "master-site"
$WebsiteUrl   = "http://$BucketName.s3-website.$Region.amazonaws.com"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Step  { param($n, $msg) Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg)     Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skipped { param($msg)   Write-Host "    [SKIP] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg)     Write-Host "    [FAIL] $msg" -ForegroundColor Red }

function Invoke-Aws {
    # $args is the automatic variable; no param block so every argument lands in it
    $result = & aws @args --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI error (exit $LASTEXITCODE):`n$result"
    }
    return $result
}

# ── State helpers — track what *this script* created ─────────────────────────
function Load-State {
    if (Test-Path $StateFile) {
        return Get-Content $StateFile -Raw | ConvertFrom-Json
    }
    return [PSCustomObject]@{ BucketCreatedByUs = $false }
}

function Save-State {
    param($State)
    $State | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
}

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-Setup {
    Write-Host "`n======================================" -ForegroundColor Cyan
    Write-Host "  Phase 1 — Public S3 Setup" -ForegroundColor Cyan
    Write-Host "  Bucket : $BucketName" -ForegroundColor Cyan
    Write-Host "  Region : $Region" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan

    $state = Load-State

    # ── Step 1: Create bucket ─────────────────────────────────────────────────
    Write-Step "1/5" "Create S3 bucket..."

    $exists = & aws s3api head-bucket --bucket $BucketName --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Skipped "Bucket '$BucketName' already exists — skipping creation."
        $state.BucketCreatedByUs = $false
        Save-State $state
    } else {
        Invoke-Aws s3api create-bucket `
            --bucket $BucketName `
            --region $Region `
            --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
        $state.BucketCreatedByUs = $true
        Save-State $state
        Write-Ok "Bucket created."
    }

    # ── Step 2: Remove Block Public Access ───────────────────────────────────
    Write-Step "2/5" "Removing Block Public Access..."
    Invoke-Aws s3api delete-public-access-block --bucket $BucketName | Out-Null
    Write-Ok "Block Public Access removed."

    # ── Step 3: Enable static website hosting ────────────────────────────────
    Write-Step "3/5" "Enabling static website hosting..."
    Invoke-Aws s3 website "s3://$BucketName/" `
        --index-document index.html `
        --error-document index.html | Out-Null
    Write-Ok "Static website hosting enabled."

    # ── Step 4: Apply public read policy ─────────────────────────────────────
    Write-Step "4/5" "Applying public-read bucket policy..."
    if (-not (Test-Path $PolicyFile)) {
        Write-Fail "Policy file not found: $PolicyFile"
        exit 1
    }
    Invoke-Aws s3api put-bucket-policy `
        --bucket $BucketName `
        --policy "file://$PolicyFile" | Out-Null
    Write-Ok "Bucket policy applied."

    # ── Step 5: Build & deploy ────────────────────────────────────────────────
    Write-Step "5/5" "Building and deploying site..."

    $orig = Get-Location
    Set-Location $SiteDir
    try {
        if (-not (Test-Path "node_modules")) {
            Write-Host "    node_modules not found — running npm install..." -ForegroundColor Yellow
            npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed." }
        }
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed." }
    } finally {
        Set-Location $orig
    }
    Write-Ok "Build complete."

    $distDir = Join-Path $SiteDir "dist"
    Invoke-Aws s3 sync $distDir "s3://$BucketName" --delete | Out-Null
    Write-Ok "Files synced to S3."

    # ── Done ──────────────────────────────────────────────────────────────────
    Write-Host "`n======================================" -ForegroundColor Green
    Write-Host "  Phase 1 setup complete!" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Test URL:" -ForegroundColor White
    Write-Host "  $WebsiteUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To tear down: .\setup-phase1.ps1 -Teardown" -ForegroundColor DarkGray
    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
#  TEARDOWN
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-Teardown {
    Write-Host "`n======================================" -ForegroundColor Yellow
    Write-Host "  Phase 1 — Teardown" -ForegroundColor Yellow
    Write-Host "  Bucket : $BucketName" -ForegroundColor Yellow
    Write-Host "  Region : $Region" -ForegroundColor Yellow
    Write-Host "======================================" -ForegroundColor Yellow

    $state = Load-State

    # ── Confirm ───────────────────────────────────────────────────────────────
    Write-Host ""
    if ($state.BucketCreatedByUs) {
        Write-Host "  This will:" -ForegroundColor White
        Write-Host "    - Delete ALL objects in '$BucketName'" -ForegroundColor White
        Write-Host "    - Delete the bucket itself" -ForegroundColor White
    } else {
        Write-Host "  This will:" -ForegroundColor White
        Write-Host "    - Remove the bucket policy" -ForegroundColor White
        Write-Host "    - Disable static website hosting" -ForegroundColor White
        Write-Host "    - Restore Block Public Access" -ForegroundColor White
        Write-Host "    - The bucket will NOT be deleted (it pre-existed)" -ForegroundColor DarkYellow
    }
    Write-Host ""
    $confirm = Read-Host "  Continue? (y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "  Teardown cancelled." -ForegroundColor DarkGray
        exit 0
    }

    # ── Check bucket exists ───────────────────────────────────────────────────
    $exists = & aws s3api head-bucket --bucket $BucketName --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Skipped "Bucket '$BucketName' does not exist — nothing to tear down."
        if (Test-Path $StateFile) { Remove-Item $StateFile -Force }
        exit 0
    }

    if ($state.BucketCreatedByUs) {
        # ── Empty and delete bucket ───────────────────────────────────────────
        Write-Step "1/4" "Deleting all objects from bucket..."
        Invoke-Aws s3 rm "s3://$BucketName" --recursive | Out-Null
        Write-Ok "All objects deleted."

        Write-Step "2/4" "Deleting bucket policy..."
        & aws s3api delete-bucket-policy --bucket $BucketName --profile $AwsProfile 2>&1 | Out-Null
        Write-Ok "Bucket policy removed (or was already absent)."

        Write-Step "3/4" "Disabling static website hosting..."
        & aws s3api delete-bucket-website --bucket $BucketName --profile $AwsProfile 2>&1 | Out-Null
        Write-Ok "Static website hosting disabled (or was already disabled)."

        Write-Step "4/4" "Deleting bucket '$BucketName'..."
        Invoke-Aws s3api delete-bucket `
            --bucket $BucketName `
            --region $Region | Out-Null
        Write-Ok "Bucket deleted."
    } else {
        # ── Pre-existing bucket: only reverse Phase 1 config ─────────────────
        Write-Step "1/3" "Deleting bucket policy..."
        & aws s3api delete-bucket-policy --bucket $BucketName --profile $AwsProfile 2>&1 | Out-Null
        Write-Ok "Bucket policy removed."

        Write-Step "2/3" "Disabling static website hosting..."
        & aws s3api delete-bucket-website --bucket $BucketName --profile $AwsProfile 2>&1 | Out-Null
        Write-Ok "Static website hosting disabled."

        Write-Step "3/3" "Restoring Block Public Access..."
        Invoke-Aws s3api put-public-access-block `
            --bucket $BucketName `
            --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" | Out-Null
        Write-Ok "Block Public Access restored."

        Write-Host ""
        Write-Host "  Bucket '$BucketName' preserved (pre-existed before Phase 1 setup)." -ForegroundColor DarkYellow
    }

    # ── Clean up state file ───────────────────────────────────────────────────
    if (Test-Path $StateFile) { Remove-Item $StateFile -Force }

    Write-Host "`n======================================" -ForegroundColor Green
    Write-Host "  Phase 1 teardown complete!" -ForegroundColor Green
    Write-Host "======================================`n" -ForegroundColor Green
}

# ── Entry point ───────────────────────────────────────────────────────────────
if ($Teardown) {
    Invoke-Teardown
} else {
    Invoke-Setup
}
