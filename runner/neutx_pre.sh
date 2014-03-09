# ex: ft=sh ts=4 sw=4 et
#------------------------------------------------------------------------
# schroot runner: worker script example (for executing as root)
#------------------------------------------------------------------------
# Since: 08 March 2014
#------------------------------------------------------------------------
# Copyright (C) 2014 Dmitriy Kargapolov <dmitriy.kargapolov@gmail.com>
# Use, modification and distribution are subject to the Boost Software
# License, Version 1.0 (See accompanying file LICENSE_1_0.txt or copy
# at http://www.boost.org/LICENSE_1_0.txt)
#------------------------------------------------------------------------

if grep -q ID=arch /etc/os-release; then
    pacman --noconfirm -S automake autoconf autoconf-archive libtool
else
    yum -y install automake autoconf autoconf-archive libtool
fi
