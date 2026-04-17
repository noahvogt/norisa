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
if [ "$ARCH" = "x86_64" ]; then
    ARCH_PKGS="xf86-video-vesa xf86-video-fbdev xf86-video-amdgpu xf86-video-intel xf86-video-nouveau ungoogled-chromium-bin obs-studio brave-bin ghostty ttf-material-symbols-variable-git nomacs wlogout unifetch shellcheck yt-dlp"
    ARCH_AUR_PKGS="simple-mtpfs google-java-format code2prompt-bin"
else
    # Asahi/ARM specific or generic alternatives
    ARCH_PKGS="chromium"
    ARCH_AUR_PKGS="unifetch shellcheck-bin yt-dlp-git logseq-desktop-bin code2prompt wlogout"
fi

readonly MAIN_PKGS="xorg-server neovim ranger xournalpp ffmpeg sxiv arandr man-db brightnessctl unzip python mupdf-gl mediainfo highlight pipewire pipewire-pulse pipewire-alsa pipewire-audio wireplumber pulsemixer pamixer ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick gimp xorg-setxkbmap wavemon dash htop wireless_tools alsa-utils acpi zip libreoffice-fresh nm-connection-editor dunst libnotify dosfstools mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat pcmanfm openbsd-netcat powertop mupdf-tools stow zsh-autosuggestions npm fzf unclutter mpd mpc ncmpcpp pavucontrol strawberry smartmontools firefox python-pynvim python-pylint tesseract-data-deu tesseract-data-eng keepassxc img2pdf dust ctags python-wand python-termcolor python-black jdk-openjdk ripgrep lf ttf-jetbrains-mono-nerd foliate coreutils curl fish foot fuzzel gjs gnome-bluetooth-3.0 gnome-control-center gnome-keyring gobject-introspection grim gtk3 gtk-layer-shell libdbusmenu-gtk3 meson nlohmann-json plasma-browser-integration playerctl polkit-gnome python-pywal sassc slurp swayidle typescript xorg-xrandr webp-pixbuf-loader yad hyprland python-poetry python-build python-pillow ttf-space-mono-nerd kitty shfmt ruff luarocks rust-analyzer hyprland-guiutils waybar socat hyprlock clang swaync bat wl-clipboard syncthing python-debugpy awww kitty tokei gemini-cli hypridle tlp texlive-basic texlive-bibtexextra texlive-binextra texlive-context texlive-fontsextra texlive-fontsrecommended texlive-fontutils texlive-formatsextra texlive-games texlive-humanities texlive-latex texlive-latexextra texlive-latexrecommended texlive-luatex texlive-mathscience texlive-metapost texlive-music texlive-pictures texlive-plaingeneric texlive-pstricks texlive-publishers texlive-xetex libva-utils blueman woff2-font-awesome bind qt5-wayland qt6-wayland pre-commit python-pandas pyright python-beautifulsoup4 tree-sitter-cli jupyterlab python-httplib2 jdk11-openjdk zathura-pdf-mupdf imv rclone openconnect python-evdev tree python-seaborn mlocate fastfetch sqlx-cli biber $ARCH_PKGS"

readonly AUR_PKGS="redshift dashbinsh cspell-lsp doasedit-alternative nodejs-cspell nvim-lazy lexend-fonts-git xwaylandvideobridge jdtls gradle-autowrap localsend-bin python-sklearn-onnx $ARCH_AUR_PKGS"

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

ensure_history_file_exists() {
    log_info "Ensure history file exists"
    if ! [ -f /home/"$username"/.cache/zsh/history ]; then
        echo -e "\e[0;30;34mEnsuring initial zsh history file exists ...\e[0m"
        mkdir -vp /home/"$username"/.cache/zsh
        touch /home/"$username"/.cache/zsh/history
        log_changed "Created history file"
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
        "/home/$username/.local/bin"
        "/home/$username/.config"
        "/home/$username/.local/share"
        "/home/$username/.local/src"
        "/home/$username/.local/"
    )
    if ! chown -v "$username:users" "${needed_dirs[@]}" >/dev/null; then
        mkdir -Rvp "${needed_dirs[@]}"
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
    local bash_history="$username/.bash_history"
    local less_history="$username/.lesshst"
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

ensure_dotfiles_are_fetched_and_applied() {
    log_info "Ensuring dotfiles are fetched and applied"
    if [ ! -d /home/"$username"/.local/src/dotfiles ]; then
        echo -e "\e[0;30;34mFetching dotfiles ...\e[0m"
        cd_into /home/"$username"/.local/src
        git clone https://git.noahvogt.com/noah/dotfiles.git || error_exit "Failed to clone dotfiles git repository"
        cd_into /home/"$username"/.local/src/dotfiles
        setup_temporary_doas
        doas -u "$username" /home/"$username"/.local/src/dotfiles/apply-dotfiles
        log_changed "dotfiles were fetched and applied successfully"
    else
        log_ok "dotfiles were already fetched"
    fi
}

ensure_pkgs_installed "$BASE_PKGS" "some basic" "pacman"

ensure_user_selected
ensure_needed_dirs_created
ensure_user_is_part_of_needed_groups
ensure_sudo_is_symlinked_to_doas

ensure_chaotic_aur_installed
ensure_paru_installed

ensure_pkgs_installed "$MAIN_PKGS" "main packages" "pacman"
ensure_pkgs_installed "$AUR_PKGS" "AUR" "doas -u $username paru --mflags --ignorearch"
ensure_dotfiles_are_fetched_and_applied

ensure_global_zsh_installed
ensure_history_file_exists
ensure_login_shell_is_zsh
setup_final_doas
ensure_bluetooth_service_enabled
ensure_dns_priority_in_nsswitch
cleanup_home
