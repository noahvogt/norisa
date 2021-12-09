#!/bin/bash

# This a lazy and DANGEROUS way to install Arch.
# I do not recommend this to other people, ONLY
# do this if you exactly understand EVERY SINGLE
# LINE of this bash script. You'll thank me later.

TZuser=$(cat tzfinal.tmp)
DRIVE=$(cat drive)

passwd

ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime

hwclock --systohc

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

pacman --noconfirm --needed -S networkmanager
systemctl enable NetworkManager

pacman --noconfirm --needed -S grub && 
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB &&
    grub-mkconfig -o /boot/grub/grub.cfg

sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=(base udev autodetect modconf block/HOOKS=(base udev autodetect modconf block encrypt/' /etc/mkinitcpio.conf
mkinitcpio -p linux

UUID="$(blkid | grep "${DRIVE}3" | awk '{print $2}' | tr -d '"')"
echo "UUID: $UUID"

sed -i "s/quiet/cryptdevice=${UUID}:cryptroot root=\/dev\/mapper\/cryptroot/" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
