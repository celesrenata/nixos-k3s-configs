#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  gremlin-rebuild-storage.sh — Catastrophic Recovery for Gremlin Nodes        ║
# ╠═══════════════════════════════════════════════════════════════════════════════╣
# ║                                                                              ║
# ║  DRIVE LAYOUT (IMSM fake RAID0 across 2× NVMe):                             ║
# ║                                                                              ║
# ║  /dev/nvme0n1 (1.8T CT2000T500SSD8)                                         ║
# ║  /dev/nvme1n1 (1.8T CT2000T500SSD8)                                         ║
# ║       └── IMSM RAID0 → /dev/md126 (3.6T)                                    ║
# ║           ├── p1: ESP        1G   vfat                                       ║
# ║           ├── p2: SWAP      96G   swap                                       ║
# ║           └── p3: SYSTEM   3.5T   btrfs                                      ║
# ║                                                                              ║
# ║  BTRFS SUBVOLUMES (on md126p3):                                              ║
# ║    root              → /              compress=zstd:3 ssd discard=async       ║
# ║    home              → /home          compress=zstd:3 ssd discard=async       ║
# ║    nix               → /nix           compress=zstd:3 ssd discard=async       ║
# ║    varlib            → /var/lib       compress=zstd:3 ssd discard=async       ║
# ║    varlib/longhorn   → /var/lib/longhorn  noatime + chattr +C (nocow)        ║
# ║                                                                              ║
# ║  NOTE: The IMSM RAID0 array (md126/md127) is created by the motherboard      ║
# ║  BIOS RAID controller. This script assumes it already exists.                 ║
# ║  If the RAID array is gone, recreate it in BIOS first.                        ║
# ║                                                                              ║
# ║  MODES:                                                                       ║
# ║    (default)   Partition, format, create subvolumes                           ║
# ║    --mount     Mount everything under /mnt for NixOS installation             ║
# ║    --dry-run   Print planned operations without executing                     ║
# ║    --gen-hw    Generate hardware-configuration.nix for a given hostname       ║
# ║                                                                              ║
# ║  USAGE:                                                                       ║
# ║    Boot NixOS installer USB, then:                                            ║
# ║      sudo ./gremlin-rebuild-storage.sh                                        ║
# ║      sudo ./gremlin-rebuild-storage.sh --mount                                ║
# ║      sudo ./gremlin-rebuild-storage.sh --gen-hw gremlin-1                     ║
# ║      nixos-install --flake /mnt/etc/nixos#gremlin-1                           ║
# ║                                                                              ║
# ║  WARNING: Default mode DESTROYS all data on the RAID array.                   ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
RAID_DEV="/dev/md126"
ESP_SIZE="1G"
SWAP_SIZE="96G"
# SYSTEM = remainder

MNT="/mnt"
TMPMT="/mnt/btrfs-setup"

SUBVOLS=("root" "home" "nix" "varlib")

DRY_RUN=false
MODE="format"
GEN_HOSTNAME=""

# =============================================================================
# HELPERS
# =============================================================================
log()  { echo "[$(date +%H:%M:%S)] $*"; }
die()  { log "ERROR: $*" >&2; exit 1; }
run()  {
  if $DRY_RUN; then log "[DRY-RUN] $*"; else log "Running: $*"; "$@"; fi
}

confirm() {
  $DRY_RUN && return 0
  echo
  log "WARNING: $1"
  read -r -p "  Proceed? [y/N] " r
  [[ "$r" =~ ^[yY] ]] || die "Aborted."
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --mount)   MODE="mount"; shift ;;
    --gen-hw)  MODE="gen-hw"; GEN_HOSTNAME="${2:-}"; shift 2 || die "--gen-hw requires a hostname" ;;
    -h|--help)
      sed -n '/^# ╔/,/^# ╚/p' "$0"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# =============================================================================
# FORMAT MODE
# =============================================================================
do_format() {
  [[ -b "$RAID_DEV" ]] || die "$RAID_DEV not found. Is the IMSM RAID array created in BIOS?"

  log "=== FORMAT MODE ==="
  log "  RAID device: $RAID_DEV"
  log "  Layout: p1=${ESP_SIZE} ESP, p2=${SWAP_SIZE} swap, p3=rest btrfs"
  log "  Subvolumes: ${SUBVOLS[*]} + varlib/longhorn (nocow)"

  confirm "This will DESTROY all data on $RAID_DEV"

  # Partition
  log "--- Partitioning $RAID_DEV ---"
  run sgdisk --zap-all "$RAID_DEV"
  run sgdisk \
    --new=1:0:+"${ESP_SIZE}"   --typecode=1:EF00 --change-name=1:"ESP" \
    --new=2:0:+"${SWAP_SIZE}"  --typecode=2:8200 --change-name=2:"SWAP" \
    --new=3:0:0                --typecode=3:8300 --change-name=3:"SYSTEM" \
    "$RAID_DEV"
  run partprobe "$RAID_DEV"
  sleep 2

  # Format ESP
  log "--- Formatting ESP ---"
  run mkfs.vfat -F 32 "${RAID_DEV}p1"

  # Format swap
  log "--- Formatting swap ---"
  run mkswap "${RAID_DEV}p2"

  # Format btrfs
  log "--- Formatting btrfs ---"
  run mkfs.btrfs -f "${RAID_DEV}p3"

  # Create subvolumes
  log "--- Creating subvolumes ---"
  if ! $DRY_RUN; then
    mkdir -p "$TMPMT"
    mount "${RAID_DEV}p3" "$TMPMT"

    for sv in "${SUBVOLS[@]}"; do
      btrfs subvolume create "${TMPMT}/${sv}"
      log "  Created subvolume: ${sv}"
    done

    # Create longhorn subvolume inside varlib with nocow
    btrfs subvolume create "${TMPMT}/varlib/longhorn"
    chattr +C "${TMPMT}/varlib/longhorn" 2>/dev/null || \
      nix-shell -p e2fsprogs --run "chattr +C ${TMPMT}/varlib/longhorn" 2>/dev/null || \
      log "WARNING: chattr not available, set nocow manually after install"
    log "  Created subvolume: varlib/longhorn (nocow)"

    umount "$TMPMT"
    rmdir "$TMPMT"
  else
    for sv in "${SUBVOLS[@]}"; do log "[DRY-RUN] btrfs subvolume create ${sv}"; done
    log "[DRY-RUN] btrfs subvolume create varlib/longhorn + chattr +C"
  fi

  log ""
  log "=== FORMAT COMPLETE ==="
  if ! $DRY_RUN; then
    log ""
    log "New UUIDs:"
    blkid "${RAID_DEV}p1" "${RAID_DEV}p2" "${RAID_DEV}p3"
    log ""
    log "Next steps:"
    log "  1. sudo $0 --mount"
    log "  2. Clone /etc/nixos into /mnt/etc/nixos"
    log "  3. sudo $0 --gen-hw <hostname>    (generates hardware-configuration.nix)"
    log "  4. nixos-install --flake /mnt/etc/nixos#<hostname>"
  fi
}

# =============================================================================
# MOUNT MODE
# =============================================================================
do_mount() {
  [[ -b "${RAID_DEV}p3" ]] || die "${RAID_DEV}p3 not found"

  local opts="compress=zstd:3,ssd,discard=async,space_cache=v2"

  log "=== MOUNT MODE ==="
  log "  Mounting under $MNT"

  run mount -o "subvol=root,${opts}" "${RAID_DEV}p3" "${MNT}"

  for dir in home nix boot; do
    run mkdir -p "${MNT}/${dir}"
  done
  run mount -o "subvol=home,${opts}" "${RAID_DEV}p3" "${MNT}/home"
  run mount -o "subvol=nix,${opts}"  "${RAID_DEV}p3" "${MNT}/nix"
  run mount "${RAID_DEV}p1" "${MNT}/boot"

  run mkdir -p "${MNT}/var/lib"
  run mount -o "subvol=varlib,${opts}" "${RAID_DEV}p3" "${MNT}/var/lib"

  run mkdir -p "${MNT}/var/lib/longhorn"
  run mount -o "subvol=varlib/longhorn,noatime,ssd,discard=async,space_cache=v2" "${RAID_DEV}p3" "${MNT}/var/lib/longhorn"

  run swapon "${RAID_DEV}p2"

  log ""
  log "=== ALL MOUNTED ==="
  if ! $DRY_RUN; then
    findmnt --target "${MNT}" --tree
  fi
}

# =============================================================================
# GENERATE HARDWARE-CONFIGURATION.NIX
# =============================================================================
do_gen_hw() {
  [[ -n "$GEN_HOSTNAME" ]] || die "--gen-hw requires a hostname (e.g., gremlin-1)"

  # Get UUIDs from mounted system or from blkid
  local btrfs_uuid esp_uuid swap_uuid
  btrfs_uuid=$(blkid -s UUID -o value "${RAID_DEV}p3" 2>/dev/null) || die "Can't read ${RAID_DEV}p3 UUID"
  esp_uuid=$(blkid -s UUID -o value "${RAID_DEV}p1" 2>/dev/null)   || die "Can't read ${RAID_DEV}p1 UUID"
  swap_uuid=$(blkid -s UUID -o value "${RAID_DEV}p2" 2>/dev/null)  || die "Can't read ${RAID_DEV}p2 UUID"

  local outdir="${MNT}/etc/nixos/hosts/${GEN_HOSTNAME}"
  local outfile="${outdir}/hardware-configuration.nix"

  mkdir -p "$outdir"

  log "Generating $outfile"
  log "  btrfs UUID: $btrfs_uuid"
  log "  ESP UUID:   $esp_uuid"
  log "  swap UUID:  $swap_uuid"

  cat > "$outfile" << NIXEOF
# Hardware configuration for ${GEN_HOSTNAME}
# Generated by gremlin-rebuild-storage.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#
# IMSM RAID0 (2× CT2000T500SSD8 NVMe) → /dev/md126
#   p1: ESP (1G)  p2: swap (96G)  p3: btrfs (rest)
#   Subvolumes: root, home, nix, varlib, varlib/longhorn (nocow)

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "nvme" "usbhid" "usb_storage" "sr_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/${btrfs_uuid}";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=root" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/${btrfs_uuid}";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=home" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/${btrfs_uuid}";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=nix" ];
    };

  fileSystems."/var/lib" =
    { device = "/dev/disk/by-uuid/${btrfs_uuid}";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=varlib" ];
    };

  fileSystems."/var/lib/longhorn" =
    { device = "/dev/disk/by-uuid/${btrfs_uuid}";
      fsType = "btrfs";
      options = [ "noatime" "subvol=varlib/longhorn" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/${esp_uuid}";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ { device = "/dev/disk/by-uuid/${swap_uuid}"; } ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
NIXEOF

  log "Written: $outfile"
  log ""
  log "Next: nixos-install --flake /mnt/etc/nixos#${GEN_HOSTNAME}"
}

# =============================================================================
# MAIN
# =============================================================================
case "$MODE" in
  format) do_format ;;
  mount)  do_mount ;;
  gen-hw) do_gen_hw ;;
esac
