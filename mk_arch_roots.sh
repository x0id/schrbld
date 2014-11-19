#!/bin/bash
# ex: ft=sh ts=4 sw=4 et
#------------------------------------------------------------------------
# This script creates Arch Linux schroots (32 and/or 64 bits) from given
# ISO image. Host OS tested - Fedora 18 x86_64.
#------------------------------------------------------------------------
# Since: 07 March 2014
#------------------------------------------------------------------------
# Copyright (C) 2014 Dmitriy Kargapolov <dmitriy.kargapolov@gmail.com>
# Use, modification and distribution are subject to the Boost Software
# License, Version 1.0 (See accompanying file LICENSE_1_0.txt or copy
# at http://www.boost.org/LICENSE_1_0.txt)
#------------------------------------------------------------------------

# volume group name, where we're going to play
vg=extra

# added schroot configuration folder
chroot_d=/etc/schroot/chroot.d

arch_dev_conf () {
    local file=$1
    local bits=$2
    echo
    echo "[arch_tmp]"
    echo "type=block-device"
    echo "device=$file"
    [[ "$bits" == "32" ]] && echo "personality=linux32"
    echo "root-users=build"
    echo "script-config=../../opt/build/config"
}

chroot_to_comb_dev () {
    local root=$1
    local bits=$2
    arch_dev_conf $root $bits >${chroot_d}/arch_tmp.conf
    schroot -c arch_tmp -u root
    rm -f ${chroot_d}/arch_tmp.conf
}

make_combined_dev () {
    local iso_dev=$1
    local cow_dev=$2
    local bits=$3

    # dev mapper name
    local name=arch-cow

    # combine two devices, dmsetup reads table spec from stdin
    # table spec = logical_start_sector num_sectors target_type <target_args>
    # snapshot target = snapshot <origin> <COW device> <persistent?> <chunksize>
    local -i iso_blocks=$(blockdev --getsz $iso_dev)
    echo "0 $iso_blocks snapshot $iso_dev $cow_dev N 1" |dmsetup create $name

    # chroot to the combined device
    chroot_to_comb_dev /dev/mapper/$name $bits

    # cleanup
    dmsetup remove $name
}

make_cow_fs_dev () {
    local root_dev=$1
    local cow_img=$2
    local bits=$3
    local cow_dev=`losetup -f --show $cow_img`
    [[ -a $cow_dev ]] && make_combined_dev $root_dev $cow_dev $bits
    losetup -d $cow_dev
}

make_root_fs_dev () {
    local root_img=$1
    local cow_img=$2
    local bits=$3
    local root_dev=`losetup -f -r --show $root_img`
    [[ -a $root_dev ]] && make_cow_fs_dev $root_dev $cow_img $bits
    losetup -d $root_dev
}

make_cow_file () {
    local root_img=$1
    local bits=$2
    # create a sparse file for COW image
    local -i cow_size=$((1024 * 1024 * 10))
    local cow_img=`mktemp --suffix=.img`
    dd if=/dev/zero of=$cow_img bs=1 count=1 seek=$((cow_size - 1)) || return
    make_root_fs_dev $root_img $cow_img $bits
    # cleanup
    rm -f $cow_img
}

mount_squash_fs () {
    local disk=$1
    local bits=$2
    local dir=`mktemp -d`
    mount -o loop $disk $dir && {
        local file=$dir/airootfs.img
        [[ -f $file ]] && make_cow_file $file $bits
        umount $dir
    }
    rmdir $dir
}

bits_to_arch () {
    [[ $1 == 32 ]] && echo i686 || echo x86_64
}

# mount arch rootfs from within iso image
arch_mount () {
    local disk=$1
    local bits=$2
    local dir=`mktemp -d`
    mount -o loop $disk $dir && {
        local file=$dir/arch/$(bits_to_arch $bits)/airootfs.sfs
        [[ -f $file ]] && mount_squash_fs $file $bits
        umount $dir
    }
    rmdir $dir
}

# write configuration files for created snapshots
make_conf_arch () {
    local bits=$1
    local name=arch_${bits}
    conf_arch $bits >${chroot_d}/${name}.conf
}

# generate schroot configuration files content
conf_arch () {
    local bits=$1
    local name=arch_${bits}
    local lv=vol_${name}
    local dev=/dev/$vg/$lv
    echo
    echo "[$name]"
    echo "type=lvm-snapshot"
    echo "description=arch ${bits}-bit"
    [[ "$bits" == "32" ]] && echo "personality=linux32"
    echo "root-users=build"
    echo "source-root-users=build"
    echo "device=$dev"
    echo "lvm-snapshot-options=--size 2G"
    echo "profile=../../opt/build"
}

# generate commands for post-bootstrap tasks
arch_post_bootstrap () {
cat <<EOT
    ln -s /usr/share/zoneinfo/America/New_York /etc/localtime
    pacman-key --init
    pacman-key --populate
    pacman --noconfirm -Syu gcc make boost git subversion vim
EOT
}

# tweaking system, adding packages
prep_arch () {
    local bits=$1
    local name=arch_${bits}
    cd /tmp
    arch_post_bootstrap |schroot -c source:$name -u root
}

# generate commands for system bootstrap
arch_bootstrap () {
    local dev=$1
cat <<EOT
    mnt=\`mktemp -d\`
    mount $dev \$mnt && {
        pacman-key --init
        pacman-key --populate
        pacstrap -d \$mnt base
        mkdir -p \$mnt/home/build
        chown build:build \$mnt/home/build
        chmod 700 \$mnt/home/build
        umount \$mnt
    }
    rmdir \$mnt
EOT
}

# create minimum arch chroot
init_arch () {
    local disk=$1
    local bits=$2
    local name=arch_${bits}
    local lv=vol_${name}
    local dev=/dev/$vg/$lv
    lvcreate -L 4G $vg -n $lv || return 1
    mkfs.ext4 $dev || return 1
    arch_bootstrap $dev |arch_mount $disk $bits
}

# create one arch chroot
make_arch_root () {
    local disk=$1
    local bits=$2
    init_arch $disk $bits && make_conf_arch $bits && prep_arch $bits
}

if (( $# < 1 )); then
    echo "use: $0 <arch-iso> [32|64]"
    exit 0
fi

if (( $# > 1 )); then
    make_arch_root $1 $2
else
    for bits in 32 64; do
        make_arch_root $1 $bits
    done
fi
