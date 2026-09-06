#!/bin/sh
# lib/user.sh — primary user account creation and privilege setup.
#
# shellcheck disable=SC2034  # globals below are read by other modules
# Globals owned by this file:
#   SETUP_USER       chosen username
#   SETUP_HOME       that user's home directory
#   SETUP_SHELL      absolute path to the login shell actually set
#   USER_PREEXISTING 1 when the account already existed before this run

SETUP_USER=""
SETUP_HOME=""
SETUP_SHELL=""
USER_PREEXISTING=0

# user_name_is_valid — validate against the portable POSIX username rules.
# Arguments: $1 candidate name. Returns: 0 if acceptable.
user_name_is_valid() {
    case "$1" in
        ''|*[!a-z0-9_-]*) return 1 ;;
    esac
    case "$1" in
        [a-z_]*) : ;;
        *) return 1 ;;
    esac
    [ "${#1}" -le 32 ] || return 1
    return 0
}

# user_name_is_reserved — reject system accounts that already own a uid.
# Arguments: $1 candidate name. Returns: 0 if reserved.
user_name_is_reserved() {
    case "$1" in
        root|bin|daemon|adm|lp|sync|shutdown|halt|mail|news|uucp|operator|man|\
        postmaster|cron|ftp|sshd|at|squid|xfs|games|cyrus|vpopmail|ntp|smmsp|\
        guest|nobody)
            return 0 ;;
    esac
    return 1
}

# user_prompt_name — ask for the primary username until a valid one is given.
# Prints nothing; sets SETUP_USER.
user_prompt_name() {
    while :; do
        _candidate=$(ask "Username for your primary account:" "")
        _candidate=$(printf '%s' "$_candidate" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

        if ! user_name_is_valid "$_candidate"; then
            ui_error "Invalid name."
            ui_note "Use a-z, 0-9, _ and -, starting with a"
            ui_note "letter or underscore. Max 32 characters."
            continue
        fi
        if user_name_is_reserved "$_candidate"; then
            ui_error "'$_candidate' is a reserved system account."
            continue
        fi
        if id "$_candidate" >/dev/null 2>&1; then
            if ask_yes_no "'$_candidate' already exists. Use it anyway?" "yes"; then
                USER_PREEXISTING=1
                SETUP_USER=$_candidate
                return 0
            fi
            continue
        fi
        if ask_yes_no "Create the account '$_candidate'?" "yes"; then
            SETUP_USER=$_candidate
            return 0
        fi
    done
}

# user_create — create the account with a home directory.
# Uses adduser (BusyBox and shadow both provide a compatible enough interface).
# Returns: 0 on success or when the account already exists.
user_create() {
    SETUP_HOME="/home/$SETUP_USER"

    if [ "$USER_PREEXISTING" = "1" ]; then
        SETUP_HOME=$(getent passwd "$SETUP_USER" 2>/dev/null | cut -d: -f6)
        [ -z "$SETUP_HOME" ] && SETUP_HOME="/home/$SETUP_USER"
        step_start "Creating user"
        step_ok "Creating user (already exists)"
    else
        step_start "Creating user"
        if log_cmd adduser -D -h "$SETUP_HOME" -s /bin/sh "$SETUP_USER"; then
            step_ok
        else
            step_fail "Creating user" "adduser failed; see the log"
            return 1
        fi
    fi

    # The home directory can be missing even when the account exists, e.g. if a
    # previous run was interrupted or the user was created with -H.
    if [ ! -d "$SETUP_HOME" ]; then
        mkdir -p "$SETUP_HOME" 2>/dev/null
        chown "$SETUP_USER:$SETUP_USER" "$SETUP_HOME" 2>/dev/null
        chmod 700 "$SETUP_HOME" 2>/dev/null
    fi
    return 0
}

# user_set_password — optionally set a login password.
# A phone is already behind a device passcode, so this is offered, not forced.
user_set_password() {
    if ask_yes_no "Set a password for '$SETUP_USER'? (Not required on iSH.)" "no"; then
        step_start "Setting password"
        if passwd "$SETUP_USER"; then
            step_ok
        else
            step_fail "Setting password" "passwd failed; the account stays passwordless"
        fi
    else
        ui_note "Skipped. sudo will be configured passwordless."
    fi
}

# user_configure_sudo — put the account in wheel and grant sudo.
# Writes a dedicated drop-in rather than editing /etc/sudoers, so a rerun is a
# plain overwrite and nothing else in the file can be damaged.
# Arguments: $1 "nopasswd" or "passwd".
# Returns: 0 on success.
user_configure_sudo() {
    _mode=${1:-nopasswd}
    step_start "Configuring sudo"

    if ! pkg_have sudo; then
        step_fail "Configuring sudo" "sudo is not installed"
        return 1
    fi

    log_cmd addgroup "$SETUP_USER" wheel || \
        log_cmd adduser "$SETUP_USER" wheel || true

    mkdir -p /etc/sudoers.d 2>/dev/null
    _dropin=/etc/sudoers.d/10-ish-setup-wheel
    backup_file "$_dropin"

    if [ "$_mode" = "nopasswd" ]; then
        printf '%%wheel ALL=(ALL) NOPASSWD: ALL\n' >"$_dropin"
    else
        printf '%%wheel ALL=(ALL) ALL\n' >"$_dropin"
    fi
    chmod 0440 "$_dropin" 2>/dev/null

    # visudo -c validates the whole sudoers tree; a malformed drop-in would lock
    # sudo out entirely, so remove it rather than ship it broken.
    if pkg_have visudo && ! visudo -c >/dev/null 2>&1; then
        rm -f "$_dropin"
        step_fail "Configuring sudo" "drop-in failed validation and was removed"
        return 1
    fi

    step_ok
    return 0
}

# user_set_shell — make zsh the login shell for the account.
# Returns: 0 on success.
user_set_shell() {
    step_start "Setting default shell"

    _zsh=$(command -v zsh 2>/dev/null)
    if [ -z "$_zsh" ]; then
        SETUP_SHELL="/bin/sh"
        step_fail "Setting default shell" "zsh is not installed; leaving /bin/sh"
        return 1
    fi

    # /etc/shells must list the shell or chsh refuses it.
    if [ -f /etc/shells ] && ! grep -qx "$_zsh" /etc/shells 2>/dev/null; then
        backup_file /etc/shells
        printf '%s\n' "$_zsh" >>/etc/shells
    fi

    if log_cmd chsh -s "$_zsh" "$SETUP_USER" || \
       log_cmd sed -i "s|^\\($SETUP_USER:.*:\\)[^:]*$|\\1$_zsh|" /etc/passwd; then
        SETUP_SHELL=$_zsh
        step_ok
        return 0
    fi

    SETUP_SHELL="/bin/sh"
    step_fail "Setting default shell" "could not change the login shell"
    return 1
}

# user_run — run a command as the primary user, from their home directory.
# Arguments: $1 shell command string.
user_run() {
    log_write CMD "as $SETUP_USER: $1"
    su - "$SETUP_USER" -s /bin/sh -c "$1" >>"$LOG_FILE" 2>&1
}
