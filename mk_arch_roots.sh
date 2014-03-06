#!/bin/bash
# ex: ts=4 sw=4 et

# volume group name, where we're going to play
vg=extra

# added schroot configuration folder
chroot_d=/etc/schroot/chroot.d

arch_conf () {
    local dir=$1
    echo
    echo "[arch_tmp]"
    echo "type=directory"
    echo "directory=$dir"
    echo "personality=linux32"
    echo "root-users=build"
    echo "script-config=../../opt/build/config"
}

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

step7 () {
    local root=$1
    local bits=$2
    arch_dev_conf $root $bits >${chroot_d}/arch_tmp.conf
    schroot -c arch_tmp -u root
    rm -f ${chroot_d}/arch_tmp.conf
}

step6 () {
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
    step7 /dev/mapper/$name $bits

    # cleanup
    dmsetup remove $name
}

step5 () {
    local root_dev=$1
    local cow_img=$2
    local bits=$3
    local cow_dev=`losetup -f --show $cow_img`
    [[ -a $cow_dev ]] && step6 $root_dev $cow_dev $bits
    losetup -d $cow_dev
}

step4 () {
    local root_img=$1
    local cow_img=$2
    local bits=$3
    local root_dev=`losetup -f -r --show $root_img`
    [[ -a $root_dev ]] && step5 $root_dev $cow_img $bits
    losetup -d $root_dev
}

step3 () {
    local root_img=$1
    local bits=$2
    # create a sparse file for COW image
    local -i cow_size=$((1024 * 1024 * 10))
    local cow_img=`mktemp --suffix=.img`
    dd if=/dev/zero of=$cow_img bs=1 count=1 seek=$((cow_size - 1)) || return
    step4 $root_img $cow_img $bits
    # cleanup
    rm -f $cow_img
}

step2 () {
    local disk=$1
    local bits=$2
    local dir=`mktemp -d`
    mount -o loop $disk $dir && {
        local file=$dir/root-image.fs
        [[ -f $file ]] && step3 $file $bits
        umount $dir
    }
    rmdir $dir
}

bits_to_arch () {
    [[ $1 == 32 ]] && echo i686 || echo x86_64
}

arch_mount () {
    local disk=$1
    local bits=$2
    local dir=`mktemp -d`
    mount -o loop $disk $dir && {
        local file=$dir/arch/$(bits_to_arch $bits)/root-image.fs.sfs
        [[ -f $file ]] && step2 $file $bits
        umount $dir
    }
    rmdir $dir
}

if (( $# < 2 )); then
    echo "use: $0 <arch-iso> 32|64"
    exit 0
fi

arch_mount $1 $2
