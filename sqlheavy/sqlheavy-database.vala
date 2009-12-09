namespace SQLHeavy {
  [CCode (cname = "sqlite3_open_v2", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_open (string filename, out unowned Sqlite.Database db, int flags = Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE, string? zVfs = null);
  [CCode (cname = "sqlite3_close", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_close (Sqlite.Database db);

  /**
   * A database.
   */
  public class Database : GLib.Object {
    internal unowned Sqlite.Database db;

    private void thread_cb (void * stmt) {
      (stmt as SQLHeavy.Statement).step_threaded ();
    }
    public GLib.ThreadPool thread_pool;

    /**
     * Create a prepared statement.
     *
     * @param sql, An SQL query.
     */
    public SQLHeavy.Statement prepare (string sql) throws SQLHeavy.Error {
      return new SQLHeavy.Statement (this, sql);
    }

    /**
     * Execute a query.
     *
     * @param sql, An SQL query.
     */
    public void execute (string sql, ssize_t max_len = -1) throws Error {
      unowned string? s = sql;

      // Could probably use a bit of work.
      for ( size_t current_max = (max_len < 0) ? s.size () : max_len ;
            (s != null) && (current_max == 0) ; ) {
        unowned char * os = (char *)s;
        {
          SQLHeavy.Statement stmt = new SQLHeavy.Statement.full (this, (!) s, (int)current_max, out s);
          stmt.execute ();
        }

        current_max -= (char *)s - os;
        // Skip white space.
        for ( unowned char * sp = (char *)s ; current_max > 0 ; current_max--, sp++, s = (string)sp )
          if ( !(*sp).isspace () )
            break;
      }
    }

    public void run_script (string filename) throws Error {
      try {
        var file = new GLib.MappedFile (filename, false);
        this.execute ((string)file.get_contents(), (ssize_t)file.get_length());
      }
      catch ( GLib.FileError e ) {
        throw new SQLHeavy.Error.IO ("Unable to open script: %s (%d).", e.message, e.code);
      }
    }

    private string? pragma_get_string (string pragma) {
      try {
        var stmt = new SQLHeavy.Statement (this, "PRAGMA %s;".printf (pragma));
        stmt.step ();
        return stmt.fetch<string> (0);
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to retrieve pragma value: %s", e.message);
        return null;
      }
    }

    private int pragma_get_int (string pragma) {
      return this.pragma_get_string (pragma).to_int ();
    }

    private bool pragma_get_bool (string pragma) {
      return this.pragma_get_int (pragma) != 0;
    }

    private void pragma_set_string (string pragma, string value) {
      try {
        var stmt = new SQLHeavy.Statement (this, "PRAGMA %s = %s;".printf (pragma, value));
        stmt.execute ();
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to retrieve pragma value: %s", e.message);
      }
    }

    private void pragma_set_int (string pragma, int value) {
      this.pragma_set_string (pragma, "%d".printf(value));
    }

    private void pragma_set_bool (string pragma, bool value) {
      this.pragma_set_int (pragma, value ? 1 : 0);
    }

    /**
     * Auto-Vacuum mode
     */
    public SQLHeavy.AutoVacuum auto_vacuum {
      get { return (SQLHeavy.AutoVacuum) this.pragma_get_int("auto_vacuum"); }
      set { this.pragma_set_int ("auto_vacuum", value); }
    }

    /**
     * Cache size
     */
    public int cache_size {
      get { return this.pragma_get_int ("cache_size"); }
      set { this.pragma_set_int ("cache_size", value); }
    }

    public bool case_sensitive_like {
      get { return this.pragma_get_bool ("case_sensitive_like"); }
      set { this.pragma_set_bool ("case_sensitive_like", value); }
    }

    public bool count_changes {
      get { return this.pragma_get_bool ("count_changes"); }
      set { this.pragma_set_bool ("count_changes", value); }
    }

    public int default_cache_size {
      get { return this.pragma_get_int ("default_cache_size"); }
      set { this.pragma_set_int ("default_cache_size", value); }
    }

    public bool empty_result_callbacks {
      get { return this.pragma_get_bool ("empty_result_callbacks"); }
      set { this.pragma_set_bool ("empty_result_callbacks", value); }
    }

    public SQLHeavy.Encoding encoding {
      get { return SQLHeavy.Encoding.from_string (this.pragma_get_string ("encoding")); }
      set { this.pragma_set_string ("encoding", value.to_string ()); }
    }

    public bool foreign_keys {
      get { return this.pragma_get_bool ("foreign_keys"); }
      set { this.pragma_set_bool ("foreign_keys", value); }
    }

    public bool full_column_names {
      get { return this.pragma_get_bool ("full_column_names"); }
      set { this.pragma_set_bool ("full_column_names", value); }
    }

    public bool full_fsync {
      get { return this.pragma_get_bool ("fullfsync"); }
      set { this.pragma_set_bool ("fullfsync", value); }
    }

    public void incremental_vacuum (int pages) {
      try {
        this.execute ("PRAGMA incremental_vacuum(%d);".printf(pages));
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to run incremental vacuum: %s", e.message);
      }
    }

    public SQLHeavy.JournalMode journal_mode {
      get { return SQLHeavy.JournalMode.from_string (this.pragma_get_string ("journal_mode")); }
      set { this.pragma_set_string ("journal_mode", value.to_string ()); }
    }

    public int journal_size_limit {
      get { return this.pragma_get_int ("journal_size_limit"); }
      set { this.pragma_set_int ("journal_size_limit", value); }
    }

    public bool legacy_file_format {
      get { return this.pragma_get_bool ("legacy_file_format"); }
      set { this.pragma_set_bool ("legacy_file_format", value); }
    }

    public SQLHeavy.LockingMode locking_mode {
      get { return SQLHeavy.LockingMode.from_string (this.pragma_get_string ("locking_mode")); }
      set { this.pragma_set_string ("locking_mode", value.to_string ()); }
    }

    public int page_size {
      get { return this.pragma_get_int ("page_size"); }
      set {
        if ( (value & (value - 1)) != 0 )
          GLib.critical ("Page size must be a power of two.");
        this.pragma_set_int ("page_size", value);
      }
    }

    public int max_page_count {
      get { return this.pragma_get_int ("max_page_count"); }
      set { this.pragma_set_int ("max_page_count", value); }
    }

    public bool read_uncommitted {
      get { return this.pragma_get_bool ("read_uncommitted"); }
      set { this.pragma_set_bool ("read_uncommitted", value); }
    }

    public bool recursive_triggers {
      get { return this.pragma_get_bool ("recursive_triggers"); }
      set { this.pragma_set_bool ("recursive_triggers", value); }
    }

    public bool reverse_unordered_selects {
      get { return this.pragma_get_bool ("reverse_unordered_selects"); }
      set { this.pragma_set_bool ("reverse_unordered_selects", value); }
    }

    public bool short_column_names {
      get { return this.pragma_get_bool ("short_column_names"); }
      set { this.pragma_set_bool ("short_column_names", value); }
    }

    public SQLHeavy.SynchronousMode synchronous {
      get { return SQLHeavy.SynchronousMode.from_string (this.pragma_get_string ("synchronous")); }
      set { this.pragma_set_string ("synchronous", value.to_string ()); }
    }

    public SQLHeavy.TempStoreMode temp_store {
      get { return SQLHeavy.TempStoreMode.from_string (this.pragma_get_string ("temp_store")); }
      set { this.pragma_set_string ("temp_store", value.to_string ()); }
    }

    public string temp_store_directory {
      owned get { return this.pragma_get_string ("temp_store_directory"); }
      set { this.pragma_set_string ("temp_store_directory", value); }
    }

    //public GLib.SList<string> collation_list { get; }
    //public ?? database_list { get; }
    //public ?? get_foreign_key_list (string table_name);

    public int free_list_count {
      get { return this.pragma_get_int ("freelist_count"); }
      set { this.pragma_set_int ("freelist_count", value); }
    }

    //public ?? get_index_info (string index_name);
    //public ?? get_index_list (string table_name);

    public int page_count {
      get { return this.pragma_get_int ("page_count"); }
      set { this.pragma_set_int ("page_count", value); }
    }

    //public ?? get_table_info (string table_name);

    public int schema_version {
      get { return this.pragma_get_int ("schema_version"); }
      set { this.pragma_set_int ("schema_version", value); }
    }

    public int user_version {
      get { return this.pragma_get_int ("user_version"); }
      set { this.pragma_set_int ("user_version", value); }
    }

    //public GLib.SList<string> integrity_check (int max_errors = 100);
    //public GLib.SList<string> quick_check (int max_errors = 100);

    public bool parser_trace {
      get { return this.pragma_get_bool ("parser_trace"); }
      set { this.pragma_set_bool ("parser_trace", value); }
    }

    public bool vdbe_trace {
      get { return this.pragma_get_bool ("vdbe_trace"); }
      set { this.pragma_set_bool ("vdbe_trace", value); }
    }

    public bool vdbe_listing {
      get { return this.pragma_get_bool ("vdbe_listing"); }
      set { this.pragma_set_bool ("vdbe_listing", value); }
    }

    protected void open (string? filename, SQLHeavy.FileMode mode) throws SQLHeavy.Error {
      if ( filename == null )
        filename = ":memory:";

      int flags = 0;
      if ( (mode & SQLHeavy.FileMode.READ) == SQLHeavy.FileMode.READ )
        flags = Sqlite.OPEN_READONLY;
      if ( (mode & SQLHeavy.FileMode.WRITE) == SQLHeavy.FileMode.WRITE )
        flags = Sqlite.OPEN_READWRITE;
      if ( (mode & SQLHeavy.FileMode.CREATE) == SQLHeavy.FileMode.CREATE )
        flags |= Sqlite.OPEN_CREATE;

      error_if_not_ok (sqlite3_open ((!) filename, out this.db, flags, null));

      try {
        this.thread_pool = new GLib.ThreadPool (thread_cb, 4, false);
      }
      catch ( GLib.ThreadError e ) {
        throw new SQLHeavy.Error.THREAD ("%s (%d)", e.message, e.code);
      }
    }

    /**
     * Open a database.
     *
     * @param filename, Where to store the database, or null for memory only.
     * @param mode, Bitmask of mode to use when opening the database.
     */
    public Database (string? filename = null,
                     SQLHeavy.FileMode mode =
                       SQLHeavy.FileMode.READ |
                       SQLHeavy.FileMode.WRITE |
                       SQLHeavy.FileMode.CREATE) throws SQLHeavy.Error {
      //error_if_not_ok (Sqlite.Config.config (Sqlite.Config.SERIALIZED));
      this.open (filename, mode);
    }

    ~ Database () {
      if ( this.db != null )
        sqlite3_close (this.db);
    }
  }
}
