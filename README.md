# Jamf MDM Re-enrollment

Idempotent Bash script for re-enrolling Macs with **expired Jamf MDM profiles**.
Designed for **headless, networked Macs (Mac minis)**.

## What This Solves

- Expired or broken MDM enrollment
- Jamf framework drift
- Headless Mac minis stuck out of compliance
- Environments where Jamf remote commands are no longer available

## Requirements
### On the controlling machine
- macOS or Linux
- `bash`
- `nmap`
- `ssh`, `scp`

### On target Macs
- macOS
- Network connectivity
- SSH enabled
- Local admin access (sudo)
- Device assigned to Jamf in **Apple Business Manager**

## Configuration

Edit `reenroll.sh` and set your Jamf URL:

```bash
JAMF_URL="https://YOURJAMF.jamfcloud.com"
```

## Usage
```bash
chmod +x run.sh reenroll.sh
./run.sh 10.0.1.0/24
```

## What this does:

- Scans the subnet for hosts with SSH (port 22)

- Copies the reenrollment script

- Executes it with sudo

- Reports success/failure per host

## Improvements
Replace the loop with GNU parallel:

``` bash
parallel -j 10 ssh "$SSH_USER@{}" \
  "sudo bash /tmp/jamf-mdm-reenroll.sh" ::: "${HOSTS[@]}"
```

## Logging
Each Mac logs locally via logger: 

`tag: jamf-mdm-reenroll`

View with:
``` bash
log show --predicate 'process == "logger"' --last 1h
```


## When This Will Not Work
- Device removed from ABM
- Activation Lock enabled
- No local admin access
- MDM profile is non-removable

In those cases, erase + ABM reassignment is required.

---