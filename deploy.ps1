<#
.SYNOPSIS
  Build the React app and deploy it to S3. Optionally invalidate CloudFront.

.PARAMETER DistributionId
  CloudFront distribution ID (required for Phase 2 cache invalidation).

.PARAMETER SkipInvalidation
  Skip CloudFront cache invalidation (use for Phase 1 or when not needed).

.EXAMPLE
  # Phase 1 — S3 only
  .\deploy.ps1 -SkipInvalidation

  # Phase 2 — S3 + CloudFront invalidation
  .\deploy.ps1 -DistributionId "EXAMPLEID123"
#>
param(
    [string]$DistributionId = "",
    [switch]$SkipInvalidation
)

$ErrorActionPreference = "Stop"

$BucketName  = "batch11-ostaddevops-site"
$AwsProfile  = "sarowar-ostad"
$SiteDir     = "batch11-site"
$ScriptRoot  = $PSScriptRoot

# ── 1. Build ─────────────────────────────────────────────────────────────────
Write-Host "`n[1/3] Building React app..." -ForegroundColor Cyan

Set-Location (Join-Path $ScriptRoot $SiteDir)
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed. Aborting deploy."
    exit 1
}
Set-Location $ScriptRoot

# ── 2. Sync to S3 ─────────────────────────────────────────────────────────────
Write-Host "`n[2/3] Syncing dist/ to s3://$BucketName ..." -ForegroundColor Cyan

aws s3 sync "$SiteDir/dist/" "s3://$BucketName" `
    --delete `
    --profile $AwsProfile

if ($LASTEXITCODE -ne 0) {
    Write-Error "S3 sync failed."
    exit 1
}

# ── 3. CloudFront Invalidation ────────────────────────────────────────────────
if (-not $SkipInvalidation) {
    if (-not $DistributionId) {
        Write-Warning "No -DistributionId provided. Skipping CloudFront invalidation."
        Write-Warning "Run: .\deploy.ps1 -DistributionId `"YOUR_DIST_ID`""
    } else {
        Write-Host "`n[3/3] Invalidating CloudFront cache ($DistributionId)..." -ForegroundColor Cyan

        aws cloudfront create-invalidation `
            --distribution-id $DistributionId `
            --paths "/*" `
            --profile $AwsProfile

        if ($LASTEXITCODE -ne 0) {
            Write-Error "CloudFront invalidation failed."
            exit 1
        }
    }
} else {
    Write-Host "`n[3/3] Skipping CloudFront invalidation (-SkipInvalidation flag set)." -ForegroundColor Gray
}

Write-Host "`nDeploy complete!" -ForegroundColor Green
