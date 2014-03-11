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

centos_repo_old () {
    local release=$1
    local major=${release%%.*}
    cat <<EOT
[tmp_centos]
name=CentOS-\$releasever - Base
baseurl=http://vault.centos.org/$release/os/\$basearch/
gpgcheck=1
gpgkey=http://vault.centos.org/$release/os/\$basearch/RPM-GPG-KEY-centos$major
multilib_policy=best

[tmp_epel]
name=Extra Packages for Enterprise Linux $major - \$basearch
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-$major&arch=\
\$basearch
gpgcheck=1
gpgkey=https://fedoraproject.org/static/217521F6.txt
multilib_policy=best
EOT
}

centos_repo () {
    local release=$1
    local major=${release%%.*}
    case $major in
    5*) epelkey=https://fedoraproject.org/static/217521F6.txt ;;
    6*) epelkey=https://fedoraproject.org/static/0608B895.txt ;;
    esac
    cat <<EOT
[tmp_centos]
name=CentOS-\$releasever - Base
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch\
&repo=os
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/\$releasever/os/\$basearch/\
RPM-GPG-KEY-CentOS-\$releasever
multilib_policy=best

[tmp_epel]
name=Extra Packages for Enterprise Linux $major - \$basearch
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-$major&arch=\
\$basearch
gpgcheck=1
gpgkey=$epelkey
multilib_policy=best
EOT
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
    case $release in
    4  ) centos_repo_old 4.9 >/etc/yum.repos.d/tmp.repo ;;
    4.*) centos_repo_old $release >/etc/yum.repos.d/tmp.repo ;;
      *) centos_repo $release >/etc/yum.repos.d/tmp.repo ;;
    esac
    if [[ "$bits" == "32" ]]; then
        to_32_conf >${chroot_d}/to_32.conf
        centos_bootstrap $dev $release $bits |schroot -c to32 -u root
        rm -f ${chroot_d}/to_32.conf
    else
        centos_bootstrap $dev $release $bits |bash
    fi
    rm -f /etc/yum.repos.d/tmp.repo
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
    add_rpms $release |schroot -c source:$name -u root
}

# install basic centos rpms needed to configure, make etc.
add_rpms () {
    local release=$1
    local -a pkg
    pkg+=(binutils gcc-c++ make boost-devel)
    pkg+=(tar file diffutils findutils)
    pkg+=(git subversion vim-enhanced)
    case $release in
    4*) pkg+=(gcc4-c++ compat-boost-1331-devel boost141-devel) ;;
    5*) pkg+=(gcc44-c++ binutils220 boost141-devel) ;;
    esac
cat <<EOT
    rpm --rebuilddb
    yum -y clean all
    yum -y update
    yum -y install ${pkg[@]}
EOT
}

# create minimum centos distribution
centos_bootstrap () {
    local dev=$1
    local release=$2
    local bits=$3
    local rel
    local unmount
    local fixrep
    case $release in
    4) rel=4.9 ;;
    *) rel=$release ;;
    esac
    case $release in
    4*)
        umount="umount \$mnt/proc; umount \$mnt"
        fixrep+="for f in \$mnt/etc/yum.repos.d/CentOS*.repo; do "
        fixrep+="cat \$f |sed -e 's/^mirrorlist/#mirrorlist/g' -e 's/^#"
        fixrep+="baseurl=http:\/\/mirror.centos.org\/centos\/\$releasever/"
        fixrep+="baseurl=http:\/\/vault.centos.org\/$rel/g'"
        fixrep+=" >\$f.fix; mv \$f.fix \$f; done"
        ;;
     *)
        umount="umount \$mnt"
        fixrep="true"
        ;;
    esac
cat <<EOT
    mnt=\`mktemp -d\`
    mount $dev \$mnt
    yum -y --releasever=$rel --installroot=\$mnt --disablerepo='*' \
        --enablerepo=tmp_centos --enablerepo=tmp_epel install \
        centos-release yum db4-utils epel-release
    pkg=\`mktemp -d\`
    cd \$pkg
    rm -f \$mnt/var/lib/rpm/__*
    mv \$mnt/var/lib/rpm/* .
    for f in *; do
    name=source:centos_${release}_${bits}
        db_dump \$f |schroot -c \$name -u root -- db_load /var/lib/rpm/\$f
        rm -f \$f
    done
    cd -
    rmdir \$pkg
    echo "multilib_policy=best" >> \$mnt/etc/yum.conf
    $fixrep
    mkdir -p \$mnt/home/build
    chown build:build \$mnt/home/build
    chmod 700 \$mnt/home/build
    $umount
    rmdir \$mnt
EOT
}

# create one centos chroot
make_centos_root () {
    local release=$1
    local bits=$2
    make_conf_centos $release $bits
    init_centos $release $bits
    prep_centos $release $bits
}

# create multiple centos chroots in a one shot
for rel in 4 5 6; do
    for bits in 32 64; do
        make_centos_root $rel $bits
    done
done
