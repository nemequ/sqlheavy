namespace SQLHeavy {
  [CCode (cname = "g_sequence_free")]
  internal extern static void g_sequence_free (GLib.Sequence seq);

  [CCode (has_target = false)]
  private delegate int WALCheckpointFunc (Sqlite.Database db, string? dbname);
  [CCode (instance_pos = 0)]
  private delegate int WALHookCallback (Sqlite.Database db, string dbname, int pages);
  [CCode (has_target = false)]
  private delegate int WALHookFunc (Sqlite.Database db, WALHookCallback hook);

  /**
   * A database.
   */
  public class Database : GLib.Object, Queryable {
    /**
     * List of registered user functions and their respective user data
     */
    private GLib.HashTable <string, UserFunction.UserFuncData> user_functions =
      new GLib.HashTable <string, UserFunction.UserFuncData>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_object_unref);

    /**
     * List of all SQLHeavy.Row objects, used for change notification
     *
     * @see orm_tables
     */
    private GLib.HashTable <string, GLib.Sequence<unowned SQLHeavy.Row>> orm_rows = null;

    /**
     * List of all SQLHeavy.Table objects, used for change notification
     *
     * @see orm_rows
     */
    private GLib.HashTable <string, GLib.Sequence<unowned SQLHeavy.Table>> orm_tables = null;

    /**
     * Write-ahead logging auto checkpoint interval
     */
    public int wal_auto_checkpoint { get; set; default = 10; }

    /**
     * Emitted when data is committed to the write-ahead log
     *
     * @see journal_mode
     */
    public virtual signal void wal_committed (string db_name, int pages) {
      if ( this.wal_auto_checkpoint > 0 &&
           this.wal_auto_checkpoint <= pages ) {
        this.try_wal_checkpoint ();
      }
    }

    // Work around for b.g.o. #625360
    private void try_wal_checkpoint () {
      try {
        this.wal_checkpoint ();
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to auto-checkpoint: %s", e.message);
      }
    }

    /**
     * Register a row for change notifications
     *
     * @param row the row to register
     */
    internal void register_orm_row (SQLHeavy.Row row) {
      lock ( this.orm_rows ) {
        if ( this.orm_rows == null )
          this.orm_rows = new GLib.HashTable<string, GLib.Sequence<unowned SQLHeavy.Row>>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, (GLib.DestroyNotify) g_sequence_free);

        var rowstr = @"$(row.table.name).$(row.id)";
        unowned GLib.Sequence<unowned SQLHeavy.Row>? list = this.orm_rows.lookup (rowstr);
        if ( list == null ) {
          this.orm_rows.insert (rowstr, new GLib.Sequence<unowned SQLHeavy.Row> (null));
          list = this.orm_rows.lookup (rowstr);
        }
        list.insert_sorted (row, (a, b) => { return a < b ? -1 : (a > b) ? 1 : 0; });
      }
    }

    /**
     * Register a table for change notifications
     *
     * @param table the table to register
     */
    internal void register_orm_table (SQLHeavy.Table table) {
      lock ( this.orm_tables ) {
        if ( this.orm_tables == null )
          this.orm_tables = new GLib.HashTable<string, GLib.Sequence<unowned SQLHeavy.Table>>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, (GLib.DestroyNotify) g_sequence_free);

        var tblname = table.name;
        unowned GLib.Sequence<unowned SQLHeavy.Table>? list = this.orm_tables.lookup (tblname);
        if ( list == null ) {
          this.orm_tables.insert (tblname, new GLib.Sequence<unowned SQLHeavy.Table> (null));
          list = this.orm_tables.lookup (tblname);
        }
        list.insert_sorted (table, (a, b) => { return a < b ? -1 : (a > b) ? 1 : 0; });
      }
    }

    /**
     * Unregister a row from change notifications
     *
     * @param row the row to unregister
     */
    internal void unregister_orm_row (SQLHeavy.Row row) {
      var rowstr = @"$(row.table.name).$(row.id)";

      lock ( this.orm_rows ) {
        unowned GLib.Sequence<unowned SQLHeavy.Row>? list = this.orm_rows.lookup (rowstr);
        if ( list != null ) {
          var iter = list.search (row, (a, b) => { return a < b ? -1 : (a > b) ? 1 : 0; }).prev ();
          unowned SQLHeavy.Row r2 = iter.get ();
          if ( (uint)row == (uint)r2 )
            list.remove (iter);
        }
      }
    }

    /**
     * Unregister a row from change notifications
     *
     * @param row the row to unregister
     */
    internal void unregister_orm_table (SQLHeavy.Table table) {
      lock ( this.orm_tables ) {
        unowned GLib.Sequence<unowned SQLHeavy.Table>? list = this.orm_tables.lookup (table.name);
        if ( list != null ) {
          var iter = list.search (table, (a, b) => { return a < b ? -1 : (a > b) ? 1 : 0; }).prev ();
          unowned SQLHeavy.Table t2 = iter.get ();
          if ( (uint)table == (uint)t2 )
            list.remove (iter);
        }
      }
    }

    /**
     * Callback provided to sqlite3_update_hook function
     *
     * See SQLite documentation at [[http://www.sqlite.org/c3ref/update_hook.html]]
     */
    private void update_hook_cb (Sqlite.Action action, string dbname, string table, int64 rowid) {
      if ( action == Sqlite.Action.UPDATE ) {
        lock ( this.orm_rows ) {
          if ( this.orm_rows == null )
            return;

          unowned GLib.Sequence<unowned SQLHeavy.Row> l = this.orm_rows.lookup (@"$(table).$(rowid)");
          if ( l != null ) {
            for ( var iter = l.get_begin_iter () ; !iter.is_end () ; iter = iter.next () ) {
              unowned SQLHeavy.Row r = iter.get ();
              r.changed ();
            }
          }
        }
      } else if ( action == Sqlite.Action.INSERT ||
                  action == Sqlite.Action.DELETE ) {
        lock ( this.orm_tables ) {
          if ( this.orm_tables == null )
            return;

          unowned GLib.Sequence<unowned SQLHeavy.Table> l = this.orm_tables.lookup (table);
          if ( l != null ) {
            for ( var iter = l.get_begin_iter () ; !iter.is_end () ; iter = iter.next () ) {
              unowned SQLHeavy.Table t = iter.get ();
              if ( action == Sqlite.Action.INSERT )
                t.row_inserted (rowid);
              else
                t.row_deleted (rowid);
            }
          }
        }

        lock ( this.orm_rows ) {
          if ( this.orm_rows != null ) {
            unowned GLib.Sequence<unowned SQLHeavy.Row> l = this.orm_rows.lookup (@"$(table).$(rowid)");
            if ( l != null ) {
              for ( var iter = l.get_begin_iter () ; !iter.is_end () ; iter = iter.next () ) {
                unowned SQLHeavy.Row r = iter.get ();
                r.on_delete ();
              }
            }
          }
        }
      }
    }

    /**
     * SQLite database for this SQLHeavy database
     */
    private Sqlite.Database? db = null;

    /**
     * Return the {@link db}
     *
     * In Vala, internal properties are exposed in the C API, so this
     * function allows other classes to access the {@link db} while
     * keeping it private.
     */
    internal unowned Sqlite.Database get_sqlite_db () {
      return (!) this.db;
    }

    /**
     * {@inheritDoc}
     */
    public SQLHeavy.Database database { owned get { return this; } }

    /**
     * Mutex to prevent us from executing queries from multiple
     * transactions at once.
     *
     * @see lock
     * @see unlock
     */
    private Sqlite.Mutex? _transaction_lock = new Sqlite.Mutex (Sqlite.MUTEX_FAST);

    /**
     * {@inheritDoc}
     */
    public void @lock () {
      this._transaction_lock.enter ();
    }

    /**
     * {@inheritDoc}
     */
    public void @unlock () {
      this._transaction_lock.leave ();
    }

    /**
     * Step lock
     *
     * Used to lock a database while stepping through a statement in
     * support of the threading for the async functions.
     *
     * @see step_lock
     * @see step_unlock
     */
    private Sqlite.Mutex? _step_lock = null;

    /**
     * Lock the step lock
     *
     * @see step_unlock
     * @see _step_lock
     */
    internal void step_lock () {
      this._step_lock.enter ();
    }

    /**
     * Unlock the step lock
     *
     * @see step_lock
     * @see _step_lock
     */
    internal void step_unlock () {
      this._step_lock.leave ();
      lock ( this.needs_update_on_step_unlock ) {
        var i = this.needs_update_on_step_unlock.get_begin_iter ();
        while ( !i.is_end () ) {
          try {
            i.get ().update_cache ();
          } catch ( SQLHeavy.Error e ) {
            GLib.warning ("Unable to update row cache: %s", e.message);
          }
          unowned GLib.SequenceIter<SQLHeavy.Row> o = i;
          i = i.next ();
          this.needs_update_on_step_unlock.remove (o);
        }
      }
    }

    /**
     * List of rows to update when the step lock is unlocked
     *
     * @see step_unlock
     * @see _step_lock
     */
    private GLib.Sequence<SQLHeavy.Row> needs_update_on_step_unlock =
      new GLib.Sequence<SQLHeavy.Row> (GLib.g_object_unref);

    /**
     * Add a callback to the {@link needs_update_on_step_unlock} list.
     *
     * @param cb the callback to add
     */
    internal void add_step_unlock_notify_row (SQLHeavy.Row row) {
      this.needs_update_on_step_unlock.append (row);
    }

    /**
     * Interrupt (cancel) the currently running query
     *
     * See SQLite documentation at [[http://www.sqlite.org/c3ref/interrupt.html]]
     */
    public void interrupt () {
      this.db.interrupt ();
    }

    /**
     * SQL executed
     *
     * Will be emitted whenever a query is executed. This is useful
     * for debugging, but {@link Queryable.query_executed} provides a
     * more powerful interface.
     *
     * @see Queryable.query_executed
     */
    public signal void sql_executed (string sql);

    /**
     * Database to store profiling data in.
     *
     * Enabling profiling while this is null will cause the database
     * to be created in :memory:
     */
    public SQLHeavy.ProfilingDatabase? profiling_data { get; set; default = null; }

    /**
     * Whether profiling is enabled.
     *
     * Profiling in SQLHeavy bypasses the SQLite profiling mechanism,
     * and instead makes use of a timer in each Statement. This is
     * done so we can gather more information about the query than is
     * available from and SQLite profiling callback.
     *
     * @see Query.execution_time_elapsed
     * @see ProfilingDatabase
     */
    public bool enable_profiling {
      get { return this.profiling_data != null; }
      set {
        if ( value == false ) {
          this.profiling_data = null;
        }
        else {
          try {
            if ( this.profiling_data == null )
              this.profiling_data = new SQLHeavy.ProfilingDatabase ();
          }
          catch ( SQLHeavy.Error e ) {
            GLib.warning ("Unable to enable profiling: %s (%d)", e.message, e.code);
            return;
          }
        }
      }
    }

    /**
     * The location of the database
     */
    public string filename { get; construct; default = ":memory:"; }

    /**
     * The mode used when opening the database.
     */
    public SQLHeavy.FileMode mode {
      get;
      construct;
      default = SQLHeavy.FileMode.READ | SQLHeavy.FileMode.WRITE | SQLHeavy.FileMode.CREATE;
    }

    /**
     * The last inserted row ID
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/last_insert_rowid.html]]
     */
    public int64 last_insert_id { get { return this.db.last_insert_rowid (); } }

    /**
     * Retreive a PRAGMA as a string
     *
     * @param pragma the PRAGMA name. Note that this is used unescaped
     * @return the value of the pragma, or null
     */
    private string? pragma_get_string (string pragma) {
      try {
        return new SQLHeavy.Query (this, "PRAGMA %s;".printf (pragma)).execute ().fetch_string (0);
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to retrieve pragma value: %s", e.message);
        return null;
      }
    }

    /**
     * Number of lookaside memory slots currently checked out
     *
     * See SQLite documentation at [[http://www.sqlite.org/malloc.html#lookaside]]
     */
    public int lookaside_used {
      get {
        int current, high;
        this.db.status (Sqlite.DatabaseStatus.LOOKASIDE_USED, out current, out high);
        return current;
      }
    }

    /**
     * Retreive a PRAGMA as an int
     *
     * @param pragma the PRAGMA name. Note that this is used unescaped
     * @return the value of the pragma, or null
     */
    private int pragma_get_int (string pragma) {
      return this.pragma_get_string (pragma).to_int ();
    }

    /**
     * Retreive a PRAGMA as a boolean
     *
     * @param pragma the PRAGMA name. Note that this is used unescaped
     * @return the value of the pragma, or null
     */
    private bool pragma_get_bool (string pragma) {
      return this.pragma_get_int (pragma) != 0;
    }

    /**
     * Set a PRAGMA as a string
     *
     * @param pragma the PRAGMA name. Note that this is used unescaped
     * @param the value of the pragma
     */
    private void pragma_set_string (string pragma, string value) {
      try {
        var stmt = new SQLHeavy.Query (this, "PRAGMA %s = %s;".printf (pragma, value));
        stmt.execute ();
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to retrieve pragma value: %s", e.message);
      }
    }

    /**
     * Set a PRAGMA as an int
     *
     * @param pragma the PRAGMA name. Note that this is used unescaped
     * @param the value of the pragma
     */
    private void pragma_set_int (string pragma, int value) {
      this.pragma_set_string (pragma, "%d".printf(value));
    }

    /**
     * Set a PRAGMA as a boolean
     *
     * @param pragma the PRAGMA name. Note that this is used unescaped
     * @param the value of the pragma
     */
    private void pragma_set_bool (string pragma, bool value) {
      this.pragma_set_int (pragma, value ? 1 : 0);
    }

    /**
     * Auto-Vacuum mode
     *
     * Auto-vacuum status in the database.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_auto_vacuum]]
     */
    public SQLHeavy.AutoVacuum auto_vacuum {
      get { return (SQLHeavy.AutoVacuum) this.pragma_get_int("auto_vacuum"); }
      set { this.pragma_set_int ("auto_vacuum", value); }
    }

    /**
     * Cache size
     *
     * Suggested maximum number of database disk pages that SQLite
     * will hold in memory at once per open database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_cache_size]]
     */
    public int cache_size {
      get { return this.pragma_get_int ("cache_size"); }
      set { this.pragma_set_int ("cache_size", value); }
    }

    /**
     * Case-sensitive like
     *
     * Whether the LIKE operator is to take case into account for
     * ASCII characters.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_case_sensitive_like]]
     */
    public bool case_sensitive_like {
      get { return this.pragma_get_bool ("case_sensitive_like"); }
      set { this.pragma_set_bool ("case_sensitive_like", value); }
    }

    /**
     * Count changes
     *
     * Whether INSERT, UPDATE, and DELETE queries should return the
     * number of rows changed.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_count_changes]]
     */
    public bool count_changes {
      get { return this.pragma_get_bool ("count_changes"); }
      set { this.pragma_set_bool ("count_changes", value); }
    }

    /**
     * Default cache size
     *
     * Suggested maximum number of pages of disk cache that will be
     * allocated per open database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_default_cache_size]]
     */
    public int default_cache_size {
      get { return this.pragma_get_int ("default_cache_size"); }
      set { this.pragma_set_int ("default_cache_size", value); }
    }

    /**
     * Empty result callbacks
     *
     * This pragma does not affect SQLHeavy
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_empty_result_callbacks]]
     */
    public bool empty_result_callbacks {
      get { return this.pragma_get_bool ("empty_result_callbacks"); }
      set { this.pragma_set_bool ("empty_result_callbacks", value); }
    }

    /**
     * Encoding
     *
     * Encoding of the database
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_encoding]]
     */
    public SQLHeavy.Encoding encoding {
      get { return SQLHeavy.Encoding.from_string (this.pragma_get_string ("encoding")); }
      set { this.pragma_set_string ("encoding", value.to_string ()); }
    }

    /**
     * Foreign keys
     *
     * Enforcement of [[http://sqlite.org/foreignkeys.html|foreign key constraints]]
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_foreign_keys]]
     */
    public bool foreign_keys {
      get { return this.pragma_get_bool ("foreign_keys"); }
      set { this.pragma_set_bool ("foreign_keys", value); }
    }

    /**
     * Full column names
     *
     * Determine the way SQLite assigns names to result columns of
     * SELECT statements. 
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_full_column_names]]
     */
    public bool full_column_names {
      get { return this.pragma_get_bool ("full_column_names"); }
      set { this.pragma_set_bool ("full_column_names", value); }
    }

    /**
     * Full fsync
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_fullfsync]]
     */
    public bool full_fsync {
      get { return this.pragma_get_bool ("fullfsync"); }
      set { this.pragma_set_bool ("fullfsync", value); }
    }

    /**
     * Incremental vacuum
     *
     * Causes up to N pages to be removed from the freelist.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_incremental_vacuum]]
     *
     * @param pages the number of pages to remove
     */
    public void incremental_vacuum (int pages) throws SQLHeavy.Error {
      this.execute ("PRAGMA incremental_vacuum(%d);".printf(pages));
    }

    /**
     * Journal mode
     *
     * Set the journal mode
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_journal_mode]]
     */
    public SQLHeavy.JournalMode journal_mode {
      get { return SQLHeavy.JournalMode.from_string (this.pragma_get_string ("journal_mode")); }
      set {
        if ( value == SQLHeavy.JournalMode.WAL ) {
          if ( Sqlite.libversion_number () < 3007000 ) {
            GLib.warning ("SQLite-%s does not support write-ahead logging.", Sqlite.libversion ());
            return;
          }

          var mod = GLib.Module.open (null, GLib.ModuleFlags.BIND_LAZY | GLib.ModuleFlags.BIND_LOCAL);
          void* sqlite3_wal_hook;
          GLib.assert (mod.symbol ("sqlite3_wal_hook", out sqlite3_wal_hook));

          ((WALHookFunc) sqlite3_wal_hook) (this.db, (db, dbname, pages) => {
              this.wal_committed (dbname, pages);
              return Sqlite.OK;
            });
        }

        this.pragma_set_string ("journal_mode", value.to_string ());
      }
    }

    /**
     * Journal size limit
     *
     * Limit the size of journal files left in the file-system after
     * transactions are committed on a per database basis.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_journal_size_limit]]
     */
    public int journal_size_limit {
      get { return this.pragma_get_int ("journal_size_limit"); }
      set { this.pragma_set_int ("journal_size_limit", value); }
    }

    /**
     * Legacy file format
     *
     * When this flag is on, new SQLite databases are created in a
     * file format that is readable and writable by all versions of
     * SQLite going back to 3.0.0.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_legacy_file_format]]
     */
    public bool legacy_file_format {
      get { return this.pragma_get_bool ("legacy_file_format"); }
      set { this.pragma_set_bool ("legacy_file_format", value); }
    }

    /**
     * Locking mode
     *
     * Database connection locking-mode
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_locking_mode]]
     */
    public SQLHeavy.LockingMode locking_mode {
      get { return SQLHeavy.LockingMode.from_string (this.pragma_get_string ("locking_mode")); }
      set { this.pragma_set_string ("locking_mode", value.to_string ()); }
    }

    /**
     * Page size
     *
     * Page size of the database
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_page_size]]
     */
    public int page_size {
      get { return this.pragma_get_int ("page_size"); }
      set {
        if ( (value & (value - 1)) != 0 )
          GLib.critical ("Page size must be a power of two.");
        this.pragma_set_int ("page_size", value);
      }
    }

    /**
     * Max page count
     *
     * Maximum number of pages in the database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_max_page_count]]
     */
    public int max_page_count {
      get { return this.pragma_get_int ("max_page_count"); }
      set { this.pragma_set_int ("max_page_count", value); }
    }

    /**
     * Read uncommitted
     *
     * Read uncommitted isolation
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_read_uncommitted]]
     */
    public bool read_uncommitted {
      get { return this.pragma_get_bool ("read_uncommitted"); }
      set { this.pragma_set_bool ("read_uncommitted", value); }
    }

    /**
     * Recursive triggers
     *
     * Recursive trigger capability
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_recursive_triggers]]
     */
    public bool recursive_triggers {
      get { return this.pragma_get_bool ("recursive_triggers"); }
      set { this.pragma_set_bool ("recursive_triggers", value); }
    }

    /**
     * Reverse unordered selects
     *
     * When enabled, this PRAGMA causes SELECT statements without a an
     * ORDER BY clause to emit their results in the reverse order of
     * what they normally would. This can help debug applications that
     * are making invalid assumptions about the result order.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_reverse_unordered_selects]]
     */
    public bool reverse_unordered_selects {
      get { return this.pragma_get_bool ("reverse_unordered_selects"); }
      set { this.pragma_set_bool ("reverse_unordered_selects", value); }
    }

    /**
     * Short column names
     *
     * Short column names flag
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_short_column_names]]
     * 
     * @see full_column_names
     */
    public bool short_column_names {
      get { return this.pragma_get_bool ("short_column_names"); }
      set { this.pragma_set_bool ("short_column_names", value); }
    }

    /**
     * Synchronous mode
     *
     * Synchronous flag
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_synchronous]]
     */
    public SQLHeavy.SynchronousMode synchronous {
      get { return SQLHeavy.SynchronousMode.from_string (this.pragma_get_string ("synchronous")); }
      set { this.pragma_set_string ("synchronous", value.to_string ()); }
    }

    /**
     * Temporary store mode
     *
     * Temporary store mode
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_temp_store]]
     */
    public SQLHeavy.TempStoreMode temp_store {
      get { return SQLHeavy.TempStoreMode.from_string (this.pragma_get_string ("temp_store")); }
      set { this.pragma_set_string ("temp_store", value.to_string ()); }
    }

    /**
     * Temporary store directory
     *
     * The directory where files used for storing temporary tables and
     * indices are kept.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_temp_store_directory]]
     */
    public string temp_store_directory {
      owned get { return (!) this.pragma_get_string ("temp_store_directory"); }
      set { this.pragma_set_string ("temp_store_directory", value); }
    }

    //public GLib.SList<string> collation_list { get; }
    //public ?? database_list { get; }
    //public ?? get_foreign_key_list (string table_name);

    /**
     * Free list count
     *
     * Number of unused pages in the database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_freelist_count]]
     */
    public int free_list_count {
      get { return this.pragma_get_int ("freelist_count"); }
    }

    //public ?? get_index_info (string index_name);
    //public ?? get_index_list (string table_name);

    /**
     * Page count
     *
     * Total number of pages in the database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_page_count]]
     */
    public int page_count {
      get { return this.pragma_get_int ("page_count"); }
      set { this.pragma_set_int ("page_count", value); }
    }

    //public ?? get_table_info (string table_name);

    /**
     * Schema version
     *
     * The schema-version is usually only manipulated internally by SQLite.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_schema_version]]
     *
     * @see user_version
     */
    public int schema_version {
      get { return this.pragma_get_int ("schema_version"); }
      set { this.pragma_set_int ("schema_version", value); }
    }

    /**
     * Secure-delete
     *
     * Whether to overwrite deleted content with zeros
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#secure_delete]]
     */
    public bool secure_delete {
      get { return this.pragma_get_bool ("secure_delete"); }
      set { this.pragma_set_bool ("secure_delete", value); }
    }

    /**
     * User version
     *
     * User-defined schema version
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_user_version]]
     */
    public int user_version {
      get { return this.pragma_get_int ("user_version"); }
      set { this.pragma_set_int ("user_version", value); }
    }

    //public GLib.SList<string> integrity_check (int max_errors = 100);
    //public GLib.SList<string> quick_check (int max_errors = 100);

    /**
     * Parser trace
     *
     * Turn tracing of the SQL parser inside of the SQLite library on and off.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_parser_trace]]
     */
    public bool parser_trace {
      get { return this.pragma_get_bool ("parser_trace"); }
      set { this.pragma_set_bool ("parser_trace", value); }
    }

    /**
     * VDBE trace
     *
     * Turn tracing of the virtual database engine inside of the SQLite library on and off.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_vdbe_trace]]
     */
    public bool vdbe_trace {
      get { return this.pragma_get_bool ("vdbe_trace"); }
      set { this.pragma_set_bool ("vdbe_trace", value); }
    }

    /**
     * VDBE listing
     *
     * Turn listings of virtual machine programs on and off.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_vdbe_listing]]
     */
    public bool vdbe_listing {
      get { return this.pragma_get_bool ("vdbe_listing"); }
      set { this.pragma_set_bool ("vdbe_listing", value); }
    }

    construct {
      if ( this.filename != ":memory:" ) {
        string dirname = GLib.Path.get_dirname (filename);
        if ( !GLib.FileUtils.test (dirname, GLib.FileTest.EXISTS) )
          GLib.DirUtils.create_with_parents (dirname, 0700);
      }

      int flags = 0;
      if ( (this.mode & SQLHeavy.FileMode.READ) == SQLHeavy.FileMode.READ )
        flags = Sqlite.OPEN_READONLY;
      if ( (this.mode & SQLHeavy.FileMode.WRITE) == SQLHeavy.FileMode.WRITE )
        flags = Sqlite.OPEN_READWRITE;
      if ( (this.mode & SQLHeavy.FileMode.CREATE) == SQLHeavy.FileMode.CREATE )
        flags |= Sqlite.OPEN_CREATE;

      if ( Sqlite.Database.open_v2 ((!) filename, out this.db, flags, null) != Sqlite.OK )
        this.db = null;
      else {
        this.db.trace ((sql) => { this.sql_executed (sql); });
        this.db.update_hook (this.update_hook_cb);
        this.db.busy_timeout (int.MAX);
      }
    }

    /**
     * Register aggregate function for use within SQLite
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/create_function.html]]
     *
     * @param name name of the function
     * @param argc number of arguments the function accepts, or -1 for any
     * @param func callback for the user defined function
     * @param final callback to finalize the user defined function
     */
    public void register_aggregate_function (string name,
                                             int argc,
                                             owned UserFunction.UserFunc func,
                                             owned UserFunction.FinalizeFunc final) {
      this.unregister_function (name);
      var ufc = new UserFunction.UserFuncData.scalar (this, name, argc, func);
      this.user_functions.insert (name, ufc);
      this.db.create_function<UserFunction.UserFuncData> (name, argc, Sqlite.UTF8, ufc, null,
                                                          UserFunction.on_user_function_called,
                                                          UserFunction.on_user_finalize_called);
    }

    /**
     * Register a scalar function for use within SQLite
     *
     * @param name name of the function to use
     * @param argc number of arguments the function accepts, or -1 for any
     * @param func callback for the user defined function
     */
    public void register_scalar_function (string name,
                                          int argc,
                                          owned UserFunction.UserFunc func) {
      this.unregister_function (name);
      var ufc = new UserFunction.UserFuncData.scalar (this, name, argc, func);
      this.user_functions.insert (name, ufc);
      this.db.create_function (name, argc, Sqlite.UTF8, ufc, UserFunction.on_user_function_called, null, null);
    }

    /**
     * Unregister a function, as specified by the user data
     *
     * @see user_functions
     */
    private void unregister_function_context (UserFunction.UserFuncData ufc) {
      this.db.create_function (ufc.name, ufc.argc, Sqlite.UTF8, ufc, null, null, null);
    }

    /**
     * Unregister a function
     *
     * Unregister a user defined function
     *
     * @param name name of the function
     */
    public void unregister_function (string name) {
      SQLHeavy.UserFunction.UserFuncData? ufc = this.user_functions.lookup (name);
      if ( ufc != null )
        this.unregister_function_context ((!) ufc);
    }

    /**
     * Registers common functions
     *
     * More functions may be added later, but currently this function
     * will register:
     *
     * * REGEXP: see [[http://www.sqlite.org/lang_expr.html#regexp]]
     * * MD5: MD5 hashing algorithm
     * * SHA1: SHA-1 hashing algorithm
     * * SHA256: SHA-256 hashing algorithm
     * * COMPRESS: Compress data using ZLib
     * * DECOMPRESS: Decompress data using ZLib
     *
     * @see CommonFunction.regex
     * @see CommonFunction.md5
     * @see CommonFunction.sha1
     * @see CommonFunction.sha256
     * @see CommonFunction.compress
     * @see CommonFunction.decompress
     */
    public void register_common_functions () {
      this.register_scalar_function ("REGEXP", 2, SQLHeavy.CommonFunction.regex);
      this.register_scalar_function ("MD5", 1, SQLHeavy.CommonFunction.md5);
      this.register_scalar_function ("SHA1", 1, SQLHeavy.CommonFunction.sha1);
      this.register_scalar_function ("SHA256", 1, SQLHeavy.CommonFunction.sha256);
      this.register_scalar_function ("COMPRESS", 1, SQLHeavy.CommonFunction.compress);
      this.register_scalar_function ("DECOMPRESS", 1, SQLHeavy.CommonFunction.decompress);
    }

    /**
     * Backup database
     *
     * @param destination the location to write the backup to
     * @see SQLHeavy.Backup
     * @see backup_async
     */
    public void backup (string destination) throws SQLHeavy.Error {
      new SQLHeavy.Backup (this, new SQLHeavy.Database (destination)).execute ();
    }

    /**
     * Backup database asynchronously
     *
     * @param destination the location to write the backup to
     * @see SQLHeavy.Backup
     * @see backup
     */
    public async void backup_async (string destination) throws SQLHeavy.Error {
      var backup = new SQLHeavy.Backup (this, new SQLHeavy.Database (destination));
      yield backup.execute_async ();
    }

    /**
     * Checkpoint the specified database
     *
     * See SQLite documentation at [[http://sqlite.org/wal.html#ckpt]]
     *
     * @see journal_mode
     */
    public void wal_checkpoint (string? database = null) throws SQLHeavy.Error {
      if ( Sqlite.libversion_number () < 3007000 )
        throw new SQLHeavy.Error.FEATURE_NOT_SUPPORTED ("Write-ahead logging features are only available in SQLite >= 3.7.0, you are using %s", Sqlite.libversion ());

      var mod = GLib.Module.open (null, GLib.ModuleFlags.BIND_LAZY | GLib.ModuleFlags.BIND_LOCAL);

      void* sqlite3_wal_checkpoint;
      GLib.assert (mod.symbol ("sqlite3_wal_checkpoint", out sqlite3_wal_checkpoint));

      error_if_not_ok (((WALCheckpointFunc) sqlite3_wal_checkpoint) (this.db, database), this);
    }

    /**
     * List all tables in the database
     *
     * @return a hash table of tables, with the key being the table name
     */
    public GLib.HashTable<string, SQLHeavy.Table> get_tables () throws SQLHeavy.Error {
      var ht = new GLib.HashTable<string, SQLHeavy.Table>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_object_unref);

      var result = this.prepare ("SELECT `name` FROM `SQLITE_MASTER` WHERE `type` = 'table';").execute ();
      while ( !result.finished ) {
        var table_name = result.fetch_string (0);
        if ( !table_name.has_prefix ("sqlite_") )
          ht.insert (table_name, new SQLHeavy.Table (this, table_name));

        result.next ();
      }

      return ht;
    }

    /**
     * Open a database.
     *
     * @param filename Where to store the database, or null for memory only.
     * @param mode Bitmask of mode to use when opening the database.
     */
    public Database (string? filename = null,
                     SQLHeavy.FileMode mode =
                       SQLHeavy.FileMode.READ |
                       SQLHeavy.FileMode.WRITE |
                       SQLHeavy.FileMode.CREATE) throws SQLHeavy.Error {
      if ( filename == null ) filename = ":memory:";
      Object (filename: (!) filename, mode: mode);

      if ( this.db == null )
        throw new SQLHeavy.Error.CAN_NOT_OPEN (sqlite_errstr (Sqlite.CANTOPEN));
    }

    /**
     * Destroy resources associated with this database
     */
    ~ Database () {
      foreach ( unowned UserFunction.UserFuncData udf in this.user_functions.get_values () )
        this.unregister_function_context (udf);
    }
  }
}
