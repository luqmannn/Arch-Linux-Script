# Arch Linux Script

![arch-linux](https://archlinux.org/static/logos/archlinux-logo-light-1200dpi.7ccd81fd52dc.png)

## :pushpin: Introduction 

This repository contain useful Arch Linux script for system setup and
installation. The objective of creating this script is to be able to 
quickly setup recently updated clean install Arch Linux system after 
enter arch-chroot environment. The use of `--noconfirm` flag is to 
make a usable script without any user interaction, no more typing required.

## :pushpin: Requirements (in order) 

1. Partition the disk manually.
2. Pacstrap the system.
3. Install text editor (e.g: nano) and git.
4. Enter arch-chroot environment.

## :pushpin: Usage 

Clone all the script
- `git clone https://github.com/luqmannn/Arch-Linux-Script.git`

**:warning: Change the hostname, username, software package and GRUB directory install in the script according to your system**

Make all the script executable and run
- `chmod +x *.sh`
- `./<script_name.sh>`