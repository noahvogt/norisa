#!/bin/bash

# ASSUMED STATE OF TARGET SYSTEM:
# - internet access
# - root user login
# - ~30 GB of free disk space
# working 1.) base 2.) linux packages

# Install opendoas and (base-devel, devtools minus sudo), libxft
echo -e "\e[0;30;34mInstalling some initial packages ...\e[0m"
pacman -Sy --noconfirm --needed archlinux-keyring opendoas autoconf automake binutils bison debugedit fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which libxft breezy coreutils curl diffutils expac git glow gum jq mercurial openssh parallel reuse rsync subversion util-linux || {
    echo -e "\e[0;30;101m Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n\e[0m"
    exit 1
}

pacman_error_exit() {
    echo -e "\e[0;30;101m Error: Pacman command was not successfull. Exiting ...\e[0m"
    exit 1
}

compile_error_exit() {
    echo -e "\e[0;30;101m Error: Compilation command was not successfull. Exiting ...\e[0m"
    exit 1
}

cd_into() {
    cd "$1" || cd_error_exit "$1"
}

cd_error_exit() {
    echo -e "\e[0;30;46m Current working directory: \e[0m"
    pwd
    echo -e "\e[0;30;101m Error: Could not change into '$1'. Exiting ...\e[0m"
    exit 1
}

setup_temporary_doas() {
    echo -e "\e[0;30;34mSetting up temporary doas config ...\e[0m"
    printf "permit nopass :wheel
permit nopass root as $username\n" >/etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
}

setup_final_doas() {
    echo -e "\e[0;30;34mSetting up final doas config ...\e[0m"
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

add_user_to_groups() {
    if ! groups "$username" | grep "input" | grep -q "video"; then
        echo -e "\e[0;30;34mAdding $username to video and input groups ... \e[0m"
        usermod -aG video "$username"
        usermod -aG input "$username"
    fi
}

ensure_history_file_exists() {
    if ! [ -f /home/"$username"/.cache/zsh/history ]; then
        echo -e "\e[0;30;34mEnsuring initial zsh history file exists ...\e[0m"
        mkdir -vp /home/"$username"/.cache/zsh
        touch /home/"$username"/.cache/zsh/history
    fi
}

change_login_shell_to_zsh() {
    if ! grep "^$username.*::/home/$username" /etc/passwd | sed 's/^.*://' |
        grep -q "^$(which zsh)$"; then
        echo -e "\e[0;30;34mSetting default shell to $(which zsh)...\e[0m"
        chsh -s "$(which zsh)" "$username" || exit 1
    fi
}

make_user_owner_of_HOME_and_mnt_dirs() {
    echo -e "\e[0;30;34mChanging ownership of /home/$username + /mnt ...\e[0m"
    chown -R "$username":users /home/"$username"/
    chown -R "$username":users /mnt/
}

# Check if /home is not empty
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

# Create ~/ Directories
echo -e "\e[0;30;34mCreating ~/ directories ...\e[0m"
mkdir -vp /home/"$username"/dox /home/"$username"/pix /home/"$username"/dl
mkdir -vp /home/"$username"/vids /home/"$username"/mus
mkdir -vp /home/"$username"/.local/bin /home/"$username"/.config
mkdir -vp /home/"$username"/.local/share /home/"$username"/.local/src

if [[ "$want_new_user" =~ ^[yY]$ ]]; then
    echo -e "\e[0;30;34mChanging ownership of /home/$username ...\e[0m"
    chown -R "$username":users /home/"$username"/* /home/"$username"/.*
fi

setup_temporary_doas

add_user_to_groups

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

# Sync all Package db's
pacman -Syyy

# Install AUR Helper (paru as paru-bin is out-of-date)
if ! pacman -Q | grep -q paru; then
    echo -e "\e[0;30;34mInstalling AUR helper (paru) ...\e[0m"
    pacman -S --noconfirm paru
fi

# Symlink sudo to doas for Compatibility with paru and hardcoded PKGBUILDs
echo -e "\e[0;30;34mSymlinking sudo to doas ...\e[0m"
if [ ! -f /usr/bin/sudo ]; then
    ln -s /usr/bin/doas /usr/bin/sudo
fi

# Fetch + Apply Dotfiles
if [ ! -d /home/"$username"/.local/src/dotfiles ]; then
    echo -e "\e[0;30;34mFetching dotfiles ...\e[0m"
    cd_into /home/"$username"/.local/src
    while true; do
        git clone https://git.noahvogt.com/noah/dotfiles.git && break
    done
fi
cd_into /home/"$username"/.local/src/dotfiles
echo -e "\e[0;30;34mApplying dotfiles ...\e[0m"
doas -u "$username" /home/"$username"/.local/src/dotfiles/apply-dotfiles

# Download Packages from the Official Repos
# TODO: add element-desktop back
echo -e "\e[0;30;34mInstalling packages from official repos ...\e[0m"
pacman -S --noconfirm --needed xorg-server xf86-video-vesa xf86-video-fbdev shellcheck neovim ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip python mupdf-gl mediainfo highlight pulseaudio-alsa pulsemixer pamixer ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick gimp xorg-setxkbmap wavemon texlive dash unifetch htop wireless_tools alsa-utils acpi zip libreoffice nm-connection-editor dunst libnotify dosfstools mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat nomacs pcmanfm openbsd-netcat powertop mupdf-tools nomacs stow zsh-autosuggestions xf86-video-amdgpu xf86-video-intel xf86-video-nouveau npm fzf unclutter ccls mpd mpc ncmpcpp pavucontrol strawberry smartmontools firefox python-pynvim python-pylint tesseract-data-deu tesseract-data-eng keepassxc ueberzug img2pdf dust ctags python-wand python-termcolor python-black jdk-openjdk ripgrep lf ungoogled-chromium-bin ttf-jetbrains-mono-nerd foliate coreutils curl fish foot fuzzel gjs gnome-bluetooth-3.0 gnome-control-center gnome-keyring gobject-introspection grim gtk3 gtk-layer-shell libdbusmenu-gtk3 meson nlohmann-json plasma-browser-integration playerctl polkit-gnome python-pywal sassc slurp swayidle typescript xorg-xrandr webp-pixbuf-loader wireplumber yad ydotool gojq hyprland python-poetry python-build python-pillow ttf-material-symbols-variable-git ttf-space-mono-nerd wlogout kitty shfmt ruff luarocks rust-analyzer hyprland-guiutils waybar socat hyprlock brave-bin clang swaync bat wl-clipboard syncthing python-debugpy ghostty awww kitty tokei gemini-cli hypridle tlp || pacman_error_exit

# Install AUR Packages
echo -e "\e[0;30;34mInstalling packages from AUR ...\e[0m"
doas -u "$username" paru -S --noconfirm --needed simple-mtpfs redshift dashbinsh cspell-lsp doasedit nodejs-cspell nvim-lazy google-java-format lexend-fonts-git || pacman_error_exit

# Set Global zshenv
echo -e "\e[0;30;34mSetting global zshenv ...\e[0m"
mkdir -vp /etc/zsh
echo "export ZDOTDIR=\$HOME/.config/zsh" >/etc/zsh/zshenv

ensure_history_file_exists

make_user_owner_of_HOME_and_mnt_dirs

change_login_shell_to_zsh

setup_final_doas

# ~/ Cleanup
echo -e "\e[0;30;34mCleaning up \$HOME ...\e[0m"
for f in /home/"$username"/.bash*; do
    [ -f "$f" ] && rm "$f"
done
for f in /home/"$username"/.less*; do
    [ -f "$f" ] && rm "$f"
done
