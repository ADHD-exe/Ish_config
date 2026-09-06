#!/bin/sh
# lib/summary.sh — the closing report.
#
# Label above value, never side by side: a two-column layout wraps into
# unreadable ribbons at 40 characters.

# _field — print one label/value pair. Arguments: $1 label, $2 value.
_field() {
    printf '\n%s%s:%s\n  %s\n' "$C_CYAN" "$1" "$C_RESET" "$2"
}

# _field_status — like _field but colours the value by outcome.
# Arguments: $1 label, $2 value, $3 "ok"|"bad"|"warn".
_field_status() {
    case $3 in
        ok)   _c=$C_GREEN ;;
        bad)  _c=$C_RED ;;
        *)    _c=$C_YELLOW ;;
    esac
    printf '\n%s%s:%s\n  %s%s%s\n' "$C_CYAN" "$1" "$C_RESET" "$_c" "$2" "$C_RESET"
}

# summary_print — render the full completion report.
summary_print() {
    _failed_pkg_count=$(count_words "$FAILED_PKGS")
    _failed_step_count=$(count_words "$FAILED_STEPS")

    printf '\n'
    ui_rule
    if [ "$_failed_step_count" -eq 0 ] && [ "$_failed_pkg_count" -eq 0 ]; then
        printf ' %sInstallation Complete%s\n' "$C_GREEN" "$C_RESET"
    else
        printf ' %sInstallation Complete (with issues)%s\n' "$C_YELLOW" "$C_RESET"
    fi
    ui_rule

    _field "Primary User" "${SETUP_USER:-none}"
    _field "Home Directory" "${SETUP_HOME:-none}"

    case "${SETUP_SHELL:-}" in
        *zsh) _field_status "Default Shell" "zsh" ok ;;
        "")   _field_status "Default Shell" "unchanged" bad ;;
        *)    _field_status "Default Shell" "$SETUP_SHELL" warn ;;
    esac

    if pkg_have zsh; then
        _field_status "Zsh" "$(zsh --version 2>/dev/null | cut -d' ' -f2)" ok
    else
        _field_status "Zsh" "not installed" bad
    fi

    case "$ZINIT_STATUS" in
        installed) _field_status "Zinit" "installed" ok ;;
        present)   _field_status "Zinit" "already present" ok ;;
        failed)    _field_status "Zinit" "failed" bad ;;
        *)         _field_status "Zinit" "skipped" warn ;;
    esac

    if pkg_have starship; then
        _field_status "Prompt" "starship" ok
    else
        _field_status "Prompt" "built-in zsh (starship unavailable)" warn
    fi

    _field "Packages Installed" "$PKG_INSTALLED"
    if [ "$PKG_SKIPPED" -gt 0 ]; then
        _field_status "Packages Unavailable" "$PKG_SKIPPED (optional)" warn
    fi

    if [ "$_failed_pkg_count" -eq 0 ]; then
        _field_status "Packages Failed" "0" ok
    else
        _field_status "Packages Failed" "$_failed_pkg_count" bad
        for _p in $FAILED_PKGS; do
            printf '    - %s\n' "$_p"
        done
    fi

    _field "Configuration Source" "local templates (config/zsh)"

    case "$ZSH_CFG_STATUS" in
        created) _field_status "Configuration" "created" ok ;;
        updated) _field_status "Configuration" "updated" ok ;;
        kept)    _field_status "Configuration" "kept existing" warn ;;
        *)       _field_status "Configuration" "failed" bad ;;
    esac

    if [ "$ISH_CONFIGURED" = "1" ]; then
        _field_status "iSH Auto-launch" "enabled for $SETUP_USER" ok
    else
        _field_status "iSH Auto-launch" "not configured" warn
    fi

    [ -n "$BACKUP_DIR" ] && _field "Backups" "$BACKUP_DIR"
    _field "Log" "$LOG_FILE"

    if [ "$_failed_step_count" -gt 0 ]; then
        printf '\n%sSteps that did not complete:%s\n' "$C_RED" "$C_RESET"
        for _s in $FAILED_STEPS; do
            printf '  - %s\n' "$(printf '%s' "$_s" | tr ':' ' ')"
        done
        printf '\n  Rerun this installer to retry. It is\n'
        printf '  safe to run as many times as you like.\n'
    fi

    if [ "$WARN_COUNT" -gt 0 ]; then
        printf '\n%s%s warning(s) recorded in the log.%s\n' \
            "$C_YELLOW" "$WARN_COUNT" "$C_RESET"
    fi

    printf '\n'
    ui_rule
    printf '\n'
    if [ "$ISH_CONFIGURED" = "1" ]; then
        printf ' Close and reopen iSH to start using\n'
        printf ' your new environment.\n\n'
        printf ' To get a root shell again:\n'
        printf '   sudo touch %s\n' "$ISH_DISABLE_FILE"
    else
        printf ' Run:  su - %s\n' "$SETUP_USER"
        printf ' to try the new environment.\n'
    fi
    printf '\n'

    log_write INFO "summary: installed=$PKG_INSTALLED failed=$_failed_pkg_count steps_failed=$_failed_step_count warnings=$WARN_COUNT"
}
