NULL =

SUBDIRS = \
	sqlheavy \
	examples \
	docs \
	$(NULL)

ACLOCAL_AMFLAGS=-I m4

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = \
	sqlheavy-@SQLHEAVY_API_VERSION@.pc \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.pc \
	$(NULL)

DISTCLEANFILES = \
	sqlheavy-@SQLHEAVY_API_VERSION@.pc \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.pc \
	$(NULL)

EXTRA_DIST = \
	sqlheavy-@SQLHEAVY_API_VERSION@.pc.in \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.pc.in \
	$(NULL)

DISTCHECK_CONFIGURE_FLAGS = \
	--enable-valadoc=no \
	$(NULL)
