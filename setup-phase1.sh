#!/usr/bin/env bash
# Phase 1 - Public S3 Static Site: setup or teardown.
#
# Usage:
#   ./setup-phase1.sh             # Setup
#   ./setup-phase1.sh --teardown  # Teardown

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BUCKET_NAME="master-ostaddevops-site"
REGION="ap-south-1"
AWS_PROFILE="sarowar-ostad"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_FILE="$SCRIPT_DIR/infra/bucket-policy-phase1.json"
STATE_FILE="$SCRIPT_DIR/.phase1-state.json"
SITE_DIR="$SCRIPT_DIR/master-site"
WEBSITE_URL="http://$BUCKET_NAME.s3-website.$REGION.amazonaws.com"

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
RED='\033[0;31m'
DARK_GRAY='\033[0;90m'
NC='\033[0m'

write_step()    { echo -e "\n${CYAN}[$1] $2${NC}"; }
write_ok()      { echo -e "    ${GREEN}[OK] $1${NC}"; }
write_skipped() { echo -e "    ${YELLOW}[SKIP] $1${NC}"; }
write_fail()    { echo -e "    ${RED}[FAIL] $1${NC}"; }

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

# ── State helpers ─────────────────────────────────────────────────────────────
BUCKET_CREATED_BY_US="false"

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        BUCKET_CREATED_BY_US=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(str(d.get('BucketCreatedByUs',False)).lower())" 2>/dev/null || echo "false")
    else
        BUCKET_CREATED_BY_US="false"
    fi
}

save_state() {
    local val
    val=$([ "$BUCKET_CREATED_BY_US" = "true" ] && echo "true" || echo "false")
    printf '{"BucketCreatedByUs": %s}\n' "$val" > "$STATE_FILE"
}

# ── Setup ─────────────────────────────────────────────────────────────────────
do_setup() {
    echo -e "\n${CYAN}======================================"
    echo -e "  Phase 1 - Public S3 Setup"
    echo -e "  Bucket : $BUCKET_NAME"
    echo -e "  Region : $REGION"
    echo -e "======================================${NC}"

    load_state

    # Step 1: Create bucket
    write_step "1/5" "Create S3 bucket..."
    if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
        write_skipped "Bucket '$BUCKET_NAME' already exists - skipping creation."
        BUCKET_CREATED_BY_US="false"
        save_state
    else
        invoke_aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration "LocationConstraint=$REGION" > /dev/null
        BUCKET_CREATED_BY_US="true"
        save_state
        write_ok "Bucket created."
    fi

    # Step 2: Remove Block Public Access
    write_step "2/5" "Removing Block Public Access..."
    invoke_aws s3api delete-public-access-block --bucket "$BUCKET_NAME" > /dev/null
    write_ok "Block Public Access removed."

    # Step 3: Enable static website hosting
    write_step "3/5" "Enabling static website hosting..."
    invoke_aws s3 website "s3://$BUCKET_NAME/" \
        --index-document index.html \
        --error-document index.html > /dev/null
    write_ok "Static website hosting enabled."

    # Step 4: Apply public read policy
    write_step "4/5" "Applying public-read bucket policy..."
    if [[ ! -f "$POLICY_FILE" ]]; then
        write_fail "Policy file not found: $POLICY_FILE"
        exit 1
    fi
    invoke_aws s3api put-bucket-policy \
        --bucket "$BUCKET_NAME" \
        --policy "$(file_uri "$POLICY_FILE")" > /dev/null
    write_ok "Bucket policy applied."

    # Step 5: Build & deploy
    write_step "5/5" "Building and deploying site..."
    pushd "$SITE_DIR" > /dev/null
    if [[ ! -d "node_modules" ]]; then
        echo -e "    ${YELLOW}node_modules not found - running npm install...${NC}"
        npm install
    fi
    npm run build
    popd > /dev/null
    write_ok "Build complete."

    invoke_aws s3 sync "$SITE_DIR/dist" "s3://$BUCKET_NAME" --delete > /dev/null
    write_ok "Files synced to S3."

    echo -e "\n${GREEN}======================================"
    echo -e "  Phase 1 setup complete!"
    echo -e "======================================${NC}"
    echo
    echo -e "  Test URL:"
    echo -e "  ${YELLOW}$WEBSITE_URL${NC}"
    echo
    echo -e "  ${DARK_GRAY}To tear down: ./setup-phase1.sh --teardown${NC}"
    echo
}

# ── Teardown ──────────────────────────────────────────────────────────────────
do_teardown() {
    echo -e "\n${YELLOW}======================================"
    echo -e "  Phase 1 - Teardown"
    echo -e "  Bucket : $BUCKET_NAME"
    echo -e "  Region : $REGION"
    echo -e "======================================${NC}"

    load_state

    echo
    if [[ "$BUCKET_CREATED_BY_US" == "true" ]]; then
        echo "  This will:"
        echo "    - Delete ALL objects in '$BUCKET_NAME'"
        echo "    - Delete the bucket itself"
    else
        echo "  This will:"
        echo "    - Remove the bucket policy"
        echo "    - Disable static website hosting"
        echo "    - Restore Block Public Access"
        echo -e "    ${YELLOW}- The bucket will NOT be deleted (it pre-existed)${NC}"
    fi
    echo
    read -rp "  Continue? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "  ${DARK_GRAY}Teardown cancelled.${NC}"
        exit 0
    fi

    # Check bucket exists
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
        write_skipped "Bucket '$BUCKET_NAME' does not exist - nothing to tear down."
        [[ -f "$STATE_FILE" ]] && rm -f "$STATE_FILE"
        exit 0
    fi

    if [[ "$BUCKET_CREATED_BY_US" == "true" ]]; then
        write_step "1/4" "Deleting all objects from bucket..."
        invoke_aws s3 rm "s3://$BUCKET_NAME" --recursive > /dev/null
        write_ok "All objects deleted."

        write_step "2/4" "Deleting bucket policy..."
        aws s3api delete-bucket-policy --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null || true
        write_ok "Bucket policy removed (or was already absent)."

        write_step "3/4" "Disabling static website hosting..."
        aws s3api delete-bucket-website --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null || true
        write_ok "Static website hosting disabled (or was already disabled)."

        write_step "4/4" "Deleting bucket '$BUCKET_NAME'..."
        invoke_aws s3api delete-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" > /dev/null
        write_ok "Bucket deleted."
    else
        write_step "1/3" "Deleting bucket policy..."
        aws s3api delete-bucket-policy --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null || true
        write_ok "Bucket policy removed."

        write_step "2/3" "Disabling static website hosting..."
        aws s3api delete-bucket-website --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null || true
        write_ok "Static website hosting disabled."

        write_step "3/3" "Restoring Block Public Access..."
        invoke_aws s3api put-public-access-block \
            --bucket "$BUCKET_NAME" \
            --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" > /dev/null
        write_ok "Block Public Access restored."

        echo
        echo -e "  ${YELLOW}Bucket '$BUCKET_NAME' preserved (pre-existed before Phase 1 setup).${NC}"
    fi

    [[ -f "$STATE_FILE" ]] && rm -f "$STATE_FILE"

    echo -e "\n${GREEN}======================================"
    echo -e "  Phase 1 teardown complete!"
    echo -e "======================================${NC}"
    echo
}

# ── Entry point ───────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--teardown" ]]; then
    do_teardown
else
    do_setup
fi
