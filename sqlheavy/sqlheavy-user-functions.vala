namespace SQLHeavy {
  /**
   * Symbols related to the creation and execution of user-created
   * functions.
   *
   * See SQLite documentation at [[http://www.sqlite.org/c3ref/create_function.html]]
   */
  namespace UserFunction {
    /**
     * This function is called as SQLite is stepping through the
     * data. It is analogous to SQLite's
     * [[http://www.sqlite.org/c3ref/create_function.html|xStep and xFunc]]
     * callback.
     *
     * @return value to return from the function
     * @param ctx execution context
     * @param args arguments passed to the function
     */
    public delegate GLib.Value? UserFunc (UserFunction.Context ctx, GLib.ValueArray args) throws Error;
    /**
     * This function is called when SQLite finishes stepping through
     * the data. It is analogous to SQLite's
     * [[http://www.sqlite.org/c3ref/create_function.html|xFinal]]
     * callback.
     *
     * @param ctx execution context
     */
    public delegate void FinalizeFunc (UserFunction.Context ctx);

    /**
     * Context data for a user function
     */
    [Compact]
    internal class UserFuncData : GLib.Object {
      public weak     Database         db;
      public            string       name;
      public               int       argc;
      public              bool  is_scalar;
      public          UserFunc?      func;
      public      FinalizeFunc?     final;

      /**
       * Create context data for a scalar function
       *
       * @param db database to create this function on
       * @param name function name
       * @param argc the number of arguments that this function accepts
       * @param func callback to execute when the function is called
       * @see Database.register_scalar_function
       */
      public UserFuncData.scalar (Database db,
                                  string name,
                                  int argc,
                                  UserFunc func) {
        this.db = db;
        this.name = name;
        this.argc = argc;
        this.is_scalar = true;
        this.func = func;
        this.final = null;
      }

      /**
       * Create context data for an aggregate function
       *
       * @param db database to create this function on
       * @param name function name
       * @param argc the number of arguments that this function accepts
       * @param func callback to execute once for each piece of data the function is called on
       * @param final callback to execute after the func has been called for the last time
       * @see Database.register_aggregate_function
       */
      public UserFuncData.aggregate (Database db,
                                     string name,
                                     int argc,
                                     UserFunc func,
                                     FinalizeFunc final) {
        this.db = db;
        this.name = name;
        this.argc = argc;
        this.is_scalar = false;
        this.func = func;
        this.final = final;
      }
    }

    [CCode (cname = "g_hash_table_unref", cheader_filename = "glib.h")]
    private extern void g_hash_table_unref (GLib.HashTable ht);
    [CCode (cname = "g_hash_table_ref", cheader_filename = "glib.h")]
    private extern unowned GLib.HashTable g_hash_table_ref (GLib.HashTable ht);
    [CCode (cname = "g_boxed_free", cheader_filename = "glib.h")]
    private extern void g_boxed_free (GLib.Type type, void * ptr);

    /**
     * Free a boxed GValue, or do nothing if called on a null
     *
     * @param value the GValue to free
     */
    private void g_boxed_value_free (void* value) {
      if ( value != null )
        g_boxed_free (typeof (GLib.Value), (void*)value);
    }

    /**
     * Context used to manage a call to a user defined function
     */
    public class Context {
      /**
       * SQLite context for this SQLHeavy context
       */
      private unowned Sqlite.Context? ctx = null;

      /**
       * Link to the pertinent {@link UserFuncData}
       */
      private unowned UserFuncData? user_func_data = null;

      private unowned GLib.HashTable<string, GLib.Value?>? _data = null;
      /**
       * Map of user data
       *
       * @see set_user_data
       * @see get_user_data
       */
      private GLib.HashTable<string, GLib.Value?> data {
        get {
          if ( this._data == null ) {
            if ( this.user_func_data.is_scalar ) {
              this._data = this.ctx.get_auxdata<GLib.HashTable<string, GLib.Value?>> (0);
              if ( this._data == null ) {
                this.ctx.set_auxdata<GLib.HashTable<string, GLib.Value?>> (0, new GLib.HashTable<string, GLib.Value?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, (GLib.DestroyNotify) g_boxed_value_free));
                this._data = this.ctx.get_auxdata<GLib.HashTable<string, GLib.Value?>> (0);
              }
            }
            else {
              GLib.Memory.copy (&this._data, this.ctx.aggregate ((int)sizeof (GLib.HashTable)), sizeof (GLib.HashTable));
              if ( this._data == null )
                this._data = g_hash_table_ref (new GLib.HashTable<string, GLib.Value?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_object_unref));
            }
          }

          return (!) this._data;
        }
      }

      /**
       * Set user data
       *
       * SQLHeavy user defined functions can store data in a hash
       * table.
       *
       * For scalar functions, this is uses the Function Auxillary Data
       * (see [[http://sqlite.org/c3ref/get_auxdata.html]])
       * feature of SQLite, meaning that, "If the same value is passed
       * to multiple invocations of the same SQL function during query
       * execution, under some circumstances the associated metadata
       * may be preserved."
       *
       * For aggregate functions, it uses the Aggregate Function Context
       * (see [[http://sqlite.org/c3ref/aggregate_context.html]])
       * feature of SQLite, allowing user data to be shared accross an
       * entire aggregate operation.
       *
       * @see get_user_data
       */
      public void set_user_data (string key, GLib.Value value) {
        this.data.replace (key, value);
      }

      /**
       * Get user data
       *
       * @see set_user_data
       */
      public unowned GLib.Value? get_user_data (string key) {
        return this.data.lookup (key);
      }

      /**
       * Take a GValue and place the data in the result of the SQLite context
       */
      internal void handle_result (GLib.Value? value) {
        if ( value == null )
          this.ctx.result_null ();
        else if ( value.holds (typeof (int)) )
          this.ctx.result_int (value.get_int ());
        else if ( value.holds (typeof (int64)) )
          this.ctx.result_int64 (value.get_int64 ());
        else if ( value.holds (typeof (double)) )
          this.ctx.result_double (value.get_double ());
        else if ( value.holds (typeof (string)) )
          this.ctx.result_text (value.get_string (), -1, GLib.g_free);
        else if ( value.holds (typeof (bool)) )
          this.ctx.result_int (value.get_boolean () ? 1 : 0);
        else if ( value.holds (typeof (GLib.ByteArray)) )
          this.ctx.result_blob (((GLib.ByteArray) value.get_boxed ()).data);
        else
          GLib.critical ("Unknown return type (%s).", value.type_name ());
      }

      /**
       * Call the supplied user function callback
       */
      internal void call_user_func (Sqlite.Value[] args) {
        try {
          var res = this.user_func_data.func (this, sqlite_value_array_to_g_value_array (args));
          this.handle_result (res);
        }
        catch ( SQLHeavy.Error e ) {
          this.ctx.result_error (this.ctx.db_handle ().errmsg (), sqlite_code_from_error (e));
        }
      }

      /**
       * Call the supplied user finalize function callback
       */
      internal void call_finalize_func () {
        if ( !this.user_func_data.is_scalar ) {
          this.user_func_data.final (this);
        }
        g_hash_table_unref (this.data);
      }

      internal Context (Sqlite.Context ctx) {
        this.ctx = ctx;
        this.user_func_data = ctx.user_data<UserFuncData> ();
      }
    }

    /**
     * The function callback supplied to the SQLite context
     */
    private static void on_user_function_called (Sqlite.Context context,
                                                 [CCode (array_length_pos = 1.9)] Sqlite.Value[] args) {
      var ctx = new Context (context);
      ctx.call_user_func (args);
    }

    /**
     * The finalize function callback supplied to the SQLite context
     */
    private static void on_user_finalize_called (Sqlite.Context context) {
      var ctx = new Context (context);
      ctx.call_finalize_func ();
    }
  }
}
