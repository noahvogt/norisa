#!/bin/bash

while true; do
    passwd && break
done

TZuser=$(cat tzfinal.tmp)
DRIVE=$(cat drive)
PVALUE=$(echo "${DRIVE}" | grep "^nvme" | sed 's/.*[0-9]/p/')

echo KEYMAP=de_CH-latin1 > /etc/vconsole.conf

ln -sf /usr/share/zoneinfo/"$TZuser" /etc/localtime

hwclock --systohc

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

pacman --noconfirm --needed -S networkmanager
systemctl enable NetworkManager

dd bs=512 count=4 if=/dev/urandom of=/crypto_keyfile.bin
while true; do
    cryptsetup luksAddKey /dev/"${DRIVE}${PVALUE}2" /crypto_keyfile.bin && break
done
chmod 000 /crypto_keyfile.bin

sed -i 's/FILES=()/FILES=(\/crypto_keyfile.bin)/' /etc/mkinitcpio.conf
sed -i 's/block filesystems/block encrypt filesystems/' /etc/mkinitcpio.conf
mkinitcpio -P

pacman --noconfirm --needed -S grub
sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=\/dev\/${DRIVE}${PVALUE}2:cryptroot\"/" /etc/default/grub
sed -i 's/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/' /etc/default/grub

echo "swap /dev/${DRIVE}${PVALUE}1 /dev/urandom swap,cipher=aes-cbc-essiv:sha256,size=256" >> /etc/crypttab

grub-install --target=i386-pc /dev/"${DRIVE}" --recheck
grub-mkconfig -o /boot/grub/grub.cfg

rm drive tzfinal.tmp
