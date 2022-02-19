#!/bin/bash

pacman -Sy --noconfirm --needed git vim base-devel opendoas sudo || { printf "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"; exit; }

# setup temporary sudo
sed -i 's/# %wheel ALL=(ALL:ALL) N/%wheel ALL=(ALL:ALL) N/g' /etc/sudoers

# setup doas
echo "permit persist :wheel" > /etc/doas.conf
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf

# make new user
read -rp "What is your desired username? " username
useradd -m -g users -G wheel "$username"
while true; do
    passwd "$username" && break
done
cd /home/"$username" || exit

# create ~/ folders
mkdir -p /home/"$username"/dox /home/"$username"/pix /home/"$username"/dl
mkdir -p /home/"$username"/vids /home/"$username"/mus
mkdir -p /home/"$username"/.local/bin /home/"$username"/.config
mkdir -p /home/"$username"/.local/share /home/"$username"/.local/src

chown -R "$username":users /home/"$username"/* /home/"$username"/.*

# install aur helper (paru)
if ! pacman -Q | grep -q paru; then
    cd /home/"$username"/.local/src || exit
    pacman -S --noconfirm --needed asp bat devtools
    curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/paru-bin.tar.gz &&
    tar xvf paru-bin.tar.gz
    cd /home/"$username" && chown -R "$username":wheel /home/"$username"/.local/src/ && cd .local/src || exit
    cd paru-bin || exit
    sudo -u "$username" makepkg --noconfirm -si
    rm /home/"$username"/.local/src/paru-bin.tar.gz
fi

# install some dependencies
pacman -S --noconfirm --needed xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot xf86-video-modesetting xf86-video-vesa xf86-video-fbdev
yes | sudo -u "$username" paru -S --needed libxft-bgra

# clone dotfiles repo
cd /home/"$username"/.local/src || exit
git clone https://github.com/noahvogt/dotfiles.git
cd dotfiles || exit
sudo -u "$username" /home/"$username"/.local/src/dotfiles/apply-dotfiles

# build dwm
cd /home/"$username"/.local/src || exit
git clone https://github.com/noahvogt/dwm.git
cd dwm || exit
make clean install

# build st
cd /home/"$username"/.local/src || exit
git clone https://github.com/noahvogt/st.git
cd st || exit
make clean install

# build dwmblocks
cd /home/"$username"/.local/src || exit
git clone https://github.com/noahvogt/dwmblocks.git
cd dwmblocks || exit
make clean install

# build dmenu
cd /home/"$username"/.local/src || exit
git clone https://github.com/noahvogt/dmenu.git
cd dmenu || exit
make clean install

# make user to owner of ~/ and /mnt/
chown -R "$username":users /home/"$username"/
chown -R "$username":users /mnt/

# download packages from the official repos
pacman -S --noconfirm --needed xorg-server xorg-xinit xorg-xwininfo xorg-xprop xorg-xbacklight xorg-xdpyinfo xorg-xsetroot xbindkeys jdk-openjdk geogebra shellcheck neovim ranger xournalpp ffmpeg obs-studio sxiv arandr man-db brightnessctl unzip python mupdf-gl mediainfo highlight pulseaudio-alsa pulsemixer pamixer  ttf-linux-libertine calcurse xclip noto-fonts-emoji imagemagick gimp xorg-setxkbmap wavemon texlive-most dash neofetch htop wireless_tools alsa-utils acpi zip libreoffice nm-connection-editor dunst libnotify dosfstools tlp mpv xorg-xinput cpupower zsh zsh-syntax-highlighting newsboat nomacs pcmanfm openbsd-netcat powertop mupdf-tools wget nomacs stow zsh-autosuggestions xf86-video-amdgpu xf86-video-intel xf86-video-nouveau npm fzf unclutter

# install aur packages
sudo -u "$username" paru -S --noconfirm --needed betterlockscreen simple-mtpfs tibasicc-git redshift dashbinsh devour vim-plug lf-bin brave-bin picom-ibhagwan-git doasedit

# set global zshenv
mkdir -p /etc/zsh
echo "export ZDOTDIR=\$HOME/.config/zsh" > /etc/zsh/zshenv

# change shell to zsh
while true; do
    sudo -u "$username" chsh -s $(which zsh) && break
done

# remove sudo
pacman -R --noconfirm sudo

# enable tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    # Enable left mouse button by tapping
    Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# cleanup
rm /home/"$username"/.bash* /home/"$username"/.less*
