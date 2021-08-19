#!/bin/bash

# Make sure to partition the disk manually, pacstrap, text editor, git and enter arch-chroot before running the script.
ln -sf /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "archminimal" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 archminimal.localdomain archminimal" >> /etc/hosts
echo root:password | chpasswd

# Change the software package based on what you need.
pacman -S --noconfirm grub efibootmgr networkmanager network-manager-applet xdg-user-dirs xdg-utils dialog wpa_supplicant linux-lts-headers ntfs-3g terminus-font os-prober alsa-utils pulseaudio inetutils

# For AMD graphic card
# pacman -S --noconfirm xf86-video-amdgpu mesa vulkan-radeon
# For Nvidia graphic card
# pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

# Install and configure bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable network service and TRIM for SSD on startup
systemctl enable NetworkManager
systemctl enable fstrim.timer

# Create and add user in wheelgroup
useradd -m aman
echo aman:password | chpasswd
usermod -aG libvirt aman

echo "aman ALL=(ALL) ALL" >> /etc/sudoers.d/aman

printf "\e[1;35mDone! Type exit, umount -a and reboot.\e[0m"
