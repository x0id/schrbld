#!/bin/bash -e
# ex: ft=sh ts=4 sw=4 et
#------------------------------------------------------------------------
# This script creates CenOS Linux schroots for given number of releases
# (32 and/or 64 bits) using yum utility and Fedora 18 x86_64 host OS. May
# also work with other releases, with some adjustments.
#------------------------------------------------------------------------
# Since: 09 March 2014
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

# create minimum centos chroot
init_centos () {
    local release=$1
    local bits=$2
    local name=centos_${release}_${bits}
    local lv=vol_${name}
    local dev=/dev/$vg/$lv
    lvcreate -L 2G $vg -n $lv
    mkfs.ext4 $dev
    if [[ "$bits" == "32" ]]; then
        to_32_conf >${chroot_d}/to_32.conf
        centos_bootstrap $dev $release |schroot -c to32 -u root
        rm -f ${chroot_d}/to_32.conf
    else
        centos_repo >/etc/yum.repos.d/tmp.repo
        centos_bootstrap $dev $release |bash
        # rm -f /etc/yum.repos.d/tmp.repo
    fi
}

# write configuration files for created snapshots
make_conf_centos () {
    local release=$1
    local bits=$2
    local name=centos_${release}_${bits}
    conf_centos $release $bits >${chroot_d}/${name}.conf
}

# generate schroot configuration files content
conf_centos () {
    local release=$1
    local bits=$2
    local name=centos_${release}_${bits}
    local lv=vol_${name}
    local dev=/dev/$vg/$lv
    echo
    echo "[$name]"
    echo "type=lvm-snapshot"
    echo "description=centos ${release} ${bits}-bit"
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
prep_centos () {
    local release=$1
    local bits=$2
    local name=centos_${release}_${bits}
    cd /tmp
    add_rpms |schroot -c source:$name -u root
}

# install basic centos rpms needed to configure, make etc.
add_rpms () {
    local -a pkg
    pkg+=(binutils gcc-c++ make boost-devel)
    pkg+=(tar file diffutils findutils)
    pkg+=(git subversion vim-enhanced)
cat <<EOT
    rpm --rebuilddb
    yum -y update
    yum -y install ${pkg[@]}
EOT
}

centos_repo () {
    cat <<EOT
[tmp]
name=CentOS-\$releasever - Base
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch\
&repo=os
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/\$releasever/os/\$basearch/\
RPM-GPG-KEY-CentOS-\$releasever
EOT
}

# create minimum centos distribution
centos_bootstrap () {
    local dev=$1
    local release=$2
cat <<EOT
    mnt=\`mktemp -d\`
    mount $dev \$mnt
    yum -y --releasever=$release --installroot=\$mnt --disablerepo='*' \
        --enablerepo=tmp install centos-release yum
    mkdir -p \$mnt/home/build
    chown build:build \$mnt/home/build
    chmod 700 \$mnt/home/build
    umount \$mnt
    rmdir \$mnt
EOT
}

# create one centos chroot
make_centos_root () {
    local release=$1
    local bits=$2
    init_centos $release $bits
    make_conf_centos $release $bits
    prep_centos $release $bits
}

# make_centos_root 6 32
# make_centos_root 6 64

# create multiple centos chroots in a one shot
for rel in 5; do
    for bits in 32 64; do
        make_centos_root $rel $bits
    done
done
