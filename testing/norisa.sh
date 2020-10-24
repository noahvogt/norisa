#!/bin/sh

pacman -Sy --noconfirm git vim

# setting up build environment
mkdir ~/.build && cd ~/.build

# make new user
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
read -p "What is your desired username? " username
useradd -m -g users -G wheel $username
passwd $username

# install aur helper
# git clone https://aur.archlinux.org/pacaur.git && cd pacaur && makepkg --allsource -si && cd


