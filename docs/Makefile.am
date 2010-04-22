NULL =

if ENABLE_VALADOC

VALADOC_FLAGS = \
		--force \
		--pkg sqlite3 \
		--pkg gio-2.0 \
		-b $(top_srcdir)/sqlheavy \
		--package-name sqlheavy-@SQLHEAVY_API_VERSION@ \
		--package-version @SQLHEAVY_VERSION@ \
		$(top_srcdir)/sqlheavy/sqlheavy-common-function.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-database.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-enums.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-error.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-queryable.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-statement.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-transaction.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-transaction-stack.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-user-functions.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-versioned-database.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-value.vala \
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
		-X $(top_srcdir)/sqlheavy/sqlheavy-1.0-internal.h \
		-X -l -X $(top_srcdir)/sqlheavy/.libs/libsqlheavy-1.0.so \
		-o gtkdoc \
		--doclet gtkdoc \
		$(VALADOC_FLAGS) \
		$(NULL)

clean-local:
	rm -rf valadoc devhelp gtkdoc

uninstall-hook:
	rm -rf $(DESTDIR)$(datadir)/devhelp/books/sqlheavy-@SQLHEAVY_API_VERSION@
#	rm -rf $(DESTDIR)$(datadir)/gtk-doc/html/sqlheavy-@SQLHEAVY_API_VERSION@

install-data-hook: devhelp # gtkdoc
	$(MKDIR_P) $(DESTDIR)$(datadir)/devhelp/books/sqlheavy-@SQLHEAVY_API_VERSION@/img
	$(INSTALL_DATA) -t $(DESTDIR)$(datadir)/devhelp/books/sqlheavy-@SQLHEAVY_API_VERSION@ devhelp/sqlheavy-@SQLHEAVY_API_VERSION@/*.*
	$(INSTALL_DATA) -t $(DESTDIR)$(datadir)/devhelp/books/sqlheavy-@SQLHEAVY_API_VERSION@/img devhelp/sqlheavy-@SQLHEAVY_API_VERSION@/img/*
#	cp -R gtkdoc/html $(DESTDIR)$(datadir)/gtk-doc/html/sqlheavy-@SQLHEAVY_API_VERSION@

all: valadoc devhelp # gtkdoc

endif
