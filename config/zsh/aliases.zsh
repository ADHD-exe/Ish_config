# aliases.zsh — loader only.
#
# The aliases themselves live in $ZDOTDIR/.zalias so they can be edited without
# touching a module file. Run `zalias` to open that file, `zr` to reload.

[[ -r "${ZDOTDIR:-$HOME/.config/zsh}/.zalias" ]] && \
    source "${ZDOTDIR:-$HOME/.config/zsh}/.zalias"
