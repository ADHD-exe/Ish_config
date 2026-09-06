#!/bin/sh
# lib/pkg.sh — Alpine package operations.
#
# Packages are installed ONE AT A TIME on purpose. A single `apk add` with 45
# arguments aborts the whole transaction when any one package is unsatisfiable,
# which is a common outcome on i686. Installing individually costs a little more
# time and buys per-package failure isolation.
#
# Globals owned by this file:
#   PKG_TOTAL      packages considered this run
#   PKG_INSTALLED  packages installed or already present
#   PKG_SKIPPED    optional packages that are simply unavailable

PKG_TOTAL=0
PKG_INSTALLED=0
PKG_SKIPPED=0

# pkg_repos_update — refresh the Alpine package index.
# Returns: 0 on success, 1 on failure (run continues either way).
pkg_repos_update() {
    step_start "Updating repositories"
    if log_cmd apk update; then
        step_ok
        return 0
    fi
    step_fail "Updating repositories" "apk update failed; see the log"
    return 1
}

# pkg_upgrade — upgrade all installed packages.
# Returns: 0 on success, 1 on failure.
pkg_upgrade() {
    step_start "Upgrading installed packages"
    if log_cmd apk upgrade; then
        step_ok
        return 0
    fi
    step_fail "Upgrading installed packages" "apk upgrade failed; see the log"
    return 1
}

# pkg_is_installed — test whether a package is already present.
# Arguments: $1 package name. Returns: 0 if installed.
pkg_is_installed() {
    apk info -e "$1" >/dev/null 2>&1
}

# pkg_exists_in_repo — test whether a package exists for this architecture.
# Arguments: $1 package name. Returns: 0 if the repository offers it.
pkg_exists_in_repo() {
    [ -n "$(apk search -x "$1" 2>/dev/null)" ]
}

# pkg_install_one — install a single package idempotently.
# Arguments: $1 package name, $2 state ("R" required or "O" optional).
# Returns: 0 installed or already present, 1 failed, 2 skipped (optional+absent).
pkg_install_one() {
    _name=$1
    _state=$2

    if pkg_is_installed "$_name"; then
        log_write INFO "already installed: $_name"
        return 0
    fi

    # Checking the index first turns the common optional-package miss into a
    # quiet skip rather than a scary red line.
    if ! pkg_exists_in_repo "$_name"; then
        if [ "$_state" = "O" ]; then
            log_write INFO "optional package unavailable on this arch: $_name"
            return 2
        fi
        record_pkg_failure "$_name"
        return 1
    fi

    if log_cmd apk add --no-cache "$_name"; then
        return 0
    fi

    if [ "$_state" = "O" ]; then
        log_write WARN "optional package failed to install: $_name"
        return 2
    fi
    record_pkg_failure "$_name"
    return 1
}

# pkg_install_manifest — walk config/packages.list and install each entry.
# Arguments: $1 path to the manifest.
# Returns: 0 always — package failures are collected, not fatal.
pkg_install_manifest() {
    _manifest=$1

    if [ ! -r "$_manifest" ]; then
        step_start "Installing packages"
        step_fail "Installing packages" "manifest not readable: $_manifest"
        return 0
    fi

    # First pass: count real entries so the percentage is meaningful.
    PKG_TOTAL=$(grep -c -E '^[[:space:]]*[RO][[:space:]]' "$_manifest" 2>/dev/null || printf '0')
    if [ "$PKG_TOTAL" -eq 0 ]; then
        ui_warn "No packages listed in the manifest."
        return 0
    fi

    ui_heading "Installing $PKG_TOTAL packages"
    _n=0

    # Second pass: install. Reading via a here-redirect (not a pipe) keeps the
    # loop in the current shell so the counters survive it.
    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            ''|\#*) continue ;;
        esac
        _state=$(printf '%s' "$_line" | awk '{print $1}')
        _name=$(printf '%s' "$_line" | awk '{print $2}')
        case "$_state" in
            R|O) : ;;
            *) continue ;;
        esac
        [ -z "$_name" ] && continue

        _n=$((_n + 1))
        step_progress "$_n" "$PKG_TOTAL" "$_name"
        pkg_install_one "$_name" "$_state"
        case $? in
            0)
                PKG_INSTALLED=$((PKG_INSTALLED + 1))
                step_item_result ok "$_n" "$PKG_TOTAL" "$_name"
                ;;
            2)
                PKG_SKIPPED=$((PKG_SKIPPED + 1))
                step_item_result skip "$_n" "$PKG_TOTAL" "$_name (not available)"
                ;;
            *)
                step_item_result fail "$_n" "$PKG_TOTAL" "$_name"
                ;;
        esac
    done <"$_manifest"

    printf '\n'
    ui_info "Installed: $PKG_INSTALLED   Skipped: $PKG_SKIPPED   Failed: $(count_words "$FAILED_PKGS")"
    return 0
}

# pkg_have — convenience predicate for the rest of the installer.
# Arguments: $1 command name. Returns: 0 if the executable is on PATH.
pkg_have() {
    command -v "$1" >/dev/null 2>&1
}
