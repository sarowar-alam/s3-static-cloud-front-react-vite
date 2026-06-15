#!/usr/bin/env bash
# certbot-import.sh — Issue/renew a Let's Encrypt cert via DNS-Route53 and
# import (or update) it in AWS ACM in any region.
#
# Usage:
#   ./certbot-import.sh -d DOMAIN -e EMAIL [-r REGION] [-p AWS_PROFILE]
#
# Examples:
#   ./certbot-import.sh -d master.ostaddevops.click -e sarowar@hotmail.com -p sarowar-ostad
#   ./certbot-import.sh -d api.example.com -e admin@example.com -r ap-southeast-1 -p my-profile
#
# Requirements (run Git Bash as Administrator):
#   - certbot               pip install certbot certbot-dns-route53
#   - aws cli v2            https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
#   - IAM permissions:      route53:ChangeResourceRecordSets, route53:ListHostedZones,
#                           route53:GetChange, acm:ImportCertificate, acm:ListCertificates,
#                           acm:DescribeCertificate

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
  $(basename "$0") -d DOMAIN -e EMAIL [-r REGION] [-p AWS_PROFILE]

${BOLD}Options:${RESET}
  -d DOMAIN       Domain name for the certificate  (required)
  -e EMAIL        Email address for Let's Encrypt   (required)
  -r REGION       AWS region to import into         (default: us-east-1)
  -p PROFILE      AWS named profile                 (default: default)
  -h              Show this help

${BOLD}Examples:${RESET}
  $(basename "$0") -d master.ostaddevops.click -e sarowar@hotmail.com -p sarowar-ostad
  $(basename "$0") -d api.example.com -e admin@example.com -r ap-southeast-1 -p prod
EOF
  exit 0
}

# ── Defaults ──────────────────────────────────────────────────────────────────
DOMAIN=""
EMAIL=""
REGION="us-east-1"
PROFILE="sarowar-ostad"

# ── Parse flags ───────────────────────────────────────────────────────────────
while getopts ":d:e:r:p:h" opt; do
  case $opt in
    d) DOMAIN="$OPTARG" ;;
    e) EMAIL="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    p) PROFILE="$OPTARG" ;;
    h) usage ;;
    :) die "Option -$OPTARG requires an argument. Run with -h for help." ;;
    \?) die "Unknown option: -$OPTARG. Run with -h for help." ;;
  esac
done

# ── Validate required args ────────────────────────────────────────────────────
[[ -z "$DOMAIN" ]] && die "-d DOMAIN is required. Run with -h for help."
[[ -z "$EMAIL"  ]] && die "-e EMAIL is required. Run with -h for help."

# ── Prerequisite checks ───────────────────────────────────────────────────────
info "Checking prerequisites..."

command -v certbot &>/dev/null \
  || die "certbot not found. Install with: pip install certbot certbot-dns-route53"

command -v aws &>/dev/null \
  || die "aws CLI not found. Install from https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"

info "Verifying AWS profile '${PROFILE}' in region '${REGION}'..."
if ! aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" \
     --output text --query 'Account' &>/dev/null; then
  die "AWS profile '${PROFILE}' failed to authenticate. Check your credentials with:\n  aws sts get-caller-identity --profile ${PROFILE}"
fi
success "AWS profile OK."

# ── Certbot: issue or renew ───────────────────────────────────────────────────
echo ""
info "Running Certbot for domain: ${BOLD}${DOMAIN}${RESET}"
info "Certbot uses AWS_PROFILE=${PROFILE} for the Route 53 DNS challenge."

export AWS_PROFILE="$PROFILE"

if ! certbot certonly \
       --dns-route53 \
       --non-interactive \
       --agree-tos \
       --email "$EMAIL" \
       -d "$DOMAIN"; then
  CERTBOT_LOG="C:/Certbot/log/letsencrypt.log"
  die "Certbot failed. Check the log at: ${CERTBOT_LOG}"
fi

success "Certbot completed successfully."

# ── Locate cert files (Windows path for AWS CLI) ──────────────────────────────
CERT_WIN_DIR="C:/Certbot/live/${DOMAIN}"
CERT_PEM="${CERT_WIN_DIR}/cert.pem"
PRIVKEY_PEM="${CERT_WIN_DIR}/privkey.pem"
CHAIN_PEM="${CERT_WIN_DIR}/chain.pem"

# Verify using bash path
CERT_BASH_DIR="/c/Certbot/live/${DOMAIN}"
for f in cert.pem privkey.pem chain.pem; do
  [[ -f "${CERT_BASH_DIR}/${f}" ]] \
    || die "Expected cert file not found: ${CERT_BASH_DIR}/${f}\nCertbot may have placed files elsewhere — check C:\\Certbot\\live\\"
done

success "All cert files verified at: C:\\Certbot\\live\\${DOMAIN}\\"

# ── Check for existing ACM certificate ───────────────────────────────────────
echo ""
info "Checking for existing ACM certificate for '${DOMAIN}' in region '${REGION}'..."

EXISTING_ARN=$(aws acm list-certificates \
  --region "$REGION" \
  --profile "$PROFILE" \
  --no-paginate \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" \
  --output text 2>/dev/null)
# Treat "None" (no match) as empty
[[ "$EXISTING_ARN" == "None" ]] && EXISTING_ARN=""

# ── Import or update ──────────────────────────────────────────────────────────
echo ""
if [[ -n "$EXISTING_ARN" && "$EXISTING_ARN" != "None" ]]; then
  info "Existing certificate found: ${EXISTING_ARN}"
  info "Re-importing to update the certificate (ARN preserved, CloudFront picks up automatically)..."
  ACTION="renewed"

  RESULT=$(aws acm import-certificate \
    --certificate-arn "$EXISTING_ARN" \
    --certificate     "fileb://${CERT_PEM}" \
    --private-key     "fileb://${PRIVKEY_PEM}" \
    --certificate-chain "fileb://${CHAIN_PEM}" \
    --region  "$REGION" \
    --profile "$PROFILE" \
    --output text \
    --query  'CertificateArn' 2>&1) \
    || die "ACM re-import failed:\n${RESULT}"

  CERT_ARN="$EXISTING_ARN"
else
  info "No existing certificate found. Performing fresh import..."
  ACTION="imported"

  RESULT=$(aws acm import-certificate \
    --certificate     "fileb://${CERT_PEM}" \
    --private-key     "fileb://${PRIVKEY_PEM}" \
    --certificate-chain "fileb://${CHAIN_PEM}" \
    --region  "$REGION" \
    --profile "$PROFILE" \
    --output json 2>&1) \
    || die "ACM import failed:\n${RESULT}"

  CERT_ARN=$(echo "$RESULT" | grep -o '"CertificateArn": *"[^"]*"' | cut -d'"' -f4)
  [[ -z "$CERT_ARN" ]] && die "Could not parse CertificateArn from ACM response:\n${RESULT}"
fi

# ── Fetch expiry date ─────────────────────────────────────────────────────────
EXPIRY=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region  "$REGION" \
  --profile "$PROFILE" \
  --query   'Certificate.NotAfter' \
  --output  text 2>/dev/null || echo "unavailable")

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  Certificate ${ACTION} successfully!${RESET}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}CertificateArn${RESET}  : ${CERT_ARN}"
echo -e "  ${BOLD}Domain         ${RESET}  : ${DOMAIN}"
echo -e "  ${BOLD}Region         ${RESET}  : ${REGION}"
echo -e "  ${BOLD}AWS Profile    ${RESET}  : ${PROFILE}"
echo -e "  ${BOLD}Expires        ${RESET}  : ${EXPIRY}"
echo -e "  ${BOLD}Action         ${RESET}  : ${ACTION}"
echo ""
echo -e "  ${YELLOW}Save the CertificateArn above — you need it for CloudFront.${RESET}"
echo ""
