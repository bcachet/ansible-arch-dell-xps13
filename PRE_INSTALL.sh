VOLUME_NAME=brarch
HOST_NAME=BrHome
MEM_SIZE=16
DEVICE=/dev/nvmen1
MAPPING_NAME=cryptlvm
KEYMAP=fr_CH-latin1
FONT=sun12x22

# Configure
setfont ${FONT}
loadkeys ${KEYMAP}
wifi-menu

timedatectl set-ntp true

# Prepare disk

## Partition
parted --script ${DEVICE} \
       mklabel gpt \
       mkpart ESP fat32 1MiB 513MiB \
       set 1 boot on \
       mkpart primary ext4 514MiB 100%

## Encryption with LUKS
cryptsetup luksFormat ${DEVICE}p2
cryptsetup open ${DEVICE}p2 ${MAPPING_NAME}

## LVM
pvcreate /dev/mapper/${MAPPING_NAME}
vgcreate ${VOLUME_NAME} /dev/mapper/${MAPPING_NAME}
lvcreate -L 100G ${VOLUME_NAME} -n root
lvcreate -L $(expr $MEM_SIZE + 2)G ${VOLUME_NAME} -n swap
lvcreate -l 100%FREE ${VOLUME_NAME} -n home

## Format
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/mapper/${VOLUME_NAME}-root
mkfs.ext4 /dev/mapper/${VOLUME_NAME}-home
mkswap /dev/mapper/${VOLUME_NAME}-swap

## Mount
mkdir -p /mnt/{home,boot}
mount /dev/mapper/${VOLUME_NAME}-root /mnt
mount /dev/mapper/${VOLUME_NAME}-home /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/mapper/${VOLUME_NAME}-swap

# Installing base system

## Generating mirrorlist
curl "https://www.archlinux.org/mirrorlist/?country=CH&protocol=https&ip_version=4&use_mirror_status=on" | sed -e 's/#Server/Server/g' > /etc/pacman.d/mirrorlist

## Install base + NetworkManager
pacstrap -i /mnt \
         base \
         base-devel \
         net-tools \
         dialog \
         wpa_supplicant \
         dhclient

# Configuring installation

genfstab -L /mnt >> /mnt/etc/fstab
arch-chroot /mnt

## Locale

echo en_US.UTF-8 >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

## Timezone

ln -s /usr/share/zoneinfo/Europe/Zurich /etc/localtime
hwclock --systohc --utc
systemctl enable dhcpd.service

## vconsole

echo FONT=${FONT} > /etc/vconsole.conf
echo KEYMAP=${KEYMAP} >> /etc/vconsole.conf

## Hostname

echo ${HOST_NAME} > /etc/hostname
echo "127.0.1.1 ${HOST_NAME}.localdomain ${HOST_NAME}" >> /etc/hosts

## Enable services

systemctl enable NetworkManager
systemctl enable dhcpd

## mkinitcpio (generate initramfs)

sed -i 's/^HOOKS=.*/HOOKS="base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt sd-lvm2 filesystems fsck"'
mkinitcpio -p linux

## Bootloader

bootctl install --path=/boot

cat > /boot/loader/loader.conf <<EOL
timeout 10
default arch
editor 1
EOL

UUID=cryptsetup luksUUID /dev/nvme0n1p2
cat > /boot/loader/entries/arch.conf <<EOL
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options rd.luks.uuid=${UUID} rd.luks.name=${UUID}=${MAPPING_NAME} root=/dev/mapper/${VOLUME_NAME}-root rw resume=/dev/mapper/${VOLUME_NAME}-swap ro intel_iommu=igfx_off
EOL

# Ansible

pacman -Sy ansible \
       git

# Reboot

exit
umount -R /mnt
reboot
