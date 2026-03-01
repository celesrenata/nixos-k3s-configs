# Get Started!

## Get yourself some NixOS!
1. https://nixos.org/download/
   a. or if you have a freshly updated copy of netboot.xyz...
   b. Boot virtual machine to netboot.xyz
       i. Select Linux Network Installs
       ii. Select Nixos
       iii. Select Nixos 24.05
2. Follow https://nixos.wiki/wiki/Btrfs to setup btrfs
   a. nix-shell -p git btrfs-progs
   b. fdisk /dev/sda
      i. g
      ii. n
      iii. 1
      iv. <enter>
      v. +1G
      vi. n
      vii. 2
      viii. <enter>
      xi. +8G
      x. n
      xi. 3
      xii. <enter>
      xiii. <enter>
      xiv. t
      xv. 1
      xvi. uefi
      xvii. t
      xviii. 2
      xix. swap
      xx. t
      xxi. 3
      xxii. linux
      xxiii. w
   c. mkfs.fat -F 32 /dev/sda1
   d. mkswap /dev/sda2
   e. mkfs.btrfs /dev/sda3
   f. mount /dev/sda3 /mnt
   g. btrfs subvolume create root
   h. btrfs subvolume create nix
   i. btrfs subvolume create home
   j. btrfs subvolume create varlib
   k. btrfs subvolume create kubedata
   l. umount /mnt
   m. mount -o compress=zstd,subvol=root /dev/sda3 /mnt
   n. mkdir -p /mnt/{home,nix,var/lib,kubedata-local,kubedata-remote}
   o. mount -o compress=zstd,subvol=home /dev/sda3 /mnt/home
   p. mount -o compress=zstd,subvol=nix /dev/sda3 /mnt/nix
   q. mount -o compress=zstd,subvol=varlib /dev/sda3 /mnt/var/lib
   r. mount -o compress=zstd,subvol=kubedata /dev/sda3 /mnt/kubedata-local
   s. mount /dev/sda1 /mnt/boot
3. Extract gremlin-1 to /mnt/etc/nixos
   a. **Update the hostnames, usernames and ip addresses in all files to be something else**
   b. blkid
      i. update /mnt/etc/nixos/hardware-configuration to match
   c. nixos-install --root /mnt
   d. reboot

4. Repeat Steps 1 - 3 for gremlin-2 and gremlin-3
5. You now have a nixos kubernetes fleet!

6. Navigate to the kube directory
7. (Optional Hard Bounce) Ensure the fleet is functioning correctly by hard resetting it.
   a. Edit resetfleet.sh to reflect the hostnames or IPs associated with your fleet starting with the cluster lead
   b. ssh-keygen or clone your key
   c. scp ~/.ssh/id_ed25519.pub (or whatever) root@gremlin-1:.ssh/authorized_keys
   d. repeat for gremlin-2 and gremlin-3
   e. ./resetfleet.sh
   f. should complete on a FAST fleet in 5 minutes.
8. Install all the things
   a. ./runmefirst.sh
