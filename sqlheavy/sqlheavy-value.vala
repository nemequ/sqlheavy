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

  internal bool value_equal (GLib.Value a, GLib.Value b) {
    var gtype = a.type ();
    if ( !b.holds (gtype) )
      return false;

    if ( gtype == typeof (int64) )
      return a.get_int64 () == a.get_int64 ();
    else if ( gtype == typeof (string) )
      return GLib.str_equal (a.get_string (), b.get_string ());
    else if ( gtype == typeof (double) )
      return a.get_double () == b.get_double ();
    else if ( gtype == typeof (GLib.ByteArray) ) {
      unowned GLib.ByteArray a1 = (GLib.ByteArray) a.get_boxed ();
      unowned GLib.ByteArray b1 = (GLib.ByteArray) b.get_boxed ();
      return (a1.len == b1.len) && (GLib.Memory.cmp (a1.data, b1.data, a1.len) == 0);
    }
    else {
      GLib.critical ("sqlheavy_value_equal not implemented for %s type.", gtype.name ());
      return false;
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
