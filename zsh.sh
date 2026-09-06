#!/bin/sh
# lib/zsh.sh — deploy the zsh configuration and install Zinit.
#
# Everything here runs as root but writes into the primary user's home, so each
# created path is chowned immediately. Existing files are backed up before they
# are replaced, and the user is asked before anything is overwritten.
#
# shellcheck disable=SC2034  # globals below are read by other modules
# Globals owned by this file:
#   ZDOTDIR_PATH    absolute path to the deployed config directory
#   ZINIT_STATUS    "installed" | "present" | "failed" | "skipped"
#   ZSH_CFG_STATUS  "created" | "updated" | "kept" | "failed"

ZDOTDIR_PATH=""
ZINIT_STATUS="skipped"
ZSH_CFG_STATUS="failed"

# zsh_own — chown a path to the primary user. Arguments: $1 path.
zsh_own() {
    chown -R "$SETUP_USER:$SETUP_USER" "$1" 2>/dev/null || true
}

# zsh_deploy_config — copy config/zsh/* into the user's ZDOTDIR.
# Arguments: $1 source directory (the repo's config/zsh).
# Returns: 0 on success.
zsh_deploy_config() {
    _src=$1
    ZDOTDIR_PATH="$SETUP_HOME/.config/zsh"

    step_start "Configuring Zsh"

    if [ ! -d "$_src" ]; then
        step_fail "Configuring Zsh" "template directory missing: $_src"
        return 1
    fi

    # An existing config is never silently destroyed.
    if [ -f "$ZDOTDIR_PATH/.zshrc" ]; then
        printf '\r\033[K'
        _choice=$(ask_menu "An existing zsh config was found." \
            "Back it up and replace it" \
            "Keep it (skip this step)" \
            "Replace it without a backup")
        case "$_choice" in
            2)
                ZSH_CFG_STATUS="kept"
                step_ok "Configuring Zsh (kept existing)"
                return 0
                ;;
            1)
                for _f in "$ZDOTDIR_PATH"/*.zsh "$ZDOTDIR_PATH/.zshrc" \
                          "$ZDOTDIR_PATH/.zalias" "$SETUP_HOME/.zshenv"; do
                    [ -e "$_f" ] && backup_file "$_f"
                done
                ;;
        esac
        ZSH_CFG_STATUS="updated"
        step_start "Configuring Zsh"
    else
        ZSH_CFG_STATUS="created"
    fi

    mkdir -p "$ZDOTDIR_PATH" 2>/dev/null || {
        step_fail "Configuring Zsh" "cannot create $ZDOTDIR_PATH"
        return 1
    }

    # .zshenv is the one file that must live in $HOME.
    backup_file "$SETUP_HOME/.zshenv"
    if ! cp "$_src/zshenv" "$SETUP_HOME/.zshenv" 2>/dev/null; then
        step_fail "Configuring Zsh" "could not write .zshenv"
        return 1
    fi

    # .zshrc plus every module.
    cp "$_src/zshrc" "$ZDOTDIR_PATH/.zshrc" 2>/dev/null || {
        step_fail "Configuring Zsh" "could not write .zshrc"
        return 1
    }

    for _mod in environment options history plugins completion \
                keybindings integrations aliases functions prompt; do
        cp "$_src/$_mod.zsh" "$ZDOTDIR_PATH/$_mod.zsh" 2>/dev/null || \
            record_warning "module not deployed: $_mod.zsh"
    done

    # .zalias is user data. Never clobber an existing one, even on "replace".
    if [ ! -f "$ZDOTDIR_PATH/.zalias" ]; then
        cp "$_src/.zalias" "$ZDOTDIR_PATH/.zalias" 2>/dev/null
    else
        ui_note "Existing .zalias kept as-is."
    fi

    # starship config, if the binary made it in.
    mkdir -p "$SETUP_HOME/.config" 2>/dev/null
    if [ -f "$SETUP_HOME/.config/starship.toml" ]; then
        backup_file "$SETUP_HOME/.config/starship.toml"
    fi
    cp "$_src/../starship.toml" "$SETUP_HOME/.config/starship.toml" 2>/dev/null

    # Cache and state directories, created now so the first launch is quiet.
    mkdir -p "$SETUP_HOME/.cache/zsh" "$SETUP_HOME/.local/state/zsh" \
             "$SETUP_HOME/.local/share" "$SETUP_HOME/.local/bin" 2>/dev/null

    zsh_own "$SETUP_HOME/.config"
    zsh_own "$SETUP_HOME/.cache"
    zsh_own "$SETUP_HOME/.local"
    chown "$SETUP_USER:$SETUP_USER" "$SETUP_HOME/.zshenv" 2>/dev/null

    step_ok
    return 0
}

# zsh_prompt_autocomplete — ask about the heavy real-time completion plugin.
# Presence of the flag file is what plugins.zsh checks.
zsh_prompt_autocomplete() {
    _flag="$ZDOTDIR_PATH/.autocomplete-enabled"
    if ask_yes_no "Enable zsh-autocomplete? It shows completion menus as you type, but redraws on every keystroke and is noticeably slower on older iPhones." "no"; then
        : >"$_flag" 2>/dev/null
        chown "$SETUP_USER:$SETUP_USER" "$_flag" 2>/dev/null
        ui_note "Enabled. Delete $_flag to turn it off."
    else
        rm -f "$_flag" 2>/dev/null
        ui_note "Skipped. Create $_flag later to enable it."
    fi
}

# zsh_install_zinit — clone Zinit into the user's data directory.
# Run as the user so file ownership is right from the start.
# Returns: 0 on success.
zsh_install_zinit() {
    _zinit_home="$SETUP_HOME/.local/share/zinit/zinit.git"

    step_start "Installing Zinit"

    if [ -d "$_zinit_home/.git" ]; then
        ZINIT_STATUS="present"
        # Best-effort update; a failure here is not worth reporting as an error.
        user_run "git -C '$_zinit_home' pull --ff-only" || \
            record_warning "Zinit update failed (existing install kept)"
        step_ok "Installing Zinit (already present)"
        return 0
    fi

    if ! pkg_have git; then
        ZINIT_STATUS="failed"
        step_fail "Installing Zinit" "git is not installed"
        return 1
    fi

    user_run "mkdir -p '$(dirname "$_zinit_home")'"
    if user_run "git clone --depth 1 https://github.com/zdharma-continuum/zinit.git '$_zinit_home'"; then
        ZINIT_STATUS="installed"
        step_ok
        return 0
    fi

    ZINIT_STATUS="failed"
    step_fail "Installing Zinit" "clone failed; check the network and the log"
    return 1
}

# zsh_warm_plugins — do the first plugin download now rather than at first launch.
# Without this, the user's first shell spends 30-60s cloning while they watch.
# Failure is non-fatal: the plugins will simply install on first launch instead.
zsh_warm_plugins() {
    [ "$ZINIT_STATUS" = "failed" ] && return 1

    step_start "Downloading plugins (first run only)"
    if user_run "zsh -i -c 'zinit self-update >/dev/null 2>&1; sleep 2; exit' "; then
        step_ok "Downloading plugins"
        return 0
    fi
    # Non-fatal by design.
    step_ok "Downloading plugins (deferred to first launch)"
    record_warning "plugin pre-warm did not complete; plugins will install on first shell start"
    return 0
}

# zsh_verify — confirm the deployed config actually parses.
# Catches a truncated copy or a bad template before the user is locked out.
zsh_verify() {
    step_start "Verifying Zsh config"
    if ! pkg_have zsh; then
        step_fail "Verifying Zsh config" "zsh is not installed"
        return 1
    fi
    if user_run "zsh -n '$ZDOTDIR_PATH/.zshrc'"; then
        step_ok
        return 0
    fi
    ZSH_CFG_STATUS="failed"
    step_fail "Verifying Zsh config" "the generated .zshrc did not parse"
    return 1
}
