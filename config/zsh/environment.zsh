# environment.zsh — XDG paths, PATH, and the variables other modules rely on.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Create the directories zsh will want to write into, quietly.
() {
    local d
    for d in "$XDG_CACHE_HOME/zsh" "$XDG_DATA_HOME" "$XDG_STATE_HOME/zsh"; do
        [[ -d $d ]] || mkdir -p $d 2>/dev/null
    done
}

# PATH — typeset -U keeps it free of duplicates across reruns and re-sources.
typeset -U path PATH
path=(
    "$HOME/.local/bin"
    "$HOME/bin"
    $path
)
export PATH

# Editor: prefer whatever is actually installed. nano first because it is the
# only one of the three that is usable without Ctrl chords on a touchscreen.
if (( $+commands[nano] )); then
    export EDITOR=nano
elif (( $+commands[vim] )); then
    export EDITOR=vim
else
    export EDITOR=vi
fi
export VISUAL="$EDITOR"

# Pager. -R keeps colour, -F skips the pager for short output, -X stops less
# from clearing the screen, which matters when scrollback is your only history.
export PAGER=less
export LESS='-R -F -X -i'
export LESSHISTFILE="$XDG_CACHE_HOME/zsh/lesshst"

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# iSH has no real TTY resize events; a sane default beats an unset COLUMNS.
export COLUMNS="${COLUMNS:-40}"
