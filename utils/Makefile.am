NULL = 

LDADD = \
	$(top_builddir)/sqlheavy/libsqlheavy$(SQLHEAVY_API_VERSION).la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GMODULE_LIBS) \
	$(SQLITE3_LIBS) \
	$(VALA_LIBS) \
	$(NULL)

bin_PROGRAMS = sqlheavy-gen-orm

VALAFLAGS = \
	--vapidir $(top_srcdir)/sqlheavy \
	--pkg $(VALA_PACKAGE) \
	--pkg sqlheavy-@SQLHEAVY_API_VERSION@ \
	$(NULL)

AM_CFLAGS = \
	-I$(top_srcdir)/sqlheavy \
	$(GIO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GMODULE_CFLAGS) \
	$(SQLITE3_CFLAGS) \
	$(VALA_CFLAGS) \
	$(NULL)

sqlheavy_gen_orm_SOURCES = \
	sqlheavy-gen-orm.vala \
	$(NULL)
