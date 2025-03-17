#!/bin/sh
#############################################################################
#
# Purpose: This script will install Node.sj
#
#############################################################################
# Copyright (c) 2014-2024 The Open Source Geospatial Foundation and others.
# Author: H.Bowman <hamish_b  yahoo com>
#
# Licensed under the GNU LGPL version >= 2.1.
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
#############################################################################


#
# This does not attempt to install QGIS-plugin infrastructure, that is
#  done in install_qgis.sh. Your QGIS packages will have to have been
#  built with grass8-enabled plugins.
#
# ***
# This script is intended to be run by the User on an existing live disc,
#  Not at build time of the disc. The North Carolina GRASS 7
#  sample dataset will also be downloaded and installed. A result of all
#  this is that users of a non-persistent ISO boot will have everything
#  on the RAM drive, which may be quite limited to begin with depending
#  on your computer's available RAM. Users with >2gb RAM shouldn't have
#  to worry, but those on old netbooks might. If run from a persistent VM
#  or 8gb USB things should be ok too.
# ***

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

# live disc's username is "user"
if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

TMP_DIR=/tmp/build_grass
mkdir -p "$TMP_DIR"

apt-get --quiet update

# Install Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
\. "$HOME/.nvm/nvm.sh"
nvm install 22

# cleanup
rmdir "$TMP_DIR"

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end

