namespace SQLHeavy {
  /**
   * Holds implementations of common functions which can be registered
   * with SQLHeavy using the user-defined function API.
   *
   * @see Database.register_common_functions
   */
  namespace CommonFunction {
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