#!/bin/bash

# install git, vim, opendoas and (base-devel minus sudo)
echo -e "\e[0;30;34mInstalling some packages ...\e[0m"
pacman -Sy --noconfirm --needed git vim opendoas autoconf automake binutils bison fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which || { echo -e "\e[0;30;101m Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n\e[0m"; exit 1; }

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
permit nopass root as $username\n" > /etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
}

setup_final_doas() {
    echo -e "\e[0;30;34mSetting up final doas config ...\e[0m"
    printf "permit persist :wheel
permit nopass $username as root cmd mount
permit nopass $username as root cmd umount
permit nopass root as $username\n" > /etc/doas.conf
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

# give info if /home is not empty
if [ "$(ls -A /home)" ]; then
    echo -e "\e[0;30;46m /home/ not empty, human users already available \e[0m"
fi

while true; do
    echo -e "\e[0;30;42m Do you want to create a new user? [y/n] \e[0m"
    read -rp " >>> " want_new_user
    if echo "$want_new_user" | grep -q "y\|Y"; then
        create_new_user; break
    elif echo "$want_new_user" | grep -q "n\|N"; then
        choose_user; break
    fi
done

# create ~/ directories
echo -e "\e[0;30;34mCreating ~/ directories ...\e[0m"
mkdir -vp /home/"$username"/dox /home/"$username"/pix /home/"$username"/dl
mkdir -vp /home/"$username"/vids /home/"$username"/mus
mkdir -vp /home/"$username"/.local/bin /home/"$username"/.config
mkdir -vp /home/"$username"/.local/share /home/"$username"/.local/src

echo -e "\e[0;30;34mChanging ownership of /home/$username ...\e[0m"
chown -R "$username":users /home/"$username"/* /home/"$username"/.*

setup_temporary_doas


# install aur helper (paru)
if ! pacman -Q | grep -q paru; then
    echo -e "\e[0;30;34mInstalling AUR helper (paru) ...\e[0m"
    cd_into /home/"$username"/.local/src
    pacman -S --noconfirm --needed asp bat devtools || pacman_error_exit
    curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/paru-bin.tar.gz &&
    tar xvf paru-bin.tar.gz
    cd_into /home/"$username" && chown -R "$username":wheel /home/"$username"/.local/src/ && cd_into .local/src
    cd_into paru-bin
    doas -u "$username" makepkg --noconfirm -si || pacman_error_exit
    rm /home/"$username"/.local/src/paru-bin.tar.gz
fi

# need to use piped yes as --noconfirm doesn't work with package conflicts
if ! pacman -Q | grep -q libxft-bgra; then
    echo -e "\e[0;30;34mInstalling libxft-bgra ...\e[0m"
    yes | doas -u "$username" paru -S --needed libxft-bgra || pacman_error_exit
fi

# fetch dotfiles repo + apply dotfiles
if [ ! -d /home/"$username"/.local/src/dotfiles ]; then
    echo -e "\e[0;30;34mFetching dotfiles ...\e[0m"
    cd_into /home/"$username"/.local/src
    git clone https://github.com/noahvogt/dotfiles.git
fi
c
d_into /home/"$username"/.local/src/dotfiles
echo -e "\e[0;30;34mApplying dotfiles ...\e[0m"
doas -u "$username" /home/"$username"/.local/src/dotfiles/apply-dotfiles

# download packages from the official repos
echo -e "\e[0;30;34mInstalling packages from official repos ...\e[0m"
pacman -S --noconfirm --needed xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot xbindkeys xf86-video-vesa xf86-video-fbdev libxinerama geogebra shellcheck neovim ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip python mupdf-gl mediainfo highlight pulseaudio-alsa pulsemixer pamixer ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick gimp xorg-setxkbmap wavemon texlive-most dash neofetch htop wireless_tools alsa-utils acpi zip libreoffice nm-connection-editor dunst libnotify dosfstools tlp mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat nomacs pcmanfm openbsd-netcat powertop mupdf-tools nomacs stow zsh-autosuggestions xf86-video-amdgpu xf86-video-intel xf86-video-nouveau npm fzf unclutter tlp ccls mpd mpc ncmpcpp pavucontrol strawberry smartmontools firefox python-pynvim python-pylint element-desktop tesseract-data-deu tesseract-data-eng keepassxc ueberzug img2pdf || pacman_error_exit

# install aur packages
echo -e "\e[0;30;34mInstalling packages from AUR ...\e[0m"
doas -u "$username" paru -S --noconfirm --needed betterlockscreen simple-mtpfs redshift dashbinsh devour vim-plug lf-bin picom-jonaburg-fix doasedit jdk-openjdk-xdg openssh-dotconfig wget-xdg networkmanager-openvpn-xdg abook-configdir ungoogled-chromium-xdg-bin nerd-fonts-jetbrains-mono-160 electron-xdg-bin yarn-xdg-bin chromium-extension-clearurls chromium-extension-copy-url-on-hover-bin chromium-extension-decentraleyes chromium-extension-history-disabler-bin chromium-extension-https-everywhere chromium-extension-keepassxc-browser-bin chromium-extension-return-youtube-dislike chromium-extension-rggl-bin chromium-extension-ublock-origin-bin || pacman_error_exit

suckless_build() {
    if [ ! -d /home/"$username"/.local/src/"$1" ]; then
        echo -e "\e[0;30;34mFetching "$1" ...\e[0m"
        cd_into /home/"$username"/.local/src
        git clone https://github.com/noahvogt/"$1".git
    fi

    cd_into /home/"$username"/.local/src/"$1"

    if ! command -v "$1" > /dev/null; then
        echo -e "\e[0;30;34mCompiling "$1" ...\e[0m"
        make install || compile_error_exit
    fi
}

dwm_build() {
    if [ ! -d /home/"$username"/.local/src/"$1" ]; then
        echo -e "\e[0;30;34mFetching "$1" ...\e[0m"
        cd_into /home/"$username"/.local/src
        git clone https://github.com/noahvogt/"$1".git --depth 1
    fi

    mv /home/"$username"/.local/src/"$1" /home/"$username"/.config
    cd_into /home/"$username"/.config/"$1"

    if ! command -v "$1" > /dev/null; then
        echo -e "\e[0;30;34mCompiling "$1" ...\e[0m"
        make install || compile_error_exit
    fi
}

dwm_build chadwm
suckless_build st
suckless_build dwmblocks
suckless_build dmenu

# set global zshenv
echo -e "\e[0;30;34mSetting global zshenv ...\e[0m"
mkdir -vp /etc/zsh
echo "export ZDOTDIR=\$HOME/.config/zsh" > /etc/zsh/zshenv

# make initial history file
echo -e "\e[0;30;34mSetting initial zsh history file ...\e[0m"
mkdir -vp /home/"$username"/.cache/zsh
[ -f /home/"$username"/.cache/zsh/history ] ||
    touch /home/"$username"/.cache/zsh/history

# make user to owner of ~/ and /mnt/
echo -e "\e[0;30;34mChanging ownership of /home/$username + /mnt ...\e[0m"
chown -R "$username":users /home/"$username"/
chown -R "$username":users /mnt/

# change shell to zsh
echo -e "\e[0;30;34mSetting default shell to $(which zsh)...\e[0m"
if ! grep "^$username.*::/home/$username" /etc/passwd | sed 's/^.*://' | \
    grep -q "^$(which zsh)$"; then
    while true; do
        doas -u "$username" chsh -s "$(which zsh)" && break
    done
fi

# enable tap to click
echo -e "\e[0;30;34mEnabling tap to click ...\e[0m"
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    # Enable left mouse button by tapping
    Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

setup_final_doas

# cleanup
echo -e "\e[0;30;34mCleaning up ...\e[0m"
ls -A /home/"$username" | grep -q "\.bash" && rm /home/"$username"/.bash*
ls -A /home/"$username" | grep -q "\.less" && rm /home/"$username"/.less*
