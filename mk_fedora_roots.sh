#!/bin/bash -e
# ex: ft=sh ts=4 sw=4 et
#------------------------------------------------------------------------
# This script creates Fedora Linux schroots for given number of releases
# (32 and/or 64 bits) using yum utility and Fedora 18 x86_64 host OS. May
# also work with other releases, with some adjustments.
#------------------------------------------------------------------------
# Since: 03 March 2014
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

# conf file needed to enforce 32-bit personality on x86_64 platform
# via schroot command
to_32_conf () {
    echo
    echo "[to32]"
    echo "type=plain"
    echo "directory=/"
    echo "personality=linux32"
}

# create minimum fedora chroot
init_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    local lv=vol_${name}
    local dev=/dev/$vg/$lv
    lvcreate -L 2G $vg -n $lv
    mkfs.ext4 $dev
    if [[ "$bits" == "32" ]]; then
        to_32_conf >${chroot_d}/to_32.conf
        fedora_bootstrap $dev $release |schroot -c to32 -u root
        rm -f ${chroot_d}/to_32.conf
    else
        fedora_bootstrap $dev $release |bash
    fi
}

# write configuration files for created snapshots
make_conf_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    conf_fedora $release $bits >${chroot_d}/${name}.conf
}

# generate schroot configuration files content
conf_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    local lv=vol_${name}
    local dev=/dev/$vg/$lv
    echo
    echo "[$name]"
    echo "type=lvm-snapshot"
    echo "description=fedora ${release} ${bits}-bit"
    if [[ "$bits" == "32" ]]; then
        echo "personality=linux32"
    fi
    echo "root-users=build"
    echo "source-root-users=build"
    echo "device=$dev"
    echo "lvm-snapshot-options=--size 1G"
    echo "script-config=../../opt/build/config"
}

# run add_rpms in chroot
prep_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    cd /tmp
    add_rpms |schroot -c source:$name -u root
}

# may be used to fix source snapshot package set
fix_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    cd /tmp
    fix_rpms |schroot -c source:$name -u root
}

# install basic fedora rpms needed to configure, make etc.
add_rpms () {
    local -a pkg
    local -i k=0
    pkg[k++]=binutils
    pkg[k++]=gcc-c++
    pkg[k++]=make
    pkg[k++]=boost-devel
    pkg[k++]=tar
    pkg[k++]=file
    pkg[k++]=less
    pkg[k++]=diffutils
    pkg[k++]=findutils
    pkg[k++]=git
    pkg[k++]=subversion
    pkg[k++]=vim-enhanced
cat <<EOT
    yum -y update
    yum -y install ${pkg[@]}
EOT
}

# remove rpms installed by mistake
fix_rpms () {
    local -a pkg
    local -i k=0
    pkg[k++]=autoconf
    pkg[k++]=automake
    pkg[k++]=autoconf-archive
cat <<EOT
    yum -y erase ${pkg[@]}
EOT
}

# create minimum fedora distribution
fedora_bootstrap () {
    local dev=$1
    local -i release=$2
    local -i myrel=`lsb_release -sr`
    if (( release < myrel )); then
        opts="--nogpgcheck"
    fi
cat <<EOT
    mnt=\`mktemp -d\`
    mount $dev \$mnt
    yum -y $opts --releasever=$release --installroot=\$mnt --disablerepo='*' \
        --enablerepo=fedora install fedora-release yum
    mkdir -p \$mnt/home/build
    chown build:build \$mnt/home/build
    chmod 700 \$mnt/home/build
    umount \$mnt
    rmdir \$mnt
EOT
}

# create one fedora chroot
make_fedora_root () {
    local dev=$1
    local release=$2
    init_fedora $dev $release
    make_conf_fedora $dev $release
    prep_fedora $dev $release
}

# create dozen fedora chroots in a one shot
for rel in 15 16 17 18 19 20; do
    for bits in 32 64; do
        make_fedora_root $rel $bits
        # fix_fedora $rel $bits
    done
done
