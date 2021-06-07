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
	browser \
	common-functions \
	orm \
	$(NULL)

AM_VALAFLAGS = \
	--vapidir $(top_srcdir)/sqlheavy \
	--pkg sqlheavy-$(SQLHEAVY_API_VERSION) \
	$(NULL)

SQLHEAVYGTK_VALAFLAGS = \
	--vapidir $(top_srcdir)/gtk \
	--pkg sqlheavygtk-$(SQLHEAVY_API_VERSION) \
	$(NULL)

AM_CFLAGS = \
	-I$(top_srcdir)/sqlheavy \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(SQLITE3_CFLAGS) \
	$(NULL)

SQLHEAVYGTK_CFLAGS = \
	-I$(top_srcdir)/gtk \
	$(NULL)

async_SOURCES = \
	async.vala \
	$(NULL)

backup_SOURCES = \
	backup.vala \
	$(NULL)

browser_SOURCES = \
	browser.vala \
	$(NULL)

browser_CFLAGS = \
	$(GTK_CFLAGS) \
	$(SQLHEAVYGTK_CFLAGS) \
	$(NULL)

browser_LDFLAGS = \
	$(top_builddir)/gtk/libsqlheavygtk$(SQLHEAVY_API_VERSION).la \
	$(GTK_LIBS) \
	$(NULL)

browser_VALAFLAGS = \
	$(SQLHEAVYGTK_VALAFLAGS) \
	$(NULL)

common_functions_SOURCES = \
	common-functions.vala \
	$(NULL)

orm_SOURCES = \
	orm.vala \
	$(NULL)
