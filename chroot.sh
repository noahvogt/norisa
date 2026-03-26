#!/bin/bash

while true; do
    passwd && break
done

TZuser=$(cat tzfinal.tmp)
AES_NI=$(cat aes.tmp)
DRIVE=$(cat drive)
PVALUE=$(echo "${DRIVE}" | grep "^nvme" | sed 's/.*[0-9]/p/')

# TODO: Add Selection TUI
echo KEYMAP=de_CH-latin1 >/etc/vconsole.conf

ln -sf /usr/share/zoneinfo/"$TZuser" /etc/localtime
hwclock --systohc

# TODO: Add Selection TUI
echo "LANG=en_GB.UTF-8" >>/etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen

pacman --noconfirm --needed -S networkmanager
systemctl enable NetworkManager

ls /sys/firmware/efi/efivars && EFI=yes

if [ "$EFI" = "yes" ]; then
    if [ "$AES_NI" = "yes" ]; then
        SWAP_LETTER="2"
        ROOT_LETTER="3"
    else
        SWAP_LETTER="2"
        ROOT_LETTER="4"
    fi
else
    if [ "$AES_NI" = "yes" ]; then
        SWAP_LETTER="1"
        ROOT_LETTER="2"
    else
        SWAP_LETTER="1"
        ROOT_LETTER="3"
    fi
fi

LUKS_UUID=$(blkid -s UUID -o value /dev/"${DRIVE}${PVALUE}${ROOT_LETTER}")
pacman --noconfirm --needed -S grub

if [ "$AES_NI" = "yes" ]; then
    # AES Fully-Encrypted Root Setup (Includes Keyfile logic)
    dd bs=512 count=4 if=/dev/urandom of=/crypto_keyfile.bin
    while true; do
        cryptsetup luksAddKey /dev/"${DRIVE}${PVALUE}${ROOT_LETTER}" /crypto_keyfile.bin && break
    done
    chmod 000 /crypto_keyfile.bin

    sed -i 's|^FILES=.*|FILES=(/crypto_keyfile.bin)|' /etc/mkinitcpio.conf
    sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
    mkinitcpio -P

    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"rd.luks.name=${LUKS_UUID}=cryptroot rd.luks.key=${LUKS_UUID}=/crypto_keyfile.bin\"|" /etc/default/grub
    sed -i 's/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/' /etc/default/grub
    SWAP_CIPHER="aes-cbc-essiv:sha256"
else
    # Adiantum Unencrypted Boot Setup (NO Keyfile logic to prevent plaintext key leak)
    sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
    mkinitcpio -P

    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"rd.luks.name=${LUKS_UUID}=cryptroot\"|" /etc/default/grub
    SWAP_CIPHER="xchacha12,aes-adiantum-plain64"
fi

echo "swap /dev/${DRIVE}${PVALUE}${SWAP_LETTER} /dev/urandom swap,cipher=${SWAP_CIPHER},size=256" >>/etc/crypttab

if [ "$EFI" = "yes" ]; then
    pacman --noconfirm --needed -S efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub /dev/"${DRIVE}" --recheck
else
    grub-install --target=i386-pc /dev/"${DRIVE}" --recheck
fi

grub-mkconfig -o /boot/grub/grub.cfg

# Cleanup
rm drive tzfinal.tmp aes.tmp
