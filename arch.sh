#!/bin/bash

# This a lazy and DANGEROUS way to install Arch.
# I do not recommend this to other people, ONLY
# do this if you exactly understand EVERY SINGLE
# LINE of this bash script. You'll thank me later.

pacman -Sy --noconfirm dialog || { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }

dialog --defaultno --title "WARNING!" --yesno "Do only run this script if you're a big brain who doesn't mind deleting one or more (this depends on your level of stupidity in the following steps) of his /dev/sd[x] drives. \n\nThis script is only really for me so I can save some of my precious time.\n\nNoah"  15 60 || { clear; exit; }

dialog --no-cancel --inputbox "Enter the hostname." 10 60 2>comp

clear
lsblk -d | sed 's/0 disk/0 disk\\n/;s/POINT/POINT\\n/'
read -rp "Press any key to continue"

dialog --no-cancel --inputbox "Enter the drive you want do install Arch on." 10 60 2>drive

dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(Europe/Zurich)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Zurich" > tz.tmp || tzselect > tz.tmp

dialog --no-cancel --inputbox "Enter swapsize in gb (only type in numbers)." 10 60 2>swapsize

ls /sys/firmware/efi/efivars && EFI=yes
SIZE=$(cat swapsize)
DRIVE=$(cat drive)
PVALUE=$(echo "${DRIVE}" | grep "^nvme" | sed 's/.*[0-9]/p/')

timedatectl set-ntp true

if [ "$EFI" = "yes" ]; then
    UEFI_LETTER="1"
    ROOT_LETTER="3"
    cat <<EOF | fdisk -W always /dev/"${DRIVE}"
g
n
p


+1024M
t
1
n
p


+${SIZE}G
t
2
19
n



w
EOF
mkfs.vfat -F32 /dev/"${DRIVE}${PVALUE}${UEFI_LETTER}"

else
    ROOT_LETTER="2"
    cat <<EOF | fdisk -W always /dev/"${DRIVE}"
o
n
p


+${SIZE}G
t
82
n
p



a
2
w
EOF
fi

partprobe

while true; do
    cryptsetup luksFormat --type luks1 /dev/"${DRIVE}${PVALUE}${ROOT_LETTER}" &&
        break
done

while true; do
    cryptsetup open /dev/"${DRIVE}${PVALUE}${ROOT_LETTER}" cryptroot && break
done

yes | mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

pacman -Sy --noconfirm archlinux-keyring

pacstrap /mnt base linux linux-firmware cryptsetup

genfstab -U /mnt >> /mnt/etc/fstab
cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp
mv drive /mnt
mv comp /mnt/etc/hostname
curl -LO noahvogt.com/chroot.sh --output-dir /mnt && arch-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh

curl -LO noahvogt.com/norisa.sh --output-dir /mnt && dialog --defaultno --title "NoRiSA" --yesno "Launch NoRiSA install script?"  6 30 && arch-chroot /mnt bash norisa.sh && rm /mnt/norisa.sh
dialog --defaultno --title "Final Qs" --yesno "Return to chroot environment?"  6 30 && arch-chroot /mnt
clear
