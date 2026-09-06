# plugins.zsh — Zinit and everything it loads.
#
# Oh My Zsh is NOT installed. Zinit pulls individual OMZ libraries and plugins
# as snippets (OMZL:: / OMZP::), which is why there is no ~/.oh-my-zsh here and
# no manual `git clone` anywhere in this file.
#
# Almost everything uses turbo mode (`wait lucid`), meaning it loads a fraction
# of a second AFTER the prompt appears. On emulated i686 this is the difference
# between a shell that feels instant and one that feels broken.
#
# To add a plugin later, append one `zinit ice` + `zinit light` pair to the
# bottom of the relevant section. Nothing else needs restructuring.

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

# No Zinit, no plugins — and no error message either.
if [[ ! -r "$ZINIT_HOME/zinit.zsh" ]]; then
    return 0
fi

source "$ZINIT_HOME/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# --------------------------------------------------------------------------
# Oh My Zsh libraries
# Loaded first because the OMZ plugins below expect these helpers to exist.
# --------------------------------------------------------------------------
zinit ice wait lucid
zinit snippet OMZL::git.zsh

# --------------------------------------------------------------------------
# Oh My Zsh plugins
# --------------------------------------------------------------------------

# git — the alias set alone justifies this on a touchscreen keyboard.
zinit ice wait lucid
zinit snippet OMZP::git

# extract — one `x <file>` for every archive format. Pure zsh.
zinit ice wait lucid
zinit snippet OMZP::extract

# web-search — `google foo`, `ddg bar`. Opens via $BROWSER; on iSH it prints
# the URL instead, which is still useful for copying into Safari.
zinit ice wait lucid
zinit snippet OMZP::web-search

# colored-man-pages — works with mandoc + less, both installed by the wizard.
zinit ice wait lucid
zinit snippet OMZP::colored-man-pages

# common-aliases — a broad, sane alias set. Loaded before our own aliases.zsh
# so anything we define wins.
zinit ice wait lucid
zinit snippet OMZP::common-aliases

# alias-finder — reminds you an alias exists for what you just typed by hand.
zinit ice wait lucid
zinit snippet OMZP::alias-finder
ZSH_ALIAS_FINDER_AUTOMATIC=true

# --- Deliberately NOT loaded on iSH -----------------------------------------
# Each of these was in the original plan and is disabled for a concrete reason.
# Uncomment if you disagree; nothing else depends on them.
#
# copyfile   — needs pbcopy/xclip/wl-copy. iSH has no clipboard bridge, so
#              every invocation fails silently.
# zinit ice wait lucid; zinit snippet OMZP::copyfile
#
# dirhistory — its entire interface is Alt+Left/Right/Up/Down. There are no Alt
#              arrows on the iPhone keyboard. See functions.zsh for `back`,
#              `fwd` and `up`, which do the same job as typed commands.
# zinit ice wait lucid; zinit snippet OMZP::dirhistory
#
# colorize   — requires Python + Pygments (~40 MB and slow under emulation).
# zinit ice wait lucid; zinit snippet OMZP::colorize
#
# aliases    — the OMZ cheatsheet plugin shells out to Python.
# zinit ice wait lucid; zinit snippet OMZP::aliases
#
# thefuck    — Python, and spawns a subprocess on every invocation.
# z          — superseded by zoxide, which is wired up in integrations.zsh.
# command-not-found — depends on a package-name database Alpine does not ship.
# zsh-autosuggestions / zoxide / eza are not OMZ plugins; they are handled
#              natively below and in integrations.zsh.

# --------------------------------------------------------------------------
# Standalone plugin repositories
# --------------------------------------------------------------------------

# Completions: added to fpath by Zinit, consumed by completion.zsh.
zinit ice wait lucid blockf atpull'zinit creinstall -q .'
zinit light zsh-users/zsh-completions

# Autosuggestions: the highest-value plugin on a phone. Suggests from history
# as you type; accept with the Right arrow.
zinit ice wait lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# you-should-use: nags when you type a command that already has an alias.
zinit ice wait lucid
zinit light MichaelAquilina/zsh-you-should-use
YSU_MESSAGE_POSITION="after"

# History substring search and syntax highlighting load LAST. Both wrap the
# line editor and will misbehave if anything binds keys after them.
zinit ice wait lucid
zinit light zsh-users/zsh-history-substring-search

zinit ice wait lucid atinit'zicompinit; zicdreplay'
zinit light zdharma-continuum/fast-syntax-highlighting

# zsh-autocomplete: real-time completion menus. Genuinely nice, and genuinely
# heavy — it redraws on every keystroke, which older iPhones feel. The wizard
# asks before creating this file; delete it to turn the plugin off.
if [[ -f "${ZDOTDIR:-$HOME/.config/zsh}/.autocomplete-enabled" ]]; then
    zinit ice wait lucid
    zinit light marlonrichert/zsh-autocomplete
fi
