#!/bin/bash

pacman -Sy --noconfirm git vim ||  { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }



# make new user
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
read -pr "What is your desired username? " username
useradd -m -g users -G wheel "$username"
passwd "$username"
cd /home/"$username" || exit

# setting up build environment
mkdir -p ~/.build && cd ~/.build || exit

# install aur helper (pacaur)
cd /tmp || exit
pacman -S --noconfirm expac jq
rm -rf /tmp/pacaur*
curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz &&
sudo -u "$username" tar -xvf yay.tar.gz
cd yay || exit
sudo -u "$username" makepkg --noconfirm -si

# clone dotfiles repo
cd /tmp || exit
git clone https://github.com/noahvogt/dotfiles.git
cp /tmp/dotfiles/.* /home/"$username" /root

# shellcheck source=/dev/null
source ~/.bashrc

# build dwm
cd /tmp || exit
git clone https://github.com/noahvogt/dwm.git
cd /dwm || exit
make clean install

# build st
cd /tmp || exit
git clone https://github.com/noahvogt/st.git
cd /st || exit
make clean install

# build dwmblocks
cd /tmp || exit
git clone https://github.com/noahvogt/dwmblocks.git
cd /dwmblocks || exit
make clean install

# download packages from the official repo
pacman -S xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot picom xbindkeys jdk-openjdk dmenu geogebra shellcheck vim firefox syncthing ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip unrar python mupdf mediainfo highlight pulseaudio-alsa pulsemixer pamixer  ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick thunderbird gimp xorg-setxkbmap wavemon cmus texlive-most

# install aur packages
sudo -u "$username" yay -S betterlockscreen simple-mtpfs-git tibasicc-git xflux
