#!/bin/sh
#############################################################################
#
# Purpose: This script will install Jave JRE and Java JDK
#
#############################################################################
# Copyright (c) 2009-2026 Open Source Geospatial Foundation (OSGeo) and others.
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

# default-jdk is OpenJDK 25 on Ubuntu 26.04; the Java applications on the
# disc (GeoServer, deegree, ...) are released for Java 21, so install that
# and make it the default for all Java alternatives
JAVA_VERSION="21"
apt-get install --yes "openjdk-$JAVA_VERSION-jdk" "openjdk-$JAVA_VERSION-jre"
if [ $? -ne 0 ] ; then
   echo 'ERROR: Package install failed! Aborting.'
   exit 1
fi
update-java-alternatives --set "java-1.$JAVA_VERSION.0-openjdk-amd64"

# GeoServer and other apps expect /usr/lib/jvm/default-java (from
# default-jre). We pin OpenJDK 21 instead of Ubuntu 26.04's default-jdk
# (OpenJDK 25), so create the conventional symlink ourselves.
JAVA_JVM_DIR="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"
if [ -x "$JAVA_JVM_DIR/bin/java" ]; then
   ln -sfn "java-${JAVA_VERSION}-openjdk-amd64" /usr/lib/jvm/default-java
else
   echo "ERROR: expected JVM missing: $JAVA_JVM_DIR"
   exit 1
fi

# OSGeoLive #2478: antialiased Swing text. Do NOT use global _JAVA_OPTIONS /
# JDK_JAVA_OPTIONS: both make "java -version" print a "Picked up ..." line
# first, which breaks the JOSM launcher (parses version via head -n1) so the
# required --add-exports flags are skipped ("Missing JVM Arguments").
SWING_PROPS="$JAVA_JVM_DIR/lib/swing.properties"
if [ -d "$JAVA_JVM_DIR/lib" ] ; then
   touch "$SWING_PROPS"
   grep -q '^swing.aatext=' "$SWING_PROPS" 2>/dev/null || \
      echo 'swing.aatext=true' >> "$SWING_PROPS"
fi

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
