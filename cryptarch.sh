#!/bin/bash

# This a lazy and DANGEROUS way to install Arch.
# I do not recommend this to other people, ONLY
# do this if you exactly understand EVERY SINGLE
# LINE of this bash script. You'll thank me later.

pacman -Sy --noconfirm dialog ||  { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }

dialog --defaultno --title "WARNING!" --yesno "Do only run this script if you're a big brain who doesn't mind deleting one or more (this depends on your level of stupidity in the following steps) of his /dev/sd[x] drives. \n\nThis script is only really for me so I can save some of my precious time.\n\nNoah"  15 60 || { clear; exit; }

dialog --no-cancel --inputbox "Enter the hostname." 10 60 2>comp

clear
lsblk -d | sed 's/0 disk/0 disk\\n/;s/POINT/POINT\\n/'
read -p "Press any key to continue"

dialog --no-cancel --inputbox "Enter the drive you want do install Arch on." 10 60 2>drive

dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(Europe/Zurich)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Zurich" > tz.tmp || tzselect > tz.tmp

dialog --no-cancel --inputbox "Enter swapsize in gb (only type in numbers)." 10 60 2>swapsize

SIZE=$(cat swapsize)
DRIVE=$(cat drive)

timedatectl set-ntp true

cat <<EOF | fdisk -W always /dev/${DRIVE}
p
g
n


+300M
t
1
n


+${SIZE}G
t
2
19
p
n



t
3
20
p
w
EOF
partprobe

mkfs.fat -F32 /dev/${DRIVE}1
mkswap /dev/${DRIVE}2
swapon /dev/${DRIVE}2
lsblk
cryptsetup luksFormat /dev/${DRIVE}3
cryptsetup luksOpen /dev/${DRIVE}3 cryptroot || exit 1
mkfs.btrfs /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
cd
umount /mnt

mount -t btrfs -o subvol=@ /dev/mapper/cryptroot /mnt
mkdir /mnt/home
mount -t btrfs -o subvol=@home /dev/mapper/cryptroot /mnt/home
mkdir /mnt/boot
mount /dev/${DRIVE}1 /mnt/boot
lsblk

pacman -Sy --noconfirm archlinux-keyring

pacstrap /mnt base base-devel linux linux-firmware networkmanager git neovim btrfs-progs cryptsetup efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab
cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp
mv drive /mnt
mv comp /mnt/etc/hostname
cp cryptchroot.sh /mnt/chroot.sh && arch-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh /mnt/drive /mnt/tzfinal.tmp

dialog --defaultno --title "Final Qs" --yesno "Reboot computer?"  5 30 && reboot
dialog --defaultno --title "Final Qs" --yesno "Return to chroot environment?"  6 30 && arch-chroot /mnt
clear
