namespace SQLHeavy {
  /**
   * Cursor for use with a {@link Table}
   */
  public class TableCursor : GLib.Object, SQLHeavy.RecordSet, SQLHeavy.Cursor {
    /**
     * The table
     */
    public SQLHeavy.Table table { get; construct; }

    /**
     * The current offset
     */
    public int64 offset { get; private set; default = 0; }

    /**
     * The order to sort the result set in
     */
    public SQLHeavy.SortOrder sort_order { get; construct set; default = SQLHeavy.SortOrder.ASCENDING; }

    /**
     * The column to sort the result set by
     */
    public string sort_column { get; set; default = "ROWID"; }

    /**
     * {@inheritDoc}
     */
    public int field_count { get { return this.table.field_count; } }

    private int64 current_id = -1;

    private SQLHeavy.Query? _query = null;
    private SQLHeavy.Query query {
      get {
        if ( this._query == null ) {
          try {
            this._query = this.table.queryable.prepare ("SELECT `ROWID` FROM `" + SQLHeavy.escape_string (this.table.name) + "` ORDER BY `" + SQLHeavy.escape_string (this.sort_column) + "` " + ((this.sort_order == SQLHeavy.SortOrder.ASCENDING) ? "ASC" : "DESC") + " LIMIT 1 OFFSET :offset;");
          } catch ( SQLHeavy.Error e ) {
            GLib.critical ("Unable to create table cursor: %s", e.message);
          }
        }

        return this._query;
      }
    }

    /**
     * {@inheritDoc}
     */
    public new SQLHeavy.Record get () throws SQLHeavy.Error {
      if ( this.current_id <= 0 )
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));

      return new SQLHeavy.Row (this.table, this.current_id);
    }

    private bool move_to_internal (int64 offset) {
      int64 id = -1;

      try {
        var q = this.query;
        q.set_int64 (":offset", offset);
        var res = q.execute ();
        id = (res.finished) ? -1 : res.fetch_int64 (0);
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to move cursor: %s", e.message);
        return false;
      }

      if ( id > 0 ) {
        GLib.debug ("Offset: %lld", offset);
        this.current_id = id;
        this.offset = offset;
        return true;
      } else {
        return false;
      }
    }

    /**
     * {@inheritDoc}
     */
    public bool move_to (int64 offset) throws SQLHeavy.Error {
      if ( !this.move_to_internal (offset) )
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));

      return true;
    }

    /**
     * {@inheritDoc}
     */
    public bool next () throws SQLHeavy.Error {
      return this.move_to_internal (this.offset + 1);
    }

    /**
     * {@inheritDoc}
     */
    public bool previous () throws SQLHeavy.Error {
      return this.move_to_internal (this.offset - 1);
    }

    construct {
      try {
        this.next ();
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to create table cursor: %s", e.message);
      }
    }

    public TableCursor (SQLHeavy.Table table) {
      GLib.Object (table: table);
    }
  }
}
