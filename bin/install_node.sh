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


./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

# live disc's username is "user"
if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

# NVM installieren
su - $USER_NAME -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash"

# NVM initialisieren
su - $USER_NAME -c ". $USER_HOME/.nvm/nvm.sh && nvm install 22"

# Optional: Überprüfe die Installation
su - $USER_NAME -c ". $USER_HOME/.nvm/nvm.sh && node -v && npm -v"

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end

