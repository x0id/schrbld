#!/bin/bash -e
# ex: ft=sh ts=4 sw=4 et
#------------------------------------------------------------------------
# This script is for running by non-superuser (build user). Sequentially
# going through the given list of schroot profiles it performs following
# steps:
# 1) opens schroot session
# 2) pipes sequence of shell scripts or commands to the schroot session
#    on behalf of running user (build) or surepuser (root)
# 3) closes session
# In case of any error happened in the chroot session, script terminates,
# leaving session open for further investigation.
# The only argument is the name of the test suite. It is assumed that
# file with same name and .conf extension exists and contains definition
# for sequence of preconfigured targets (schroot profile names) and
# sequence of commands to run in schroot sessions. See example provided.
# See schroot manual pages for details on its operation.
#------------------------------------------------------------------------
# Since: 08 March 2014
#------------------------------------------------------------------------
# Copyright (C) 2014 Dmitriy Kargapolov <dmitriy.kargapolov@gmail.com>
# Use, modification and distribution are subject to the Boost Software
# License, Version 1.0 (See accompanying file LICENSE_1_0.txt or copy
# at http://www.boost.org/LICENSE_1_0.txt)
#------------------------------------------------------------------------

# name of the test suite
name=$1

# what to run - sequence of commands
declare -a script

# where to run - sequence of schroot profiles
declare -a target

# no verbose by default
verbose=0

# configure tests - expected to add scripts and targets
. $name.conf

run_id=$(date +%s)

for sid in ${target[@]}; do
    ses=${sid}_${run_id}
    if (( $verbose )); then
        echo
        echo "running test in schroot $sid, session $ses"
    fi
    schroot -c $sid -b -n $ses
    for cmd in ${script[@]}; do
        case $cmd in
        *:root)
            cmd=${cmd%:root}
            if (( $verbose )); then
                echo running $cmd as root
            fi
            $cmd |schroot -c $ses -u root -r
            ;;
        *)
            if (( $verbose )); then
                echo running $cmd
            fi
            $cmd |schroot -c $ses -r
            ;;
        esac
    done
    schroot -c $ses -e
done
