#!/bin/bash

pacman -Sy --noconfirm git vim ||  { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }



# make new user
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
read -p "What is your desired username? " username
useradd -m -g users -G wheel "$username"
passwd "$username"
cd /home/"$username" || exit

# setting up build environment
sudo -u "$username" mkdir -p /home/"$username"/.build && cd .. && chown -R "$username":wheel "$username"/.build/
pwd
ls "$username"

# install aur helper (pacaur)
cd /home/"$username"/.build || exit
pacman -S --noconfirm expac jq
rm -rf /tmp/pacaur*
curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz &&
tar xvf yay.tar.gz
cd .. && chown -R "$username":wheel .build/ && cd .build
cd yay || exit
sudo -u "$username" makepkg --noconfirm -si

pacman -S --noconfirm xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot 
sudo -u "$username" yay -S --noconfirm libxft-bgra-git

# clone dotfiles repo
cd /home/"$username"/.build || exit
git clone https://github.com/noahvogt/dotfiles.git
cp dotfiles/.* /home/"$username" /root

# shellcheck source=/dev/null
source ~/.bashrc

# build dwm
cd /home/"$username"/.build || exit
git clone https://github.com/noahvogt/dwm.git
cd dwm || exit
make clean install

# build st
cd /home/"$username"/.build || exit
git clone https://github.com/noahvogt/st.git
cd st || exit
make clean install

# build dwmblocks
cd /home/"$username"/.build || exit
git clone https://github.com/noahvogt/dwmblocks.git
cd dwmblocks || exit
make clean install

# download packages from the official repo
pacman -S --noconfirm xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot picom xbindkeys jdk-openjdk dmenu geogebra shellcheck vim firefox syncthing ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip unrar python mupdf mediainfo highlight pulseaudio-alsa pulsemixer pamixer  ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick thunderbird gimp xorg-setxkbmap wavemon cmus texlive-most

# install aur packages
sudo -u "$username" yay -S --noconfirm betterlockscreen simple-mtpfs-git tibasicc-git xflux
