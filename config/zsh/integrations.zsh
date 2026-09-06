# integrations.zsh — optional tools, each behind a guard.
#
# Every block here follows the same shape: check the executable exists, then
# wire it up. Nothing in this file can produce output on startup when a tool is
# missing, which is what makes the optional half of the package list safe.

# --- zoxide: frecency-based cd -------------------------------------------
# Replaces the `z` plugin entirely. `cd` stays as cd; `j <partial>` jumps.
if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh --cmd j 2>/dev/null)"
fi

# --- fzf: fuzzy finder ----------------------------------------------------
# The stock key bindings need Ctrl-T / Ctrl-R. They are sourced when present,
# but the typed wrappers in functions.zsh (ff, fh, fcd, fkill) are the
# intended interface here.
if (( $+commands[fzf] )); then
    export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=sharp --info=inline"

    if (( $+commands[fd] )); then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi

    # Alpine installs these under /usr/share/fzf; the git install puts them in
    # ~/.fzf/shell. Check both, take whichever exists.
    for _fzf_dir in /usr/share/fzf "$HOME/.fzf/shell"; do
        [[ -r "$_fzf_dir/key-bindings.zsh" ]] && source "$_fzf_dir/key-bindings.zsh"
        [[ -r "$_fzf_dir/completion.zsh" ]]  && source "$_fzf_dir/completion.zsh"
    done
    unset _fzf_dir
fi

# --- atuin: searchable, synced shell history ------------------------------
# Loaded AFTER the keybindings module on purpose. atuin rebinds Up by default,
# which would fight history-substring-search; --disable-up-arrow keeps Up doing
# what keybindings.zsh set it to and leaves atuin on Ctrl-R and the `at` alias.
if (( $+commands[atuin] )); then
    eval "$(atuin init zsh --disable-up-arrow 2>/dev/null)"
fi

# --- eza: modern ls -------------------------------------------------------
# The ll/la/l aliases in aliases.zsh detect eza themselves; this only sets the
# shared options so both paths agree.
if (( $+commands[eza] )); then
    export EZA_ICONS_AUTO=0   # icons need a Nerd Font; iSH does not have one
fi

# --- git ------------------------------------------------------------------
if (( $+commands[git] )); then
    # Long diffs are unreadable in 40 columns without a pager that wraps.
    export GIT_PAGER="less -R -F -X"
fi

# --- less / man colouring --------------------------------------------------
# A fallback for when the colored-man-pages plugin has not loaded yet (turbo
# mode means the first man invocation may beat it). Harmless duplication.
export LESS_TERMCAP_md=$'\e[1;36m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;32m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;44;33m'
export LESS_TERMCAP_se=$'\e[0m'

# --- ssh-agent -------------------------------------------------------------
# Started lazily: only when a key exists and no agent is already running.
# iSH kills background processes aggressively, so this re-checks each session.
if (( $+commands[ssh-agent] )) && [[ -z "$SSH_AUTH_SOCK" ]]; then
    if [[ -d "$HOME/.ssh" ]] && ls "$HOME"/.ssh/id_* >/dev/null 2>&1; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1
    fi
fi
