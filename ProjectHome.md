# About #

SQLHeavy is a wrapper on top of SQLite with a GObject-based interface, providing very nice APIs for C and Vala, GObject Introspection support, and additional functionality not present in SQLite.

For a high-level overview of the library, see the [User Guide](UserGuide.md).

<table><tr><td></td><td><wiki:gadget url="http://www.ohloh.net/p/482507/widgets/project_users.xml?style=gray" height="100" border="0"/></td></tr></table>

# Features #

SQLHeavy provides convenient interfaces for several interfaces which can be a bit difficult and/or awkward to use properly from SQLite (especially from Vala), such as user defined functions and pragmas, as well as easy to use ways to keep track of transactions and schemas.

Additionally, SQLHeavy makes use of features provided by the GLIb libraries to provide functionality which is absent from SQLite itself, including:

  * Regular expressions
  * Checksums
  * ZLib compression/decompression
  * Asynchronous queries and backups
  * ORM, including a [code generator](ORMGenerator.md) and field-level change notifications
  * GTK+ integration

# Downloading #

Version 0.1.0 is available! See the [downloads](http://code.google.com/p/sqlheavy/downloads/list) page to download the source code.

[Debian packages](http://packages.qa.debian.org/s/sqlheavy.html) are available in testing, and [Ubuntu packages](http://packages.ubuntu.com/source/precise/sqlheavy) in Precise Pangolin. A [PPA](https://launchpad.net/~nemequ/+archive/sqlheavy) is also available for 11.10+:

```
deb http://ppa.launchpad.net/nemequ/sqlheavy/ubuntu natty main 
deb-src http://ppa.launchpad.net/nemequ/sqlheavy/ubuntu natty main 
```

SQLHeavy uses a [git repository](http://gitorious.org/sqlheavy) hosted on gitorious:

```
git clone git://gitorious.org/sqlheavy/sqlheavy.git
```

# License #

SQLHeavy is dual licensed under the LGPL 2.1 and LGPL 3.0.