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

      private class FieldInfo : GLib.Object {
        public int index;
        public string name;
        public string affinity;
        public bool not_null;

        public FieldInfo (int index, string name, string affinity, bool not_null) {
          this.index = index;
          this.name = name;
          this.affinity = affinity;
          this.not_null = not_null;
        }

        public FieldInfo.from_stmt (SQLHeavy.Statement stmt) throws SQLHeavy.Error {
          this.index = stmt.fetch_int (0);
          this.name = stmt.fetch_string (1);
          this.affinity = stmt.fetch_string (2);
          this.not_null = stmt.fetch_int (3) > 0;
        }
      }

      private GLib.Sequence<FieldInfo>? _field_data = null;
      private GLib.HashTable<string, int?>? _field_names = null;

      private unowned GLib.Sequence<FieldInfo> get_field_data () throws SQLHeavy.Error {
        if ( this._field_data == null ) {
          this._field_data = new GLib.Sequence<FieldInfo> (GLib.g_object_unref);
          this._field_names = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);

          var stmt = this.queryable.prepare (@"PRAGMA table_info (`$(escape_string (this.name))`);");
          while ( stmt.step () ) {
            var row = new FieldInfo.from_stmt (stmt);
            this._field_data.insert_sorted (row, (a, b) => {
                return ((FieldInfo) a).index - ((FieldInfo) b).index;
              });
            this._field_names.insert (row.name, row.index);
          }
        }

        return (!) this._field_data;
      }

      public int field_count {
        get {
          try {
            return this.get_field_data ().get_length ();
          } catch ( SQLHeavy.Error e ) {
            GLib.critical ("Unable to get number of fields: %s (%d)", e.message, e.code);
            return -1;
          }
        }
      }

      public string field_name (int index) throws SQLHeavy.Error {
        var iter = this.get_field_data ().get_iter_at_pos (index);
        if ( iter == null )
          throw new SQLHeavy.Error.RANGE ("Invalid field index (%d)", index);

        return iter.get ().name;
      }

      public int field_index (string name) throws SQLHeavy.Error {
        if ( this._field_names == null )
          this.get_field_data ();

        var index = this._field_names.lookup (name);
        if ( index == null )
          throw new SQLHeavy.Error.RANGE ("Invalid field name (`%s')", name);

        return index;
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

      public int field_count { get { return this.table.field_count; } }

      private GLib.Value?[]? values = null;

      public void save () throws SQLHeavy.Error {
        lock ( this.values ) {
          if ( this.values == null )
            return;

          var field = 0;
          var field_count = this.table.field_count;
          var query = new GLib.StringBuilder ();
          var first_field = true;

          if ( this._id > 0 ) {
            query.printf ("UPDATE `%s` SET ", this.table.name);

            for ( field = 0 ; field < field_count ; field++ ) {
              if ( this.values[field] != null ) {
                if ( !first_field )
                  query.append (", ");
                var field_name = this.table.field_name (field);
                query.append (@"`$(field_name)` = :$(field_name)");
                first_field = false;
              }
            }
            query.append (" WHERE `ROWID` = :ROWID;");
          } else {
            query.printf ("INSERT INTO `%s` (", this.table.name);
            var qvalues = new GLib.StringBuilder ();

            for ( field = 0 ; field < field_count ; field++ ) {
              if ( this.values[field] != null ) {
                if ( !first_field ) {
                  query.append (", ");
                  qvalues.append (", ");
                }

                var field_name = this.table.field_name (field);
                query.append (@"`$(field_name)`");
                qvalues.append (@":$(field_name)");
              }
            }

            query.append (") VALUES (");
            query.append (qvalues.str);
            query.append (");");
          }

          var stmt = this.table.queryable.prepare (query.str);

          for ( field = 0 ; field < field_count ; field++ ) {
            if ( this.values[field] != null ) {
              var field_name = this.table.field_name (field);
              stmt.bind_named (@":$(field_name)", this.values[field]);
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
        return this.table.field_index (field);
      }

      public string field_name (int field) throws SQLHeavy.Error {
        return this.table.field_name (field);
      }

      public GLib.Type field_type (int field) throws SQLHeavy.Error {
        return this.fetch (field).type ();
      }

      public void put (int field, GLib.Value value) throws SQLHeavy.Error {
        var field_count = this.table.field_count;

        if ( field < 0 || field >= field_count )
          throw new SQLHeavy.Error.RANGE ("Invalid field index (%d)", field);

        lock ( this.values ) {
          if ( this.values == null )
            this.values = new GLib.Value[field_count];

          this.values[field] = value;
        }
      }

      public GLib.Value fetch (int field) throws SQLHeavy.Error {
        if ( this.values != null && this.values[field] != null )
          return this.values[field];

        var field_name = this.table.field_name (field);
        if ( this._id <= 0 )
          throw new SQLHeavy.Error.MISUSE ("Cannot read field `%s` from record not persisted to database.", field_name);

        var stmt = this.table.queryable.prepare (@"SELECT `$(field_name)` FROM `$(this.table.name)` WHERE `ROWID` = $(this._id)");
        return stmt.fetch_result ();
      }

      public Row (Table table, int64 id = 0) {
        Object (table: table, id: id);
      }
    }
  }
}
