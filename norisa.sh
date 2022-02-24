#!/bin/bash

# install git, vim, opendoas and (base-devel minus sudo)
pacman -Sy --noconfirm --needed git vim opendoas autoconf automake binutils bison fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which || { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }

setup_temporary_doas() {
    printf "permit nopass :wheel
permit nopass root as $username\n" > /etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
}

setup_final_doas() {
    printf "permit persist :wheel
permit nopass root as $username\n" > /etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
}

create_new_user() {
    read -rp "What is your desired username >>> " username
    useradd -m -g users -G wheel "$username"
    while true; do
        passwd "$username" && break
    done
}

choose_user() {
    echo "Available users:"
    ls /home
    while true; do
    read -rp "Enter in your chosen user >>> " username
        ls /home/ | grep -q "^$username$" && break
    done
}

# ask for new user if /home is not empty
if [ "$(ls -A /home)" ]; then
    echo "/home/ not empty, human users already available"
    while true; do
        read -rp "Do you want to create a new user? [y/n] " want_new_user
        if echo "$want_new_user" | grep -q "y\|Y"; then
            create_new_user; break
        elif echo "$want_new_user" | grep -q "n\|N"; then
            choose_user; break
        fi
    done
fi

# create ~/ folders
mkdir -p /home/"$username"/dox /home/"$username"/pix /home/"$username"/dl
mkdir -p /home/"$username"/vids /home/"$username"/mus
mkdir -p /home/"$username"/.local/bin /home/"$username"/.config
mkdir -p /home/"$username"/.local/share /home/"$username"/.local/src

chown -R "$username":users /home/"$username"/* /home/"$username"/.*

setup_temporary_doas

# install aur helper (paru)
if ! pacman -Q | grep -q paru; then
    cd /home/"$username"/.local/src || exit
    pacman -S --noconfirm --needed asp bat devtools
    curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/paru-bin.tar.gz &&
    tar xvf paru-bin.tar.gz
    cd /home/"$username" && chown -R "$username":wheel /home/"$username"/.local/src/ && cd .local/src || exit
    cd paru-bin || exit
    doas -u "$username" makepkg --noconfirm -si
    rm /home/"$username"/.local/src/paru-bin.tar.gz
fi

# need to use piped yes as --noconfirm doesn't work with package conflicts
if ! pacman -Q | grep -q libxft-bgra; then
    yes | doas -u "$username" paru -S --needed libxft-bgra
fi

# fetch dotfiles repo + apply dotfiles
if [ ! -d /home/"$username"/.local/src/dotfiles ]; then
    cd /home/"$username"/.local/src || exit
    git clone https://github.com/noahvogt/dotfiles.git
fi
cd /home/"$username"/.local/src/dotfiles || exit
doas -u "$username" /home/"$username"/.local/src/dotfiles/apply-dotfiles

# download packages from the official repos
pacman -S --noconfirm --needed xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot xbindkeys  xf86-video-modesetting xf86-video-vesa xf86-video-fbdev libxinerama jdk-openjdk geogebra shellcheck neovim ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip python mupdf-gl mediainfo highlight pulseaudio-alsa pulsemixer pamixer  ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick gimp xorg-setxkbmap wavemon texlive-most dash neofetch htop wireless_tools alsa-utils acpi zip libreoffice nm-connection-editor dunst libnotify dosfstools tlp mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat nomacs pcmanfm openbsd-netcat powertop mupdf-tools wget nomacs stow zsh-autosuggestions xf86-video-amdgpu xf86-video-intel xf86-video-nouveau npm fzf unclutter

# install aur packages
doas -u "$username" paru -S --noconfirm --needed betterlockscreen simple-mtpfs tibasicc-git redshift dashbinsh devour vim-plug lf-bin brave-bin picom-ibhagwan-git doasedit

# build dwm
if [ ! -d /home/"$username"/.local/src/dwm ]; then
    cd /home/"$username"/.local/src || exit
    git clone https://github.com/noahvogt/dwm.git
fi
cd /home/"$username"/.local/src/dwm || exit
make install

# build st
if [ ! -d /home/"$username"/.local/src/st ]; then
    cd /home/"$username"/.local/src || exit
    git clone https://github.com/noahvogt/st.git
fi
cd /home/"$username"/.local/src/st || exit
make install

# build dwmblocks
if [ ! -d /home/"$username"/.local/src/dwmblocks ]; then
    cd /home/"$username"/.local/src || exit
    git clone https://github.com/noahvogt/dwmblocks.git
fi
cd /home/"$username"/.local/src/dwmblocks || exit
make install

# build dmenu
if [ ! -d /home/"$username"/.local/src/dmenu ]; then
    cd /home/"$username"/.local/src || exit
    git clone https://github.com/noahvogt/dmenu.git
fi
cd /home/"$username"/.local/src/dmenu || exit
make install

# set global zshenv
mkdir -p /etc/zsh
echo "export ZDOTDIR=\$HOME/.config/zsh" > /etc/zsh/zshenv

# make initial history file
mkdir -p /home/"$username"/.cache/zsh
[ -f /home/"$username"/.cache/zsh/history ] ||
    touch /home/"$username"/.cache/zsh/history

# make user to owner of ~/ and /mnt/
chown -R "$username":users /home/"$username"/
chown -R "$username":users /mnt/

# change shell to zsh
while true; do
    doas -u "$username" chsh -s "$(which zsh)" && break
done

# enable tap to click
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
ls -A /home/"$username" | grep -q "\.bash" && rm /home/"$username"/.bash*
ls -A /home/"$username" | grep -q "\.less" && rm /home/"$username"/.less*
