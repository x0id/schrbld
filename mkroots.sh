#!/bin/bash -e
# ex: ts=4 sw=4 et

vg=extra
chroot_d=/etc/schroot/chroot.d

to_32_conf () {
    echo
    echo "[to32]"
    echo "type=plain"
    echo "directory=/"
    echo "personality=linux32"
}

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
        bootstrap $dev $release |schroot -c to32 -u root
        rm -f ${chroot_d}/to_32.conf
    else
        bootstrap $dev $release |bash
    fi
}

make_conf_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    conf_fedora $release $bits >${chroot_d}/${name}.conf
}

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

prep_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    cd /tmp
    add_rpms |schroot -c source:$name -u root
}

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
    pkg[k++]=autoconf
    pkg[k++]=automake
    pkg[k++]=autoconf-archive
    pkg[k++]=git
    pkg[k++]=svn
    pkg[k++]=vim-enhanced
cat <<EOT
    yum -y update
    yum -y install ${pkg[@]}
EOT
}

bootstrap () {
    local dev=$1
    local release=$2
cat <<EOT
    mnt=\`mktemp -d\`
    mount $dev \$mnt
    yum -y --releasever=$release --installroot=\$mnt --disablerepo='*' \
        --enablerepo=fedora install fedora-release yum
    mkdir -p \$mnt/home/build
    chown build:build \$mnt/home/build
    chmod 700 \$mnt/home/build
    umount \$mnt
    rmdir \$mnt
EOT
}

# init_fedora 20 32
# make_conf_fedora 20 32
prep_fedora 20 32
