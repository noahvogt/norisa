#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# ASSUMED STATE OF TARGET SYSTEM:
# - internet access
# - root user login
# - ~30 GB of free disk space
# working 1.) base 2.) linux packages

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

# Install opendoas and (base-devel, devtools minus sudo), libxft
readonly BASE_PKGS="archlinux-keyring opendoas autoconf automake binutils bison debugedit fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which libxft breezy coreutils curl diffutils expac git glow gum jq mercurial openssh parallel reuse rsync subversion util-linux"

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
        "$3" -Sy --noconfirm --needed "$MISSING_PKGS" || pkg_install_error_exit
        log_changed "$2 packages are now installed"
    else
        log_ok "$2 packages are already installed"
    fi
}

setup_temporary_doas() {
    log_info "Setting up temporary doas config"
    printf "permit nopass :wheel
permit nopass root as $username\n" >/etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
}

setup_final_doas() {
    log_info "Setting up final doas config"
    printf "permit persist :wheel
permit nopass $username as root cmd mount
permit nopass $username as root cmd umount
permit nopass root as $username\n" >/etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
}

create_new_user() {
    echo -e "\e[0;30;42m Enter your desired username \e[0m"
    read -rp " >>> " username
    useradd -m -g users -G wheel "$username"
    while true; do
        passwd "$username" && break
    done
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
    fi
}

ensure_pkgs_installed "$BASE_PKGS" "some basic" "pacman"

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

ensure_user_selected

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
    )
    mkdir -vp "${needed_dirs[@]}"
    chown -v "$username:users" "${needed_dirs[@]}"
}

ensure_needed_dirs_created

setup_temporary_doas

ensure_user_is_part_of_needed_groups

# add xdg-repo
# if ! grep -q "^\s*\[xdg-repo\]\s*$" /etc/pacman.conf; then
#     echo -e "\e[0;30;34mAdding Noah's xdg-repo ...\e[0m"
#     pacman-key --recv-keys 7FA7BB604F2A4346 --keyserver keyserver.ubuntu.com
#     pacman-key --lsign-key 7FA7BB604F2A4346
#     echo "[xdg-repo]
# Server = https://git.noahvogt.com/noah/\$repo/raw/master/\$arch" >> /etc/pacman.conf
# fi

# Add chaotic-aur
if ! grep -q "^\s*\[chaotic-aur\]\s*$" /etc/pacman.conf; then
    echo -e "\e[0;30;34mAdding the chaotic aur repo ...\e[0m"
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo "[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist" >>/etc/pacman.conf
fi

# Install AUR Helper (paru as paru-bin is out-of-date)
ensure_paru_installed() {
    log_info "Ensuring paru is installed"
    if ! pacman -Q | grep -q paru; then
        pacman -S --noconfirm paru
        log_changed "Installed AUR helper (paru)"
    else
        log_ok "AUR helper (paru) is already installed"
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

ensure_dotfiles_are_fetched() {
    log_info "Ensuring dotfiles are fetched"
    if [ ! -d /home/"$username"/.local/src/dotfiles ]; then
        echo -e "\e[0;30;34mFetching dotfiles ...\e[0m"
        cd_into /home/"$username"/.local/src
        while true; do
            git clone https://git.noahvogt.com/noah/dotfiles.git && break
        done
        log_changed "dotfiles were fetched successfully"
    else
        log_ok "dotfiles were already fetched"
    fi
}

apply_dotfiles() {
    log_info "Applying dotfiles"
    cd_into /home/"$username"/.local/src/dotfiles
    doas -u "$username" /home/"$username"/.local/src/dotfiles/apply-dotfiles
}

apply_dotfiles

# TODO: add element-desktop back
MAIN_PKGS="xorg-server xf86-video-vesa xf86-video-fbdev shellcheck neovim ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip python mupdf-gl mediainfo highlight pulseaudio-alsa pulsemixer pamixer ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick gimp xorg-setxkbmap wavemon texlive dash unifetch htop wireless_tools alsa-utils acpi zip libreoffice nm-connection-editor dunst libnotify dosfstools mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat nomacs pcmanfm openbsd-netcat powertop mupdf-tools nomacs stow zsh-autosuggestions xf86-video-amdgpu xf86-video-intel xf86-video-nouveau npm fzf unclutter ccls mpd mpc ncmpcpp pavucontrol strawberry smartmontools firefox python-pynvim python-pylint tesseract-data-deu tesseract-data-eng keepassxc ueberzug img2pdf dust ctags python-wand python-termcolor python-black jdk-openjdk ripgrep lf ungoogled-chromium-bin ttf-jetbrains-mono-nerd foliate coreutils curl fish foot fuzzel gjs gnome-bluetooth-3.0 gnome-control-center gnome-keyring gobject-introspection grim gtk3 gtk-layer-shell libdbusmenu-gtk3 meson nlohmann-json plasma-browser-integration playerctl polkit-gnome python-pywal sassc slurp swayidle typescript xorg-xrandr webp-pixbuf-loader wireplumber yad ydotool gojq hyprland python-poetry python-build python-pillow ttf-material-symbols-variable-git ttf-space-mono-nerd wlogout kitty shfmt ruff luarocks rust-analyzer hyprland-guiutils waybar socat hyprlock brave-bin clang swaync bat wl-clipboard syncthing python-debugpy ghostty awww kitty tokei gemini-cli hypridle tlp"
ensure_history_file_exists "$MAIN_PKGS" "main packages" "pacman"

AUR_PKGS="simple-mtpfs redshift dashbinsh cspell-lsp doasedit nodejs-cspell nvim-lazy google-java-format lexend-fonts-git"
ensure_pkgs_installed "$AUR_PKGS" "AUR" "doas -u $username paru"

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

ensure_global_zsh_installed

ensure_history_file_exists

ensure_login_shell_is_zsh

setup_final_doas

cleanup_home() {
    log_info "Cleaning up \$HOME"
    for f in /home/"$username"/.bash*; do
        [ -f "$f" ] && rm "$f"
    done
    for f in /home/"$username"/.less*; do
        [ -f "$f" ] && rm "$f"
    done
}

cleanup_home
