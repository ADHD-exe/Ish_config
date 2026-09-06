# options.zsh — shell behaviour.

# Directory navigation: cd by typing the directory name, and keep a stack so
# the `-` alias and dirs -v are useful without any keybindings.
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Globbing.
setopt EXTENDED_GLOB
setopt NUMERIC_GLOB_SORT
unsetopt CASE_GLOB
setopt NO_NOMATCH          # leave an unmatched glob alone instead of erroring

# Completion feel.
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt AUTO_MENU
setopt AUTO_LIST
setopt AUTO_PARAM_SLASH
unsetopt MENU_COMPLETE
unsetopt FLOW_CONTROL      # frees ^S/^Q, which are unreachable on a phone anyway

# Correction is off on purpose: a mis-fired "did you mean" prompt on a
# touchscreen costs more taps than retyping the command.
unsetopt CORRECT
unsetopt CORRECT_ALL

# Quality of life.
setopt INTERACTIVE_COMMENTS
setopt LONG_LIST_JOBS
setopt NOTIFY
unsetopt BEEP
unsetopt HUP               # background jobs survive an iSH suspend/resume
