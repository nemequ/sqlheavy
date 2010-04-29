namespace SQLHeavy {
  /**
   * Basic ORM
   *
   * This namespace is highly EXPERIMENTAL—the API will change.
   */
  namespace ORM {
    public class Table : GLib.Object {
      public string name { get; construct; }
      public SQLHeavy.Queryable queryable { get; construct; }

      private class ColumnInfo : GLib.Object {
        public int position;
        public string name;
        public string affinity;
        public bool not_null;

        public ColumnInfo (int position, string name, string affinity, bool not_null) {
          this.position = position;
          this.name = name;
          this.affinity = affinity;
          this.not_null = not_null;
        }

        public ColumnInfo.from_stmt (SQLHeavy.Statement stmt) throws SQLHeavy.Error {
          this.position = stmt.fetch_int (0);
          this.name = stmt.fetch_string (1);
          this.affinity = stmt.fetch_string (2);
          this.not_null = stmt.fetch_int (3) > 0;
        }
      }

      private GLib.Sequence<ColumnInfo>? _column_data = null;
      private GLib.HashTable<string, int?>? _column_names = null;

      private unowned GLib.Sequence<ColumnInfo> get_column_data () throws SQLHeavy.Error {
        if ( this._column_data == null ) {
          this._column_data = new GLib.Sequence<ColumnInfo> (GLib.g_object_unref);
          this._column_names = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);

          var stmt = this.queryable.prepare (@"PRAGMA table_info (`$(escape_string (this.name))`);");
          while ( stmt.step () ) {
            var row = new ColumnInfo.from_stmt (stmt);
            this._column_data.insert_sorted (row, (a, b) => {
                return ((ColumnInfo) a).position - ((ColumnInfo) b).position;
              });
            this._column_names.insert (row.name, row.position);
          }
        }

        return (!) this._column_data;
      }

      public int columns {
        get {
          try {
            return this.get_column_data ().get_length ();
          } catch ( SQLHeavy.Error e ) {
            GLib.critical ("Unable to get number of columns: %s (%d)", e.message, e.code);
            return -1;
          }
        }
      }

      public string column_name (int position) throws SQLHeavy.Error {
        var iter = this.get_column_data ().get_iter_at_pos (position);
        if ( iter == null )
          throw new SQLHeavy.Error.RANGE ("Invalid column position (%d)", position);

        return iter.get ().name;
      }

      public int column_position (string name) throws SQLHeavy.Error {
        if ( this._column_names == null )
          this.get_column_data ();

        var position = this._column_names.lookup (name);
        if ( position == null )
          throw new SQLHeavy.Error.RANGE ("Invalid column name (`%s')", name);

        return position;
      }

      public Table (SQLHeavy.Queryable queryable, string name) throws SQLHeavy.Error {
        Object (queryable: queryable, name: name);
      }
    }

    public class Row : GLib.Object, SQLHeavy.Record {
      public Table table { get; construct; }

      private int64 _id = 0;
      public int64 id {
        get { return this._id; }
        construct { this._id = value; }
      }

      public int field_count { get { return this.table.columns; } }

      private GLib.Value?[]? values = null;

      public void save () throws SQLHeavy.Error {
        lock ( this.values ) {
          if ( this.values == null )
            return;

          var field = 0;
          var column_count = this.table.columns;
          var query = new GLib.StringBuilder ();
          var first_field = true;

          if ( this._id > 0 ) {
            query.printf ("UPDATE `%s` SET ", this.table.name);

            for ( field = 0 ; field < column_count ; field++ ) {
              if ( this.values[field] != null ) {
                if ( !first_field )
                  query.append (", ");
                var column_name = this.table.column_name (field);
                query.append (@"`$(column_name)` = :$(column_name)");
                first_field = false;
              }
            }
            query.append (" WHERE `ROWID` = :ROWID;");
          } else {
            query.printf ("INSERT INTO `%s` (", this.table.name);
            var qvalues = new GLib.StringBuilder ();

            for ( field = 0 ; field < column_count ; field++ ) {
              if ( this.values[field] != null ) {
                if ( !first_field ) {
                  query.append (", ");
                  qvalues.append (", ");
                }

                var column_name = this.table.column_name (field);
                query.append (@"`$(column_name)`");
                qvalues.append (@":$(column_name)");
              }
            }

            query.append (") VALUES (");
            query.append (qvalues.str);
            query.append (");");
          }

          var stmt = this.table.queryable.prepare (query.str);

          for ( field = 0 ; field < column_count ; field++ ) {
            if ( this.values[field] != null ) {
              var column_name = this.table.column_name (field);
              stmt.bind_named (@":$(column_name)", this.values[field]);
            }
          }

          if ( this._id > 0 ) {
            stmt.bind_named_int64 (":ROWID", this._id);
            stmt.execute ();
          }
          else
            this._id = stmt.execute_insert ();

          this.values = null;
        }
      }

      public int field_index (string field) throws SQLHeavy.Error {
        return this.table.column_position (field);
      }

      public string field_name (int field) throws SQLHeavy.Error {
        return this.table.column_name (field);
      }

      public GLib.Type field_type (int field) throws SQLHeavy.Error {
        return this.fetch (field).type ();
      }

      public void put (int field, GLib.Value value) throws SQLHeavy.Error {
        var column_count = this.table.columns;

        if ( field < 0 || field >= column_count )
          throw new SQLHeavy.Error.RANGE ("Invalid field position (%d)", field);

        lock ( this.values ) {
          if ( this.values == null )
            this.values = new GLib.Value[column_count];

          this.values[field] = value;
        }
      }

      public GLib.Value fetch (int field) throws SQLHeavy.Error {
        if ( this.values != null && this.values[field] != null )
          return this.values[field];

        var column_name = this.table.column_name (field);
        if ( this._id <= 0 )
          throw new SQLHeavy.Error.MISUSE ("Cannot read field `%s` from record not persisted to database.", column_name);

        var stmt = this.table.queryable.prepare (@"SELECT `$(column_name)` FROM `$(this.table.name)` WHERE `ROWID` = $(this._id)");
        return stmt.fetch_result ();
      }

      public Row (Table table, int64 id = 0) {
        Object (table: table, id: id);
      }
    }
  }
}
