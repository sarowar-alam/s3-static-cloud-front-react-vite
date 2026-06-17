<#
.SYNOPSIS
  Phase 2  -  Private S3 + CloudFront + HTTPS + Custom Domain.

.DESCRIPTION
  Fully independent of Phase 1. Uses existing ACM certificate and Route 53 hosted zone.
  Default  : If infrastructure already exists → re-deploys site only (build + sync + invalidate).
             If infrastructure does not exist  → creates everything then deploys.
  Teardown : Reverses only what this script created.

.PARAMETER Teardown
  Tear down all Phase 2 resources created by this script.

.EXAMPLE
  .\setup-phase2.ps1           # Setup (first run) or re-deploy (subsequent runs)
  .\setup-phase2.ps1 -Teardown # Destroy all Phase 2 resources
#>
param(
    [switch]$Teardown
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Config ────────────────────────────────────────────────────────────────────
$BucketName     = "master-ostaddevops-site-private"
$Region         = "ap-south-1"
$AwsProfile     = "sarowar-ostad"
$AccountId      = "388779989543"
$Domain         = "master.ostaddevops.click"
$HostedZoneId   = "Z1019653XLWIJ02C53P5"
$CfAliasZone    = "Z2FDTNDATAQYW2"   # Fixed AWS constant  -  same for every CloudFront distribution
$AcmCertArn     = "arn:aws:acm:us-east-1:388779989543:certificate/392fe338-b0b8-4aeb-ac2c-c930b219bb13"
$OacName        = "master-oac"
$CfTemplate     = Join-Path $PSScriptRoot "infra\cloudfront-distribution.json"
$PolicyTemplate = Join-Path $PSScriptRoot "infra\bucket-policy-phase2.json"
$StateFile      = Join-Path $PSScriptRoot ".phase2-state.json"
$SiteDir        = Join-Path $PSScriptRoot "master-site"

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Step    { param($n, $msg) Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-Ok      { param($msg)     Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skipped { param($msg)     Write-Host "    [SKIP] $msg" -ForegroundColor Yellow }
function Write-Info    { param($msg)     Write-Host "    $msg" -ForegroundColor DarkGray }

# ── AWS CLI wrapper ───────────────────────────────────────────────────────────
# No param block  -  $args automatic variable collects all space-separated arguments
function Invoke-Aws {
    $ErrorActionPreference = "Continue"
    $result = & aws @args --profile $AwsProfile 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = $result | Out-String
        throw "AWS CLI error (exit $LASTEXITCODE):`n$msg"
    }
    return $result
}

# ── Temp JSON file helper ─────────────────────────────────────────────────────
function New-TempJson {
    param([string]$Content)
    $path = Join-Path $env:TEMP "phase2-$(New-Guid).json"
    [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
    return $path
}

# ── State helpers ─────────────────────────────────────────────────────────────
function Load-State {
    if (Test-Path $StateFile) {
        return Get-Content $StateFile -Raw | ConvertFrom-Json
    }
    return [PSCustomObject]@{
        BucketCreatedByUs    = $false
        OacId                = $null
        OacCreatedByUs       = $false
        DistributionId       = $null
        DistributionDomain   = $null
        Route53RecordCreated = $false
    }
}

function Save-State {
    param($s)
    $s | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
}

# ── Build → Sync → Invalidate (shared by Setup and Deploy) ───────────────────
function Invoke-BuildAndSync {
    param([string]$DistributionId)

    Write-Step "Build" "Building React app..."
    $orig = Get-Location
    Set-Location $SiteDir
    try {
        if (-not (Test-Path "node_modules")) {
            Write-Info "node_modules not found  -  running npm install..."
            npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed." }
        }
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed." }
    } finally {
        Set-Location $orig
    }
    Write-Ok "Build complete."

    Write-Step "Sync" "Syncing dist/ to s3://$BucketName..."
    $distDir = Join-Path $SiteDir "dist"
    Invoke-Aws s3 sync $distDir "s3://$BucketName" --delete | Out-Null
    Write-Ok "Files synced to S3."

    Write-Step "Invalidate" "Invalidating CloudFront cache..."
    Invoke-Aws cloudfront create-invalidation `
        --distribution-id $DistributionId `
        --paths "/*" | Out-Null
    Write-Ok "CloudFront cache invalidated."
}

# =============================================================================
#  SETUP
# =============================================================================
function Invoke-Setup {
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "  Phase 2  -  Private S3 + CloudFront Setup"    -ForegroundColor Cyan
    Write-Host "  Bucket : $BucketName"                       -ForegroundColor Cyan
    Write-Host "  Domain : $Domain"                           -ForegroundColor Cyan
    Write-Host "  Region : $Region"                           -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan

    $state = Load-State

    # ── Step 1: S3 bucket ─────────────────────────────────────────────────────
    Write-Step "1/7" "Create private S3 bucket..."

    $bucketExists = $false
    try { & aws s3api head-bucket --bucket $BucketName --profile $AwsProfile 2>&1 | Out-Null; $bucketExists = ($LASTEXITCODE -eq 0) } catch { $bucketExists = $false }
    if ($bucketExists) {
        Write-Skipped "Bucket '$BucketName' already exists."
        $state.BucketCreatedByUs = $false
    } else {
        Invoke-Aws s3api create-bucket `
            --bucket $BucketName `
            --region $Region `
            --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
        $state.BucketCreatedByUs = $true
        Write-Ok "Bucket created."
    }
    Save-State $state

    # Harden bucket (idempotent  -  safe on every run)
    Invoke-Aws s3api put-public-access-block `
        --bucket $BucketName `
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" | Out-Null
    Invoke-Aws s3api put-bucket-versioning `
        --bucket $BucketName `
        --versioning-configuration "Status=Enabled" | Out-Null
    $encTemp = New-TempJson '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    try {
        Invoke-Aws s3api put-bucket-encryption `
            --bucket $BucketName `
            --server-side-encryption-configuration "file://$encTemp" | Out-Null
    } finally { Remove-Item $encTemp -Force -ErrorAction SilentlyContinue }
    Write-Ok "Bucket hardened (Block Public Access ON, versioning enabled, SSE-S3 encryption)."

    # ── Step 2: CloudFront OAC ────────────────────────────────────────────────
    Write-Step "2/7" "Create CloudFront Origin Access Control..."

    if ($state.OacId) {
        Write-Skipped "OAC already in state: $($state.OacId)"
    } else {
        $oacConfigJson = [ordered]@{
            Name                          = $OacName
            Description                   = "OAC for $BucketName"
            SigningProtocol               = "sigv4"
            SigningBehavior               = "always"
            OriginAccessControlOriginType = "s3"
        } | ConvertTo-Json
        $oacTemp = New-TempJson $oacConfigJson
        try {
            $oacResult = Invoke-Aws cloudfront create-origin-access-control `
                --origin-access-control-config "file://$oacTemp" | ConvertFrom-Json
        } finally { Remove-Item $oacTemp -Force -ErrorAction SilentlyContinue }
        $state.OacId          = $oacResult.OriginAccessControl.Id
        $state.OacCreatedByUs = $true
        Save-State $state
        Write-Ok "OAC created: $($state.OacId)"
    }

    # ── Step 3: CloudFront distribution ──────────────────────────────────────
    Write-Step "3/7" "Create CloudFront distribution..."

    if ($state.DistributionId) {
        Write-Skipped "Distribution already in state: $($state.DistributionId)"
    } else {
        # Patch template in-memory  -  infra/cloudfront-distribution.json is never modified on disk
        $cfConfig = Get-Content $CfTemplate -Raw | ConvertFrom-Json
        $cfConfig.CallerReference                         = "master-site-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $cfConfig.Origins.Items[0].OriginAccessControlId = $state.OacId
        $cfConfig.ViewerCertificate.ACMCertificateArn    = $AcmCertArn
        $cfTemp = New-TempJson ($cfConfig | ConvertTo-Json -Depth 20)
        try {
            $dist = Invoke-Aws cloudfront create-distribution `
                --distribution-config "file://$cfTemp" | ConvertFrom-Json
        } finally { Remove-Item $cfTemp -Force -ErrorAction SilentlyContinue }
        $state.DistributionId     = $dist.Distribution.Id
        $state.DistributionDomain = $dist.Distribution.DomainName
        Save-State $state
        Write-Ok "Distribution created: $($state.DistributionId)"
        Write-Info "CF domain: $($state.DistributionDomain)"
    }

    # ── Step 4: S3 bucket policy ──────────────────────────────────────────────
    Write-Step "4/7" "Apply OAC-only bucket policy..."

    $policyContent = (Get-Content $PolicyTemplate -Raw) `
        -replace 'ACCOUNT_ID',      $AccountId `
        -replace 'DISTRIBUTION_ID', $state.DistributionId
    $policyTemp = New-TempJson $policyContent
    try {
        Invoke-Aws s3api put-bucket-policy `
            --bucket $BucketName `
            --policy "file://$policyTemp" | Out-Null
    } finally { Remove-Item $policyTemp -Force -ErrorAction SilentlyContinue }
    Write-Ok "Bucket policy applied (OAC-only access from CloudFront)."

    # ── Step 5: Route 53 A alias ──────────────────────────────────────────────
    Write-Step "5/7" "Create Route 53 A alias: $Domain → CloudFront..."

    $r53Json = '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"' + $Domain + '","Type":"A","AliasTarget":{"HostedZoneId":"' + $CfAliasZone + '","DNSName":"' + $state.DistributionDomain + '","EvaluateTargetHealth":false}}}]}'
    $r53Temp = New-TempJson $r53Json
    try {
        Invoke-Aws route53 change-resource-record-sets `
            --hosted-zone-id $HostedZoneId `
            --change-batch "file://$r53Temp" | Out-Null
    } finally { Remove-Item $r53Temp -Force -ErrorAction SilentlyContinue }
    $state.Route53RecordCreated = $true
    Save-State $state
    Write-Ok "DNS alias record created (UPSERT)."

    # ── Step 6: Wait for CloudFront to deploy ────────────────────────────────
    Write-Step "6/7" "Waiting for CloudFront to finish deploying..."
    Write-Info "This typically takes 5-15 minutes. Please wait..."
    Invoke-Aws cloudfront wait distribution-deployed --id $state.DistributionId | Out-Null
    Write-Ok "Distribution deployed."

    # ── Step 7: Build & deploy site ───────────────────────────────────────────
    Write-Step "7/7" "Building and deploying site..."
    Invoke-BuildAndSync $state.DistributionId

    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "  Phase 2 setup complete!"                      -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Live URL   : https://$Domain"                 -ForegroundColor Yellow
    Write-Host "  CF Dist ID : $($state.DistributionId)"        -ForegroundColor White
    Write-Host "  CF Domain  : $($state.DistributionDomain)"    -ForegroundColor White
    Write-Host ""
    Write-Host "  Re-deploy  : .\setup-phase2.ps1"           -ForegroundColor DarkGray
    Write-Host "  Tear down  : .\setup-phase2.ps1 -Teardown"    -ForegroundColor DarkGray
    Write-Host ""
}

# =============================================================================
#  TEARDOWN
# =============================================================================
function Invoke-Teardown {
    Write-Host "`n=============================================" -ForegroundColor Yellow
    Write-Host "  Phase 2  -  Teardown"                           -ForegroundColor Yellow
    Write-Host "  Domain : $Domain"                             -ForegroundColor Yellow
    Write-Host "  Bucket : $BucketName"                         -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Yellow

    $state = Load-State

    Write-Host "`n  This will remove:" -ForegroundColor White
    if ($state.Route53RecordCreated)  { Write-Host "    - Route 53 A alias      : $Domain" -ForegroundColor White }
    if ($state.DistributionId)        { Write-Host "    - CloudFront dist        : $($state.DistributionId)" -ForegroundColor White }
    if ($state.OacCreatedByUs)        { Write-Host "    - CloudFront OAC         : $($state.OacId)" -ForegroundColor White }
    if ($state.BucketCreatedByUs) {
        Write-Host "    - S3 bucket + all objects: $BucketName" -ForegroundColor White
    } else {
        Write-Host "    - S3 bucket policy only  : $BucketName (bucket preserved  -  it pre-existed)" -ForegroundColor DarkYellow
    }
    Write-Host ""
    $confirm = Read-Host "  Continue? (y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "  Teardown cancelled." -ForegroundColor DarkGray
        exit 0
    }

    # ── 1. Route 53 A alias ───────────────────────────────────────────────────
    Write-Step "1/5" "Delete Route 53 A alias..."
    if ($state.Route53RecordCreated -and $state.DistributionDomain) {
        $r53Json = '{"Changes":[{"Action":"DELETE","ResourceRecordSet":{"Name":"' + $Domain + '","Type":"A","AliasTarget":{"HostedZoneId":"' + $CfAliasZone + '","DNSName":"' + $state.DistributionDomain + '","EvaluateTargetHealth":false}}}]}'
        $r53Temp = New-TempJson $r53Json
        try {
            Invoke-Aws route53 change-resource-record-sets `
                --hosted-zone-id $HostedZoneId `
                --change-batch "file://$r53Temp" | Out-Null
        } finally { Remove-Item $r53Temp -Force -ErrorAction SilentlyContinue }
        $state.Route53RecordCreated = $false
        Save-State $state
        Write-Ok "Route 53 record deleted."
    } else {
        Write-Skipped "Not in state  -  skipping."
    }

    # ── 2. Disable + delete CloudFront distribution ───────────────────────────
    Write-Step "2/5" "Disable + delete CloudFront distribution..."
    if ($state.DistributionId) {
        $etag = & aws cloudfront get-distribution-config `
                    --id $state.DistributionId `
                    --profile $AwsProfile `
                    --query ETag --output text 2>&1
        $configJson = & aws cloudfront get-distribution-config `
                    --id $state.DistributionId `
                    --profile $AwsProfile `
                    --query DistributionConfig --output json 2>&1 | Out-String
        # Disable by patching Enabled field
        $disabledJson = $configJson.Trim() -replace '"Enabled"\s*:\s*true', '"Enabled": false'
        $cfTemp = New-TempJson $disabledJson
        try {
            Invoke-Aws cloudfront update-distribution `
                --id $state.DistributionId `
                --if-match $etag `
                --distribution-config "file://$cfTemp" | Out-Null
        } finally { Remove-Item $cfTemp -Force -ErrorAction SilentlyContinue }
        Write-Info "Distribution disabled. Waiting for propagation (~5-15 min)..."
        Invoke-Aws cloudfront wait distribution-deployed --id $state.DistributionId | Out-Null
        $newEtag = & aws cloudfront get-distribution-config `
                    --id $state.DistributionId `
                    --profile $AwsProfile `
                    --query ETag --output text 2>&1
        Invoke-Aws cloudfront delete-distribution `
            --id $state.DistributionId `
            --if-match $newEtag | Out-Null
        Write-Ok "CloudFront distribution deleted."
        $state.DistributionId     = $null
        $state.DistributionDomain = $null
        Save-State $state
    } else {
        Write-Skipped "No distribution in state  -  skipping."
    }

    # ── 3. Delete OAC ────────────────────────────────────────────────────────
    Write-Step "3/5" "Delete CloudFront OAC..."
    if ($state.OacCreatedByUs -and $state.OacId) {
        $oacEtag = & aws cloudfront get-origin-access-control `
                        --id $state.OacId `
                        --profile $AwsProfile `
                        --query ETag --output text 2>&1
        Invoke-Aws cloudfront delete-origin-access-control `
            --id $state.OacId `
            --if-match $oacEtag | Out-Null
        Write-Ok "OAC deleted."
        $state.OacId          = $null
        $state.OacCreatedByUs = $false
        Save-State $state
    } else {
        Write-Skipped "OAC not created by this script  -  skipping."
    }

    # ── 4. S3 bucket ─────────────────────────────────────────────────────────
    Write-Step "4/5" "Clean up S3..."
    $bucketExists = $false
    try { & aws s3api head-bucket --bucket $BucketName --profile $AwsProfile 2>&1 | Out-Null; $bucketExists = ($LASTEXITCODE -eq 0) } catch { $bucketExists = $false }
    if (-not $bucketExists) {
        Write-Skipped "Bucket '$BucketName' not found - skipping."
    } elseif ($state.BucketCreatedByUs) {
        # Versioning is enabled  -  must delete all versions + delete markers before bucket can be deleted
        Write-Info "Deleting all object versions and delete markers..."
        $hasMore = $true
        while ($hasMore) {
            $versionsJson = & aws s3api list-object-versions `
                --bucket $BucketName `
                --profile $AwsProfile `
                --output json 2>&1 | Out-String
            $versionsObj = $versionsJson | ConvertFrom-Json

            # Collect versions and delete markers into one list
            $toDelete = @()
            if ($versionsObj.PSObject.Properties.Name -contains 'Versions' -and $versionsObj.Versions) {
                $toDelete += $versionsObj.Versions | ForEach-Object {
                    [PSCustomObject]@{ Key = $_.Key; VersionId = $_.VersionId }
                }
            }
            if ($versionsObj.PSObject.Properties.Name -contains 'DeleteMarkers' -and $versionsObj.DeleteMarkers) {
                $toDelete += $versionsObj.DeleteMarkers | ForEach-Object {
                    [PSCustomObject]@{ Key = $_.Key; VersionId = $_.VersionId }
                }
            }

            if ($toDelete.Count -eq 0) { $hasMore = $false; break }

            # delete-objects accepts max 1000 per call; list-object-versions pages at 1000 so one call suffices
            $deletePayload = [PSCustomObject]@{
                Objects = $toDelete
                Quiet   = $true
            } | ConvertTo-Json -Depth 5
            $delTemp = New-TempJson $deletePayload
            try {
                Invoke-Aws s3api delete-objects `
                    --bucket $BucketName `
                    --delete "file://$delTemp" | Out-Null
            } finally { Remove-Item $delTemp -Force -ErrorAction SilentlyContinue }

            # If IsTruncated was true there are more pages  -  loop again
            $hasMore = ($versionsObj.PSObject.Properties.Name -contains 'IsTruncated') -and ($versionsObj.IsTruncated -eq $true)
        }
        Write-Info "All versions deleted. Deleting bucket..."
        Invoke-Aws s3api delete-bucket --bucket $BucketName --region $Region | Out-Null
        Write-Ok "Bucket emptied and deleted."
    } else {
        & aws s3api delete-bucket-policy --bucket $BucketName --profile $AwsProfile 2>&1 | Out-Null
        Write-Ok "Bucket policy removed (bucket preserved  -  it pre-existed)."
    }
    $state.BucketCreatedByUs = $false
    Save-State $state

    # ── 5. Remove state file ──────────────────────────────────────────────────
    Write-Step "5/5" "Removing state file..."
    if (Test-Path $StateFile) { Remove-Item $StateFile -Force }
    Write-Ok "State file removed."

    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "  Phase 2 teardown complete!"                   -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
}

# ── Entry point ───────────────────────────────────────────────────────────────
if ($Teardown) {
    Invoke-Teardown
} else {
    $existingState = Load-State
    if ($existingState.DistributionId) {
        # Infrastructure already exists  -  re-deploy only
        Write-Host "`n=============================================" -ForegroundColor Cyan
        Write-Host "  Phase 2  -  Re-deploy"                          -ForegroundColor Cyan
        Write-Host "  Bucket : $BucketName"                         -ForegroundColor Cyan
        Write-Host "  Dist   : $($existingState.DistributionId)"    -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Invoke-BuildAndSync $existingState.DistributionId
        Write-Host "`n  Re-deploy complete!" -ForegroundColor Green
        Write-Host "  https://$Domain`n"     -ForegroundColor Yellow
    } else {
        Invoke-Setup
    }
}
