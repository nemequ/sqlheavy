NULL = 

LDADD = \
	$(top_builddir)/sqlheavy/libsqlheavy-$(SQLHEAVY_API_VERSION).la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GMODULE_LIBS) \
	$(SQLITE3_LIBS) \
	$(NULL)

noinst_PROGRAMS = \
	async \
	common-functions \
	$(NULL)

VALAFLAGS = \
	--vapidir $(top_builddir)/sqlheavy \
	--pkg sqlheavy-1.0 \
	$(NULL)

CFLAGS = \
	-I$(top_builddir)/sqlheavy \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(SQLITE3_CFLAGS) \
	$(NULL)

async_SOURCES = \
	async.vala \
	$(NULL)

common_functions_SOURCES = \
	common-functions.vala \
	$(NULL)
