# Security Policy

## Reporting a vulnerability

Report privately through GitHub's security advisory form:

https://github.com/KabosuNeko/Ringo/security/advisories/new

Do not open a public issue for anything you believe is exploitable.

Include what you can: the affected file or component, the impact, and the steps
or input that trigger it. This is a personal configuration maintained in spare
time, so there is no response time guarantee, but every report is read.

## Scope

Ringo is a desktop configuration: dotfiles, an `install.sh` that deploys them
with GNU Stow, and `ringo-shell`, a Quickshell configuration plus the
`IslandBackend` C++ plugin it loads.

The shell runs as your user with your user's privileges and talks to niri over
the Wayland socket. It is not a sandbox and does not try to be one: anything it
can read or write, a bug in it can read or write, and any process running as
your user can talk to its IPC socket. That baseline is by design, not a
vulnerability.

In scope are bugs that widen that exposure, for example:

- running a command built from untrusted input, such as a wallpaper filename, a
  notification body, a clipboard entry or a D-Bus reply;
- writing or deleting outside the paths the shell owns (`~/.config/ringo-shell`,
  the XDG state and cache directories, the configured wallpaper directory);
- reading secrets such as PAM credentials and leaking them into logs, state
  files or notifications.

`install.sh` needs `sudo` for package installation and service setup; treat it
as any installer from a repository you trust. Review it before running it.

Bugs in Niri, Quickshell, pywal16, the vendored engines or any other
third-party component belong upstream, not here.
