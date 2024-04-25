#!/bin/bash
#
# Jamf MDM Re-enrollment
# Supports expired MDM remediation for headless Macs
#
# Requirements:
# - Local admin (sudo)
# - Network connectivity
# - Device assigned to Jamf in ABM OR QuickAdd available
#
# Exit codes:
# 0 = Success
# 1 = Failure
#

set -euo pipefail

JAMF_URL="https://YOURJAMF.jamfcloud.com"
QUICKADD_URL="$JAMF_URL/bin/jamfQuickAdd.pkg"
LOG_TAG="reenroll"

log() {
  logger -t "$LOG_TAG" "$1"
  echo "$1"
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log "ERROR: Must be run as root"
    exit 1
  fi
}

remove_mdm_profile() {
  log "Checking for existing MDM profile"

  local mdm_uuid
  mdm_uuid=$(profiles list 2>/dev/null | awk '/com.apple.mdm/ {print $NF}')

  if [[ -n "$mdm_uuid" ]]; then
    log "Removing MDM profile: $mdm_uuid"
    profiles remove -identifier "$mdm_uuid" || true
  else
    log "No MDM profile present"
  fi
}

remove_jamf_framework() {
  if [[ -x /usr/local/bin/jamf ]]; then
    log "Removing Jamf framework"
    /usr/local/bin/jamf removeFramework || true
  else
    log "Jamf framework not present"
  fi
}

attempt_ade_enrollment() {
  log "Attempting Automated Device Enrollment"
  if profiles renew -type enrollment 2>/dev/null; then
    sleep 10
    if profiles status -type enrollment | grep -q "MDM enrollment: Yes"; then
      log "ADE enrollment successful"
      return 0
    fi
  fi
  log "ADE enrollment failed or unavailable"
  return 1
}

quickadd_enrollment() {
  log "Attempting QuickAdd enrollment"

  local pkg="/tmp/jamfQuickAdd.pkg"
  rm -f "$pkg"

  if ! curl -fsSL "$QUICKADD_URL" -o "$pkg"; then
    log "ERROR: Failed to download QuickAdd"
    return 1
  fi

  if installer -pkg "$pkg" -target /; then
    sleep 10
    if profiles status -type enrollment | grep -q "MDM enrollment: Yes"; then
      log "QuickAdd enrollment successful"
      return 0
    fi
  fi

  log "ERROR: QuickAdd enrollment failed"
  return 1
}

validate() {
  log "Validating enrollment state"

  profiles status -type enrollment
  if [[ -x /usr/local/bin/jamf ]]; then
    /usr/local/bin/jamf checkJSSConnection || true
  fi
}

main() {
  require_root
  log "Starting Jamf MDM reenrollment"

  remove_mdm_profile
  remove_jamf_framework

  if ! attempt_ade_enrollment; then
    quickadd_enrollment
  fi

  validate
  log "Reenrollment process completed"
}

main "$@"
