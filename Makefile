.PHONY:	mythtv/mythtv mythtv/mythplugins myththemes nuvexport mythweb
.PHONY: force backgrounds

SUBDIRS = mythtv/mythtv mythtv/mythplugins myththemes #nuvexport

all clean patch-clean patch-remove:
	gmake do-$@ ${MAKEOPTS}

do-all:	${SUBDIRS} backgrounds

do-clean:	force
	-for i in ${SUBDIRS} ; do ${MAKE} -C $$i distclean ; done

do-patch-clean:	force
	find . -name \*.rej -exec rm {} \;
	find . -name \*.orig -exec rm {} \;

do-patch-remove: force
	find . -name \*.diff -exec rm {} \;
	find . -name \*.patch \( -exec egrep {} patch.exclude \; \) \
	    -prune -o \( -name \*.patch -exec rm {} \; \)

BRANCH=${shell git branch | sed -e '/^[^\*]/d' -e 's/^\* //' -e 's/(no branch)/testing/'}
HOST=${shell hostname | sed -e 's/\..*$$//'}

THREADS-mythbe	             = -j 9
THREADS-mythfe	             = -j 3
THREADS-mythtv	             = -j 2

CONFIG-mythtv-fitpc          = --enable-vaapi

CONFIG-mythtv-freebsd        = --extra-cflags=-I/usr/local/include
CONFIG-mythtv-freebsd       += --extra-ldflags=-I/usr/local/lib
CONFIG-mythplugins-freebsd   = --extra-cflags=-I/usr/local/include
CONFIG-mythplugins-freebsd  += --extra-ldflags=-I/usr/local/lib



PREFIX               = /opt/mythtv/${BRANCH}

PERLOPTS             = PREFIX=${PREFIX}
#PERLOPTS            += SITELIBEXP=${PREFIX}/share/perl/5.10.1
#PERLOPTS            += SITEARCHEXP=${PREFIX}/lib/perl/5.10.1

CONFIG-mythtv        = --prefix=${PREFIX}
CONFIG-mythtv       += --compile-type=debug
CONFIG-mythtv       += --enable-symbol-visibility
CONFIG-mythtv       += --perl-config-opts="${PERLOPTS}"
CONFIG-mythtv       += ${CONFIG-mythtv-${HOST}}

CONFIG-myththemes    = --prefix=${PREFIX}
CONFIG-myththemes   += --compile-type=debug

CONFIG-mythplugins   = --prefix=${PREFIX}
CONFIG-mythplugins  += --enable-all 
CONFIG-mythplugins  += --compile-type=debug
CONFIG-mythplugins  += ${CONFIG-mythtvplugins-${HOST}}

mythtv/mythtv myththemes mythtv/mythplugins:
	(cd $@ ; ./configure ${CONFIG-${@*/%%}})
	${MAKE} ${THREADS-${HOST}} -C $@
	sudo ${MAKE} -C $@ install

backgrounds:
	sudo rsync -avCt --delete backgrounds/ ${PREFIX}/share/mythtv/themes/Arclight/Backgrounds/

nuvexport:
	sudo ${MAKE} -C $@ install

mythweb:
	sudo rsync -avCt mythweb/ /var/www/mythweb/
	sudo chown -R www-data.www-data /var/www/mythweb/

# WARNING: disabling Python bindings; missing MySQLdb
# WARNING: disabling Python bindings; missing lxml
# WARNING: disabling Perl bindings; missing DBI
# WARNING: disabling Perl bindings; missing Net::UPnP::QueryResponse
# WARNING: disabling Perl bindings; missing Net::UPnP::ControlPoint
# MythMusic requires FLAC.
# MythMusic requires libcdaudio.
# MythMusic requires CDDA Paranoia.
# MythMusic requires taglib 1.5 or later.

# Core and bindings
DEBS  = python-mysqldb python-lxml libdbi-perl libdbd-mysql-perl 
DEBS += libnet-upnp-perl mysql-server mysql-client libmysqlclient-dev
# Mythmusic
DEBS += libflac-dev libcdaudio-dev libcdparanoia-dev libtag1-dev 
# Mythgallery
DEBS += libexif-dev dcraw icc-profiles
# Mythweather scripts
DEBS += libdate-manip-perl libxml-simple-perl libimage-size-perl
DEBS += libdatetime-format-iso8601-perl libsoap-lite-perl libxml-xpath-perl
# Mythnetvision
DEBS += python-oauth
# JAMU
DEBS += python-imaging python-imdbpy
# nuvexport
DEBS += libid3-3.8.3-dev

apt-get:	force
	sudo apt-get build-dep mythtv
	sudo apt-get install ${DEBS}
