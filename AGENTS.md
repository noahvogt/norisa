# Working in this repository

norisa: the IaC setup for my Arch Linux dev machines (x86_64 and Asahi/Apple Silicon).

* `arch.sh` + `chroot.sh`: interactive, destructive base install from the Arch ISO
  (partitions and wipes the chosen drive).
* `norisa.sh`: post-install provisioning, run as root. Installs packages (pacman,
  chaotic-aur, paru/AUR), sets up the user, doas, services, zram, earlyoom, etc., and
  finally fetches and applies the dotfiles.

## Sibling repo: dotfiles

All git source repos on these machines live in `~/dox/src`. The user-level config
lives in **`~/dox/src/dotfiles`** (cloned there by
`ensure_dotfiles_are_fetched_and_applied`, applied with its `apply-dotfiles` stow
script).

So the two repos depend on each other:

* A package added or removed here often has config, keybinds or scripts in dotfiles
  (`dot-config/`, `local-bin/`) that use it. Check there, and say so or make the
  matching change.
* System-level config (`/etc`, system services, pacman, doas, groups) belongs here;
  per-user config under `~` belongs in dotfiles.

## Conventions

* `norisa.sh` must stay idempotent: it is re-run on already provisioned machines. Every
  step is an `ensure_*` function that checks the current state first, then logs with
  `log_ok` (already fine) or `log_changed` (did something), and fails via `error_exit`.
  New steps follow that pattern and get called from the list at the bottom of the file.
* Packages go in `BASE_PKGS`, `MAIN_PKGS` or `AUR_PKGS`; architecture-specific ones in
  `ARCH_PKGS`/`ARCH_AUR_PKGS` inside the `uname -m` branch (and the Apple M1 check).
* Check scripts with `shellcheck` and format with `shfmt`.
* Never run `arch.sh`, `chroot.sh` or `norisa.sh` yourself: they modify the system as
  root, and `arch.sh` wipes disks.

## Workflow

* **NEVER commit or push.** Leave all git history operations to the user.
* When a change is done, suggest a commit message following Conventional Commits,
  **unscoped** (`feat!: ...`, `feat: ...`, `fix: ...`, `chore: ...`, `doc: ...`, `refactor: ...`),
  lowercase, imperative, matching `git log`. If the change spans both repos, suggest
  one message per repo.
