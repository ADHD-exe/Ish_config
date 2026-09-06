# ish-setup

A first-run setup wizard for **iSH** (Alpine Linux, i686) on iPhone. It turns a
fresh install into a configured zsh development environment in one pass, and it
is safe to run again as many times as you like.

## Install

From a fresh iSH shell (you are root by default):

```sh
apk add curl
curl -L -o ish-setup.tar.gz [https://github.com/ADHD-exe/Ish_config.git]
tar xzf ish-setup.tar.gz
cd ish-setup
sh install.sh
```

Type a number, press Return. That is the whole interface — no Ctrl, Alt, or
function keys are used anywhere.

Non-interactive full run: `sh install.sh --all`

## What it does

1. Refreshes the Alpine index and upgrades what is installed.
2. Installs ~45 packages **one at a time**, so an unsatisfiable package on i686
   costs you that package and nothing else.
3. Creates your primary user, adds it to `wheel`, writes a validated sudo
   drop-in, and sets zsh as the login shell.
4. Wires `/etc/profile` so iSH opens directly into that user's zsh.
5. Installs Zinit and deploys a modular zsh config to `~/.config/zsh`.
6. Prints a report of everything that worked and everything that did not.

## Safety

The one edit that can genuinely make iSH unusable is `/etc/profile`, so that
block is defensive by design:

- `su` is **not** `exec`'d — if zsh is broken, control returns and you keep a
  working root shell instead of a dead app.
- The generated file is syntax-checked with `sh -n`; a failure restores the
  backup automatically.
- Delimited by markers and replaced wholesale on rerun, so blocks never stack.

**Escape hatches**, in order of convenience:

```sh
sudo touch /etc/ish-setup/disable-autologin   # permanent, survives reboot
ISH_SETUP_SKIP=1                              # if you can set the environment
```

Every file the installer touches is copied to
`~/ish-setup/backups/<timestamp>/` before it is modified. The full log is at
`~/ish-setup/install.log`.

## Layout

```
ish-setup/
├── install.sh              entrypoint: preflight, menu, orchestration
├── lib/
│   ├── log.sh              logging + non-fatal failure collection
│   ├── ui.sh               colors, numbered menus, progress lines
│   ├── pkg.sh              apk operations, per-package isolation
│   ├── user.sh             account, sudo, login shell
│   ├── ish.sh              platform detection, backups, /etc/profile block
│   ├── zsh.sh              Zinit install + config deployment
│   └── summary.sh          the closing report
└── config/
    ├── packages.list       R = required, O = optional
    ├── starship.toml       tuned for ~40 columns
    └── zsh/                module templates -> ~/.config/zsh/
```

## The shell you end up with

`ZDOTDIR` is `~/.config/zsh`. Only `.zshenv` remains in `$HOME`. `.zshrc`
sources ten modules in a fixed order; each guards its own dependencies, so a
missing tool produces **zero** startup output.

Plugins are managed by Zinit in turbo mode (`wait lucid`) — they load just
after the prompt appears, which is what keeps startup usable on emulated i686.
Oh My Zsh is not installed; its plugins are pulled individually as `OMZP::`
snippets.

### Typed commands instead of modifier keys

Everything below exists because its normal interface is a Ctrl or Alt chord:

| Command | Replaces |
|---|---|
| `fh` | Ctrl-R history search |
| `ff` | Ctrl-T file finder |
| `fcd` | Alt-C directory jump |
| `fkill` | reading a wide `ps` table |
| `up N` | Alt-Up |
| `back` / `fwd` | Alt-Left / Alt-Right |
| `j <partial>` | zoxide jump |
| `zalias` | edit your aliases |
| `zr` | reload the config |
| `ishinfo` | environment at a glance |
| `zbench` | measure startup time |

Up and Down arrows do substring history search. The Right arrow accepts an
autosuggestion. That is the entire required keyboard vocabulary.

## Deliberate omissions

Several things from the original plan are disabled, each with the reason left
in a comment where it would have gone (`config/zsh/plugins.zsh`):

- **`copyfile`** — needs a clipboard bridge iSH does not have.
- **`dirhistory`** — its whole interface is Alt+arrows. Use `back` / `fwd` / `up`.
- **`colorize`**, **`aliases`**, **`thefuck`** — all require Python; slow here.
- **`z`** — superseded by zoxide.
- **`command-not-found`** — depends on a package database Alpine does not ship.
- **`zsh-autocomplete`** — offered during setup, off by default. It redraws on
  every keystroke and older iPhones feel it. Toggle with
  `~/.config/zsh/.autocomplete-enabled`.
- **`ssh-agent`** as a package — it ships inside `openssh-client-default`.

Optional packages (`starship`, `zoxide`, `fzf`, `eza`, `ripgrep`, `fd`,
`atuin`, `bat`, `neovim`) are frequently missing or broken on i686. They are
marked `O` in the manifest, their absence is a quiet skip, and the shell config
falls back cleanly — including a native zsh prompt that mirrors the starship
one when starship is unavailable.

`openrc` and friends are included but init does not usefully run under iSH.
They are there only so `rc-service sshd start` is available to try. Safe to
delete those three lines from `config/packages.list`.

## Customising

- **Aliases** → `zalias` (edits `~/.config/zsh/.zalias`, never overwritten on
  rerun once it exists)
- **Plugins** → `zplug` (append one `zinit ice` + `zinit light` pair)
- **Anything else** → create `~/.config/zsh/local.zsh`. It is sourced last and
  the installer never touches it.

Run `zr` after any change.
