namespace SQLHeavy {
  internal GLib.Value? sqlite_value_to_g_value (Sqlite.Value value) {
    GLib.Value? gval = null;
    var stype = value.to_type ();

    switch ( stype ) {
      case Sqlite.INTEGER:
        if ( value.to_int64 () < int.MAX ) {
          gval = GLib.Value (typeof (int));
          gval.set_int (value.to_int ());
        }
        else {
          gval = GLib.Value (typeof (int64));
          gval.set_int64 (value.to_int64 ());
        }
        break;
      case Sqlite.FLOAT:
        gval = GLib.Value (typeof (double));
        gval.set_double (value.to_double ());
        break;
      case Sqlite.TEXT:
        gval = GLib.Value (typeof (string));
        gval.set_string (value.to_text ());
        break;
      case Sqlite.BLOB:
        gval = GLib.Value (typeof (void *));
        gval.set_pointer (value.to_blob ());
        break;
      case Sqlite.NULL:
        break;
      default:
        GLib.assert_not_reached ();
    }

    return gval;
  }

  internal GLib.SList<GLib.Value?>? sqlite_value_array_to_g_value_slist (Sqlite.Value[] values) {
    if ( values.length == 0 )
      return null;

    var vl = new GLib.SList<GLib.Value?> ();
    for ( int i = values.length ; i > 0 ; i-- )
      vl.prepend (sqlite_value_to_g_value (values[i - 1]));

    return vl;
  }
}
