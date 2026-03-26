#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# This a lazy and DANGEROUS way to install Arch.
# I do not recommend this to other people, ONLY
# do this if you exactly understand EVERY SINGLE
# LINE of this bash script. You'll thank me later.

pacman -Sy --noconfirm dialog || {
    printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"
    exit
}

# Hardware AES Detection
if grep -q "\baes\b" /proc/cpuinfo; then
    AES_NI="yes"
else
    AES_NI="no"
fi

dialog --no-cancel --inputbox "Enter the hostname." 10 60 2>comp

clear
lsblk -d | sed 's/0 disk/0 disk\\n/;s/POINT/POINT\\n/'
read -rp "Press any key to continue"

dialog --no-cancel --inputbox "Enter the drive you want do install Arch on." 10 60 2>drive

dialog --defaultno --title "Time Zone select" --yesno "Do you want use the default time zone(Europe/Zurich)?.\n\nPress no for select your own time zone" 10 60 && echo "Europe/Zurich" >tz.tmp || tzselect >tz.tmp

dialog --no-cancel --inputbox "Enter swapsize in gb (only type in numbers)." 10 60 2>swapsize

ls /sys/firmware/efi/efivars && EFI=yes
SIZE=$(cat swapsize)
DRIVE=$(cat drive)
PVALUE=$(echo "${DRIVE}" | grep "^nvme" | sed 's/.*[0-9]/p/')

timedatectl set-ntp true

# Dynamic Partitioning
if [ "$EFI" = "yes" ]; then
    if [ "$AES_NI" = "yes" ]; then
        UEFI_LETTER="1"
        SWAP_LETTER="2"
        ROOT_LETTER="3"
        cat <<EOF | fdisk -W always /dev/"${DRIVE}"
g
n


+1024M
t
1
n


+${SIZE}G
t
2
19
n



w
EOF
    else
        UEFI_LETTER="1"
        SWAP_LETTER="2"
        BOOT_LETTER="3"
        ROOT_LETTER="4"
        cat <<EOF | fdisk -W always /dev/"${DRIVE}"
g
n


+1024M
t
1
n


+${SIZE}G
t
2
19
n


+1024M
n



w
EOF
    fi
else
    if [ "$AES_NI" = "yes" ]; then
        SWAP_LETTER="1"
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
    else
        SWAP_LETTER="1"
        BOOT_LETTER="2"
        ROOT_LETTER="3"
        cat <<EOF | fdisk -W always /dev/"${DRIVE}"
o
n
p


+${SIZE}G
t
82
n
p


+1024M
n
p



a
2
w
EOF
    fi
fi

partprobe

# Dynamic LUKS Formatting
while true; do
    if [ "$AES_NI" = "yes" ]; then
        cryptsetup luksFormat --type luks2 /dev/"${DRIVE}${PVALUE}${ROOT_LETTER}" && break
    else
        cryptsetup luksFormat --type luks2 --cipher xchacha12,aes-adiantum-plain64 --hash sha256 /dev/"${DRIVE}${PVALUE}${ROOT_LETTER}" && break
    fi
done

while true; do
    cryptsetup open /dev/"${DRIVE}${PVALUE}${ROOT_LETTER}" cryptroot && break
done

yes | mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

# Mount Unencrypted Boot (if Adiantum)
if [ "$AES_NI" = "no" ]; then
    yes | mkfs.ext4 /dev/"${DRIVE}${PVALUE}${BOOT_LETTER}"
    mkdir -p /mnt/boot
    mount /dev/"${DRIVE}${PVALUE}${BOOT_LETTER}" /mnt/boot
fi

# Mount EFI
if [ "$EFI" = "yes" ]; then
    mkfs.vfat -F32 /dev/"${DRIVE}${PVALUE}${UEFI_LETTER}"
    mkdir -p /mnt/boot/efi
    mount /dev/"${DRIVE}${PVALUE}${UEFI_LETTER}" /mnt/boot/efi
fi

pacman -Sy --noconfirm archlinux-keyring
pacstrap /mnt base linux linux-firmware cryptsetup

genfstab -U /mnt >>/mnt/etc/fstab

# Pass variables to chroot
cat tz.tmp >/mnt/tzfinal.tmp
echo "$AES_NI" >/mnt/aes.tmp
rm tz.tmp
mv drive /mnt
mv comp /mnt/etc/hostname

curl -LO https://noahvogt.com/chroot.sh --output-dir /mnt && arch-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh
