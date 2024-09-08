#!/bin/bash

# Logging setup
LOG_FILE="/var/log/arch_install.log"
exec > >(tee -i $LOG_FILE) 2>&1

echo "Arch Linux Installation Script (with feedback and interactive options)"
echo "All output is logged to $LOG_FILE for troubleshooting purposes."

# List available disks
echo "Available disks:"
lsblk
read -p "Enter the disk to install Arch Linux on (e.g., /dev/nvme0n1): " DISK

# Confirmation before proceeding
echo "WARNING: This will completely wipe $DISK. Have you backed up your data?"
read -p "Do you want to proceed with the installation? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Installation aborted."
    exit 1
fi

# Zap the drive (wipe it completely)
echo "Zapping the drive $DISK..."
wipefs -a $DISK
if [ $? -ne 0 ]; then
    echo "Error zapping the drive. Exiting..."
    exit 1
fi

dd if=/dev/zero of=$DISK bs=1M count=100 status=progress
if [ $? -ne 0 ]; then
    echo "Error wiping the drive with dd. Exiting..."
    exit 1
fi

# Set partition sizes
BOOT_SIZE="1G"
SWAP_SIZE="16G"
ROOT_SIZE="50G"

# User info
USERNAME="novosta"
USER_PASSWORD="password"
ROOT_PASSWORD="rootpasswd"

# Partition the disk using cgdisk
echo "Creating partitions on $DISK..."
sgdisk -o $DISK  # Create new GPT partition table
sgdisk -n 1:0:+$BOOT_SIZE -t 1:ef00 $DISK  # EFI partition
sgdisk -n 2:0:+$SWAP_SIZE -t 2:8200 $DISK  # Swap partition
sgdisk -n 3:0:+$ROOT_SIZE -t 3:8300 $DISK  # Root partition
sgdisk -n 4:0:0 -t 4:8300 $DISK            # Home partition (remaining space)

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${DISK}p1
mkswap ${DISK}p2
mkfs.ext4 ${DISK}p3
mkfs.ext4 ${DISK}p4

# Enable swap
echo "Enabling swap..."
swapon ${DISK}p2

# Mount partitions
echo "Mounting partitions..."
mount ${DISK}p3 /mnt
mkdir /mnt/boot
mount ${DISK}p1 /mnt/boot
mkdir /mnt/home
mount ${DISK}p4 /mnt/home

# Install base system including nano and linux headers
echo "Installing base system packages (linux, linux-headers, nano)..."
pacstrap /mnt base linux linux-firmware linux-headers nano sudo
if [ $? -ne 0 ]; then
    echo "Error during pacstrap. Exiting..."
    exit 1
fi

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
echo "Entering the new system (chroot)..."
arch-chroot /mnt /bin/bash <<EOF

# Set time zone
echo "Setting time zone to America/Phoenix..."
ln -sf /usr/share/zoneinfo/America/Phoenix /etc/localtime
hwclock --systohc

# Set locale
echo "Configuring locale..."
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "Setting hostname to Amphetamine..."
echo "Amphetamine" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 Amphetamine.localdomain Amphetamine" >> /etc/hosts

# Set root password
echo "Setting root password..."
echo root:$ROOT_PASSWORD | chpasswd

# Create user with sudo privileges
echo "Creating user $USERNAME with sudo privileges..."
useradd -mG wheel $USERNAME
echo $USERNAME:$USER_PASSWORD | chpasswd

# Allow wheel group to use sudo and enable rootpw option
echo "Configuring sudo for wheel group..."
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "Defaults rootpw" >> /etc/sudoers

# Install and configure GRUB for UEFI
echo "Installing GRUB bootloader..."
pacman -S --noconfirm grub efibootmgr

# Configure GRUB to boot automatically with UUIDs
echo "Configuring GRUB to boot automatically..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/#GRUB_DISABLE_LINUX_PARTUUID=false/GRUB_DISABLE_LINUX_PARTUUID=false/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Enable NetworkManager for internet access
echo "Enabling NetworkManager..."
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

# Enable UFW firewall for security
echo "Enabling UFW firewall..."
pacman -S --noconfirm ufw
ufw default deny incoming
ufw default allow outgoing
ufw enable
systemctl enable ufw

# Optional: Test network connectivity
echo "Testing network connectivity..."
ping -c 3 google.com
if [ $? -eq 0 ]; then
    echo "Network is working!"
else
    echo "Network connection failed! Please check your settings."
fi

# Optional: Enable TRIM for SSD
read -p "Would you like to enable TRIM for SSD performance optimization? (y/n): " enable_trim
if [[ "$enable_trim" == "y" ]]; then
    systemctl enable fstrim.timer
fi

EOF

# Post installation: Unmount partitions and offer reboot or chroot
echo "Installation completed. What would you like to do next?"
echo "1. Reboot into the new system."
echo "2. Stay in the chroot environment."
echo "3. Exit chroot without rebooting."

read -p "Choose an option (1/2/3): " choice

if [[ "$choice" == "1" ]]; then
    echo "Unmounting partitions and rebooting..."
    umount -R /mnt
    reboot
elif [[ "$choice" == "2" ]]; then
    echo "Staying in chroot environment. Type 'exit' when you're ready to leave."
    arch-chroot /mnt
elif [[ "$choice" == "3" ]]; then
    echo "Exiting chroot without rebooting. You can manually reboot later."
    exit 0
else
    echo "Invalid choice. Staying in chroot by default."
    arch-chroot /mnt
fi
