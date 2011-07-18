NULL = 

lib_LTLIBRARIES = \
	libsqlheavygtk@SQLHEAVY_API_VERSION@.la \
	$(NULL)

libsqlheavygtk@SQLHEAVY_API_VERSION@_la_SOURCES = \
	sqlheavy-gtk-model.vala \
	$(NULL)

# If introspection is enabled we need to ask valac to generate a GIR
# for us.

if HAVE_INTROSPECTION
GIR_SQLHEAVYGTK_VALAFLAGS = \
	--gir SQLHeavyGtk-@SQLHEAVY_API_VERSION@.gir \
	$(NULL)
else
GIR_SQLHEAVYGTK_VALAFLAGS =
endif

libsqlheavygtk@SQLHEAVY_API_VERSION@_la_VALAFLAGS = \
	$(GIR_SQLHEAVYGTK_VALAFLAGS) \
	--library sqlheavygtk-@SQLHEAVY_API_VERSION@ \
	--target-glib 2.24 \
	--vapi sqlheavygtk-@SQLHEAVY_API_VERSION@.vapi \
	-H SQLHeavyGTK.h \
	--use-header \
	--internal-header sqlheavygtk-@SQLHEAVY_API_VERSION@-internal.h \
	--vapidir $(top_srcdir)/sqlheavy \
	--pkg $(GTK_PACKAGE) \
	--pkg sqlheavy-@SQLHEAVY_API_VERSION@ \
	$(NULL)

libsqlheavygtk@SQLHEAVY_API_VERSION@_la_CFLAGS = \
	-I$(top_srcdir)/sqlheavy \
	$(GTK_CFLAGS) \
	$(NULL)

libsqlheavygtk@SQLHEAVY_API_VERSION@_la_LDFLAGS = \
	$libsqlheavy@SQLHEAVY_API_VERSION@_la_LDFLAGS \
	$(GTK_LIBS) \
	$(NULL)

sqlheavyincludedir = $(includedir)/sqlheavy/sqlheavy-$(SQLHEAVY_API_VERSION)
sqlheavyinclude_HEADERS = \
	SQLHeavyGTK.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
vapi_DATA = \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.vapi \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.deps \
	$(NULL)

DISTCLEANFILES = \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.deps \
	$(NULL)

MAINTAINERCLEANFILES = \
	SQLHeavyGTK.h \
	SQLHeavyGtk-@SQLHEAVY_API_VERSION@.gir \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.vapi \
	$(NULL)

EXTRA_DIST = \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.vapi \
	sqlheavygtk-@SQLHEAVY_API_VERSION@.deps.in \
	$(NULL)
