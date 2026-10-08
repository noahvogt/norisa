#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# ASSUMED STATE OF TARGET SYSTEM:
# - internet access
# - root user login
# - ~30 GB of free disk space
# working 1.) base 2.) linux packages

# Install opendoas and (base-devel, devtools minus sudo), libxft, cargo
readonly BASE_PKGS="archlinux-keyring opendoas autoconf automake binutils bison debugedit fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which libxft breezy coreutils curl diffutils expac git glow gum jq mercurial openssh parallel reuse rsync subversion util-linux cargo"

# Architecture-specific packages
ARCH=$(uname -m)
IS_APPLE_M1="no"
if [ "$ARCH" = "x86_64" ]; then
    ARCH_PKGS="intel-ucode amd-ucode fwupd tlp xf86-video-vesa xf86-video-fbdev xf86-video-amdgpu xf86-video-intel ungoogled-chromium-bin obs-studio brave-bin ghostty ttf-material-symbols-variable-git nomacs wlogout unifetch shellcheck yt-dlp logseq-desktop ipscan nodejs-intelephense"
    GAMING_PKGS="steam ttf-liberation lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-intel lib32-vulkan-intel gamemode lib32-gamemode mangohud lib32-mangohud"
    ARCH_AUR_PKGS="simple-mtpfs code2prompt-bin"

    GAMING_WANTED=""
    if [ -f /etc/norisa ]; then
        GAMING_WANTED=$(grep "^gaming=" /etc/norisa | cut -d'=' -f2)
    fi

    if [ -z "$GAMING_WANTED" ]; then
        echo -e "\e[0;30;42m Do you want to install gaming packages (Steam, multilib, etc.)? [y/n] \e[0m"
        read -rp " >>> " want_gaming
        if [[ "$want_gaming" =~ ^[yY]$ ]]; then
            GAMING_WANTED="yes"
        else
            GAMING_WANTED="no"
        fi
        echo "gaming=$GAMING_WANTED" >>/etc/norisa
    fi

    if [ "$GAMING_WANTED" = "yes" ]; then
        ARCH_PKGS="$ARCH_PKGS $GAMING_PKGS"
    fi
else
    # Asahi/ARM specific or generic alternatives
    ARCH_PKGS="chromium"
    ARCH_AUR_PKGS="unifetch shellcheck-bin yt-dlp-git logseq-desktop-bin code2prompt wlogout"

    # Apple M1 family (t8103: M1, t600x: M1 Pro/Max/Ultra)
    if tr '\0' '\n' </proc/device-tree/compatible 2>/dev/null | grep -qE '^apple,(t8103|t600[0-2])$'; then
        IS_APPLE_M1="yes"
        ARCH_PKGS="$ARCH_PKGS avd-fw"
        ARCH_AUR_PKGS="$ARCH_AUR_PKGS libva-v4l2_request-asahi"
    fi
fi

readonly MAIN_PKGS="xorg-server neovim ranger xournalpp ffmpeg sxiv arandr man-db brightnessctl unzip python mupdf-gl mediainfo highlight pipewire pipewire-pulse pipewire-alsa pipewire-audio wireplumber pulsemixer pamixer ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick gimp xorg-setxkbmap wavemon dash htop wireless_tools alsa-utils acpi zip libreoffice-fresh nm-connection-editor dunst libnotify dosfstools mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat pcmanfm openbsd-netcat powertop mupdf-tools stow zsh-autosuggestions npm fzf unclutter mpd mpc ncmpcpp pavucontrol strawberry smartmontools firefox python-pynvim python-pylint tesseract-data-deu tesseract-data-eng keepassxc img2pdf dust ctags python-wand python-termcolor python-black jdk-openjdk ripgrep lf ttf-jetbrains-mono-nerd foliate coreutils curl fish foot fuzzel gjs gnome-bluetooth-3.0 gnome-control-center gnome-keyring gobject-introspection grim gtk3 gtk-layer-shell libdbusmenu-gtk3 meson nlohmann-json plasma-browser-integration playerctl polkit-gnome python-pywal sassc slurp swayidle typescript xorg-xrandr webp-pixbuf-loader yad hyprland python-poetry python-build python-pillow ttf-space-mono-nerd kitty shfmt ruff luarocks rust-analyzer hyprland-guiutils waybar socat hyprlock clang swaync bat wl-clipboard syncthing python-debugpy awww kitty tokei hypridle texlive-basic texlive-bibtexextra texlive-binextra texlive-context texlive-fontsextra texlive-fontsrecommended texlive-fontutils texlive-formatsextra texlive-games texlive-humanities texlive-latex texlive-latexextra texlive-latexrecommended texlive-luatex texlive-mathscience texlive-metapost texlive-music texlive-pictures texlive-plaingeneric texlive-pstricks texlive-publishers texlive-xetex libva-utils blueman woff2-font-awesome bind qt5-wayland qt6-wayland pre-commit python-pandas python-pylatexenc pyright python-beautifulsoup4 tree-sitter-cli jupyterlab python-httplib2 jdk11-openjdk zathura-pdf-mupdf imv rclone openconnect python-evdev tree python-seaborn plocate fastfetch sqlx-cli biber texlive-langgerman wget docker docker-compose docker-buildx gnome-connections python-aiohttp ansible mariadb-clients psalm llvm uvicorn python-fastapi python-kivy pandoc-cli nmap kdenlive wol just pacman-contrib lm_sensors wlsunset jupyterlab-widgets azure-cli kubectl helm gns3-gui gns3-server glab python-httpx2 networkmanager-openconnect github-cli zram-generator earlyoom systembus-notify stress-ng $ARCH_PKGS"

readonly AUR_PKGS="fluffychat-color-emoji openconnect-ms-auth redshift dashbinsh cspell-lsp doasedit-alternative nodejs-cspell nvim-lazy lexend-fonts-git xwaylandvideobridge jdtls gradle-autowrap localsend-bin python-sklearn-onnx kotlin-language-server-bin ktlint-compose-rules ktlint pup beekeeper-studio-bin python-pyotp python-jupytext python-selenium wireshark-qt python-jupytext marksman-git python-openstackclient $ARCH_AUR_PKGS"

readonly C_RESET='\e[0m'
readonly C_INFO='\e[1;36m'   # Cyan
readonly C_OK='\e[1;32m'     # Green
readonly C_CHANGE='\e[1;33m' # Yellow
readonly C_ERR='\e[1;31m'    # Red

log_info() {
    echo -e "${C_INFO}[ INFO ]${C_RESET} $1"
}

log_ok() {
    echo -e "${C_OK}[  OK  ]${C_RESET} $1"
}

log_changed() {
    echo -e "${C_CHANGE}[ CHANGE ]${C_RESET} $1"
}

log_error() {
    echo -e "${C_ERR}[ ERROR ]${C_RESET} $1" >&2
}

error_exit() {
    log_error "$1"
    exit 1
}

pkg_install_error_exit() {
    error_exit "Package installation command was not successfull. Exiting ..."
}

cd_error_exit() {
    log_info "Current working directory:"
    pwd
    error_exit "Could not change into '$1'. Exiting ..."
}

cd_into() {
    cd "$1" || cd_error_exit "$1"
}

ensure_pkgs_installed() {
    MISSING_PKGS="$(pacman -T $1)"
    log_info "Ensuring $2 packages are installed"
    if [ -n "$MISSING_PKGS" ]; then
        if [[ "$3" == *doas* ]]; then
            setup_temporary_doas
        fi
        $3 -Sy --noconfirm --needed $MISSING_PKGS || pkg_install_error_exit
        log_changed "$2 packages are now installed"
    else
        log_ok "$2 packages are already installed"
    fi
}

_write_doas_config() {
    local content="$1"
    local config_path="/etc/doas.conf"

    if [[ -f "$config_path" ]] &&
        [[ "$(cat "$config_path")" == "$content" ]] &&
        [[ "$(stat -c "%a %U:%G" "$config_path")" == "400 root:root" ]]; then
        return 1 # no change needed
    fi

    printf "%s\n" "$content" >"$config_path"
    chown root:root "$config_path"
    chmod 400 "$config_path"
    return 0 # changed
}

setup_temporary_doas() {
    log_info "Setting up temporary doas config"
    local content="permit nopass :wheel
permit nopass root as $username"

    if _write_doas_config "$content"; then
        log_changed "Temporary doas config was set"
    else
        log_ok "doas config is already in desired state"
    fi
}

setup_final_doas() {
    log_info "Setting up final doas config"
    local content="permit persist :wheel
permit nopass $username as root cmd mount
permit nopass $username as root cmd umount
permit nopass root as $username"

    if _write_doas_config "$content"; then
        log_changed "Final doas config was set"
    else
        log_ok "doas config is already in desired state"
    fi
}

create_new_user() {
    echo -e "\e[0;30;42m Enter your desired username \e[0m"
    read -rp " >>> " username
    useradd -m -g users -G wheel "$username"
    log_changed "user '$username' was created"
    while true; do
        passwd "$username" && break
    done
    log_changed "password for user '$username' was set"
}

choose_user() {
    echo -e "\e[0;30;46m Available users: \e[0m"
    ls /home
    while true; do
        echo -e "\e[0;30;42m Enter in your chosen user \e[0m"
        read -rp " >>> " username
        ls /home/ | grep -q "^$username$" && break
    done
}

ensure_user_is_part_of_needed_groups() {
    log_info "Verify $username is part of video and input groups"
    if ! groups "$username" | grep "input" | grep -q "video"; then
        log_info "Adding $username to video and input groups"
        usermod -aG video "$username"
        usermod -aG input "$username"
    else
        log_ok "$username is already part of these groups"
    fi
}

ensure_user_is_part_of_docker_group() {
    log_info "Verify $username is part of docker group"
    if ! groups "$username" | grep "docker"; then
        log_info "Adding $username to docker group"
        usermod -aG docker "$username"
    else
        log_ok "$username is already part of the docker group"
    fi
}

ensure_user_is_part_of_wireshark_group() {
    log_info "Verify $username is part of wireshark group"
    if ! groups "$username" | grep "wireshark"; then
        log_info "Adding $username to wireshark group"
        usermod -aG wireshark "$username"
    else
        log_ok "$username is already part of the wireshark group"
    fi
}

ensure_history_file_exists() {
    log_info "Ensure history file exists"
    local history_dir="/home/$username/.cache/zsh"
    local history_file="$history_dir/history"
    if ! [ -f "$history_file" ] ||
        [ "$(stat -c "%U" "$history_dir")" != "$username" ] ||
        [ "$(stat -c "%U" "$history_file")" != "$username" ]; then
        echo -e "\e[0;30;34mEnsuring initial zsh history file exists ...\e[0m"
        install -d -o "$username" -g users "$history_dir" || error_exit "Failed to create $history_dir"
        touch "$history_file" || error_exit "Failed to create $history_file"
        chown "$username:users" "$history_file" || error_exit "Failed to chown $history_file"
        log_changed "Created history file owned by $username"
    else
        log_ok "history file is already present"
    fi
}

ensure_login_shell_is_zsh() {
    log_info "Ensure login shell is zsh"
    if ! grep "^$username.*::/home/$username" /etc/passwd | sed 's/^.*://' |
        grep -q "^$(which zsh)$"; then
        echo -e "\e[0;30;34mSetting default shell to $(which zsh)...\e[0m"
        chsh -s "$(which zsh)" "$username" || exit 1
        log_changed "changed shell to zsh"
    else
        log_ok "login shell is already zsh"
    fi
}

ensure_user_selected() {
    if [ -d /home ]; then
        mapfile -t home_users < <(ls -A /home)
        user_count=${#home_users[@]}
    else
        user_count=0
    fi

    if [ "$user_count" -eq 1 ]; then
        username="${home_users[0]}"
        echo -e "\e[0;30;46m A single user was found: $username \e[0m"
    elif [ "$user_count" -gt 1 ]; then
        echo -e "\e[0;30;46m /home/ not empty, $user_count users already available \e[0m"
        while true; do
            echo -e "\e[0;30;42m Do you want to create another user? [y/n] \e[0m"
            read -rp " >>> " want_new_user

            if [[ "$want_new_user" =~ ^[yY]$ ]]; then
                create_new_user
                break
            elif [[ "$want_new_user" =~ ^[nN]$ ]]; then
                choose_user
                break
            fi
        done
    else
        want_new_user=y
        create_new_user
    fi
}

ensure_needed_dirs_created() {
    log_info "Creating needed ~/ directories"
    needed_dirs=(
        "/home/$username/dox"
        "/home/$username/pix"
        "/home/$username/dl"
        "/home/$username/vids"
        "/home/$username/mus"
        "/home/$username/.local/"
        "/home/$username/.local/bin"
        "/home/$username/.local/share"
        "/home/$username/.config"
        "/home/$username/.cache"
        "/home/$username/dox/src"
    )
    local dirs_to_fix=()
    for dir in "${needed_dirs[@]}"; do
        if [ ! -d "$dir" ] || [ "$(stat -c "%U" "$dir")" != "$username" ]; then
            dirs_to_fix+=("$dir")
        fi
    done
    if [ ${#dirs_to_fix[@]} -gt 0 ]; then
        mkdir -vp "${dirs_to_fix[@]}" || error_exit "Failed to create needed ~/ directories"
        chown "$username:users" "${dirs_to_fix[@]}" || error_exit "Failed to chown needed ~/ directories"
        log_changed "Created needed ~/ directories"
    else
        log_ok "Needed ~/ directories are already present"
    fi
}

ensure_sudo_is_symlinked_to_doas() {
    log_info "Ensure sudo is symlinked to doas"
    if [ ! -f /usr/bin/sudo ]; then
        ln -s /usr/bin/doas /usr/bin/sudo
        log_changed "sudo was symlinked to doas"
    else
        log_ok "sudo is already symlinked to doas"
    fi
}

# add xdg-repo
# if ! grep -q "^\s*\[xdg-repo\]\s*$" /etc/pacman.conf; then
#     echo -e "\e[0;30;34mAdding Noah's xdg-repo ...\e[0m"
#     pacman-key --recv-keys 7FA7BB604F2A4346 --keyserver keyserver.ubuntu.com
#     pacman-key --lsign-key 7FA7BB604F2A4346
#     echo "[xdg-repo]
# Server = https://git.noahvogt.com/noah/\$repo/raw/master/\$arch" >> /etc/pacman.conf
# fi

# paru inherits this, e.g. for colored PKGBUILD diffs on AUR updates
ensure_pacman_color_enabled() {
    log_info "Ensuring pacman color output is enabled"
    if grep -q "^#Color\s*$" /etc/pacman.conf; then
        sed -i 's/^#Color\s*$/Color/' /etc/pacman.conf
        log_changed "Enabled pacman color output"
    else
        log_ok "pacman color output is already enabled"
    fi
}

ensure_multilib_enabled() {
    if [ "$ARCH" = "x86_64" ] && [ "$GAMING_WANTED" = "yes" ]; then
        log_info "Ensuring multilib repository is enabled"
        if grep -q "^#\[multilib\]" /etc/pacman.conf; then
            sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
            pacman -Sy
            log_changed "Enabled [multilib] repository"
        else
            log_ok "[multilib] repository is already enabled"
        fi
    fi
}

ensure_chaotic_aur_installed() {
    if [ "$ARCH" = "x86_64" ]; then
        if ! grep -q "^\s*\[chaotic-aur\]\s*$" /etc/pacman.conf; then
            echo -e "\e[0;30;34mAdding the chaotic aur repo ...\e[0m"
            pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
            pacman-key --lsign-key 3056513887B78AEB
            pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
            pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
            echo "[chaotic-aur]
    Include = /etc/pacman.d/chaotic-mirrorlist" >>/etc/pacman.conf
        fi
    fi
}

# Install AUR Helper (paru as paru-bin is out-of-date)
ensure_paru_installed() {
    log_info "Ensuring paru is installed"
    if ! command -v paru >/dev/null 2>&1; then
        if [ "$ARCH" = "x86_64" ] && pacman -Si paru >/dev/null 2>&1; then
            pacman -S --noconfirm paru
        else
            setup_temporary_doas
            log_info "Building paru from source..."
            temp_dir=$(mktemp -d)
            chown "$username:users" "$temp_dir"
            doas -u "$username" bash -c "cd $temp_dir && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg --noconfirm"
            pacman -U --noconfirm "$temp_dir"/paru/*.pkg.tar.* || pkg_install_error_exit
        fi
        log_changed "Installed AUR helper (paru)"
    else
        log_ok "AUR helper (paru) is already installed"
    fi
}

# Let paru build the PKGBUILDs from my pkgbuilds repo like AUR packages
ensure_paru_pkgbuild_repo_configured() {
    if ! grep -q "^\s*\[pkgbuilds\]\s*$" /etc/paru.conf; then
        echo "
[pkgbuilds]
Url = https://github.com/noahvogt/pkgbuilds.git
SkipReview" >>/etc/paru.conf
        log_changed "Added pkgbuilds PKGBUILD repository to paru"
    else
        log_ok "pkgbuilds PKGBUILD repository is already configured in paru"
    fi
}

ensure_global_zsh_installed() {
    log_info "Ensuring global zshenv"
    if grep -q "export ZDOTDIR=\$HOME/.config/zsh" /etc/zsh/zshenv; then
        log_ok "Global zshenv ist already installed"
    else
        mkdir -vp /etc/zsh
        echo "export ZDOTDIR=\$HOME/.config/zsh" >/etc/zsh/zshenv
        log_changed "Installed global zshenv"
    fi
}

ensure_bluetooth_service_enabled() {
    log_info "Ensuring Bluetooth service is enabled"
    if ! systemctl is-enabled bluetooth.service >/dev/null 2>&1; then
        systemctl enable bluetooth.service
        log_changed "Enabled bluetooth.service system-wide"
    else
        log_ok "Bluetooth service is already enabled"
    fi
}

# start dockerd on first use of the docker socket instead of at boot, which
# saves boot time and the RAM of an idle dockerd + containerd. containers with
# a restart policy therefore only come back up after the first docker command
ensure_docker_socket_enabled() {
    log_info "Ensuring Docker is socket-activated"
    if ! systemctl is-enabled docker.socket >/dev/null 2>&1; then
        systemctl enable --now docker.socket || error_exit "Failed to enable docker.socket"
        log_changed "Enabled docker.socket system-wide"
    else
        log_ok "docker.socket is already enabled"
    fi
    if systemctl is-enabled docker.service >/dev/null 2>&1; then
        systemctl disable docker.service || error_exit "Failed to disable docker.service"
        log_changed "Disabled docker.service at boot"
    else
        log_ok "docker.service is already disabled at boot"
    fi
}

# some images (e.g. asahi alarm) enable systemd-networkd alongside
# NetworkManager. both then fight over the same interfaces, and
# systemd-networkd-wait-online times out for 2 minutes on every boot
ensure_networkd_disabled_for_networkmanager() {
    log_info "Ensuring systemd-networkd does not run alongside NetworkManager"
    if ! systemctl is-enabled NetworkManager.service >/dev/null 2>&1; then
        log_ok "NetworkManager is not enabled, leaving systemd-networkd alone"
        return
    fi
    # disabling the service also disables its sockets, network-generator and
    # wait-online via Also=. wait-online is still checked on its own, since it
    # can be enabled without the service
    local units="systemd-networkd.service systemd-networkd-wait-online.service"
    local enabled_units=""
    for unit in $units; do
        if systemctl is-enabled "$unit" >/dev/null 2>&1; then
            enabled_units="$enabled_units $unit"
        fi
    done
    if [ -n "$enabled_units" ]; then
        # shellcheck disable=SC2086
        systemctl disable $enabled_units || error_exit "Failed to disable systemd-networkd"
        log_changed "Disabled$enabled_units"
    else
        log_ok "systemd-networkd is already disabled"
    fi
}

ensure_ntp_enabled() {
    log_info "Ensuring NTP and systemd-timesyncd are enabled"
    if ! systemctl is-enabled systemd-timesyncd >/dev/null 2>&1; then
        timedatectl set-ntp true
        systemctl enable --now systemd-timesyncd
        log_changed "Enabled NTP and systemd-timesyncd system-wide"
    else
        log_ok "NTP and systemd-timesyncd are already enabled"
    fi
}

ensure_zram_swap_configured() {
    log_info "Ensuring zram swap is configured"
    local config_file="/etc/systemd/zram-generator.conf"
    local sysctl_file="/etc/sysctl.d/99-vm-zram-parameters.conf"
    if [ ! -f "$config_file" ]; then
        cat <<'EOF' >"$config_file" || error_exit "Failed to write $config_file"
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
        systemctl daemon-reload
        systemctl start systemd-zram-setup@zram0.service || error_exit "Failed to start zram swap"
        log_changed "Configured and started zram swap"
    else
        log_ok "zram swap is already configured"
    fi
    # recommended tuning for in-memory swap, see arch wiki zram article:
    # - swappiness (0-200) is the relative cost of swapping anon memory vs
    #   dropping file cache (100 = equal). zram is cheaper than disk I/O, so
    #   180 swaps idle anon pages eagerly and keeps more file cache. also
    #   applies to disk swap on machines that have it, but zram has higher
    #   priority so it fills first
    # - watermark_boost_factor = 0 disables extra reclaim after fragmentation
    #   events, which would needlessly push pages into zram
    # - watermark_scale_factor = 125 starts background reclaim (kswapd)
    #   earlier, so compression happens there instead of stalling the
    #   allocating process
    # - page-cluster = 0 reads one page per swap-in instead of 8; readahead
    #   only helps on disks with seek cost, zram has none
    if [ ! -f "$sysctl_file" ]; then
        cat <<'EOF' >"$sysctl_file" || error_exit "Failed to write $sysctl_file"
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
        sysctl -q -p "$sysctl_file"
        log_changed "Applied zram sysctl tuning"
    else
        log_ok "zram sysctl tuning is already applied"
    fi
}

ensure_earlyoom_enabled() {
    # systemd-oomd kills whole cgroups, which would take down the entire
    # hyprland session scope, so use earlyoom to kill single processes instead
    log_info "Ensuring earlyoom is configured and enabled"
    local config_file="/etc/default/earlyoom"
    local wanted_args='EARLYOOM_ARGS="-r 3600 -n --avoid ^(Hyprland|waybar|swaync|kitty|systemd|sshd)$"'
    if ! grep -qxF "$wanted_args" "$config_file" 2>/dev/null; then
        echo "$wanted_args" >"$config_file" || error_exit "Failed to write $config_file"
        systemctl restart earlyoom.service 2>/dev/null
        log_changed "Configured earlyoom"
    else
        log_ok "earlyoom is already configured"
    fi
    if ! systemctl is-enabled earlyoom.service >/dev/null 2>&1; then
        systemctl enable --now earlyoom.service
        log_changed "Enabled earlyoom.service system-wide"
    else
        log_ok "earlyoom service is already enabled"
    fi
}

# weekly TRIM tells the SSD which blocks are free, so its garbage collection
# does not keep copying stale data. Persistent=true in the shipped timer
# catches up after boot or resume if the laptop was off at the scheduled time
ensure_fstrim_timer_enabled() {
    log_info "Ensuring fstrim.timer is enabled"
    if ! systemctl is-enabled fstrim.timer >/dev/null 2>&1; then
        systemctl enable --now fstrim.timer || error_exit "Failed to enable fstrim.timer"
        log_changed "Enabled fstrim.timer system-wide"
    else
        log_ok "fstrim.timer is already enabled"
    fi
}

# dm-crypt drops discards by default, so fstrim would not reach the SSD.
# allowing them leaks which blocks are unused (not their content), which is
# acceptable here. applies to all luks devices unlocked in the initramfs and
# takes effect on the next boot
ensure_luks_discard_allowed() {
    local grub_file="/etc/default/grub"
    if ! grep -q '^GRUB_CMDLINE_LINUX=.*rd\.luks\.name=' "$grub_file" 2>/dev/null; then
        return
    fi
    log_info "Ensuring discards are allowed on the LUKS root"
    if grep -q '^GRUB_CMDLINE_LINUX=.*rd\.luks\.options=[^ "]*discard' "$grub_file"; then
        log_ok "LUKS discards are already allowed"
    else
        sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 rd.luks.options=discard"/' "$grub_file" ||
            error_exit "Failed to add rd.luks.options=discard to $grub_file"
        grub-mkconfig -o /boot/grub/grub.cfg || error_exit "Failed to regenerate grub config"
        log_changed "Allowed LUKS discards via rd.luks.options=discard (active after reboot)"
    fi
}

# make builds serially without -j. makepkg sources its config as bash on every
# build, so $(nproc) is evaluated then and matches each machine's thread count
ensure_makeflags_use_all_threads() {
    log_info "Ensuring makepkg builds with all threads"
    local config_file="/etc/makepkg.conf.d/norisa.conf"
    # shellcheck disable=SC2016 # nproc is expanded by makepkg, not here
    local content='MAKEFLAGS="-j$(nproc)"'
    if [[ ! -f "$config_file" ]] || [[ "$(cat "$config_file")" != "$content" ]]; then
        mkdir -p /etc/makepkg.conf.d || error_exit "Failed to create /etc/makepkg.conf.d"
        printf "%s\n" "$content" >"$config_file" || error_exit "Failed to write $config_file"
        log_changed "Set MAKEFLAGS to use all threads"
    else
        log_ok "MAKEFLAGS already use all threads"
    fi
}

# keep one older version of each package for downgrades and drop the cache of
# uninstalled packages. the default (-r) keeps 3 versions
ensure_paccache_timer_configured() {
    log_info "Ensuring paccache.timer is configured and enabled"
    local dropin_dir="/etc/systemd/system/paccache.service.d"
    local dropin_file="$dropin_dir/norisa.conf"
    local content="[Service]
ExecStart=
ExecStart=/usr/bin/paccache -rk2
ExecStart=/usr/bin/paccache -ruk0"
    if [[ ! -f "$dropin_file" ]] || [[ "$(cat "$dropin_file")" != "$content" ]]; then
        mkdir -p "$dropin_dir" || error_exit "Failed to create $dropin_dir"
        printf "%s\n" "$content" >"$dropin_file" || error_exit "Failed to write $dropin_file"
        systemctl daemon-reload
        log_changed "Configured paccache to keep 2 versions and drop uninstalled packages"
    else
        log_ok "paccache is already configured"
    fi
    if ! systemctl is-enabled paccache.timer >/dev/null 2>&1; then
        systemctl enable --now paccache.timer || error_exit "Failed to enable paccache.timer"
        log_changed "Enabled paccache.timer system-wide"
    else
        log_ok "paccache.timer is already enabled"
    fi
}

# the default limit is 10% of the filesystem capped at 4G. 1G keeps roughly two
# months of logs, enough to compare behaviour before and after an update
ensure_journald_size_limited() {
    log_info "Ensuring journald size is limited"
    local dropin_dir="/etc/systemd/journald.conf.d"
    local dropin_file="$dropin_dir/norisa.conf"
    local content="[Journal]
SystemMaxUse=1G"
    if [[ ! -f "$dropin_file" ]] || [[ "$(cat "$dropin_file")" != "$content" ]]; then
        mkdir -p "$dropin_dir" || error_exit "Failed to create $dropin_dir"
        printf "%s\n" "$content" >"$dropin_file" || error_exit "Failed to write $dropin_file"
        systemctl restart systemd-journald || error_exit "Failed to restart systemd-journald"
        log_changed "Limited journald to 1G"
    else
        log_ok "journald size is already limited"
    fi
}

# smartd checks drive health (critical warning, spare, media errors) every 30
# min. there is no mailer, so warnings are sent over the system bus and shown
# by systembus-notify in the user session, like earlyoom kills. temperature
# only warns at 70 C, without logging every change. unsupported checks (e.g.
# the error log and self-tests on apple nvme) are skipped by smartd itself
ensure_smartd_configured() {
    log_info "Ensuring smartd is configured and enabled"
    local config_file="/etc/smartd.conf"
    local notify_script="/usr/local/bin/smartd-notify"
    local wanted_line="DEVICESCAN -a -W 0,0,70 -m <nomailer> -M exec $notify_script"
    # shellcheck disable=SC2016 # SMARTD_* expand when the script runs
    local notify_content='#!/bin/sh
# called by smartd (-M exec) with the warning in SMARTD_* env vars
exec dbus-send --system / net.nuetzlich.SystemNotifications.Notify \
    "string:SMART $SMARTD_FAILTYPE on $SMARTD_DEVICE" "string:$SMARTD_MESSAGE"'
    local changed=false

    if [[ ! -f "$notify_script" ]] ||
        [[ "$(cat "$notify_script")" != "$notify_content" ]] ||
        [[ "$(stat -c "%a" "$notify_script")" != "755" ]]; then
        printf "%s\n" "$notify_content" >"$notify_script" || error_exit "Failed to write $notify_script"
        chmod 755 "$notify_script"
        changed=true
    fi
    if ! grep -qxF "$wanted_line" "$config_file"; then
        # smartd ignores everything after the first DEVICESCAN line
        if grep -q "^DEVICESCAN" "$config_file"; then
            sed -i "0,/^DEVICESCAN.*/s||$wanted_line|" "$config_file" ||
                error_exit "Failed to update $config_file"
        else
            echo "$wanted_line" >>"$config_file" || error_exit "Failed to update $config_file"
        fi
        changed=true
    fi
    if [ "$changed" = true ]; then
        systemctl try-restart smartd.service
        log_changed "Configured smartd with desktop notifications"
    else
        log_ok "smartd is already configured"
    fi

    if ! systemctl is-enabled smartd.service >/dev/null 2>&1; then
        systemctl enable --now smartd.service || error_exit "Failed to enable smartd.service"
        log_changed "Enabled smartd.service system-wide"
    else
        log_ok "smartd service is already enabled"
    fi
}

# keep caches and dependency trees out of the locate database, they are the
# bulk of all entries and never what you search for
ensure_updatedb_prunenames_set() {
    log_info "Ensuring updatedb skips cache and dependency directories"
    local config_file="/etc/updatedb.conf"
    local wanted_line='PRUNENAMES = ".git .hg .svn node_modules __pycache__ .venv .cache"'
    if grep -qxF "$wanted_line" "$config_file"; then
        log_ok "updatedb PRUNENAMES are already set"
    elif grep -q "^PRUNENAMES" "$config_file"; then
        sed -i "s|^PRUNENAMES.*|$wanted_line|" "$config_file" || error_exit "Failed to update $config_file"
        log_changed "Updated updatedb PRUNENAMES"
    else
        echo "$wanted_line" >>"$config_file" || error_exit "Failed to update $config_file"
        log_changed "Added updatedb PRUNENAMES"
    fi
}

has_system_battery() {
    # peripherals like wireless mice also report a battery, but with
    # scope=Device, so they do not make a desktop count as a laptop
    local supply
    for supply in /sys/class/power_supply/*; do
        if [ "$(cat "$supply/type" 2>/dev/null)" = "Battery" ] &&
            [ "$(cat "$supply/scope" 2>/dev/null)" != "Device" ]; then
            return 0
        fi
    done
    return 1
}

# only worth it on battery: on AC tlp uses performance settings anyway, but
# its usb autosuspend stays active and can make some usb devices drop out.
# tlp manages radio state itself, so systemd-rfkill is masked as its docs say
ensure_tlp_enabled_on_laptops() {
    if [ "$ARCH" != "x86_64" ]; then
        return
    fi
    log_info "Ensuring tlp is enabled on laptops"
    if ! has_system_battery; then
        log_ok "No system battery found, leaving tlp disabled"
        return
    fi
    local unit
    for unit in systemd-rfkill.service systemd-rfkill.socket; do
        if [ "$(systemctl is-enabled "$unit" 2>/dev/null)" != "masked" ]; then
            systemctl mask "$unit" || error_exit "Failed to mask $unit"
            log_changed "Masked $unit for tlp"
        else
            log_ok "$unit is already masked"
        fi
    done
    if ! systemctl is-enabled tlp.service >/dev/null 2>&1; then
        systemctl enable --now tlp.service || error_exit "Failed to enable tlp.service"
        log_changed "Enabled tlp.service system-wide"
    else
        log_ok "tlp service is already enabled"
    fi
}

ensure_php_extensions_enabled() {
    log_info "Ensuring required PHP extensions are enabled"
    local changed=false
    if [ -f /etc/php/php.ini ]; then
        for ext in iconv mbstring zip; do
            if grep -q "^;extension=${ext}" /etc/php/php.ini; then
                sed -i "s/^;extension=${ext}/extension=${ext}/" /etc/php/php.ini
                changed=true
            fi
        done
        if [ "$changed" = true ]; then
            log_changed "Enabled required PHP extensions"
        else
            log_ok "Required PHP extensions are already enabled"
        fi
    else
        log_ok "PHP is not installed yet or /etc/php/php.ini is missing"
    fi
}

ensure_history_file_not_present() {
    if [ -f "$1" ]; then
        rm "$1"
        log_changed "$2 history file was removed"
    else
        log_ok "No $2 history file is present"
    fi
}

cleanup_home() {
    log_info "Cleaning up \$HOME"
    local bash_history="/home/$username/.bash_history"
    local less_history="/home/$username/.lesshst"
    ensure_history_file_not_present "$bash_history" bash
    ensure_history_file_not_present "$less_history" less
}

ensure_dns_priority_in_nsswitch() {
    log_info "Ensuring DNS priority in /etc/nsswitch.conf"
    if grep -q "hosts:.*dns.*resolve" /etc/nsswitch.conf; then
        log_ok "DNS priority is already correct in nsswitch.conf"
    else
        cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
        sed -i 's/^hosts:.*/hosts: mymachines files dns resolve [!UNAVAIL=return] myhostname/' /etc/nsswitch.conf || error_exit "Failed to set new config options on /etc/nsswitch.conf"
        log_changed "Updated hosts config in nsswitch.conf"
    fi
}

ensure_libva_driver_set_to_v4l2_request() {
    log_info "Ensuring LIBVA_DRIVER_NAME=v4l2_request in /etc/environment"
    if grep -q "^LIBVA_DRIVER_NAME=v4l2_request$" /etc/environment; then
        log_ok "LIBVA_DRIVER_NAME is already set to v4l2_request"
    elif grep -q "^LIBVA_DRIVER_NAME=" /etc/environment; then
        sed -i 's/^LIBVA_DRIVER_NAME=.*/LIBVA_DRIVER_NAME=v4l2_request/' /etc/environment || error_exit "Failed to update LIBVA_DRIVER_NAME in /etc/environment"
        log_changed "Changed LIBVA_DRIVER_NAME to v4l2_request in /etc/environment"
    else
        echo "LIBVA_DRIVER_NAME=v4l2_request" >>/etc/environment || error_exit "Failed to add LIBVA_DRIVER_NAME to /etc/environment"
        log_changed "Added LIBVA_DRIVER_NAME=v4l2_request to /etc/environment"
    fi
}

ensure_mpv_uses_opengl() {
    # vulkan dmabuf import of vaapi frames shows wrong colors on asahi
    log_info "Ensuring mpv uses gpu-api=opengl in /etc/mpv/mpv.conf"
    if grep -q "^gpu-api=opengl$" /etc/mpv/mpv.conf 2>/dev/null; then
        log_ok "mpv already uses gpu-api=opengl"
    else
        mkdir -p /etc/mpv || error_exit "Failed to create /etc/mpv"
        echo "gpu-api=opengl" >>/etc/mpv/mpv.conf || error_exit "Failed to add gpu-api=opengl to /etc/mpv/mpv.conf"
        log_changed "Added gpu-api=opengl to /etc/mpv/mpv.conf"
    fi
}

ensure_dotfiles_are_fetched_and_applied() {
    log_info "Ensuring dotfiles are fetched and applied"
    if [ ! -d /home/"$username"/dox/src/dotfiles ]; then
        echo -e "\e[0;30;34mFetching dotfiles ...\e[0m"
        cd_into /home/"$username"/dox/src
        setup_temporary_doas
        doas -u "$username" git clone https://git.noahvogt.com/noah/dotfiles.git || error_exit "Failed to clone dotfiles git repository"
        cd_into /home/"$username"/dox/src/dotfiles
        doas -u "$username" /home/"$username"/dox/src/dotfiles/apply-dotfiles
        log_changed "dotfiles were fetched and applied successfully"
    else
        log_ok "dotfiles were already fetched"
    fi
}

ensure_hyprland_systemd_target_created() {
    log_info "Ensuring hyprland-session.target is created for xdg-desktop-portal"
    local target_dir="/home/$username/.config/systemd/user"
    local target_file="$target_dir/hyprland-session.target"
    if [ ! -f "$target_file" ]; then
        mkdir -vp "$target_dir"
        cat <<'EOF' >"$target_file"
[Unit]
Description=Hyprland compositor session
Documentation=man:systemd.special(7)
BindsTo=graphical-session.target
Wants=graphical-session-pre.target
After=graphical-session-pre.target
EOF
        chown -R "$username:users" "/home/$username/.config/systemd"
        log_changed "Created hyprland-session.target"
    else
        log_ok "hyprland-session.target already exists"
    fi
}

ensure_pkgs_installed "$BASE_PKGS" "some basic" "pacman"

ensure_user_selected
# the temporary doas config grants passwordless root to wheel, so restore the
# final one even if a step exits early, until it is set regularly below
trap setup_final_doas EXIT
ensure_needed_dirs_created
ensure_user_is_part_of_needed_groups
ensure_sudo_is_symlinked_to_doas

ensure_pacman_color_enabled
ensure_multilib_enabled
ensure_chaotic_aur_installed
ensure_paru_installed
ensure_paru_pkgbuild_repo_configured
ensure_makeflags_use_all_threads

ensure_pkgs_installed "$MAIN_PKGS" "main packages" "pacman"
ensure_user_is_part_of_docker_group
ensure_php_extensions_enabled
ensure_pkgs_installed "$AUR_PKGS" "AUR" "doas -u $username paru --mflags --ignorearch"
ensure_user_is_part_of_wireshark_group
ensure_dotfiles_are_fetched_and_applied

ensure_global_zsh_installed
ensure_history_file_exists
ensure_login_shell_is_zsh
setup_final_doas
trap - EXIT
ensure_bluetooth_service_enabled
ensure_docker_socket_enabled
ensure_networkd_disabled_for_networkmanager
ensure_ntp_enabled
ensure_zram_swap_configured
ensure_earlyoom_enabled
ensure_fstrim_timer_enabled
ensure_luks_discard_allowed
ensure_paccache_timer_configured
ensure_journald_size_limited
ensure_smartd_configured
ensure_updatedb_prunenames_set
ensure_tlp_enabled_on_laptops
ensure_dns_priority_in_nsswitch
ensure_hyprland_systemd_target_created
if [ "$IS_APPLE_M1" = "yes" ]; then
    ensure_libva_driver_set_to_v4l2_request
    ensure_mpv_uses_opengl
fi
cleanup_home
