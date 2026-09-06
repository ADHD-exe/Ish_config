#!/bin/sh
# lib/log.sh — logging and non-fatal failure collection.
#
# Every message written by the UI layer is also appended to the log file, with
# ANSI colour stripped. Non-fatal failures accumulate in two space-separated
# lists that summary.sh reads at the end of the run.
#
# Globals owned by this file:
#   LOG_FILE      absolute path to the install log
#   FAILED_STEPS  space-separated list of failed step labels (colons for spaces)
#   FAILED_PKGS   space-separated list of packages that would not install
#   WARN_COUNT    number of warnings emitted

# shellcheck disable=SC2034  # STATE_DIR/LOG_ENABLED are read by other modules
# STATE_DIR holds the log and the backups. It is resolved at runtime rather than
# hardcoded to $HOME, because $HOME is not reliably set in every way iSH can be
# launched, and because a home directory on a mounted iOS Files volume is not
# always writable.
STATE_DIR=""
LOG_FILE=""
LOG_ENABLED=0
FAILED_STEPS=""
FAILED_PKGS=""
WARN_COUNT=0

# _log_try_dir — test whether a directory can actually be written to.
# Creating the directory is not proof: some iSH mounts accept mkdir and then
# refuse the file. Arguments: $1 candidate directory. Returns: 0 if writable.
_log_try_dir() {
    [ -n "$1" ] || return 1
    mkdir -p "$1" 2>/dev/null || return 1
    if : >>"$1/.write-test" 2>/dev/null; then
        rm -f "$1/.write-test" 2>/dev/null
        return 0
    fi
    return 1
}

# log_resolve_dir — pick the first writable location from a candidate list.
# Sets STATE_DIR and LOG_FILE. Returns: 0 if any candidate worked.
log_resolve_dir() {
    for _cand in \
        "${ISH_SETUP_DIR:-}" \
        "${HOME:-}/ish-setup" \
        "/root/ish-setup" \
        "/var/ish-setup" \
        "/tmp/ish-setup"
    do
        case "$_cand" in
            ''|/ish-setup) continue ;;   # skips an unset or empty $HOME
        esac
        if _log_try_dir "$_cand"; then
            STATE_DIR=$_cand
            LOG_FILE="$_cand/install.log"
            return 0
        fi
    done
    # Last resort: run without a log rather than refuse to run at all.
    STATE_DIR=""
    LOG_FILE="/dev/null"
    return 1
}

# log_init — resolve a writable location and stamp a run header.
# Arguments: none. Returns: 0 on success, 1 if no location was writable.
# A failure is NOT fatal; the installer continues with logging disabled.
log_init() {
    log_resolve_dir || return 1
    LOG_ENABLED=1
    {
        printf '\n'
        printf '========================================\n'
        printf 'ish-setup run started %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
        printf 'uname: %s\n' "$(uname -a 2>/dev/null)"
        printf '========================================\n'
    } >>"$LOG_FILE"
    return 0
}

# log_write — append a single line to the log with a severity tag.
# Arguments: $1 severity, $2..$n message text.
log_write() {
    _sev=$1
    shift
    printf '[%s] %-5s %s\n' \
        "$(date '+%H:%M:%S' 2>/dev/null)" "$_sev" "$*" >>"$LOG_FILE" 2>/dev/null
}

# log_cmd — run a command, tee its output to the log, return its exit status.
# Use for anything whose output matters during triage (apk, git, chsh).
# Arguments: $1..$n the command and its arguments.
log_cmd() {
    log_write CMD "$*"
    "$@" >>"$LOG_FILE" 2>&1
    _rc=$?
    [ "$_rc" -ne 0 ] && log_write ERROR "exit $_rc from: $*"
    return "$_rc"
}

# record_step_failure — remember that a named step did not complete.
# The label is stored with spaces replaced by colons so the list stays
# word-splittable in POSIX sh (no arrays available).
# Arguments: $1 human-readable step label.
record_step_failure() {
    _label=$(printf '%s' "$1" | tr ' ' ':')
    FAILED_STEPS="$FAILED_STEPS $_label"
    log_write ERROR "step failed: $1"
}

# record_pkg_failure — remember that a package would not install.
# Arguments: $1 package name.
record_pkg_failure() {
    FAILED_PKGS="$FAILED_PKGS $1"
    log_write ERROR "package failed: $1"
}

# record_warning — bump the warning counter and log the reason.
# Arguments: $1..$n message text.
record_warning() {
    WARN_COUNT=$((WARN_COUNT + 1))
    log_write WARN "$*"
}

# count_words — count space-separated entries in a list variable.
# Arguments: $1 the list string. Prints: the count.
count_words() {
    # shellcheck disable=SC2086
    set -- $1
    printf '%s' "$#"
}
