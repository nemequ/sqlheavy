NULL = 

CLEANFILES =

lib_LTLIBRARIES = \
	libsqlheavy-@SQLHEAVY_API_VERSION@.la \
	$(NULL)

libsqlheavy_@SQLHEAVY_API_VERSION@_la_SOURCES = \
	sqlheavy-backup.vala \
	sqlheavy-common-function.vala \
	sqlheavy-database.vala \
	sqlheavy-database-pool.vala \
	sqlheavy-enums.vala \
	sqlheavy-error.vala \
	sqlheavy-queryable.vala \
	sqlheavy-record.vala \
	sqlheavy-row.vala \
	sqlheavy-statement.vala \
	sqlheavy-table.vala \
	sqlheavy-transaction.vala \
	sqlheavy-transaction-stack.vala \
	sqlheavy-user-functions.vala \
	sqlheavy-value.vala \
	sqlheavy-version.vala \
	sqlheavy-versioned-database.vala \
	$(NULL)

if HAVE_INTROSPECTION
GIR_VALAFLAGS = \
	--gir SQLHeavy-@SQLHEAVY_API_VERSION@.gir \
	--library sqlheavy-1.0 \
	$(NULL)
else
GIR_VALAFLAGS =
endif

libsqlheavy_@SQLHEAVY_API_VERSION@_la_VALAFLAGS = \
	$(GIR_VALAFLAGS) \
	--target-glib $(GLIB_VERSION) \
	--vapi sqlheavy-@SQLHEAVY_API_VERSION@.vapi \
	-H SQLHeavy.h \
	--internal-header sqlheavy-@SQLHEAVY_API_VERSION@-internal.h \
	--vapidir $(top_srcdir)/sqlheavy \
	--pkg config \
	--pkg gio-2.0 \
	--pkg glib-2.0 \
	--pkg gobject-2.0 \
	--pkg sqlite3 \
	$(NULL)

libsqlheavy_@SQLHEAVY_API_VERSION@_la_CFLAGS = \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(SQLITE3_CFLAGS) \
	$(NULL)

libsqlheavy_@SQLHEAVY_API_VERSION@_la_LDFLAGS = \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GMODULE_LIBS) \
	$(SQLITE3_LIBS) \
	$(NULL)

sqlheavyincludedir = $(includedir)/sqlheavy/sqlheavy-$(SQLHEAVY_API_VERSION)
sqlheavyinclude_HEADERS = \
	SQLHeavy.h \
	$(NULL)

vapidir = $(datadir)/vala/vapi
vapi_DATA = \
	sqlheavy-@SQLHEAVY_API_VERSION@.vapi \
	sqlheavy-@SQLHEAVY_API_VERSION@.deps \
	$(NULL)

if HAVE_INTROSPECTION

girdir = $(INTROSPECTION_GIRDIR)
# gir_DATA = SQLHeavy-$(SQLHEAVY_API_VERSION).gir

typelibsdir = $(INTROSPECTION_TYPELIBDIR)
# typelibs_DATA = $(gir_DATA:.gir=.typelib)

%.typelib: %.gir $(INTROSPECTION_COMPILER)
	LD_LIBRARY_PATH=.libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} \
	$(INTROSPECTION_COMPILER) \
		--includedir=$(srcdir) \
		--includedir=. \
		$(INTROSPECTION_COMPILER_OPTS) $< -o $(@F)

CLEANFILES += \
	$(typelibs_DATA) \
	$(NULL)

endif # HAVE_INTROSPECTION

MAINTAINERCLEANFILES = \
	SQLHeavy.h \
	SQLHeavy-@SQLHEAVY_API_VERSION@.gir \
	sqlheavy-@SQLHEAVY_API_VERSION@.vapi \
	$(NULL)


EXTRA_DIST = \
	config.vapi \
	sqlheavy-version.vala.in \
	sqlheavy-@SQLHEAVY_API_VERSION@.vapi \
	sqlheavy-@SQLHEAVY_API_VERSION@.deps \
	$(NULL)
