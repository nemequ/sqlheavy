NULL =

man_MANS = sqlheavy-gen-orm.1

EXTRA_DIST = sqlheavy-gen-orm.1

if ENABLE_VALADOC

VALADOC_FLAGS = --force \
		--vapidir $(top_srcdir)/sqlheavy \
		--pkg config \
		--pkg sqlite3 \
		--pkg gio-2.0 \
		--pkg gmodule-2.0 \
		-b $(top_srcdir)/sqlheavy \
		--package-name SQLHeavy \
		--package-version @SQLHEAVY_VERSION@ \
		$(top_srcdir)/sqlheavy/sqlheavy-backup.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-common-function.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-cursor.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-database.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-database-pool.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-enums.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-error.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-mutable-record.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-profiling-database.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-query.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-queryable.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-query-result.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-record.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-record-set.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-row.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-table.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-table-cursor.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-transaction.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-user-functions.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-value.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-version.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-versioned-database.vala \
		$(NULL)

valadoc:
	$(VALADOC) \
		-o valadoc \
		$(VALADOC_FLAGS) \
		$(NULL)

devhelp:
	$(VALADOC) \
		-o devhelp \
		--doclet devhelp \
		$(VALADOC_FLAGS) \
		$(NULL)

gtkdoc:
	$(VALADOC) \
		-X --ignore-headers \
		-X $(top_srcdir)/sqlheavy/sqlheavy-@SQLHEAVY_API_VERSION@-internal.h \
		-X -l -X $(top_srcdir)/sqlheavy/.libs/libsqlheavy-@SQLHEAVY_API_VERSION@.so \
		-o gtkdoc \
		--doclet gtkdoc \
		$(VALADOC_FLAGS) \
		$(NULL)

clean-local:
	rm -rf valadoc devhelp gtkdoc

uninstall-hook:
	rm -rf $(DESTDIR)$(datadir)/devhelp/books/SQLHeavy
	rm -rf $(DESTDIR)$(datadir)/gtk-doc/html/SQLHeavy

install-data-hook: devhelp gtkdoc
	$(MKDIR_P) $(DESTDIR)$(datadir)/devhelp/books/SQLHeavy/img
	$(INSTALL_DATA) -t $(DESTDIR)$(datadir)/devhelp/books/SQLHeavy devhelp/SQLHeavy/*.*
	$(INSTALL_DATA) -t $(DESTDIR)$(datadir)/devhelp/books/SQLHeavy/img devhelp/SQLHeavy/img/*
	cp -R gtkdoc/html $(DESTDIR)$(datadir)/gtk-doc/html/SQLHeavy

all: valadoc devhelp # gtkdoc

endif
