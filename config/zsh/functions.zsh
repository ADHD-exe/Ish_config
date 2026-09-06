# functions.zsh — typed replacements for things that normally need modifier keys.
#
# Every function here exists because its usual interface is a Ctrl or Alt chord.
# On a touchscreen keyboard, a short typed name is faster and always available.

# mkcd — make a directory and enter it.
mkcd() {
    [[ -z "$1" ]] && { print "usage: mkcd <dir>"; return 1; }
    mkdir -p "$1" && cd "$1"
}

# up — go up N directories. Replaces dirhistory's Alt+Up.
up() {
    local n=${1:-1} p=""
    while (( n-- > 0 )); do p="../$p"; done
    cd "$p" || return 1
}

# back / fwd — walk the directory stack. Replaces dirhistory's Alt+Left/Right.
back() { popd >/dev/null 2>&1 || print "directory stack is empty"; }
fwd()  { pushd +1 >/dev/null 2>&1 || print "nothing to go forward to"; }

# ff — fuzzy-find a file and open it in $EDITOR. Replaces fzf's Ctrl-T.
ff() {
    (( $+commands[fzf] )) || { print "fzf is not installed"; return 1; }
    local f
    f=$(fzf --prompt="file> " --query="${1:-}") || return
    [[ -n "$f" ]] && $EDITOR "$f"
}

# fcd — fuzzy-find a directory and cd into it. Replaces fzf's Alt-C.
fcd() {
    (( $+commands[fzf] )) || { print "fzf is not installed"; return 1; }
    local dir
    if (( $+commands[fd] )); then
        dir=$(fd --type d --hidden --exclude .git | fzf --prompt="dir> " --query="${1:-}")
    else
        dir=$(find . -type d -not -path '*/.git/*' 2>/dev/null | fzf --prompt="dir> " --query="${1:-}")
    fi
    [[ -n "$dir" ]] && cd "$dir"
}

# fh — fuzzy-search history and put the result on the command line.
# Replaces Ctrl-R. Uses atuin's search when available, fzf otherwise.
fh() {
    if (( $+commands[atuin] )); then
        atuin search -i
        return
    fi
    (( $+commands[fzf] )) || { print "install fzf or atuin for history search"; return 1; }
    local cmd
    cmd=$(fc -rl 1 | sed 's/^ *[0-9]* *//' | awk '!seen[$0]++' | fzf --prompt="history> " --query="${1:-}")
    [[ -n "$cmd" ]] && print -z "$cmd"
}

# fkill — pick a process and kill it. Replaces needing to read a wide ps table.
fkill() {
    (( $+commands[fzf] )) || { print "fzf is not installed"; return 1; }
    local pid
    pid=$(ps -eo pid,comm 2>/dev/null | sed 1d | fzf --prompt="kill> " | awk '{print $1}')
    [[ -n "$pid" ]] && kill "${1:--TERM}" "$pid"
}

# extract — fallback for when the OMZ extract plugin has not loaded.
# Named differently (ex) so it never collides with the plugin's `x`.
ex() {
    [[ -f "$1" ]] || { print "no such file: $1"; return 1; }
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1"   ;;
        *.tar.gz|*.tgz)   tar xzf "$1"   ;;
        *.tar.xz)         tar xJf "$1"   ;;
        *.tar)            tar xf  "$1"   ;;
        *.bz2)            bunzip2 "$1"   ;;
        *.gz)             gunzip  "$1"   ;;
        *.zip)            unzip   "$1"   ;;
        *.Z)              uncompress "$1";;
        *) print "don't know how to extract $1"; return 1 ;;
    esac
}

# ishinfo — one screen of environment facts, sized for portrait.
ishinfo() {
    print -P "%F{cyan}user%f      $USER"
    print -P "%F{cyan}host%f      ${HOST:-$(hostname 2>/dev/null)}"
    print -P "%F{cyan}shell%f     zsh $ZSH_VERSION"
    print -P "%F{cyan}arch%f      $(uname -m)"
    print -P "%F{cyan}alpine%f    $(cat /etc/alpine-release 2>/dev/null || print unknown)"
    print -P "%F{cyan}zdotdir%f   ${ZDOTDIR}"
    print -P "%F{cyan}editor%f    ${EDITOR}"
    print -P "%F{cyan}uptime%f    $(uptime 2>/dev/null | sed 's/^ *//')"
}

# zprofile-startup — measure shell startup time. Useful after adding plugins.
zbench() {
    local i total=0 start end
    for i in {1..5}; do
        start=$(date +%s%N 2>/dev/null) || { print "need GNU date"; return 1; }
        zsh -i -c exit
        end=$(date +%s%N)
        total=$(( total + (end - start) / 1000000 ))
    done
    print "average startup: $(( total / 5 )) ms over 5 runs"
}
