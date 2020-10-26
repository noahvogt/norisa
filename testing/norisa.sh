#!/bin/sh

pacman -Sy --noconfirm git vim ||  { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }



# make new user
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
read -p "What is your desired username? " username
useradd -m -g users -G wheel $username
passwd $username
cd /home/$username

# setting up build environment
mkdir -p ~/.build && cd ~/.build

# install aur helper (pacaur)
cd /tmp || exit
pacman -S --noconfirm expac jq
rm -rf /tmp/pacaur*
curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz &&
sudo -u "$username" tar -xvf yay.tar.gz
cd yay
sudo -u "$username" makepkg --noconfirm -si
cd /tmp || exit
curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/pacaur.tar.gz &&
sudo -u "$username" tar -xvf pacaur.tar.gz
cd pacaur
sudo -u "$username" makepkg --noconfirm -si
