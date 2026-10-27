#!/bin/sh
#
# install_ossim.sh
#
#############################################################################
# Created by Massimo Di Stefano on 07/12/09.
# Copyright (c) 2010-2026 Open Source Geospatial Foundation (OSGeo) and others.
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
# in the "LICENSE.LGPL.txt" file distributed with this software or at
# web page "http://www.fsf.org/licenses/lgpl.html".
#############################################################################

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

# ossim-core is not in Ubuntu 26.04 and there is no maintained binary
# package for the live disc. Skip on the ISO; optional tooling for
# builders may use install_vm_only.sh later.
echo "NOTE: OSSIM is not packaged for Ubuntu 26.04; skipping install_ossim.sh."

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
