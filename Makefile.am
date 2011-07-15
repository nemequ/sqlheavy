NULL =

SUBDIRS = \
	sqlheavy \
	gtk \
	examples \
	utils \
	docs \
	data \
	$(NULL)

ACLOCAL_AMFLAGS=-I m4

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = \
	sqlheavy-@SQLHEAVY_API_VERSION@.pc \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.pc \
	$(NULL)

DISTCLEANFILES = \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.pc \
	$(NULL)

EXTRA_DIST = \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.pc.in \
	$(NULL)

DISTCHECK_CONFIGURE_FLAGS = \
        --enable-introspection=no \
        $(NULL)
