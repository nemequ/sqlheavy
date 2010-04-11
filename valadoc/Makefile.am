NULL =

VALADOC_FLAGS = \
		--force \
		--pkg sqlite3 \
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

sqlheavy-@SQLHEAVY_API_VERSION@:
	valadoc \
		-o $(top_srcdir)/valadoc/sqlheavy-@SQLHEAVY_API_VERSION@ \
		$(VALADOC_FLAGS) \
		$(NULL)

sqlheavy-@SQLHEAVY_API_VERSION@-gtkdoc/html:
	valadoc \
		-X --ignore-headers \
		-X $(top_srcdir)/sqlheavy/sqlheavy-1.0-internal.h \
		-X -l -X $(top_srcdir)/sqlheavy/.libs/libsqlheavy-1.0.so \
		-o $(top_srcdir)/valadoc/sqlheavy-@SQLHEAVY_API_VERSION@-gtkdoc \
		--doclet gtkdoc \
		$(VALADOC_FLAGS) \
		$(NULL)

valadoc_DATA = sqlheavy-@SQLHEAVY_API_VERSION@
valadocdir = /usr/share/doc/sqlheavy-@SQLHEAVY_API_VERSION@

gtkdoc_DATA = sqlheavy-@SQLHEAVY_API_VERSION@-gtkdoc/html
gtkdocdir = /usr/share/gtk-doc/html
