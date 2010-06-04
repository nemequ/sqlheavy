#!/usr/bin/env seed

const SQLHeavy = imports.gi.SQLHeavy;
const GLib = imports.gi.GLib;

try {
  var db = new SQLHeavy.Database ({ filename: "test.db",
                                    mode:
                                      SQLHeavy.FileMode.READ |
                                      SQLHeavy.FileMode.WRITE |
                                      SQLHeavy.FileMode.CREATE });

  db.execute ("CREATE TABLE `foo` ( `bar` INT );", -1);

  var stmt = db.prepare ("INSERT INTO `foo` (`bar`) VALUES (:bar);");
  for ( var i = 0 ; i < 32 ; i++ ) {
    stmt.bind_int (":bar", i);
    stmt.execute ();
  }
} catch ( e ) {
  print ("Encountered an error: " + e.message);
}

