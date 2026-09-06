#!/bin/sh
# ish-setup — interactive first-run setup wizard for iSH (Alpine Linux, i686).
#
#   sh install.sh              interactive menu
#   sh install.sh --all        full install, no menu
#   sh install.sh --help       usage
#
# Design notes worth knowing before editing:
#
#   * POSIX sh only. iSH's /bin/sh is BusyBox ash; bashisms will not run.
#   * `set -u` is on, `set -e` is deliberately off. Almost every failure in this
#     installer is survivable, and aborting halfway through leaves a worse state
#     than continuing. Failures are collected and reported at the end.
#   * Only three conditions abort: not root, not iSH, no network.
#   * Every step is idempotent. Rerunning is the supported way to retry.

set -u

VERSION="1.0.1"
NO_LOG=0

# Resolve our own directory without letting a stray CDPATH redirect cd.
unset CDPATH 2>/dev/null || true
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
LIB_DIR="$SCRIPT_DIR/lib"
CONFIG_DIR="$SCRIPT_DIR/config"

# --------------------------------------------------------------------------
# Load libraries. log.sh must come first; ui.sh calls into it.
# --------------------------------------------------------------------------
for _lib in log ui ish pkg user zsh summary; do
    if [ ! -r "$LIB_DIR/$_lib.sh" ]; then
        printf 'ish-setup: missing library: %s/%s.sh\n' "$LIB_DIR" "$_lib" >&2
        printf 'Run this script from inside the ish-setup directory.\n' >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    . "$LIB_DIR/$_lib.sh"
done

# --------------------------------------------------------------------------
# Preflight
# --------------------------------------------------------------------------

# usage — print help and exit.
usage() {
    cat <<USAGE
ish-setup $VERSION
First-run setup wizard for iSH on iPhone.

  sh install.sh           interactive menu
  sh install.sh --all     run everything without prompting for the menu
  sh install.sh --help    this message

Run as root, from inside the ish-setup directory.
USAGE
    exit 0
}

# preflight — the only checks allowed to abort the run.
# Returns: 0 to proceed; exits 1 otherwise.
preflight() {
    if ! ish_is_root; then
        printf 'ish-setup: must be run as root.\n' >&2
        printf 'In iSH you are root by default. Try: exit, reopen iSH, rerun.\n' >&2
        exit 1
    fi

    if ! ish_detect; then
        printf 'ish-setup: this does not look like iSH.\n' >&2
        printf 'Expected /proc/ish or an i686 architecture.\n' >&2
        printf 'This installer edits /etc/profile and assumes iSH behaviour;\n' >&2
        printf 'running it elsewhere is not supported. Aborting.\n' >&2
        exit 1
    fi

    # Logging is a convenience, not a prerequisite. If nothing is writable we
    # say so clearly and keep going, because refusing to run is worse than
    # running without a transcript.
    if ! log_init; then
        printf '\nish-setup: could not find a writable place for the log.\n' >&2
        printf 'Tried, in order:\n' >&2
        printf '  $ISH_SETUP_DIR  = %s\n' "${ISH_SETUP_DIR:-(unset)}" >&2
        printf '  $HOME/ish-setup = %s\n' "${HOME:-(HOME unset)}/ish-setup" >&2
        printf '  /root/ish-setup\n  /var/ish-setup\n  /tmp/ish-setup\n' >&2
        printf '\nContinuing without a log or backups.\n' >&2
        printf 'To pick a location yourself, rerun as:\n' >&2
        printf '  ISH_SETUP_DIR=/tmp/ish-setup sh install.sh\n\n' >&2
        NO_LOG=1
    fi
    backup_init || NO_LOG=1
}

# check_network — verified after the banner so the user sees why we are waiting.
check_network() {
    step_start "Checking network"
    if ish_has_network; then
        step_ok
        return 0
    fi
    step_fail "Checking network" "no route to the Alpine mirrors"
    printf '\n'
    ui_error "Network is required to install packages."
    ui_note "Check Wi-Fi or cellular, then rerun."
    exit 1
}

# --------------------------------------------------------------------------
# Steps
# --------------------------------------------------------------------------

# do_packages — repositories, upgrade, then the manifest.
do_packages() {
    ui_heading "Packages"
    pkg_repos_update
    pkg_upgrade
    pkg_install_manifest "$CONFIG_DIR/packages.list"
}

# do_user — account, sudo, login shell.
do_user() {
    ui_heading "Primary user"
    user_prompt_name
    user_create || return 1
    user_set_password
    user_configure_sudo nopasswd
    user_set_shell
}

# do_shell_config — Zinit, the zsh module tree, and verification.
do_shell_config() {
    ui_heading "Shell configuration"
    zsh_deploy_config "$CONFIG_DIR/zsh" || return 1
    zsh_prompt_autocomplete
    zsh_install_zinit
    zsh_warm_plugins
    zsh_verify
}

# do_ish — the /etc/profile launch block.
do_ish() {
    ui_heading "iSH integration"
    ish_configure_autologin "$SETUP_USER"
}

# ensure_user_selected — steps 3 and 4 need SETUP_USER; ask if we skipped step 2.
# Returns: 0 if a usable account is selected.
ensure_user_selected() {
    [ -n "$SETUP_USER" ] && return 0
    user_prompt_name
    if [ "$USER_PREEXISTING" != "1" ]; then
        user_create || return 1
    else
        SETUP_HOME=$(getent passwd "$SETUP_USER" 2>/dev/null | cut -d: -f6)
        [ -z "$SETUP_HOME" ] && SETUP_HOME="/home/$SETUP_USER"
    fi
    return 0
}

# run_all — the full path, in dependency order.
run_all() {
    do_packages
    do_user
    do_shell_config
    do_ish
}

# --------------------------------------------------------------------------
# Menu
# --------------------------------------------------------------------------

main_menu() {
    while :; do
        _choice=$(ask_menu "What would you like to do?" \
            "Full setup (recommended)" \
            "Packages only" \
            "Create the user account only" \
            "Shell configuration only" \
            "Configure iSH auto-launch only" \
            "Show the log" \
            "Quit")

        case "$_choice" in
            1) run_all; return 0 ;;
            2) do_packages; return 0 ;;
            3) do_user; return 0 ;;
            4) ensure_user_selected && do_shell_config; return 0 ;;
            5) ensure_user_selected && do_ish; return 0 ;;
            6)
                printf '\n'
                if [ "$NO_LOG" = "1" ] || [ ! -s "$LOG_FILE" ]; then
                    ui_note "No log is available for this run."
                else
                    tail -n 40 "$LOG_FILE" 2>/dev/null
                fi
                ui_pause
                ;;
            7)
                printf '\nNothing was changed.\n\n'
                exit 0
                ;;
        esac
    done
}

# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

main() {
    _mode=menu
    case "${1:-}" in
        --help|-h) usage ;;
        --all|-a)  _mode=all ;;
        "")        : ;;
        *)
            printf 'ish-setup: unknown option: %s\n' "$1" >&2
            usage
            ;;
    esac

    preflight
    ui_init

    ui_banner "ish-setup $VERSION"
    printf '\n'
    printf ' Turns a fresh iSH install into a\n'
    printf ' configured zsh environment.\n\n'
    printf ' Safe to run more than once.\n'
    printf ' Every change is backed up first.\n'
    if [ "$NO_LOG" = "1" ]; then
        printf '\n %sLog: disabled (nowhere writable)%s\n' "$C_YELLOW" "$C_RESET"
    else
        printf '\n Log: %s\n' "$LOG_FILE"
    fi

    check_network

    if [ "$_mode" = "all" ]; then
        run_all
    else
        main_menu
    fi

    summary_print
    exit 0
}

main "$@"
