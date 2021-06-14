#!/bin/bash

pacman -Sy --noconfirm git vim ||  { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }



# make new user
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
read -rp "What is your desired username? " username
useradd -m -g users -G wheel "$username"
passwd "$username"
cd /home/"$username" || exit

# setting up build environment
sudo -u "$username" mkdir -p /home/"$username"/.local/src && cd .. && chown -R "$username":wheel "$username"/.local/src/
pwd
ls "$username"

# install aur helper (paru)
cd /home/"$username"/.local/src || exit
pacman -S --noconfirm asp bat devtools
curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/paru.tar.gz &&
tar xvf paru.tar.gz
cd .. && chown -R "$username":wheel /home/"$username"/.local/src/ && cd .local/src || exit
cd paru || exit
sudo -u "$username" makepkg --noconfirm -si

pacman -S --noconfirm xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot 
sudo -u "$username" paru -S --noconfirm libxft-bgra-git

# clone dotfiles repo
cd /home/"$username"/.local/src || exit
git clone git@github.com:noahvogt/dotfiles.git
cp -f dotfiles/.* /home/"$username" /root

# build dwm
cd /home/"$username"/.local/src || exit
git clone git@github.com:noahvogt/dwm.git
cd dwm || exit
make clean install

# build st
cd /home/"$username"/.local/src || exit
git clone git@github.com:noahvogt/st.git
cd st || exit
make clean install

# build dwmblocks
cd /home/"$username"/.local/src || exit
git clone git@github.com:noahvogt/dwmblocks.git
cd dwmblocks || exit
make clean install

# build dmenu
cd /home/"$username"/.local/src || exit
git clone git@github.com:noahvogt/dmenu.git
cd dmenu || exit
make clean install

# make user to owner of ~/ and /mnt/
chown -R "$username":wheel /home/"$username"/
chown -R "$username":wheel /mnt/

# download packages from the official repo
pacman -S --noconfirm xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot picom xbindkeys jdk-openjdk geogebra shellcheck neovim ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip unrar python mupdf-gl mediainfo highlight pulseaudio-alsa pulsemixer pamixer  ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick thunderbird gimp xorg-setxkbmap wavemon cmus texlive-most dash neofetch htop wireless_tools alsa-utils acpi zip unrar libreoffice nm-connection-editor dunst libnotify dosfstools tlp mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat nomacs pcmanfm openbsd-netcat powertop mupdf-tools

# install aur packages
sudo -u "$username" paru -S --noconfirm betterlockscreen simple-mtpfs tibasicc-git redshift dashbinsh devour plymouth vim-plug librewolf-bin lf-bin brave-bin

# enable tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    # Enable left mouse button by tapping
    Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# set global zshenv
[ ! -d /etc/zsh ] && mkdir -p /etc/zsh
echo "export ZDOTDIR=\$HOME/.config/zsh" > /etc/zsh/zshenv

# set the real world /etc/sudoers
sed -i "s/%wheel ALL=(ALL) NOPASSWD: ALL/${username} ALL = NOPASSWD: \/usr\/bin\/mount, \/usr\/bin\/umount/g" /etc/sudoers
