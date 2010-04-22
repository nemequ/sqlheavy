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

    [CCode (cname = "g_hash_table_unref", cheader_filename = "glib.h")]
    private extern void g_hash_table_unref (GLib.HashTable ht);
    [CCode (cname = "g_hash_table_ref", cheader_filename = "glib.h")]
    private extern unowned GLib.HashTable g_hash_table_ref (GLib.HashTable ht);
    [CCode (cname = "g_boxed_free", cheader_filename = "glib.h")]
    private extern void g_boxed_free (GLib.Type type, void * ptr);

    private void g_boxed_value_free (void* value) {
      if ( value != null )
        g_boxed_free (typeof (GLib.Value), (void*)value);
    }

    /**
     * Context used to manage a call to a user defined function
     */
    public class Context {
      private unowned Sqlite.Context ctx = null;
      private unowned UserFuncData user_func_data = null;

      private unowned GLib.HashTable<string, GLib.Value?> _data;
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

      internal void call_user_func (Sqlite.Value[] args) {
        try {
          var res = this.user_func_data.func (this, sqlite_value_array_to_g_value_array (args));
          this.handle_result (res);
        }
        catch ( SQLHeavy.Error e ) {
          this.ctx.result_error (this.ctx.db_handle ().errmsg (), sqlite_code_from_error (e));
        }
      }

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

    private static void on_user_function_called (Sqlite.Context context,
                                                 [CCode (array_length_pos = 1.9)] Sqlite.Value[] args) {
      var ctx = new Context (context);
      ctx.call_user_func (args);
    }

    private static void on_user_finalize_called (Sqlite.Context context) {
      var ctx = new Context (context);
      ctx.call_finalize_func ();
    }

    /**
     * Implementation of a REGEXP function using GRegex
     *
     * SQLite includes special support for a function named REGEXP,
     * which is left unimplemented by SQLite. This function provides a
     * basic implementation based on the regex support in GLib.
     *
     * @return whether or not the expression matched
     * @param ctx execution context
     * @param args arguments to the function
     */
    public GLib.Value? regex (UserFunction.Context ctx, GLib.ValueArray args) throws Error {
      GLib.Regex? regex = null;
      unowned string str_expr = args.get_nth (0).get_string ();
      GLib.Value? gv_expr = ctx.get_user_data (str_expr);
      if ( gv_expr == null ) {
        try {
          regex = new GLib.Regex (str_expr, GLib.RegexCompileFlags.OPTIMIZE | GLib.RegexCompileFlags.DOLLAR_ENDONLY);
        }
        catch ( GLib.RegexError e ) {
          throw new SQLHeavy.Error.ERROR ("Unable to compile regular expression: %s", e.message);
        }
        ctx.set_user_data (str_expr, regex);
      }
      else {
        regex = (GLib.Regex)gv_expr.get_boxed ();
      }

      var arg = args.get_nth (1);
      if ( arg == null )
        return false;
      if ( !arg.holds (typeof (string)) ) {
        // TODO: attempt to transform -> string
        throw new SQLHeavy.Error.MISMATCH (sqlite_errstr (Sqlite.MISMATCH));
      }

      return regex.match (arg.get_string ());
    }

    private GLib.Value? checksum (GLib.ChecksumType cs, UserFunction.Context ctx, GLib.ValueArray args) throws Error {
      var arg = args.get_nth (0);
      if ( arg.holds (typeof (string)) )
        return GLib.Checksum.compute_for_string (cs, arg.get_string ());
      else if ( arg.holds (typeof (GLib.ByteArray)) )
        return GLib.Checksum.compute_for_data (cs, ((GLib.ByteArray) arg.get_boxed ()).data);
      else
        throw new SQLHeavy.Error.MISMATCH (sqlite_errstr (Sqlite.MISMATCH));
    }

    /**
     * Implementation of a MD5 function using GChecksum
     *
     * @return whether or not the expression matched
     * @param ctx execution context
     * @param args arguments to the function
     * @see sha1
     * @see sha256
     */
    public GLib.Value? md5 (UserFunction.Context ctx, GLib.ValueArray args) throws Error {
      return checksum (GLib.ChecksumType.MD5, ctx, args);
    }

    /**
     * Implementation of a SHA-1 function using GChecksum
     *
     * @return whether or not the expression matched
     * @param ctx execution context
     * @param args arguments to the function
     * @see sha256
     * @see md5
     */
    public GLib.Value? sha1 (UserFunction.Context ctx, GLib.ValueArray args) throws Error {
      return checksum (GLib.ChecksumType.SHA1, ctx, args);
    }

    /**
     * Implementation of a SHA-256 function using GChecksum
     *
     * @return whether or not the expression matched
     * @param ctx execution context
     * @param args arguments to the function
     * @see sha1
     * @see md5
     */
    public GLib.Value? sha256 (UserFunction.Context ctx, GLib.ValueArray args) throws Error {
      return checksum (GLib.ChecksumType.SHA256, ctx, args);
    }

    private GLib.Value? convert_blob (GLib.Converter converter, UserFunction.Context ctx, GLib.ValueArray args) throws SQLHeavy.Error {
      var arg = args.values[0];
      uint8[] in_data;

      if ( arg.holds (typeof (string)) )
        in_data = (uint8[]) arg.get_string ().to_utf8 ();
      else if ( arg.holds (typeof (GLib.ByteArray)) )
        in_data = ((GLib.ByteArray) arg.get_boxed ()).data;
      else
        throw new SQLHeavy.Error.MISMATCH (sqlite_errstr (Sqlite.MISMATCH));

      var res = new GLib.ByteArray ();
      size_t bytes_read, bytes_written, outbuf_l = 4096;
      int in_offset = 0;
      void * outbuf = GLib.malloc (outbuf_l);

      while ( true ) {
        try {
          var end = int.min (in_offset + 256, in_data.length);

          var cr = converter.convert (in_data[in_offset:end],
                                      end - in_offset,
                                      outbuf,
                                      outbuf_l,
                                      end >= in_data.length ? GLib.ConverterFlags.INPUT_AT_END : GLib.ConverterFlags.NO_FLAGS,
                                      out bytes_read,
                                      out bytes_written);

          if ( cr == GLib.ConverterResult.CONVERTED ||
               cr == GLib.ConverterResult.FINISHED ) {
            unowned uint8[] data = (uint8[]) outbuf;
            data.length = (int) bytes_written;
            res.append (data);

            if ( cr == GLib.ConverterResult.FINISHED )
              break;
            else
              in_offset += (int) bytes_read;
          }
        } catch ( GLib.Error e ) {
          if ( e is GLib.IOError.PARTIAL_INPUT ) {
            GLib.free (outbuf);
            outbuf_l += 4096;
            outbuf = GLib.malloc (outbuf_l);
          }
          GLib.error (e.message);
        }
      }

      GLib.free (outbuf);
      return res;
    }

    /**
     * Implementation of a ZLib COMPRESS function
     *
     * @return whether or not the expression matched
     * @param ctx execution context
     * @param args arguments to the function
     * @see decompress
     */
    public GLib.Value? compress (UserFunction.Context ctx, GLib.ValueArray args) throws SQLHeavy.Error {
      return convert_blob (new GLib.ZlibCompressor (GLib.ZlibCompressorFormat.ZLIB, -1), ctx, args);
    }

    /**
     * Implementation of a ZLib DECOMPRESS function
     *
     * @return whether or not the expression matched
     * @param ctx execution context
     * @param args arguments to the function
     * @see compress
     */
    public GLib.Value? decompress (UserFunction.Context ctx, GLib.ValueArray args) throws SQLHeavy.Error {
      return convert_blob (new GLib.ZlibDecompressor (GLib.ZlibCompressorFormat.ZLIB), ctx, args);
    }
  }
}
