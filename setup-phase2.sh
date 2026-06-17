#!/usr/bin/env bash
# Phase 2 - Private S3 + CloudFront + HTTPS + Custom Domain.
#
# Fully independent of Phase 1. Uses existing ACM certificate and Route 53 hosted zone.
# Default  : If infrastructure already exists -> re-deploys site only (build + sync + invalidate).
#            If infrastructure does not exist  -> creates everything then deploys.
# Teardown : Reverses only what this script created.
#
# Usage:
#   ./setup-phase2.sh             # Setup (first run) or re-deploy (subsequent runs)
#   ./setup-phase2.sh --teardown  # Destroy all Phase 2 resources
#
# Requirements: aws cli, jq, node/npm

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BUCKET_NAME="master-ostaddevops-site-private"
REGION="ap-south-1"
AWS_PROFILE="sarowar-ostad"
ACCOUNT_ID="388779989543"
DOMAIN="master.ostaddevops.click"
HOSTED_ZONE_ID="Z1019653XLWIJ02C53P5"
CF_ALIAS_ZONE="Z2FDTNDATAQYW2"   # Fixed AWS constant - same for every CloudFront distribution
ACM_CERT_ARN="arn:aws:acm:us-east-1:388779989543:certificate/392fe338-b0b8-4aeb-ac2c-c930b219bb13"
OAC_NAME="master-oac"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CF_TEMPLATE="$SCRIPT_DIR/infra/cloudfront-distribution.json"
POLICY_TEMPLATE="$SCRIPT_DIR/infra/bucket-policy-phase2.json"
STATE_FILE="$SCRIPT_DIR/.phase2-state.json"
SITE_DIR="$SCRIPT_DIR/master-site"

# ── File URI helper (Git Bash on Windows needs cygpath for AWS CLI file://) ──
file_uri() {
    if command -v cygpath &>/dev/null; then
        echo "file://$(cygpath -w "$1")"
    else
        echo "file://$1"
    fi
}

# ── Colour helpers ────────────────────────────────────────────────────────────
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DARK_GRAY='\033[0;90m'
NC='\033[0m'

write_step()    { echo -e "\n${CYAN}[$1] $2${NC}"; }
write_ok()      { echo -e "    ${GREEN}[OK] $1${NC}"; }
write_skipped() { echo -e "    ${YELLOW}[SKIP] $1${NC}"; }
write_info()    { echo -e "    ${DARK_GRAY}$1${NC}"; }

# ── Dependency check ──────────────────────────────────────────────────────────
for cmd in aws jq node npm; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed." >&2
        exit 1
    fi
done

# ── AWS CLI wrapper ───────────────────────────────────────────────────────────
invoke_aws() {
    local output exit_code=0
    output=$(aws "$@" --profile "$AWS_PROFILE" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "AWS CLI error (exit $exit_code):" >&2
        echo "$output" >&2
        exit "$exit_code"
    fi
    echo "$output"
}

# ── Temp JSON file helper ─────────────────────────────────────────────────────
new_temp_json() {
    local content="$1"
    local tmp
    tmp=$(mktemp /tmp/phase2-XXXXXX.json)
    printf '%s' "$content" > "$tmp"
    echo "$tmp"
}

# ── State helpers ─────────────────────────────────────────────────────────────
BUCKET_CREATED_BY_US="false"
OAC_ID=""
OAC_CREATED_BY_US="false"
DIST_ID=""
DIST_DOMAIN=""
ROUTE53_RECORD_CREATED="false"

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        BUCKET_CREATED_BY_US=$(jq -r '.BucketCreatedByUs'         "$STATE_FILE")
        OAC_ID=$(              jq -r '.OacId              // ""'   "$STATE_FILE")
        OAC_CREATED_BY_US=$(   jq -r '.OacCreatedByUs'            "$STATE_FILE")
        DIST_ID=$(             jq -r '.DistributionId     // ""'   "$STATE_FILE")
        DIST_DOMAIN=$(         jq -r '.DistributionDomain // ""'   "$STATE_FILE")
        ROUTE53_RECORD_CREATED=$(jq -r '.Route53RecordCreated'     "$STATE_FILE")
    fi
}

save_state() {
    jq -n \
        --argjson bucketCreated   "$BUCKET_CREATED_BY_US" \
        --arg     oacId           "${OAC_ID:-}" \
        --argjson oacCreated      "$OAC_CREATED_BY_US" \
        --arg     distId          "${DIST_ID:-}" \
        --arg     distDomain      "${DIST_DOMAIN:-}" \
        --argjson r53Created      "$ROUTE53_RECORD_CREATED" \
        '{
            BucketCreatedByUs:    $bucketCreated,
            OacId:                (if $oacId     == "" then null else $oacId     end),
            OacCreatedByUs:       $oacCreated,
            DistributionId:       (if $distId    == "" then null else $distId    end),
            DistributionDomain:   (if $distDomain== "" then null else $distDomain end),
            Route53RecordCreated: $r53Created
        }' > "$STATE_FILE"
}

# ── Build → Sync → Invalidate ─────────────────────────────────────────────────
invoke_build_and_sync() {
    local dist_id="$1"

    write_step "Build" "Building React app..."
    pushd "$SITE_DIR" > /dev/null
    if [[ ! -d "node_modules" ]]; then
        write_info "node_modules not found - running npm install..."
        npm install
    fi
    npm run build
    popd > /dev/null
    write_ok "Build complete."

    write_step "Sync" "Syncing dist/ to s3://$BUCKET_NAME..."
    invoke_aws s3 sync "$SITE_DIR/dist" "s3://$BUCKET_NAME" --delete > /dev/null
    write_ok "Files synced to S3."

    write_step "Invalidate" "Invalidating CloudFront cache..."
    invoke_aws cloudfront create-invalidation \
        --distribution-id "$dist_id" \
        --paths "/*" > /dev/null
    write_ok "CloudFront cache invalidated."
}

# =============================================================================
#  SETUP
# =============================================================================
do_setup() {
    echo -e "\n${CYAN}============================================="
    echo -e "  Phase 2 - Private S3 + CloudFront Setup"
    echo -e "  Bucket : $BUCKET_NAME"
    echo -e "  Domain : $DOMAIN"
    echo -e "  Region : $REGION"
    echo -e "=============================================${NC}"

    load_state

    # ── Step 1: S3 bucket ─────────────────────────────────────────────────────
    write_step "1/7" "Create private S3 bucket..."
    if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
        write_skipped "Bucket '$BUCKET_NAME' already exists."
        BUCKET_CREATED_BY_US="false"
    else
        invoke_aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration "LocationConstraint=$REGION" > /dev/null
        BUCKET_CREATED_BY_US="true"
        write_ok "Bucket created."
    fi
    save_state

    # Harden bucket (idempotent - safe on every run)
    invoke_aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" > /dev/null
    invoke_aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration "Status=Enabled" > /dev/null
    enc_temp=$(new_temp_json '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}')
    invoke_aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration "$(file_uri "$enc_temp")" > /dev/null
    rm -f "$enc_temp"
    write_ok "Bucket hardened (Block Public Access ON, versioning enabled, SSE-S3 encryption)."

    # ── Step 2: CloudFront OAC ─────────────────────────────────────────────────
    write_step "2/7" "Create CloudFront Origin Access Control..."
    if [[ -n "$OAC_ID" ]]; then
        write_skipped "OAC already in state: $OAC_ID"
    else
        oac_config_json=$(jq -n \
            --arg name "$OAC_NAME" \
            --arg bucket "$BUCKET_NAME" \
            '{
                Name:                         $name,
                Description:                  ("OAC for " + $bucket),
                SigningProtocol:              "sigv4",
                SigningBehavior:              "always",
                OriginAccessControlOriginType:"s3"
            }')
        oac_temp=$(new_temp_json "$oac_config_json")
        oac_result=$(invoke_aws cloudfront create-origin-access-control \
            --origin-access-control-config "$(file_uri "$oac_temp")")
        rm -f "$oac_temp"
        OAC_ID=$(echo "$oac_result" | jq -r '.OriginAccessControl.Id')
        OAC_CREATED_BY_US="true"
        save_state
        write_ok "OAC created: $OAC_ID"
    fi

    # ── Step 3: CloudFront distribution ───────────────────────────────────────
    write_step "3/7" "Create CloudFront distribution..."
    if [[ -n "$DIST_ID" ]]; then
        write_skipped "Distribution already in state: $DIST_ID"
    else
        caller_ref="master-site-$(date -u +%Y%m%d%H%M%S)"
        cf_config=$(jq \
            --arg ref  "$caller_ref" \
            --arg oac  "$OAC_ID" \
            --arg cert "$ACM_CERT_ARN" \
            '.CallerReference                        = $ref  |
             .Origins.Items[0].OriginAccessControlId = $oac  |
             .ViewerCertificate.ACMCertificateArn    = $cert' \
            "$CF_TEMPLATE")
        cf_temp=$(new_temp_json "$cf_config")
        dist_result=$(invoke_aws cloudfront create-distribution \
            --distribution-config "$(file_uri "$cf_temp")")
        rm -f "$cf_temp"
        DIST_ID=$(    echo "$dist_result" | jq -r '.Distribution.Id')
        DIST_DOMAIN=$(echo "$dist_result" | jq -r '.Distribution.DomainName')
        save_state
        write_ok "Distribution created: $DIST_ID"
        write_info "CF domain: $DIST_DOMAIN"
    fi

    # ── Step 4: S3 bucket policy ───────────────────────────────────────────────
    write_step "4/7" "Apply OAC-only bucket policy..."
    policy_content=$(sed \
        -e "s/ACCOUNT_ID/$ACCOUNT_ID/g" \
        -e "s/DISTRIBUTION_ID/$DIST_ID/g" \
        "$POLICY_TEMPLATE")
    policy_temp=$(new_temp_json "$policy_content")
    invoke_aws s3api put-bucket-policy \
        --bucket "$BUCKET_NAME" \
        --policy "$(file_uri "$policy_temp")" > /dev/null
    rm -f "$policy_temp"
    write_ok "Bucket policy applied (OAC-only access from CloudFront)."

    # ── Step 5: Route 53 A alias ───────────────────────────────────────────────
    write_step "5/7" "Create Route 53 A alias: $DOMAIN -> CloudFront..."
    r53_json=$(jq -n \
        --arg domain  "$DOMAIN" \
        --arg cfzone  "$CF_ALIAS_ZONE" \
        --arg cfdns   "$DIST_DOMAIN" \
        '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":$domain,"Type":"A","AliasTarget":{"HostedZoneId":$cfzone,"DNSName":$cfdns,"EvaluateTargetHealth":false}}}]}')
    r53_temp=$(new_temp_json "$r53_json")
    invoke_aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "$(file_uri "$r53_temp")" > /dev/null
    rm -f "$r53_temp"
    ROUTE53_RECORD_CREATED="true"
    save_state
    write_ok "DNS alias record created (UPSERT)."

    # ── Step 6: Wait for CloudFront ────────────────────────────────────────────
    write_step "6/7" "Waiting for CloudFront to finish deploying..."
    write_info "This typically takes 5-15 minutes. Please wait..."
    invoke_aws cloudfront wait distribution-deployed --id "$DIST_ID" > /dev/null
    write_ok "Distribution deployed."

    # ── Step 7: Build & deploy site ────────────────────────────────────────────
    write_step "7/7" "Building and deploying site..."
    invoke_build_and_sync "$DIST_ID"

    echo -e "\n${GREEN}============================================="
    echo -e "  Phase 2 setup complete!"
    echo -e "=============================================${NC}"
    echo
    echo -e "  Live URL   : ${YELLOW}https://$DOMAIN${NC}"
    echo -e "  CF Dist ID : $DIST_ID"
    echo -e "  CF Domain  : $DIST_DOMAIN"
    echo
    echo -e "  ${DARK_GRAY}Re-deploy  : ./setup-phase2.sh"
    echo -e "  Tear down  : ./setup-phase2.sh --teardown${NC}"
    echo
}

# =============================================================================
#  TEARDOWN
# =============================================================================
do_teardown() {
    echo -e "\n${YELLOW}============================================="
    echo -e "  Phase 2 - Teardown"
    echo -e "  Domain : $DOMAIN"
    echo -e "  Bucket : $BUCKET_NAME"
    echo -e "=============================================${NC}"

    load_state

    echo -e "\n  This will remove:"
    [[ "$ROUTE53_RECORD_CREATED" == "true" ]] && echo "    - Route 53 A alias      : $DOMAIN"
    [[ -n "$DIST_ID"             ]]           && echo "    - CloudFront dist        : $DIST_ID"
    [[ "$OAC_CREATED_BY_US" == "true" ]]      && echo "    - CloudFront OAC         : $OAC_ID"
    if [[ "$BUCKET_CREATED_BY_US" == "true" ]]; then
        echo "    - S3 bucket + all objects: $BUCKET_NAME"
    else
        echo -e "    ${YELLOW}- S3 bucket policy only  : $BUCKET_NAME (bucket preserved - it pre-existed)${NC}"
    fi
    echo
    read -rp "  Continue? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "  ${DARK_GRAY}Teardown cancelled.${NC}"
        exit 0
    fi

    # ── 1. Route 53 A alias ────────────────────────────────────────────────────
    write_step "1/5" "Delete Route 53 A alias..."
    if [[ "$ROUTE53_RECORD_CREATED" == "true" && -n "$DIST_DOMAIN" ]]; then
        r53_json=$(jq -n \
            --arg domain "$DOMAIN" \
            --arg cfzone "$CF_ALIAS_ZONE" \
            --arg cfdns  "$DIST_DOMAIN" \
            '{"Changes":[{"Action":"DELETE","ResourceRecordSet":{"Name":$domain,"Type":"A","AliasTarget":{"HostedZoneId":$cfzone,"DNSName":$cfdns,"EvaluateTargetHealth":false}}}]}')
        r53_temp=$(new_temp_json "$r53_json")
        invoke_aws route53 change-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --change-batch "$(file_uri "$r53_temp")" > /dev/null
        rm -f "$r53_temp"
        ROUTE53_RECORD_CREATED="false"
        save_state
        write_ok "Route 53 record deleted."
    else
        write_skipped "Not in state - skipping."
    fi

    # ── 2. Disable + delete CloudFront distribution ────────────────────────────
    write_step "2/5" "Disable + delete CloudFront distribution..."
    if [[ -n "$DIST_ID" ]]; then
        etag=$(aws cloudfront get-distribution-config \
            --id "$DIST_ID" --profile "$AWS_PROFILE" \
            --query ETag --output text)
        config_json=$(aws cloudfront get-distribution-config \
            --id "$DIST_ID" --profile "$AWS_PROFILE" \
            --query DistributionConfig --output json)
        disabled_json=$(echo "$config_json" | jq '.Enabled = false')
        cf_temp=$(new_temp_json "$disabled_json")
        invoke_aws cloudfront update-distribution \
            --id "$DIST_ID" \
            --if-match "$etag" \
            --distribution-config "$(file_uri "$cf_temp")" > /dev/null
        rm -f "$cf_temp"
        write_info "Distribution disabled. Waiting for propagation (~5-15 min)..."
        invoke_aws cloudfront wait distribution-deployed --id "$DIST_ID" > /dev/null
        new_etag=$(aws cloudfront get-distribution-config \
            --id "$DIST_ID" --profile "$AWS_PROFILE" \
            --query ETag --output text)
        invoke_aws cloudfront delete-distribution \
            --id "$DIST_ID" \
            --if-match "$new_etag" > /dev/null
        write_ok "CloudFront distribution deleted."
        DIST_ID=""
        DIST_DOMAIN=""
        save_state
    else
        write_skipped "No distribution in state - skipping."
    fi

    # ── 3. Delete OAC ─────────────────────────────────────────────────────────
    write_step "3/5" "Delete CloudFront OAC..."
    if [[ "$OAC_CREATED_BY_US" == "true" && -n "$OAC_ID" ]]; then
        oac_etag=$(aws cloudfront get-origin-access-control \
            --id "$OAC_ID" --profile "$AWS_PROFILE" \
            --query ETag --output text)
        invoke_aws cloudfront delete-origin-access-control \
            --id "$OAC_ID" \
            --if-match "$oac_etag" > /dev/null
        write_ok "OAC deleted."
        OAC_ID=""
        OAC_CREATED_BY_US="false"
        save_state
    else
        write_skipped "OAC not created by this script - skipping."
    fi

    # ── 4. S3 bucket ──────────────────────────────────────────────────────────
    write_step "4/5" "Clean up S3..."
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
        write_skipped "Bucket '$BUCKET_NAME' not found - skipping."
    elif [[ "$BUCKET_CREATED_BY_US" == "true" ]]; then
        # Versioning is enabled - must delete all versions + delete markers before bucket deletion
        write_info "Deleting all object versions and delete markers..."
        has_more="true"
        while [[ "$has_more" == "true" ]]; do
            versions_json=$(aws s3api list-object-versions \
                --bucket "$BUCKET_NAME" \
                --profile "$AWS_PROFILE" \
                --output json 2>&1)

            delete_payload=$(echo "$versions_json" | jq '{
                Objects: (
                    ([(.Versions       // [])[] | {Key: .Key, VersionId: .VersionId}] +
                     [(.DeleteMarkers  // [])[] | {Key: .Key, VersionId: .VersionId}])
                ),
                Quiet: true
            }')

            count=$(echo "$delete_payload" | jq '.Objects | length')
            if [[ "$count" -eq 0 ]]; then
                has_more="false"
                break
            fi

            del_temp=$(new_temp_json "$delete_payload")
            invoke_aws s3api delete-objects \
                --bucket "$BUCKET_NAME" \
                --delete "$(file_uri "$del_temp")" > /dev/null
            rm -f "$del_temp"

            has_more=$(echo "$versions_json" | jq -r '.IsTruncated // false')
        done
        write_info "All versions deleted. Deleting bucket..."
        invoke_aws s3api delete-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" > /dev/null
        write_ok "Bucket emptied and deleted."
    else
        aws s3api delete-bucket-policy \
            --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null || true
        write_ok "Bucket policy removed (bucket preserved - it pre-existed)."
    fi
    BUCKET_CREATED_BY_US="false"
    save_state

    # ── 5. Remove state file ───────────────────────────────────────────────────
    write_step "5/5" "Removing state file..."
    [[ -f "$STATE_FILE" ]] && rm -f "$STATE_FILE"
    write_ok "State file removed."

    echo -e "\n${GREEN}============================================="
    echo -e "  Phase 2 teardown complete!"
    echo -e "=============================================${NC}"
    echo
}

# ── Entry point ───────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--teardown" ]]; then
    do_teardown
else
    load_state
    if [[ -n "$DIST_ID" ]]; then
        # Infrastructure already exists - re-deploy only
        echo -e "\n${CYAN}============================================="
        echo -e "  Phase 2 - Re-deploy"
        echo -e "  Bucket : $BUCKET_NAME"
        echo -e "  Dist   : $DIST_ID"
        echo -e "=============================================${NC}"
        invoke_build_and_sync "$DIST_ID"
        echo -e "\n  ${GREEN}Re-deploy complete!${NC}"
        echo -e "  ${YELLOW}https://$DOMAIN${NC}"
        echo
    else
        do_setup
    fi
fi
