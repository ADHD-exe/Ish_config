# completion.zsh — completion system and its cache.
#
# fast-syntax-highlighting runs compinit for us via its atinit hook (zicompinit)
# when Zinit is present. This module handles the no-Zinit case and configures
# the completion styles either way.

ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
[[ -d ${ZSH_COMPDUMP:h} ]] || mkdir -p ${ZSH_COMPDUMP:h} 2>/dev/null

# Only run compinit here if Zinit is not going to do it. Running it twice is a
# measurable startup cost under emulation.
if [[ ! -r "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git/zinit.zsh" ]]; then
    autoload -Uz compinit
    # Full security check at most once a day; -C reuses the dump the rest of the
    # time. The glob tests "is the dump newer than 24h old".
    if [[ -n ${ZSH_COMPDUMP}(#qN.mh-24) ]]; then
        compinit -C -d "$ZSH_COMPDUMP"
    else
        compinit -d "$ZSH_COMPDUMP"
    fi
fi

# Cache expensive completions (apk, git subcommands) between sessions.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# Case-insensitive, then partial-word, then substring. Typing precisely on glass
# is the bottleneck, so match as loosely as possible.
zstyle ':completion:*' matcher-list \
    'm:{a-zA-Z}={A-Za-z}' \
    'r:|[._-]=* r:|=*' \
    'l:|=* r:|=*'

zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' verbose yes

# Narrow screen: one column, short descriptions, no wide tables.
zstyle ':completion:*' list-packed false
zstyle ':completion:*:descriptions' format '%F{cyan}%d%f'
zstyle ':completion:*:warnings'     format '%F{red}no matches%f'

# Don't offer the file you are already editing, or . and ..
zstyle ':completion:*' ignore-parents parent pwd
zstyle ':completion:*:(rm|cp|mv):*' ignore-line other

# Process names for kill, which is otherwise unusable without a mouse.
zstyle ':completion:*:*:kill:*:processes' \
    list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,comm'
