#!/bin/bash

# Colors for output
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Progress bar function
progress_bar() {
    local duration=$1
    local interval=1
    local elapsed=0

    while [ $elapsed -lt $duration ]; do
        elapsed=$((elapsed + interval))
        local progress=$((elapsed * 100 / duration))
        echo -ne "${YELLOW}Progress: ["
        for i in $(seq 1 $progress); do echo -n "="; done
        for i in $(seq $progress 100); do echo -n " "; done
        echo -ne "] $progress%${RESET}\r"
        sleep $interval
    done
    echo -ne "\n"
}

# Set disk (replace this if your NVMe drive has a different name)
DISK="/dev/nvme0n1"

# Set partition sizes
BOOT_SIZE="1G"
SWAP_SIZE="16G"
ROOT_SIZE="50G"

# User info
USERNAME="novosta"
USER_PASSWORD="password"
ROOT_PASSWORD="rootpasswd"

# Start installation
echo -e "${GREEN}Welcome to the Arch Linux installation script!${RESET}"
echo "This will install Arch Linux with the following settings:"
echo "- Boot: $BOOT_SIZE, Swap: $SWAP_SIZE, Root: $ROOT_SIZE, and remaining space for Home."
echo "- User: $USERNAME with default password (you can change later)."
echo "- Root password will be set to $ROOT_PASSWORD."

# Confirmation prompt
read -p "Do you want to proceed with these settings? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo -e "${RED}Installation aborted.${RESET}"
    exit 1
fi

# Zap the drive (wipe it completely)
echo -e "${YELLOW}Zapping the drive $DISK...${RESET}"
wipefs -a $DISK > /dev/null 2>&1
dd if=/dev/zero of=$DISK bs=1M count=100 status=progress > /dev/null 2>&1
echo -e "${GREEN}Drive zapped.${RESET}"

# Partition the disk using cgdisk
echo -e "${YELLOW}Creating partitions...${RESET}"
sgdisk -o $DISK > /dev/null 2>&1
sgdisk -n 1:0:+$BOOT_SIZE -t 1:ef00 $DISK > /dev/null 2>&1
sgdisk -n 2:0:+$SWAP_SIZE -t 2:8200 $DISK > /dev/null 2>&1
sgdisk -n 3:0:+$ROOT_SIZE -t 3:8300 $DISK > /dev/null 2>&1
sgdisk -n 4:0:0 -t 4:8300 $DISK > /dev/null 2>&1
echo -e "${GREEN}Partitions created.${RESET}"

# Format partitions
echo -e "${YELLOW}Formatting partitions...${RESET}"
mkfs.fat -F32 ${DISK}p1 > /dev/null 2>&1
mkswap ${DISK}p2 > /dev/null 2>&1
mkfs.ext4 ${DISK}p3 > /dev/null 2>&1
mkfs.ext4 ${DISK}p4 > /dev/null 2>&1
echo -e "${GREEN}Partitions formatted.${RESET}"

# Enable swap
echo -e "${YELLOW}Enabling swap...${RESET}"
swapon ${DISK}p2 > /dev/null 2>&1
echo -e "${GREEN}Swap enabled.${RESET}"

# Mount partitions
echo -e "${YELLOW}Mounting partitions...${RESET}"
mount ${DISK}p3 /mnt > /dev/null 2>&1
mkdir /mnt/boot > /dev/null 2>&1
mount ${DISK}p1 /mnt/boot > /dev/null 2>&1
mkdir /mnt/home > /dev/null 2>&1
mount ${DISK}p4 /mnt/home > /dev/null 2>&1
echo -e "${GREEN}Partitions mounted.${RESET}"

# Install base system including nano, linux headers, and sudo
echo -e "${YELLOW}Installing base system packages (linux, linux-headers, nano, sudo)...${RESET}"
progress_bar 30 &  # Simulate a progress bar for 30 seconds (replace with actual pacstrap time)
pacstrap /mnt base linux linux-firmware linux-headers nano sudo > /dev/null 2>&1
echo -e "${GREEN}Base system installed.${RESET}"

# Generate fstab
echo -e "${YELLOW}Generating fstab...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab
echo -e "${GREEN}fstab generated.${RESET}"

# Chroot into the new system
echo -e "${YELLOW}Entering the new system (chroot)...${RESET}"
arch-chroot /mnt /bin/bash <<EOF

# Set time zone
echo -e "${YELLOW}Setting time zone to America/Phoenix...${RESET}"
ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
hwclock --systohc

# Set locale
echo -e "${YELLOW}Configuring locale...${RESET}"
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo -e "${YELLOW}Setting hostname to Amphetamine...${RESET}"
echo "Amphetamine" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 Amphetamine.localdomain Amphetamine" >> /etc/hosts

# Set root password
echo -e "${YELLOW}Setting root password...${RESET}"
echo root:$ROOT_PASSWORD | chpasswd

# Create user with sudo privileges
echo -e "${YELLOW}Creating user $USERNAME with sudo privileges...${RESET}"
useradd -mG wheel $USERNAME
echo $USERNAME:$USER_PASSWORD | chpasswd

# Allow wheel group to use sudo and enable rootpw option
echo -e "${YELLOW}Configuring sudo for wheel group...${RESET}"
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "Defaults rootpw" >> /etc/sudoers

# Install and configure GRUB for UEFI
echo -e "${YELLOW}Installing GRUB bootloader...${RESET}"
pacman -S --noconfirm grub efibootmgr > /dev/null 2>&1

# Install GRUB to the EFI directory
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB > /dev/null 2>&1

# Configure GRUB to boot automatically with UUIDs and no timeout
sed -i 's/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/#GRUB_DISABLE_LINUX_PARTUUID=false/GRUB_DISABLE_LINUX_PARTUUID=false/' /etc/default/grub

# Generate the GRUB configuration file
grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
echo -e "${GREEN}GRUB installed and configured.${RESET}"

# Install and enable NetworkManager
echo -e "${YELLOW}Installing and enabling NetworkManager...${RESET}"
pacman -S --noconfirm networkmanager > /dev/null 2>&1
systemctl enable NetworkManager > /dev/null 2>&1
echo -e "${GREEN}NetworkManager installed and enabled.${RESET}"

# Enable UFW firewall for security
echo -e "${YELLOW}Enabling UFW firewall...${RESET}"
pacman -S --noconfirm ufw > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw enable > /dev/null 2>&1
systemctl enable ufw > /dev/null 2>&1

EOF

# Post installation: Unmount partitions and reboot
echo -e "${YELLOW}Installation completed. What would you like to do next?${RESET}"
echo "1. Reboot into the new system."
echo "2. Stay in the chroot environment."
echo "3. Exit chroot without rebooting."

read -p "Choose an option (1/2/3): " choice

if [[ "$choice" == "1" ]]; then
    echo -e "${YELLOW}Unmounting partitions and rebooting...${RESET}"
    umount -R /mnt
    reboot
elif [[ "$choice" == "2" ]]; then
    echo -e "${YELLOW}Staying in chroot environment. Type 'exit' when you're ready to leave.${RESET}"
    arch-chroot /mnt
elif [[ "$choice" == "3" ]]; then
    echo -e "${YELLOW}Exiting chroot without rebooting. You can manually reboot later.${RESET}"
    exit 0
else
    echo -e "${YELLOW}Invalid choice. Staying in chroot by default.${RESET}"
    arch-chroot /mnt
fi