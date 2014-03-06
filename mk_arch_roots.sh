#!/bin/bash
# ex: ts=4 sw=4 et

# volume group name, where we're going to play
vg=extra

# added schroot configuration folder
chroot_d=/etc/schroot/chroot.d

step7 () {
    local root=$1
    mkdir $root/lalala
    ls -la $root >$root/lalala/lst.txt
    cat $root/lalala/lst.txt
}

step6 () {
    local iso_dev=$1
    local cow_dev=$2

    # dev mapper name
    local name=arch-cow

    # combine two devices, dmsetup reads table spec from stdin
    # table spec = logical_start_sector num_sectors target_type <target_args>
    # snapshot target = snapshot <origin> <COW device> <persistent?> <chunksize>
    # local -i iso_blocks=$(du $origin |cut -f1)
    local -i iso_blocks=$(blockdev --getsz $iso_dev)
    echo "0 $iso_blocks snapshot $iso_dev $cow_dev P 16" |dmsetup create $name

    # mount the combined device
    local dir=`mktemp -d`
    mount /dev/mapper/$name $dir && {
        # do the work
        step7 $dir
        umount $dir
    }
    rmdir $dir

    # cleanup
    dmsetup remove $name
}

step5 () {
    local root_dev=$1
    local cow_img=$2
    local cow_dev=`losetup -f --show $cow_img`
    [[ -a $cow_dev ]] && step6 $root_dev $cow_dev
    losetup -d $cow_dev
}

step4 () {
    local root_img=$1
    local cow_img=$2
    local root_dev=`losetup -f -r --show $root_img`
    [[ -a $root_dev ]] && step5 $root_dev $cow_img
    losetup -d $root_dev
}

step3 () {
    local root_img=$1
    # create a sparse file for COW image
    local -i cow_size=$((1024 * 1024 * 10))
    local cow_img=`mktemp --suffix=.img`
    dd if=/dev/zero of=$cow_img bs=1 count=1 seek=$((cow_size - 1)) || return
    step4 $root_img $cow_img
    # cleanup
    rm -f $cow_img
}

step2 () {
    local disk=$1
    local dir=`mktemp -d`
    mount -o loop $disk $dir && {
        local file=$dir/root-image.fs
        [[ -f $file ]] && step3 $file
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
        [[ -f $file ]] && step2 $file
        umount $dir
    }
    rmdir $dir
}

arch_iso=/home/dk/Downloads/archlinux-2014.02.01-dual.iso
arch_mount $arch_iso 32
