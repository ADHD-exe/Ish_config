#!/bin/sh
# lib/ui.sh — terminal output for a ~40-column iPhone screen.
#
# Design rules enforced here:
#   * Never print anything wider than UI_WIDTH columns.
#   * Never require a key other than a digit and Return.
#   * Progress rewrites in place on a TTY, falls back to new lines otherwise.
#   * ASCII only, apart from the three status glyphs.
#
# Globals owned by this file:
#   UI_WIDTH   assumed terminal width
#   C_*        colour escapes (empty when output is not a TTY)
#   UI_STEP    label of the step currently in progress

UI_WIDTH=40
UI_STEP=""
G_OK="+"; G_NO="x"; G_RUN="~"

# ui_init — detect colour support and populate the C_* escapes.
# Arguments: none.
ui_init() {
    if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
        C_RESET=$(printf '\033[0m')
        C_YELLOW=$(printf '\033[1;33m')
        C_GREEN=$(printf '\033[1;32m')
        C_RED=$(printf '\033[1;31m')
        C_CYAN=$(printf '\033[1;36m')
        C_DIM=$(printf '\033[2m')
        UI_TTY=1
        # UTF-8 check / cross, built with printf so no literal bytes
        # need to survive editing on the phone.
        G_OK=$(printf '\342\234\223')
        G_NO=$(printf '\342\234\227')
        G_RUN="~"
    else
        C_RESET=""; C_YELLOW=""; C_GREEN=""; C_RED=""; C_CYAN=""; C_DIM=""
        UI_TTY=0
        G_OK="+"; G_NO="x"; G_RUN="~"
    fi
}

# ui_rule — print a horizontal rule at the current width.
ui_rule() {
    printf '%s\n' "$(_ui_repeat '=' "$UI_WIDTH")"
}

# _ui_repeat — repeat a character n times. Arguments: $1 char, $2 count.
_ui_repeat() {
    _c=$1; _n=$2; _out=""
    while [ "$_n" -gt 0 ]; do
        _out="$_out$_c"
        _n=$((_n - 1))
    done
    printf '%s' "$_out"
}

# ui_banner — print the title block. Arguments: $1 title text.
ui_banner() {
    printf '\n'
    ui_rule
    printf '%s %s%s\n' "$C_CYAN" "$1" "$C_RESET"
    ui_rule
}

# ui_heading — print a section heading. Arguments: $1 text.
ui_heading() {
    printf '\n%s%s%s\n' "$C_CYAN" "$1" "$C_RESET"
    log_write INFO "--- $1 ---"
}

# ui_info — print an indented informational line. Arguments: $1..$n text.
ui_info() {
    printf '    %s\n' "$*"
    log_write INFO "$*"
}

# ui_note — print a dimmed secondary line. Arguments: $1..$n text.
ui_note() {
    printf '    %s%s%s\n' "$C_DIM" "$*" "$C_RESET"
    log_write INFO "$*"
}

# ui_warn — print a warning and record it. Arguments: $1..$n text.
ui_warn() {
    printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
    record_warning "$*"
}

# ui_error — print an error line. Arguments: $1..$n text.
ui_error() {
    printf '%s[x]%s %s\n' "$C_RED" "$C_RESET" "$*"
    log_write ERROR "$*"
}

# step_start — announce a step as in progress (yellow).
# The line is left un-terminated on a TTY so step_ok/step_fail can rewrite it.
# Arguments: $1 step label.
step_start() {
    UI_STEP=$1
    log_write INFO "step: $1"
    if [ "$UI_TTY" = "1" ]; then
        printf '%s[%s]%s %s' "$C_YELLOW" "$G_RUN" "$C_RESET" "$1"
    else
        printf '[%s] %s\n' "$G_RUN" "$1"
    fi
}

# step_ok — close the current step as complete (green).
# Arguments: $1 optional label override.
step_ok() {
    _label=${1:-$UI_STEP}
    if [ "$UI_TTY" = "1" ]; then
        printf '\r\033[K%s[%s]%s %s\n' "$C_GREEN" "$G_OK" "$C_RESET" "$_label"
    else
        printf '[%s] %s\n' "$G_OK" "$_label"
    fi
    log_write OK "$_label"
    UI_STEP=""
}

# step_fail — close the current step as failed (red) and record it.
# The run continues; summary.sh reports the failure at the end.
# Arguments: $1 optional label override, $2 optional reason.
step_fail() {
    _label=${1:-$UI_STEP}
    if [ "$UI_TTY" = "1" ]; then
        printf '\r\033[K%s[%s]%s %s\n' "$C_RED" "$G_NO" "$C_RESET" "$_label"
    else
        printf '[%s] %s\n' "$G_NO" "$_label"
    fi
    [ -n "${2:-}" ] && printf '    %s%s%s\n' "$C_DIM" "$2" "$C_RESET"
    record_step_failure "$_label"
    UI_STEP=""
}

# step_progress — rewrite the in-progress line with a counter.
# Used by the package loop: [~] 12/48 (25%) ripgrep
# Arguments: $1 current, $2 total, $3 item label.
step_progress() {
    _pct=$(( $1 * 100 / $2 ))
    if [ "$UI_TTY" = "1" ]; then
        printf '\r\033[K%s[%s]%s %s/%s (%s%%) %s' \
            "$C_YELLOW" "$G_RUN" "$C_RESET" "$1" "$2" "$_pct" "$3"
    fi
}

# step_item_result — print one finished sub-item on its own line.
# Arguments: $1 "ok"|"fail"|"skip", $2 current, $3 total, $4 label.
step_item_result() {
    case $1 in
        ok)   _g="${C_GREEN}[${G_OK}]" ;;
        fail) _g="${C_RED}[${G_NO}]" ;;
        *)    _g="${C_DIM}[-]" ;;
    esac
    if [ "$UI_TTY" = "1" ]; then
        printf '\r\033[K%s%s %s/%s %s\n' "$_g" "$C_RESET" "$2" "$3" "$4"
    else
        printf '%s %s/%s %s\n' "$_g" "$2" "$3" "$4"
    fi
}

# ask — prompt for a free-text answer with a default.
# Arguments: $1 prompt text, $2 default value. Prints: the answer.
ask() {
    printf '\n%s\n' "$1" >&2
    if [ -n "${2:-}" ]; then
        printf '[default: %s]\n> ' "$2" >&2
    else
        printf '> ' >&2
    fi
    read -r _answer || _answer=""
    [ -z "$_answer" ] && _answer=${2:-}
    printf '%s' "$_answer"
}

# ask_yes_no — numbered yes/no question. No y/n typing, no Ctrl keys.
# Arguments: $1 question, $2 default ("yes"|"no"). Returns: 0 for yes, 1 for no.
ask_yes_no() {
    _default=${2:-yes}
    printf '\n%s\n' "$1" >&2
    printf '  1) Yes\n  2) No\n' >&2
    printf '[default: %s]\n> ' "$_default" >&2
    read -r _reply || _reply=""
    case "$_reply" in
        1) return 0 ;;
        2) return 1 ;;
        "") [ "$_default" = "yes" ] && return 0 || return 1 ;;
        *) printf 'Please type 1 or 2.\n' >&2; ask_yes_no "$1" "$_default" ;;
    esac
}

# ask_menu — numbered menu. Every option is one short line, portrait-safe.
# Arguments: $1 title, $2..$n option labels. Prints: the chosen index (1-based).
ask_menu() {
    _title=$1
    shift
    _count=$#
    printf '\n%s%s%s\n' "$C_CYAN" "$_title" "$C_RESET" >&2
    _i=1
    for _opt in "$@"; do
        printf '  %s) %s\n' "$_i" "$_opt" >&2
        _i=$((_i + 1))
    done
    printf '> ' >&2
    read -r _choice || _choice=""
    case "$_choice" in
        ''|*[!0-9]*)
            printf 'Please type a number from 1 to %s.\n' "$_count" >&2
            ask_menu "$_title" "$@"
            return
            ;;
    esac
    if [ "$_choice" -lt 1 ] || [ "$_choice" -gt "$_count" ]; then
        printf 'Please type a number from 1 to %s.\n' "$_count" >&2
        ask_menu "$_title" "$@"
        return
    fi
    printf '%s' "$_choice"
}

# ui_pause — wait for Return so a screen of output can be read before scrolling.
ui_pause() {
    printf '\n%sPress Return to continue.%s\n> ' "$C_DIM" "$C_RESET"
    read -r _ || true
}
