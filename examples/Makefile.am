NULL =

LDADD = \
	$(top_builddir)/sqlheavy/libsqlheavy$(SQLHEAVY_API_VERSION).la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GMODULE_LIBS) \
	$(SQLITE3_LIBS) \
	$(NULL)

noinst_PROGRAMS = \
	async \
	backup \
	common-functions \
	orm \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir $(top_builddir)/sqlheavy \
	--pkg sqlheavy-$(SQLHEAVY_API_VERSION) \
	--pkg gio-2.0 \
	$(NULL)

AM_CFLAGS = \
	-I$(top_builddir)/sqlheavy \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(SQLITE3_CFLAGS) \
	$(NULL)

async_SOURCES = \
	async.vala \
	$(NULL)

backup_SOURCES = \
	backup.vala \
	$(NULL)

common_functions_SOURCES = \
	common-functions.vala \
	$(NULL)

orm_SOURCES = \
	orm.vala \
	$(NULL)
