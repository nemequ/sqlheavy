namespace SQLHeavy {
  /**
   * Interface on which queries may be run
   */
  public interface Queryable : GLib.Object {
    /**
     * Database
     */
    public abstract SQLHeavy.Database database { owned get; }

    /**
     * Signal which is emitted when a query finished executing.
     *
     * @param query the query which was executed
     * @see Database.sql_executed
     */
    public signal void query_executed (SQLHeavy.Query query);

    /**
     * Lock the queryable and refuse to run any queries against it.
     *
     * @see unlock
     */
    public abstract void @lock ();

    /**
     * Unlock the queryable and allow queries to be run against it.
     *
     * @see lock
     */
    public abstract void @unlock ();

    /**
     * Queue a query to be executed when the queryable is unlocked
     *
     * @param query the query to queue
     */
    public abstract void queue (SQLHeavy.Query query) throws SQLHeavy.Error;

    /**
     * Begin a transaction. Will lock the queryable until the transaction is resolved.
     *
     * @return a new transaction
     */
    public virtual Transaction begin_transaction () throws SQLHeavy.Error {
      return new Transaction (this);
    }

    /**
     * Parse variadic arguments into a hash table
     *
     * @param args the list of arguments to parse
     */
    private static GLib.HashTable<string,GLib.Value?> va_list_to_hash_table (va_list args) throws SQLHeavy.Error {
      GLib.HashTable<string,GLib.Value?> parameters = new GLib.HashTable<string,GLib.Value?> (GLib.str_hash, GLib.str_equal);

      for ( unowned string? current_parameter = args.arg () ; current_parameter != null ; current_parameter = args.arg () ) {
        GLib.Type gtype = args.arg ();
        GLib.Value gval = GLib.Value (gtype);

        if ( (gtype == typeof (int64)) ||
             (gtype == typeof (int)) )
          gval.set_int64 (args.arg ());
        else if ( gtype == typeof (double) )
          gval.set_double (args.arg ());
        else if ( gtype == typeof (string) )
          gval.set_string (args.arg ());
        else if ( gtype == typeof (GLib.ByteArray) )
          gval.set_boxed (args.arg ());
        else if ( gtype == typeof (void*) )
          gval.set_pointer (null);
        else
          throw new SQLHeavy.Error.DATA_TYPE ("Data type (`%s') unsupported.", gtype.name ());

        parameters.replace (current_parameter, gval);
      }

      return parameters;
    }

    /**
     * Execute the supplied SQL
     *
     * This function accepts an arbitrary number of groups of
     * arguments for binding values. The first argument in the group
     * must be the name of the parameter to bind, the second a GType,
     * and the third the value.
     *
     * @param sql the SQL to execute
     * @return the result
     * @see Query.execute
     */
    public SQLHeavy.QueryResult execute (string sql, ...) throws SQLHeavy.Error {
      unowned string? s = sql;
      var args = va_list ();
      SQLHeavy.QueryResult? result = null;
      GLib.HashTable<string,GLib.Value?>? parameters = null;

      for ( unowned char * sp = (char *)s ; *sp != '\0' ; sp++, s = (string)sp ) {
        if ( !(*sp).isspace () ) {
          SQLHeavy.Query? query = null;
          try {
            if ( result != null ) {
              GLib.critical ("Executing multiple statements from Queryable.execute is deprecated. Use Queryable.run.");
            }
            query = new SQLHeavy.Query.full (this, (!) s, -1, out s);
            sp = ((char*) s) - 1;
          } catch ( SQLHeavy.Error e ) {
            if ( e is SQLHeavy.Error.NO_SQL )
              break;
            else
              throw e;
          }

          int param_count = query.parameter_count;
          for ( int p = 0 ; p < param_count ; p++ ) {
            if ( parameters == null )
              parameters = va_list_to_hash_table (args);

            unowned string name = query.parameter_name (p + 1);
            unowned GLib.Value? value = parameters.lookup (name);
            if ( value == null )
              throw new SQLHeavy.Error.MISSING_PARAMETER ("Parameter `%s' left unbound", name);

            query.set (name, value);
          }

          result = query.execute ();
        }
      }

      return result;
    }

    /**
     * Execute the supplied SQL, iterating through multiple statements
     * if necessary.
     *
     * This function accepts an arbitrary number of groups of
     * arguments for binding values. The first argument in the group
     * must be the name of the parameter to bind, the second a GType,
     * and the third the value.
     *
     * @param sql the SQL query to run
     * @see Query.execute
     */
    public void run (string sql, ...) throws SQLHeavy.Error {
      unowned string? s = sql;
      var args = va_list ();
      GLib.HashTable<string,GLib.Value?>? parameters = null;
      SQLHeavy.Transaction trans = this.begin_transaction ();

      for ( unowned char * sp = (char *)s ; *sp != '\0' ; sp++, s = (string)sp ) {
        if ( !(*sp).isspace () ) {
          SQLHeavy.Query? query = null;
          try {
            query = new SQLHeavy.Query.full (trans, (!) s, -1, out s);
            sp = ((char*) s) - 1;
          } catch ( SQLHeavy.Error e ) {
            if ( e is SQLHeavy.Error.NO_SQL )
              break;
            else
              throw e;
          }

          int param_count = query.parameter_count;
          for ( int p = 0 ; p < param_count ; p++ ) {
            if ( parameters == null )
              parameters = va_list_to_hash_table (args);

            unowned string name = query.parameter_name (p + 1);
            unowned GLib.Value? value = parameters.lookup (name);
            if ( value == null )
              throw new SQLHeavy.Error.MISSING_PARAMETER ("Parameter `%s' left unbound", name);

            query.set (name, value);
          }
          query.execute ();
        }
      }

      trans.commit ();
    }

    /**
     * Execute the supplied insert statement
     *
     * This function accepts an arbitrary number of groups of
     * arguments for binding values. The first argument in the group
     * must be the name of the parameter to bind, the second a GType,
     * and the third the value.
     *
     * @param sql an INSERT query
     * @return the inserted row ID
     * @see execute
     * @see Query.execute_insert
     */
    public int64 execute_insert (string sql, ...) throws SQLHeavy.Error {
      SQLHeavy.Query query = this.prepare (sql);

      var args = va_list ();
      query.set_list (false, null, args);

      return query.execute_insert ();
    }

    /**
     * Execute the supplied SQL, iterating through multiple statements if necessary.
     *
     * @param sql An SQL query.
     * @param max_len the maximum length of the query, or -1 to use strlen (sql)
     */
    private void run_internal (string sql, ssize_t max_len = -1) throws SQLHeavy.Error {
      unowned string? s = sql;

      // Could probably use a bit of work.
      for ( size_t current_max = (max_len < 0) ? s.length : max_len ;
            (s != null) && (current_max > 0) ; ) {
        unowned char * os = (char *)s;
        {
          new SQLHeavy.Query.full (this, (!) s, (int) current_max, out s).execute ();
        }

        current_max -= (char *)s - os;
        // Skip white space.
        for ( unowned char * sp = (char *)s ; current_max > 0 ; current_max--, sp++, s = (string)sp )
          if ( !(*sp).isspace () )
            break;
      }
    }

    /**
     * Create a prepared statement.
     *
     * @param sql An SQL query.
     * @return a new statement
     */
    public virtual SQLHeavy.Query prepare (string sql) throws SQLHeavy.Error {
      return new SQLHeavy.Query (this, sql);
    }

    /**
     * Runs an SQL script located in a file
     *
     * @param filename the location of the script
     */
    public virtual void run_script (string filename) throws Error {
      try {
        GLib.MappedFile file = new GLib.MappedFile (filename, false);

        SQLHeavy.Transaction trans = this.begin_transaction ();
        trans.run_internal ((string) file.get_contents(), (ssize_t) file.get_length());
        trans.commit ();
      }
      catch ( GLib.FileError e ) {
        throw new SQLHeavy.Error.IO ("Unable to open script: %s (%d).", e.message, e.code);
      }
    }

    /**
     * Print the result set to a file stream
     *
     * @param sql the query
     * @param fd the stream to print to
     * @see Queryable.print_table
     */
    public virtual void print_table (string sql, GLib.FileStream? fd = null) throws SQLHeavy.Error {
      this.prepare (sql).print_table ();
    }
  }
}
