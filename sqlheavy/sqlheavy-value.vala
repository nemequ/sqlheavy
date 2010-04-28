namespace SQLHeavy {
  internal GLib.Type sqlite_type_to_g_type (int stype) throws SQLHeavy.Error {
    switch ( stype ) {
      case Sqlite.INTEGER:
        return typeof (int64);
      case Sqlite.TEXT:
        return typeof (string);
      case Sqlite.FLOAT:
        return typeof (double);
      case Sqlite.NULL:
        return typeof (void);
      case Sqlite.BLOB:
        return typeof (GLib.ByteArray);
      default:
        throw new SQLHeavy.Error.DATA_TYPE ("Data type unsupported.");
    }
  }

  // internal GLib.Type sqlite_type_string_to_g_type (string stype) throws SQLHeavy.Error {
  //   switch ( stype ) {
  //     case "INTEGER":
  //       return typeof (int64);
  //     case "TEXT":
  //       return typeof (string);
  //     case "STRING":
  //       return typeof (string);
  //     case "FLOAT":
  //       return typeof (double);
  //     case "BLOB":
  //       return typeof (GLib.ByteArray);
  //     default:
  //       throw new SQLHeavy.Error.DATA_TYPE ("Data type \"%s\" unsupported.", stype);
  //   }
  // }

  internal GLib.Value sqlite_value_to_g_value (Sqlite.Value value) {
    GLib.Type gtype;
    try {
      gtype = sqlite_type_to_g_type (value.to_type ());
    }
    catch ( SQLHeavy.Error e ) {
      GLib.assert_not_reached ();
    }

    GLib.Value gval = GLib.Value (gtype);

    if ( gtype == typeof (int64) )
      gval = value.to_int64 ();
    else if ( gtype == typeof (double) )
      gval = value.to_double ();
    else if ( gtype == typeof (string) )
      gval = value.to_text ();
    else if ( gtype == typeof (GLib.ByteArray) ) {
      unowned uint8[] blob = (uint8[])value.to_blob ();
      blob.length = value.to_bytes ();
      var ba = new GLib.ByteArray.sized (blob.length);
      ba.append (blob);
      gval = ba;
    }

    return gval;
  }

  internal GLib.ValueArray sqlite_value_array_to_g_value_array (Sqlite.Value[] values) {
    var va = new GLib.ValueArray (values.length);
    for ( int i = 0 ; i < values.length ; i++ )
      va.append (sqlite_value_to_g_value (values[i]));

    return va;
  }

  /**
   * Escape a string for use in an SQL query.
   *
   * This function should be used sparingly, as it is generally
   * preferable to use prepared statements.
   *
   * @see Statement.bind_string
   * @see Statement.bind_named_string
   */
  public static string escape_string (string str) {
    return str.replace ("'", "''");
  }
}
