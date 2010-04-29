NULL = 

LDADD = \
	$(top_builddir)/sqlheavy/libsqlheavy-$(SQLHEAVY_API_VERSION).la \
	$(GIO_LIBS) \
	$(GLIB_LIBS) \
	$(GMODULE_LIBS) \
	$(SQLITE3_LIBS) \
	$(NULL)

bin_PROGRAMS = sqlheavy-gen-orm

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

sqlheavy_gen_orm_SOURCES = \
	sqlheavy-gen-orm.vala \
	$(NULL)
