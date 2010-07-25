NULL =

SUBDIRS = \
	sqlheavy \
	examples \
	utils \
	docs \
	$(NULL)

ACLOCAL_AMFLAGS=-I m4

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = \
	sqlheavy-@SQLHEAVY_API_VERSION@.pc \
	$(NULL)

DISTCLEANFILES = \
	sqlheavy-@SQLHEAVY_API_VERSION@.pc \
	$(NULL)

EXTRA_DIST = \
	sqlheavy-@SQLHEAVY_API_VERSION@.pc.in \
	$(NULL)

DISTCHECK_CONFIGURE_FLAGS = \
        --enable-introspection=no \
        $(NULL)
