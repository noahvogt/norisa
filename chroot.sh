#!/bin/bash

# This a lazy and DANGEROUS way to install Arch.
# I do not recommend this to other people, ONLY
# do this if you exactly understand EVERY SINGLE
# LINE of this bash script. You'll thank me later.

read -p "Press any key to continue"
passwd
read -p "Press any key to continue"

TZuser=$(cat tzfinal.tmp)

ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime
read -p "Press any key to continue"

hwclock --systohc
read -p "Press any key to continue"

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
read -p "Press any key to continue"

pacman --noconfirm --needed -S networkmanager
systemctl enable NetworkManager
systemctl start NetworkManager
read -p "Press any key to continue"

DRIVE=$(cat drive)
pacman --noconfirm --needed -S grub && grub-install --target=i386-pc /dev/${DRIVE} && grub-mkconfig -o /boot/grub/grub.cfg
read -p "Press any key to continue"
