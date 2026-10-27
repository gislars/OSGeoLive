#!/bin/sh
# Copyright (c) 2018-2026 The Open Source Geospatial Foundation and others.
# Licensed under the GNU LGPL v.2.1.
#
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 2.1 of the License,
# or any later version.  This library is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY, without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details, either
# in the "LGPL-2.1.txt" file distributed with this software or at
# web page "http://www.fsf.org/licenses/lgpl.html".
#
#
# script to install PDAL -
#    osgeolive 12dev  -dbb
#    PDAL homepage: https://pdal.io
#

./diskspace_probe.sh "`basename $0`" begin
####

# live disc's username is "user"
if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

# pdal and libpdal-plugins are not in Ubuntu 26.04. There is no official
# standalone Linux binary comparable to the former Debian packages yet.
# Documented as removed/replaced pending a pinned binary; do not fail the
# full ISO build on a missing lidar stack.
echo "NOTE: PDAL is not packaged for Ubuntu 26.04; skipping install_PDAL.sh."

####
./diskspace_probe.sh "`basename $0`" end
