#!/bin/sh
#############################################################################
#
# Purpose: This script will install Jave JRE and Java JDK
#
#############################################################################
# Copyright (c) 2009-2024 Open Source Geospatial Foundation (OSGeo) and others.
#
# Licensed under the GNU LGPL.
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
####

# NOTE: We have changed the java-common package in our ppa to point default-jdk to openjdk-17
#apt-get install --yes default-jdk default-jre
apt-get install --yes openjdk-11-jdk openjdk-11-jre

ln -s /usr/lib/jvm/java-11-openjdk-amd64/ /usr/lib/jvm/default-java

cat <<EOF >> /etc/environment
# fix #2478 - java ugly/non-antialiased font rendering
_JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true'
EOF

# apt-get install --yes gsfonts-x11

# Fetch/Install prebuilt libgdal-java components
# URL="http://download.osgeo.org/livedvd/data/gdal/gdal-3.4.3+dfsg-java.20220622.tgz"
# FILE=/tmp/$(basename "$URL")
# wget --no-verbose -O "$FILE" "$URL" && \
# tar xvf "$FILE" -C / && \
# ls -la /usr/lib/jni/libgdalalljni.so /usr/share/java/gdal.jar && \
# rm "$FILE" || { echo "error installing gdal-java"; exit 1; }

####
./diskspace_probe.sh "`basename $0`" end
