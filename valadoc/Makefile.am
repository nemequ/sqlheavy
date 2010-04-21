NULL =

if ENABLE_VALADOC

VALADOC_FLAGS = \
		--force \
		--pkg sqlite3 \
		--pkg gio-2.0 \
		-b $(top_srcdir)/sqlheavy \
		--package-name sqlheavy-@SQLHEAVY_API_VERSION@ \
		--package-version @SQLHEAVY_VERSION@ \
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

# The gtkdoc doclet doesn't play nice yet.
#gtkdoc_DATA = sqlheavy-@SQLHEAVY_API_VERSION@-gtkdoc/html
#gtkdocdir = /usr/share/gtk-doc/html

clean-local:
	rm -rf devhelp

uninstall-hook:
	rm -rf $(datadir)/devhelp/books/sqlheavy-@SQLHEAVY_API_VERSION@

install-data-hook: devhelp
	cp -R devhelp/sqlheavy-@SQLHEAVY_API_VERSION@ $(datadir)/devhelp/books/sqlheavy-@SQLHEAVY_API_VERSION@

all: devhelp

endif
