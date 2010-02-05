NULL =

sqlheavy-@SQLHEAVY_API_VERSION@:
	valadoc \
		--force \
		--pkg sqlite3 \
		-b $(top_srcdir)/sqlheavy \
		-o $(top_srcdir)/valadoc/sqlheavy-@SQLHEAVY_API_VERSION@ \
		--package-name sqlheavy-@SQLHEAVY_API_VERSION@ \
		--package-version @SQLHEAVY_VERSION@ \
		$(top_srcdir)/sqlheavy/sqlheavy-database.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-enums.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-error.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-queryable.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-statement.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-transaction.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-user-functions.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-versioned-database.vala \
		$(top_srcdir)/sqlheavy/sqlheavy-value.vala \
		$(NULL)

valadoc_DATA = sqlheavy-@SQLHEAVY_API_VERSION@
valadocdir = /usr/share/doc/sqlheavy-@SQLHEAVY_API_VERSION@
