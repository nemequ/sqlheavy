NULL = 

lib_LTLIBRARIES = \
	libsqlheavy.la \
	$(NULL)

libsqlheavy_la_SOURCES = \
	sqlheavy-database.vala \
	sqlheavy-enums.vala \
	sqlheavy-error.vala \
	sqlheavy-statement.vala

libsqlheavy_la_VALAFLAGS = \
	--vapi sqlheavy-@SQLHEAVY_API_VERSION@.vapi \
	--gir SQLHeavy-@SQLHEAVY_API_VERSION@.gir \
	-H SQLHeavy.h \
	--use-header \
	--internal-header sqlheavy-internal.h \
	--internal-vapi sqlheavy-internal.vapi \
	--thread \
	--pkg gio-2.0 \
	--pkg glib-2.0 \
	--pkg gobject-2.0 \
	--pkg sqlite3 \
	$(NULL)

libsqlheavy_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(SQLITE3_CFLAGS) \
	$(NULL)

sqlheavyincludedir = $(includedir)/sqlheavy-$(SQLHEAVY_API_VERSION)
sqlheavyinclude_HEADERS = \
	SQLHeavy.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
vapi_DATA = \
	sqlheavy-@SQLHEAVY_API_VERSION@.vapi \
	$(NULL)

# For some reason valac isn't generating SQLHeavy-1.0.gir
#girdir = $(datadir)/gir-1.0
#gir_DATA = \
#	SQLHeavy-$(SQLHEAVY_API_VERSION).gir \
#	$(NULL)