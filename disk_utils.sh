#!/bin/bash
# disk_utils.sh
# Purpose: Helpers for File System operations (Backup, Restore, Partitioning).
# WARNING: These commands can cause DATA LOSS. Use with caution.

set -e

# Device configuration (Edit these if your devices differ)
NVME_DEV="/dev/nvme0n1"
SD_DEV="/dev/mmcblk0"
BACKUP_DIR="/backup"
BACKUP_PARTITION_ID="p3" # e.g., nvme0n1p3

usage() {
    echo "Usage: sudo ./disk_utils.sh [command]"
    echo "Commands:"
    echo "  prepare_nvme   - Partition and format NVMe drive (DESTRUCTIVE)"
    echo "  clone_sd       - Clone SD card to NVMe (DESTRUCTIVE to NVMe)"
    echo "  setup_backup   - Create backup partition on NVMe"
    echo "  create_backup  - Create a full disk image backup of NVMe"
    echo "  restore_backup - Restore from backup (Requires careful usage)"
    exit 1
}

confirm() {
    read -p "WARNING: You are about to run a DESTRUCTIVE operation on $1. Are you sure? (type 'yes' to confirm): " confirm_str
    if [ "$confirm_str" != "yes" ]; then
        echo "Operation cancelled."
        exit 1
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root (sudo)."
        exit 1
    fi
}

cmd_prepare_nvme() {
    check_root
    confirm "$NVME_DEV"
    
    echo "Unmounting $NVME_DEV..."
    umount ${NVME_DEV}* || true

    echo "Creating partition table..."
    fdisk $NVME_DEV <<EOF
o
n
p
1


w
EOF
    echo "Formatting as ext4..."
    mkfs.ext4 "${NVME_DEV}p1"
    echo "Done."
}

cmd_clone_sd() {
    check_root
    confirm "$NVME_DEV (Overwriting with data from $SD_DEV)"
    
    echo "Cloning $SD_DEV to $NVME_DEV..."
    dd if=$SD_DEV of=$NVME_DEV bs=4M status=progress
    echo "Clone complete."
}

cmd_setup_backup() {
    check_root
    echo "Creating backup partition (p3) on $NVME_DEV..."
    # Warning: This assumes space is available at the end of the drive.
    parted $NVME_DEV mkpart primary ext4 100% -20GB
    mkfs.ext4 "${NVME_DEV}${BACKUP_PARTITION_ID}"
    
    mkdir -p $BACKUP_DIR
    mount "${NVME_DEV}${BACKUP_PARTITION_ID}" $BACKUP_DIR
    
    # Add to fstab if not present
    if ! grep -q "$BACKUP_DIR" /etc/fstab; then
        echo "${NVME_DEV}${BACKUP_PARTITION_ID} $BACKUP_DIR ext4 defaults 0 2" | tee -a /etc/fstab
    fi
    echo "Backup partition setup complete."
}

cmd_create_backup() {
    check_root
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Backup directory $BACKUP_DIR does not exist. Run setup_backup first."
        exit 1
    fi
    
    DATE_STR=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/full-backup-$DATE_STR.img"
    
    echo "Creating backup to $BACKUP_FILE..."
    dd if=$NVME_DEV of=$BACKUP_FILE bs=4M status=progress
    echo "Compressing..."
    gzip $BACKUP_FILE
    echo "Backup created: ${BACKUP_FILE}.gz"
}

case "$1" in
    prepare_nvme)
        cmd_prepare_nvme
        ;;
    clone_sd)
        cmd_clone_sd
        ;;
    setup_backup)
        cmd_setup_backup
        ;;
    create_backup)
        cmd_create_backup
        ;;
    restore_backup)
        echo "Restore logic is complex and best done manually or from valid recovery media."
        echo "Refer to the script comments for commands."
        ;;
    *)
        usage
        ;;
esac
