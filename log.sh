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

LOG_FILE="${LOG_FILE:-$HOME/ish-setup/install.log}"
FAILED_STEPS=""
FAILED_PKGS=""
WARN_COUNT=0

# log_init — create the log directory and stamp a run header.
# Arguments: none. Returns: 0 on success, 1 if the log is not writable.
log_init() {
    _dir=$(dirname "$LOG_FILE")
    mkdir -p "$_dir" 2>/dev/null || return 1
    : >>"$LOG_FILE" 2>/dev/null || return 1
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
