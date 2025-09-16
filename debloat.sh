#!/usr/bin/env bash
# DISCLAIMER: This tool is provided as-is, without warranties.
# You accept all risks. The author(s) are not responsible for any damage,
# data loss, boot issues, or consequences. Not affiliated with Xiaomi/POCO/Redmi.

set -euo pipefail

# Universal HyperOS debloat via ADB (no root).
# - Profiles: safe | optional | all (safe+optional)
# - Dry run: just prints what would be done
# - Revert: tries to enable or install-existing for previously touched packages
#
# Device-agnostic: Only handles packages that actually exist on the device.
# Protects critical packages (updater, launcher, security, systemui, settings, play services, play store, camera, theme manager).
# Requires: USB debugging enabled. If you see SecurityException, also enable "USB debugging (Security settings)".
#
# Logs & backups:
# - Logs: debloat-YYYY-MM-DD_HHMMSS.log
# - Backup: packages-backup-YYYY-MM-DD.txt (pm list packages -f)

ADB_BIN="${ADB_BIN:-adb}"
PROFILE="safe"
DRYRUN=false
REVERT=false
LIST_DIR="${LIST_DIR:-device-profiles}"

timestamp() { date +"%Y-%m-%d_%H%M%S"; }
logfile="debloat-$(timestamp).log"

usage() {
  cat <<EOF
Usage:
  $0 [--profile safe|optional|all] [--dry-run] [--revert]

Options:
  --profile <p>   Profile: safe (default), optional, or all (safe+optional)
  --dry-run       Show what would be changed, do nothing
  --revert        Try to restore (enable/install-existing) packages from profiles

Env:
  ADB_BIN=<path to adb>     default: adb in PATH
  LIST_DIR=<profiles dir>   default: device-profiles

Examples:
  $0 --profile safe
  $0 --profile optional
  $0 --profile all
  $0 --revert
EOF
}

# Protected packages: do not touch
PROTECT_REGEX='(com\.xiaomi\.updater|com\.miui\.home|com\.miui\.securitycenter|com\.android\.systemui|com\.android\.settings|com\.google\.android\.gms|com\.android\.vending|com\.google\.android\.gsf|com\.android\.camera|com\.android\.thememanager|com\.xiaomi\.securitycore)'

profile_list_files() {
  local -a files=()
  case "${PROFILE}" in
    safe) files+=("${LIST_DIR}/hyperos-safe.txt");;
    optional) files+=("${LIST_DIR}/hyperos-optional.txt");;
    all) files+=("${LIST_DIR}/hyperos-safe.txt" "${LIST_DIR}/hyperos-optional.txt");;
    *) echo "Unknown profile: ${PROFILE}" >&2; exit 1;;
  esac
  printf "%s\n" "${files[@]}"
}

need_device() {
  if ! ${ADB_BIN} get-state 1>/dev/null 2>&1; then
    echo "✗ ADB cannot see a device. Plug in USB and enable USB debugging." | tee -a "${logfile}"
    exit 1
  fi
}

backup_packages() {
  local fn
  fn="packages-backup-$(date +%F).txt"
  echo "📦 Creating package backup list: ${fn}" | tee -a "${logfile}"
  ${ADB_BIN} shell "pm list packages -f" | sed 's/^package://g' > "${fn}"
}

pkg_exists() {
  local pkg="$1"
  ${ADB_BIN} shell "cmd package list packages ${pkg}" >/dev/null 2>&1
}

disable_pkg() {
  local pkg="$1"

  if [[ -z "${pkg}" ]] || [[ "${pkg}" == \#* ]]; then return; fi  # skip comments/empty
  echo -n "→ ${pkg} … " | tee -a "${logfile}"

  if [[ "${pkg}" =~ ${PROTECT_REGEX} ]]; then
    echo "SKIP (protected)" | tee -a "${logfile}"
    return
  fi

  if ! ${ADB_BIN} shell "cmd package list packages ${pkg} | grep -q ${pkg}"; then
    echo "not present" | tee -a "${logfile}"
    return
  fi

  if ${DRYRUN}; then
    echo "would disable/uninstall-user0" | tee -a "${logfile}"
    return
  fi

  # Try disable first (reversible)
  if ${ADB_BIN} shell "pm disable-user --user 0 ${pkg}" >/dev/null 2>&1; then
    echo "disabled" | tee -a "${logfile}"
    return
  fi

  # Fallback uninstall for user 0 (still reversible via install-existing)
  if ${ADB_BIN} shell "pm uninstall -k --user 0 ${pkg}" >/dev/null 2>&1; then
    echo "uninstalled for user 0" | tee -a "${logfile}"
    return
  fi

  echo "FAILED (maybe protected by vendor)" | tee -a "${logfile}"
}

enable_pkg() {
  local pkg="$1"
  if [[ -z "${pkg}" ]] || [[ "${pkg}" == \#* ]]; then return; fi  # skip comments/empty
  echo -n "↩ ${pkg} … " | tee -a "${logfile}"

  if ${DRYRUN}; then
    echo "would enable/install-existing" | tee -a "${logfile}"
    return
  fi

  # Try enabling (if it was disabled)
  if ${ADB_BIN} shell "pm enable --user 0 ${pkg}" >/dev/null 2>&1; then
    echo "enabled" | tee -a "${logfile}"
    return
  fi
  # Try install-existing (if it was uninstalled for user 0)
  if ${ADB_BIN} shell "cmd package install-existing --user 0 ${pkg}" >/dev/null 2>&1; then
    echo "installed-existing" | tee -a "${logfile}"
    return
  fi
  # Final try
  if ${ADB_BIN} shell "pm enable --user 0 ${pkg}" >/dev/null 2>&1; then
    echo "enabled" | tee -a "${logfile}"
    return
  fi

  echo "FAILED (package may not exist on ROM)" | tee -a "${logfile}"
}

main() {
  # Args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile) PROFILE="${2:-safe}"; shift 2;;
      --dry-run) DRYRUN=true; shift;;
      --revert)  REVERT=true; shift;;
      -h|--help) usage; exit 0;;
      *) echo "Unknown option: $1"; usage; exit 1;;
    esac
  done

  need_device
  echo "📝 Logging to ${logfile}"
  backup_packages

  # Collect profile files
  mapfile -t files < <(profile_list_files)

  if ${REVERT}; then
    echo "↩ Reverting packages from profiles (${PROFILE})…" | tee -a "${logfile}"
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || { echo "Profile file missing: $f" | tee -a "${logfile}"; continue; }
      while IFS= read -r pkg; do
        enable_pkg "${pkg}"
      done < <(grep -vE '^\s*(#|$)' "$f")
    done
    echo "✔ Revert finished." | tee -a "${logfile}"
    exit 0
  fi

  echo "🧹 Applying debloat profile: ${PROFILE}" | tee -a "${logfile}"
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || { echo "Profile file missing: $f" | tee -a "${logfile}"; continue; }
    while IFS= read -r pkg; do
      disable_pkg "${pkg}"
    done < <(grep -vE '^\s*(#|$)' "$f")
  done
  echo "✔ Done. A reboot is recommended." | tee -a "${logfile}"
}

main "$@"
