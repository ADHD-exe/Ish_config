# history.zsh — a large, shared, de-duplicated history.
#
# History is the single most valuable thing on a phone shell: retyping a long
# command on a touchscreen keyboard is the main cost of the whole environment.

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h} 2>/dev/null

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY      # write as you go, so a killed app loses nothing
setopt SHARE_HISTORY           # every iSH tab sees the same history
setopt EXTENDED_HISTORY        # timestamps, used by atuin and by fc
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE       # prefix a command with a space to hide it
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY             # expand !! for review instead of running it blind
