
update_fedora () {
    local release=$1
    local bits=$2
    local name=fedora_${release}_${bits}
    cd /tmp
    echo "yum -y update" |schroot -c source:$name -u root
}

update_centos () {
    local release=$1
    local bits=$2
    local name=centos_${release}_${bits}
    cd /tmp
    echo "yum -y update" |schroot -c source:$name -u root
}

update_arch () {
    local bits=$1
    local name=arch_${bits}
    cd /tmp
    echo "pacman --noconfirm -Syu" |schroot -c source:$name -u root
}

for rel in 15 16 17 18 19 20; do
    for bits in 32 64; do
        update_fedora
    done
done

for rel in 4 5 6; do
    for bits in 32 64; do
        update_centos $rel $bits
    done
done

for bits in 32 64; do
    update_arch $1 $bits
done
