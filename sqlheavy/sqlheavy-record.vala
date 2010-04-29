namespace SQLHeavy {
  /**
   * A record
   */
  public interface Record : GLib.Object {
    /**
     * The number of columns in the result set.
     */
    public abstract int column_count { get; }

    /**
     * Fetch the column name for the specified index
     *
     * @param col index of column to fetch
     * @return the name of the column
     * @see column_index
     * @see column_names
     */
    public abstract string column_name (int col) throws SQLHeavy.Error;

    /**
     * Fetch the index for the specified column name
     *
     * @param col column name
     * @return the index of the column
     * @see column_name
     */
    public abstract int column_index (string col) throws SQLHeavy.Error;

    /**
     * Fetch the column names for the results
     *
     * @return an array of column names
     * @see column_name
     */
    public string[] column_names () {
      try {
        var columns = new string[this.column_count];

        for ( var i = 0 ; i < columns.length ; i++ )
          columns[i] = this.column_name (i);

        return columns;
      }
      catch ( SQLHeavy.Error e ) {
        /* The only thing that throws an error is the column_name
         * call, and since we know 0 <= argument < column_count, it
         * should never fail. */
        GLib.assert_not_reached ();
      }
    }

    /**
     * Get column type
     *
     * @param col the column index
     * @return the datatype of the column
     */
    public abstract GLib.Type column_type (int col) throws SQLHeavy.Error;

    /**
     * Return a field from result.
     *
     * @param col the index of the column to return.
     * @return the value of the field
     * @see fetch_named
     * @see fetch_row
     */
    public abstract GLib.Value fetch (int col) throws SQLHeavy.Error;

    /**
     * Fetch a field from the result by name
     *
     * @param col column name
     * @return the field value
     * @see fetch
     */
    public GLib.Value? fetch_named (string col) throws SQLHeavy.Error {
      return this.fetch (this.column_index (col));
    }

    /**
     * Return a row from result
     *
     * @return the current row
     * @see fetch
     */
    public GLib.ValueArray fetch_row () throws SQLHeavy.Error {
      var columns = this.column_count;
      var data = new GLib.ValueArray (columns);

      for ( var c = 0 ; c < columns ; c++ )
        data.append (this.fetch (c));

      return data;
    }

    /**
     * Fetch a field from the result, and attempt to transform it if necessary
     *
     * @param requested_type the requested type
     * @param col the column_index
     * @return the field value
     * @see fetch
     */
    public GLib.Value fetch_with_type (GLib.Type requested_type, int col = 0) throws SQLHeavy.Error {
      var val = this.fetch (col);
      if ( val.holds (requested_type) )
        return val;

      var transformed_val = GLib.Value (typeof (string));
      if ( val.transform (ref transformed_val) )
        return transformed_val;

      throw new SQLHeavy.Error.DATA_TYPE ("Unable to transform %s to %s.", val.type ().name (), requested_type.name ());
    }

    /**
     * Fetch a field from the result as a string
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_string
     * @see fetch
     */
    public string? fetch_string (int col = 0) throws SQLHeavy.Error {
      return this.fetch_with_type (typeof (string), col).get_string ();
    }

    /**
     * Fetch a field from the result as a string by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_string
     * @see fetch
     */
    public string? fetch_named_string (string col) throws SQLHeavy.Error {
      return this.fetch_string (this.column_index (col));
    }

    /**
     * Fetch a field from the result as an integer
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_int
     * @see fetch
     */
    public int fetch_int (int col = 0) throws SQLHeavy.Error {
      return this.fetch_with_type (typeof (int), col).get_int ();
    }

    /**
     * Fetch a field from the result as an integer by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_int
     * @see fetch
     */
    public int fetch_named_int (string col) throws SQLHeavy.Error {
      return this.fetch_int (this.column_index (col));
    }

    /**
     * Fetch a field from the result as a signed 64-bit integer
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_int64
     * @see fetch
     */
    public int64 fetch_int64 (int col = 0) throws SQLHeavy.Error {
      return this.fetch_with_type (typeof (int64), col).get_int64 ();
    }

    /**
     * Fetch a field from the result as a signed 64-bit integer by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_int64
     * @see fetch
     */
    public int64 fetch_named_int64 (string col) throws SQLHeavy.Error {
      return this.fetch_int64 (this.column_index (col));
    }

    /**
     * Fetch a field from the result as a double
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_double
     * @see fetch
     */
    public double fetch_double (int col = 0) throws SQLHeavy.Error {
      return this.fetch_with_type (typeof (double), col).get_double ();
    }

    /**
     * Fetch a field from the result as a double by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_double
     * @see fetch
     */
    public double fetch_named_double (string col) throws SQLHeavy.Error {
      return this.fetch_double (this.column_index (col));
    }

    /**
     * Fetch a field from the result as an array of bytes
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_blob
     * @see fetch
     */
    public uint8[] fetch_blob (int col = 0) throws SQLHeavy.Error {
      return ((GLib.ByteArray) this.fetch_with_type (typeof (GLib.ByteArray), col).get_boxed ()).data;
    }

    /**
     * Fetch a field from the result as an array of bytes by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_blob
     * @see fetch
     */
    public uint8[] fetch_named_blob (string col) throws SQLHeavy.Error {
      return this.fetch_blob (this.column_index (col));
    }
  }
}
