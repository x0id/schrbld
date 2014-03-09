# ex: ft=sh ts=4 sw=4 et
#------------------------------------------------------------------------
# schroot runner: worker script example
#------------------------------------------------------------------------
# Since: 08 March 2014
#------------------------------------------------------------------------
# Copyright (C) 2014 Dmitriy Kargapolov <dmitriy.kargapolov@gmail.com>
# Use, modification and distribution are subject to the Boost Software
# License, Version 1.0 (See accompanying file LICENSE_1_0.txt or copy
# at http://www.boost.org/LICENSE_1_0.txt)
#------------------------------------------------------------------------

if (( $verbose )); then
    echo "       dev = $dev"
    echo " build_dev = $build_dev"
    echo "build_prod = $build_prod"
    echo "  test_dev = $test_dev"
    echo " test_prod = $test_prod"
fi

set -e

if (( $dev )); then
    git clone https://github.com/x0id/neutx
    cd neutx
    ./bootstrap
else
    tar zxf /tmp/neutx-0.1.tar.gz
    cd neutx-0.1
fi

if (( $build_dev )); then
    ./devconf.sh
    make
    if (( $test_dev )); then
        ./test.sh all
    fi
fi

if (( $build_prod )); then
    if (( $build_dev )); then
        make clean
        make distclean
    fi
    ./conf.sh
    make
    if (( $test_prod )); then
        ./test.sh all
    fi
fi
