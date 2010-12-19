#!/bin/sh -e
set -v

[ -z "$DIR" ] && echo "DIR is not set" && exit 1
[ ! -d "$DIR" ] && echo "No such directory: $DIR" && exit 1

install="$DIR/install"
[ -d $install ] && rm -rf $install
mkdir -p $install && cd $install

# Copy these files.
ver="0.24"
cp -p $DIR/bin/libfreetype-6.dll $DIR/bin/libmp3lame-0.dll $DIR/bin/pthreadGC2.dll .
cp -p $DIR/bin/QtCored4.dll $DIR/bin/QtGuid4.dll $DIR/bin/QtNetworkd4.dll $DIR/bin/QtOpenGLd4.dll $DIR/bin/QtSqld4.dll $DIR/bin/QtWebKitd4.dll $DIR/bin/QtXmld4.dll $DIR/bin/Qt3Supportd4.dll $DIR/bin/QtSvgd4.dll .
cp -r $DIR/plugins/* .
cp $DIR/bin/libmythavcodec-52.dll $DIR/bin/libmythavcore-0.dll $DIR/bin/libmythavdevice-52.dll $DIR/bin/libmythavfilter-1.dll $DIR/bin/libmythavformat-52.dll $DIR/bin/libmythavutil-50.dll $DIR/bin/libmythpostproc-51.dll $DIR/bin/libmythswscale-0.dll .
cp $DIR/bin/libmyth-$ver.dll $DIR/bin/libmythdb-$ver.dll $DIR/bin/libmythfreemheg-$ver.dll $DIR/bin/libmythmetadata-$ver.dll $DIR/bin/libmythtv-$ver.dll $DIR/bin/libmythui-$ver.dll $DIR/bin/libmythupnp-$ver.dll .
cp $DIR/bin/mythfrontend.exe $DIR/bin/mythbackend.exe $DIR/bin/mythtv-setup.exe .
mkdir share && cp -p -r $DIR/share/mythtv share/
mkdir lib && cp -p -r $DIR/lib/mythtv lib/
# Mingw runtime
cp -p /usr/share/doc/mingw32-runtime/mingwm10.dll.gz . && gunzip mingwm10.dll.gz
# MySQL
#cp -p $DIR/mysql-5.5.5-m3-win32/lib/libmysql.dll .
cp -p $DIR/build/mysql-5.0.89-win32/lib/opt/libmysql.dll .
# Optional if mythgallery built
cp -p $DIR/bin/libexif-12.dll .
# Optional if mythmusic built
cp -p $DIR/bin/libogg-0.dll $DIR/bin/libvorbis-0.dll $DIR/bin/libvorbisenc-2.dll $DIR/bin/libtag-1.dll .

