#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

m4_define([sqlheavy_major], [0])
m4_define([sqlheavy_minor], [2])
m4_define([sqlheavy_micro], [0])

m4_define([sqlheavy_version], [sqlheavy_major.sqlheavy_minor.sqlheavy_micro])
m4_define([sqlheavy_api_version], [0.2])

m4_define([sqlheavy_name], [sqlheavy])

AC_PREREQ([2.64])
AC_INIT([SQLHeavy], [sqlheavy_version], [evan@coeus-group.com]. [sqlheavy_name])
AC_CONFIG_HEADERS([sqlheavy/config.h])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([dist-bzip2])
AM_MAINTAINER_MODE

SQLHEAVY_MAJOR_VERSION=sqlheavy_major
SQLHEAVY_MINOR_VERSION=sqlheavy_minor
SQLHEAVY_MICRO_VERSION=sqlheavy_micro
SQLHEAVY_VERSION=sqlheavy_version
SQLHEAVY_API_VERSION=sqlheavy_api_version
AC_SUBST(SQLHEAVY_MAJOR_VERSION)
AC_SUBST(SQLHEAVY_MINOR_VERSION)
AC_SUBST(SQLHEAVY_MICRO_VERSION)
AC_SUBST(SQLHEAVY_VERSION)
AC_SUBST(SQLHEAVY_API_VERSION)

AX_DEFINE_DIR([SQL_HEAVY_CONFIG_PATH_PREFIX], [prefix], [sqlheavy installation prefix])
AX_DEFINE_DIR([SQL_HEAVY_CONFIG_PATH_DATA], [datadir], [sqlheavy data directory])
AX_DEFINE_DIR([SQL_HEAVY_CONFIG_PATH_PACKAGE_DATA], [datadir]/[sqlheavy_name], [sqlheavy package data directory])

m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

GLIB_REQUIRED=2.22.0
SQLITE3_REQUIRED=3.6.20
VALADOC_REQUIRED=0.2
VALA_REQUIRED=0.13.1
GTK_REQUIRED=2.24

# Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_INSTALL
AC_PROG_LIBTOOL
AM_PROG_VALAC($VALA_REQUIRED)

# GOBJECT_INTROSPECTION_CHECK([0.10])
AM_CONDITIONAL(HAVE_INTROSPECTION, false)

# Checks for libraries.
PKG_CHECK_MODULES(GIO, gio-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GIO_CFLAGS)
AC_SUBST(GIO_LIBS)
PKG_CHECK_MODULES(GLIB, glib-2.0 >= $GLIB_REQUIRED)
GLIB_VERSION=$($PKG_CONFIG --modversion glib-2.0)
AC_SUBST(GLIB_VERSION)
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)
PKG_CHECK_MODULES(GMODULE, gmodule-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GMODULE_CFLAGS)
AC_SUBST(GMODULE_LIBS)
PKG_CHECK_MODULES(SQLITE3, sqlite3 >= $SQLITE3_REQUIRED)
AC_SUBST(SQLITE3_CFLAGS)
AC_SUBST(SQLITE3_LIBS)
PKG_CHECK_MODULES(VALA, libvala-0.14 >= $VALA_REQUIRED)
VALA_PACKAGE=libvala-0.14
AC_SUBST(VALA_PACKAGE)
AC_SUBST(VALA_CFLAGS)
AC_SUBST(VALA_LIBS)
PKG_CHECK_MODULES(GTK, gtk+-2.0 >= $GTK_REQUIRED)
GTK_PACKAGE=gtk+-2.0
AC_SUBST(GTK_PACKAGE)
AC_SUBST(GTK_CFLAGS)
AC_SUBST(GTK_LIBS)

AC_ARG_ENABLE(valadoc,
  AS_HELP_STRING([--enable-valadoc[=@<:@no/auto/yes@:>@]], [Enable valadoc support]),,
    [enable_valadoc=auto])

found_valadoc=no
AS_IF([test "x$enable_valadoc" != "xno"], [
    AC_PATH_PROG(VALADOC, valadoc, :)
    AS_IF([test -x "$VALADOC"], [
      found_valadoc=yes
      AC_SUBST(VALADOC)
    ], [
      AS_IF([test "x$enable_valadoc" == "xyes"], AC_MSG_ERROR([Unable to find valadoc]))
    ])
  ])

AM_CONDITIONAL(ENABLE_VALADOC, test x$found_valadoc = xyes)

# Checks for header files.
AC_CHECK_HEADERS([stdlib.h string.h])

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_CONFIG_FILES([Makefile
                 data/Makefile
                 data/schemas/Makefile
                 data/schemas/profiling/Makefile
                 docs/Makefile
                 examples/Makefile
                 gtk/Makefile
                 gtk/sqlheavygtk-$SQLHEAVY_API_VERSION.deps
                 sqlheavy/Makefile
                 sqlheavy/sqlheavy-version.vala
                 sqlheavy-$SQLHEAVY_API_VERSION.pc
                 sqlheavygtk-$SQLHEAVY_API_VERSION.pc
                 utils/Makefile])
AC_OUTPUT
