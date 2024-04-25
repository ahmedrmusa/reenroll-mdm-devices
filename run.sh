#!/bin/bash
#
# Run Jamf MDM reenrollment against all Macs in a subnet
#

set -euo pipefail

SUBNET="${1:-}"
SSH_USER="admin"
SCRIPT="reenroll.sh"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5"

if [[ -z "$SUBNET" ]]; then
  echo "Usage: $0 <subnet>"
  echo "Example: $0 10.0.1.0/24"
  exit 1
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: $SCRIPT not found"
  exit 1
fi

echo "Scanning subnet: $SUBNET"

mapfile -t HOSTS < <(
  nmap -p 22 --open -n "$SUBNET" \
  | awk '/Nmap scan report/ {print $NF}'
)

if [[ "${#HOSTS[@]}" -eq 0 ]]; then
  echo "No SSH hosts found"
  exit 0
fi

echo "Found ${#HOSTS[@]} hosts"

for host in "${HOSTS[@]}"; do
  echo "----- $host -----"

  if ssh $SSH_OPTS "$SSH_USER@$host" "uname" >/dev/null 2>&1; then
    scp $SSH_OPTS "$SCRIPT" "$SSH_USER@$host:/tmp/" >/dev/null

    ssh $SSH_OPTS "$SSH_USER@$host" \
      "sudo bash /tmp/$SCRIPT" \
      && echo "$host: SUCCESS" \
      || echo "$host: FAILED"
  else
    echo "$host: SSH unreachable"
  fi
done
