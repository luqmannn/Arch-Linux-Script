#!/bin/bash

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo pacman -S --noconfirm --needed xorg lightdm lightdm-webkit2-greeter xfce4 xfce4-whiskermenu-plugin capitaine-cursors papirus-icon-theme arc-gtk-theme arc-icon-theme neofetch base-devel firefox simplescreenrecorder

git clone https://aur.archlinux.org/pikaur.git
cd pikaur/
makepkg -si --noconfirm 

sudo systemctl enable lightdm
/bin/echo -e "\e[1;34mREBOOTING IN 5..4..3..2..1..\e[0m"
sleep 5
sudo reboot