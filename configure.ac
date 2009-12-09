#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

m4_define([sqlheavy_major], [0])
m4_define([sqlheavy_minor], [0])
m4_define([sqlheavy_micro], [1])

m4_define([sqlheavy_version], [sqlheavy_major.sqlheavy_minor.sqlheavy_micro])
m4_define([sqlheavy_api_version], [1.0])

AC_PREREQ([2.65])
AC_INIT([SQLHeavy], [sqlheavy_version], [evan@coeus-group.com]. [sqlheavy])
AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([dist-bzip2])
AC_CONFIG_MACRO_DIR([m4])
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

#m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LIBTOOL

AM_PROG_VALAC([0.7.9])

# Checks for libraries.
GLIB_REQUIRED=2.12.0
SQLITE3_REQUIRED=3.6.20

PKG_CHECK_MODULES(GIO, gio-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GIO_CFLAGS)
AC_SUBST(GIO_LIBS)
PKG_CHECK_MODULES(GLIB, glib-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)
PKG_CHECK_MODULES(GMODULE, gmodule-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GMODULE_CFLAGS)
AC_SUBST(GMODULE_LIBS)
PKG_CHECK_MODULES(SQLITE3, sqlite3 >= $SQLITE3_REQUIRED)
AC_SUBST(SQLITE3_CFLAGS)
AC_SUBST(SQLITE3_LIBS)

# Checks for header files.
AC_CHECK_HEADERS([stdlib.h string.h])

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_CONFIG_FILES([Makefile
                 sqlheavy/Makefile
                 sqlheavy-$SQLHEAVY_API_VERSION.pc])
AC_OUTPUT
