# prompt.zsh — starship when installed, a native zsh prompt when not.
#
# Both prompts show the same information and both are two lines: status on the
# first, a bare marker on the second. At 40 columns, sharing a line between
# context and input means every command wraps.

if (( $+commands[starship] )); then
    export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
    export STARSHIP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
    [[ -d $STARSHIP_CACHE ]] || mkdir -p $STARSHIP_CACHE 2>/dev/null
    eval "$(starship init zsh)"
    return 0
fi

# ---------------------------------------------------------------------------
# Fallback prompt. No subprocesses: git state comes from vcs_info, which zsh
# computes internally. Spawning `git` on every prompt is visibly slow on iSH.
# ---------------------------------------------------------------------------

setopt PROMPT_SUBST

autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats       ' %F{magenta}%b%f%F{yellow}%u%c%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta}%b%f %F{red}%a%f'

precmd() { vcs_info }

# Root gets red, everyone else gets green. The difference is deliberately
# obvious: on a phone you will not read the username, you will read the colour.
if [[ $EUID -eq 0 ]]; then
    _p_user='%F{red}%B%n%b%f'
    _p_mark='%F{red}#%f'
else
    _p_user='%F{green}%n%f'
    _p_mark='%F{cyan}$%f'
fi

# %2~ truncates to the last two path components, keeping ~ notation.
# %(?..) renders the exit code only when the last command failed.
PROMPT='${_p_user}%F{8}@%f%F{blue}%m%f %F{yellow}%2~%f${vcs_info_msg_0_}%(?.. %F{red}[%?]%f)
${_p_mark} '

# Right prompt: time only, and only when the terminal is wide enough to spare
# the space. RPROMPT is cleared as soon as a line wraps, so this costs nothing.
RPROMPT='%F{8}%*%f'

# Continuation and select prompts, kept short.
PROMPT2='%F{8}...%f '
PROMPT3='%F{8}?#%f '
