namespace SQLHeavy {
  namespace UserFunction {
    public delegate GLib.Value? UserFunc (UserFunction.Context ctx, GLib.SList<GLib.Value?> args) throws Error;
    public delegate void FinalizeFunc (UserFunction.Context ctx);

    [Compact]
    internal class UserFuncData : GLib.Object {
      public weak     Database         db;
      public            string       name;
      public               int       argc;
      public              bool  is_scalar;
      public          UserFunc?      func;
      public      FinalizeFunc?     final;

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

    [Compact]
    private class Value : GLib.Object {
      public void* value;
      public GLib.DestroyNotify destroy_notify;

      ~ Value () {
        if ( this.destroy_notify != null )
          this.destroy_notify (value);
      }

      public Value (void* value, GLib.DestroyNotify destroy_notify = GLib.g_free) {
        this.value = value;
        this.destroy_notify = destroy_notify;
      }
    }

    [CCode (cname = "g_hash_table_unref", cheader_filename = "glib.h")]
    private extern void g_hash_table_unref (GLib.HashTable ht);
    [CCode (cname = "g_hash_table_ref", cheader_filename = "glib.h")]
    private extern weak GLib.HashTable g_hash_table_ref (GLib.HashTable ht);

    /**
     * Context used to manage a call to a user defined function
     */
    public class Context {
      private unowned Sqlite.Context ctx = null;
      private unowned UserFuncData user_func_data = null;

      private unowned GLib.HashTable<string, Value>? _data = null;
      private unowned GLib.HashTable<string, Value> data {
        get {
          if ( this._data == null ) {
            if ( this.user_func_data.is_scalar ) {
              this._data = (GLib.HashTable<string, Value>)this.ctx.get_auxdata (0);
              if ( this._data == null ) {
                this.ctx.set_auxdata (0, new GLib.HashTable<string, Value>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_object_unref), (GLib.DestroyNotify)g_hash_table_unref);
                this._data = (GLib.HashTable<string, Value>)this.ctx.get_auxdata (0);
              }
            }
            else {
              GLib.Memory.copy (&this._data, this.ctx.aggregate_context ((int)sizeof (GLib.HashTable)), sizeof (GLib.HashTable));
              if ( this._data == null )
                this._data = g_hash_table_ref (new GLib.HashTable<string, Value>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_object_unref));
            }
          }

          return this._data;
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
       * This function is meant to be similar to
       * GLib.Object.set_data_full
       *
       * @see get_user_data
       */
      public void set_user_data (string key, void* value, GLib.DestroyNotify destroy_notify = GLib.g_free) {
        this.data.replace (key, new Value (value, destroy_notify));
      }

      /**
       * Get user data
       *
       * This function is meant to be similar to GLib.Object.get_data
       *
       * @see set_user_data
       */
      public unowned void* get_user_data (string key) {
        unowned Value v = this.data.lookup (key);
        return (v != null) ? v.value : null;
      }

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
        else
          GLib.error ("Unknown return type.");
      }

      internal void call_user_func (Sqlite.Value[] args) {
        try {
          GLib.SList<GLib.Value?> gargs = null;
          if ( args.length > 0 )
            gargs = sqlite_value_array_to_g_value_slist (args);

          var res = this.user_func_data.func (this, gargs);
          this.handle_result (res);
        }
        catch ( SQLHeavy.Error e ) {
          this.ctx.result_error_code (sqlite_code_from_error (e));
        }
      }

      internal void call_finalize_func () {
        if ( !this.user_func_data.is_scalar ) {
          this.user_func_data.final (this);
          g_hash_table_unref (this.data);
        }
      }

      internal Context (Sqlite.Context ctx) {
        this.ctx = ctx;
        this.user_func_data = (UserFuncData)ctx.user_data ();
      }
    }

    private static void on_user_function_called (Sqlite.Context context,
                                                 [CCode (array_length_pos = 1.9)] Sqlite.Value[] args) {
      var ctx = new Context (context);
      ctx.call_user_func (args);
    }

    private static void on_user_finalize_called (Sqlite.Context context) {
      var ctx = new Context (context);
      ctx.call_finalize_func ();
    }
  }
}
