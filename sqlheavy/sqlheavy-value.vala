namespace SQLHeavy {
  /**
   * Covert an SQLite type (integer) to a GLib.Type.
   *
   * @param stype the SQLite type
   * @return the GLib.Type
   */
  internal GLib.Type sqlite_type_to_g_type (int stype) throws SQLHeavy.Error {
    switch ( stype ) {
      case Sqlite.INTEGER:
        return typeof (int64);
      case Sqlite.TEXT:
        return typeof (string);
      case Sqlite.FLOAT:
        return typeof (double);
      case Sqlite.NULL:
        return typeof (void*);
      case Sqlite.BLOB:
        return typeof (GLib.ByteArray);
      default:
        throw new SQLHeavy.Error.DATA_TYPE ("Data type unsupported.");
    }
  }

  /**
   * Test whether two GLib.Values are equal
   */
  internal bool value_equal (GLib.Value a, GLib.Value b) {
    var gtype = a.type ();
    if ( !b.holds (gtype) )
      return false;

    if ( gtype == typeof (int64) )
      return a.get_int64 () == a.get_int64 ();
    else if ( gtype == typeof (string) )
      return GLib.str_equal (a.get_string (), b.get_string ());
    else if ( gtype == typeof (double) )
      return a.get_double () == b.get_double ();
    else if ( gtype == typeof (GLib.ByteArray) ) {
      unowned GLib.ByteArray a1 = (GLib.ByteArray) a.get_boxed ();
      unowned GLib.ByteArray b1 = (GLib.ByteArray) b.get_boxed ();
      return (a1.len == b1.len) && (GLib.Memory.cmp (a1.data, b1.data, a1.len) == 0);
    } else if ( gtype == typeof (void*) )
      return a.get_pointer () == b.get_pointer ();
    else {
      GLib.critical ("sql_heavy_value_equal not implemented for %s type.", gtype.name ());
      return false;
    }
  }

  /**
   * Convert an SQLite value to a GLib.Value
   *
   * @param value the SQLite value
   * @return the GLib.Value
   */
  internal GLib.Value sqlite_value_to_g_value (Sqlite.Value value) {
    GLib.Type gtype;
    try {
      gtype = sqlite_type_to_g_type (value.to_type ());
    }
    catch ( SQLHeavy.Error e ) {
      GLib.assert_not_reached ();
    }

    GLib.Value gval = GLib.Value (gtype);

    if ( gtype == typeof (int64) )
      gval = value.to_int64 ();
    else if ( gtype == typeof (double) )
      gval = value.to_double ();
    else if ( gtype == typeof (string) )
      gval = value.to_text ();
    else if ( gtype == typeof (GLib.ByteArray) ) {
      unowned uint8[] blob = (uint8[])value.to_blob ();
      blob.length = value.to_bytes ();
      var ba = new GLib.ByteArray.sized (blob.length);
      ba.append (blob);
      gval = ba;
    } else if ( gtype == typeof (void*) ) {
      gval.set_pointer (null);
    }

    return gval;
  }

  /**
   * Convert an array of SQLite values to a GLib.ValueArray
   *
   * @param values the SQLite values
   * @return the GLib.ValueArray
   */
  internal GLib.ValueArray sqlite_value_array_to_g_value_array (Sqlite.Value[] values) {
    var va = new GLib.ValueArray (values.length);
    for ( int i = 0 ; i < values.length ; i++ )
      va.append (sqlite_value_to_g_value (values[i]));

    return va;
  }

  /**
   * Escape a string for use in an SQL query.
   *
   * This function should be used sparingly, as it is generally
   * preferable to use prepared statements.
   *
   * @param str the string to escape
   * @return the escaped string
   * @see Query.bind_string
   */
  public static string escape_string (string str) {
    return str.replace ("'", "''");
  }

  /**
   * Check to see whether the specified GType is handled by SQLHeavy
   *
   * @param gtype the type to check
   * @return whether or not the type is handled by SQLHeavy
   */
  internal bool check_type (GLib.Type gtype) {
    return ( (gtype == typeof (int)) ||
             (gtype == typeof (string)) ||
             (gtype == typeof (int64)) ||
             (gtype == typeof (float)) ||
             (gtype == typeof (double)) ||
             (gtype == typeof (void*)) ||
             (gtype == typeof (GLib.ByteArray)) );
  }

  /**
   * A copy-on-write array of GValues
   */
  public class ValueArray : GLib.Object {
    /**
     * The source array, or null if none
     */
    public ValueArray? source {
      get {
        return this._source;
      }

      construct set {
        if ( value != null ) {
          var len = value.length;
          GLib.return_if_fail (len > 0);

          this._source = value;
          this.to_source_map = new int[len];
          for ( int i = 0 ; i < len ; i++ )
            this.to_source_map[i] = i;

          value.position_changed["before"].connect (this.on_parent_position_changed);
          value.value_changed["before"].connect (this.on_parent_value_changed);
        }
      }
    }
    private ValueArray? _source = null;

    /**
     * How the values are mapped to the source array, or null if there
     * is no source array
     */
    private int[]? to_source_map = null;

    /**
     * Actual array containing the GValues
     */
    private GLib.Value?[]? values = null;

    /**
     * The length of the array
     */
    public int length {
      get {
        if ( this.values != null )
          return this.values.length;
        else if ( this.source != null )
          return this.source.length;
        else
          return 0;
      }
    }

    /**
     * The position of one of the elements in the array changed
     */
    [Signal (detailed = true)]
    public signal void position_changed (int old_index, int new_index);

    /**
     * The value of one of the elements in the array changed
     */
    [Signal (detailed = true)]
    public signal void value_changed (int index);

    /**
     * Retrieve a value
     *
     * @param index the index of the value to retrieve
     * @return the value
     */
    public new unowned GLib.Value? get (int index) {
      GLib.return_val_if_fail (index < this.length, null);

      if ( this.values != null && ((this.to_source_map == null) || (this.to_source_map[index] == -1)) )
        return this.values[index];
      else if ( this._source != null && this.to_source_map[index] != -1 )
        return this._source[this.to_source_map[index]];
      else
        return null;
    }

    /**
     * Prepare to set a value
     *
     * @param index the index of the value to prepare
     */
    private void prepare_set (int index) {
      var len = this.length;

      if ( index >= len ) {
        var i = int.max (index, len - 1);
        this.insert_padding (index, int.max (1, index - i));
      } else if ( this.values == null ) {
        this.set_values_length (len);
      }

      this.value_changed["before"] (index);
    }

    /**
     * Finish setting a value
     *
     * @param index the index of the value to finish setting
     */
    private void finish_set (int index) {
      if ( this.to_source_map != null )
        this.to_source_map[index] = -1;

      this.value_changed (index);
    }

    /**
     * Set a value
     *
     * This function will replace the value at the specified index if
     * it exists. If the array is not long enough to accomodate a
     * value at the specified index it is expanded.
     *
     * @param index the index to write to
     * @param value the value to write
     */
    public new void set (int index, GLib.Value? value) {
      this.prepare_set (index);
      this.values[index] = value;
      this.finish_set (index);
    }

    /**
     * Set a string value
     *
     * @param index the index to write to
     * @param value the value to write
     */
    public void set_string (int index, string value) {
      this.prepare_set (index);
      this.values[index] = value;
      this.finish_set (index);
    }

    /**
     * Set a int value
     *
     * @param index the index to write to
     * @param value the value to write
     */
    public void set_int (int index, int value) {
      this.prepare_set (index);
      this.values[index] = value;
      this.finish_set (index);
    }

    /**
     * Set a 64-bit integer value
     *
     * @param index the index to write to
     * @param value the value to write
     */
    public void set_int64 (int index, int64 value) {
      this.prepare_set (index);
      this.values[index] = value;
      this.finish_set (index);
    }

    /**
     * Set a double value
     *
     * @param index the index to write to
     * @param value the value to write
     */
    public void set_double (int index, double value) {
      this.prepare_set (index);
      this.values[index] = value;
      this.finish_set (index);
    }

    /**
     * Set a binary data value
     *
     * @param index the index to write to
     * @param value the value to write
     */
    public void set_byte_array (int index, GLib.ByteArray value) {
      this.prepare_set (index);
      this.values[index] = value;
      this.finish_set (index);
    }

    public void set_null (int index) {
      this.prepare_set (index);
      var v = GLib.Value (typeof (void*));
      v.set_pointer (null);
      this.values[index] = v;
      this.finish_set (index);
    }

    /**
     * Insert a value into the array
     *
     * Rather than replacing the value at the specified index, this
     * function will move all subsequent data in order to make room
     * for the new value.
     *
     * @param index the index to write to
     * @param value the value to write
     */
    public void insert (int index, GLib.Value? value) {
      this.insert_padding (index, 1);
      this.set (index, value);
    }

    /**
     * Append a value
     *
     * @param value the value to write
     */
    public void append (GLib.Value? value) {
      var len = this.length;
      this.insert_padding (len, 1);
      this.set (len, value);
    }

    /**
     * Prepend a value
     *
     * Note that prepend is much slower than append, since all other
     * values in the array must be moved.
     *
     * @param value the value to write
     */
    public void prepend (GLib.Value? value) {
      this.insert_padding (0, 1);
      this.set (0, value);
    }

    /**
     * Remove a value
     *
     * All values after the removed value will be moved one slot in
     * order to fill in the gap.
     *
     * @param index the index of the value to remove
     */
    public void remove (int index) {
      this.insert_padding (index, -1);
    }

    /**
     * Set the length of the {@link values} array
     */
    private void set_values_length (int length) {
      if ( this.values != null ) {
        if ( this.values.length != length )
          this.values.resize (length);
      } else {
        void* m = GLib.malloc0 (sizeof (GLib.Value?) * (length + 1));
        GLib.Memory.copy (&this.values, &m, sizeof (GLib.Value?[]));
        this.values.length = length;
      }

      if ( this.to_source_map != null )
        this.to_source_map.resize (length);
    }

    /**
     * Handle an item in the {@link source} array moving
     *
     * This is currently not implemented.
     */
    private void on_parent_position_changed (ValueArray src, int old_index, int new_index) {
      // TODO
    }

    /**
     * Handle data in the {@link source} array being changed
     */
    private void on_parent_value_changed (ValueArray src, int index) {
      this.set (index, src[index]);
    }

    /**
     * Insert or remove padding from the array
     *
     * If members is positive, padding will be added. If elements is
     * negative, elements/padding will be removed.
     *
     * @param index to add/remove from
     * @param members number of members to add/remove
     */
    public void insert_padding (int index, int members) {
      if ( members == 0 )
        return;

      int old_length = this.length;
      int new_length = old_length + members;

      if ( members > 0 ) { // Inserting
        for ( int i = int.min (old_length, index + members) ; i >= index ; i-- )
          this.position_changed["before"] (i, i + members);

        if ( this.values != null ) {
          this.set_values_length (new_length);

          if ( index < old_length ) { // Into the middle
            GLib.Memory.move ((void*) (((ulong) this.values) + ((index + members) * sizeof (GLib.Value?))),
                              (void*) (((ulong) this.values) + (index * sizeof (GLib.Value?))),
                              members * sizeof (GLib.Value?));
            GLib.Memory.set ((void*) (((ulong) this.values) + (index * sizeof (GLib.Value?))), 0, members * sizeof (GLib.Value?));
            if ( this.to_source_map != null )
              GLib.Memory.move ((void*) (((ulong) this.to_source_map) + ((index + members) * sizeof (int))),
                                (void*) (((ulong) this.to_source_map) + (index * sizeof (int))),
                                members * sizeof (int));
          }
        } else {
          this.set_values_length (new_length);
        }

        for ( int i = int.min (old_length, index + members) ; i >= index ; i-- )
          this.position_changed (i, i + members);
      } else { // Removing
        for ( int i = index ; i < (index - members) ; i++ ) {
          this.position_changed["before"] (i, -1);
          this[i] = null;
        }

        for ( int i = (index - members) ; i < old_length ; i++ )
          this.position_changed["before"] (i, i + members);

        if ( (index - members) < old_length ) { // From the middle
          GLib.Memory.move ((void*) (((ulong) this.values) + (index * sizeof (GLib.Value?))),
                            (void*) (((ulong) this.values) + ((index - members) * sizeof (GLib.Value?))),
                            ((old_length - index) + members) * sizeof (GLib.Value?));
          GLib.Memory.set ((void*) (((ulong) this.values) + ((old_length + members) * sizeof (GLib.Value?))),
                           0, (-members) * sizeof (GLib.Value?));

          if ( this.to_source_map != null ) {
            GLib.Memory.move ((void*) (((ulong) this.to_source_map) + (index * sizeof (int))),
                              (void*) (((ulong) this.to_source_map) + ((index - members) * sizeof (int))),
                              ((old_length - index) + members) * sizeof (int));
            GLib.Memory.set ((void*) (((ulong) this.to_source_map) + ((old_length + members) * sizeof (int))),
                             0, (-members) * sizeof (int));
          }
        }

        this.set_values_length (new_length);

        for ( int i = index ; i < (index - members) ; i++ )
          this.position_changed (i, -1);
        for ( int i = (index - members) ; i < old_length ; i++ )
          this.position_changed (i, i + members);
      }
    }

    /**
     * Clear all values from the array
     */
    public void clear () {
      if ( this.values != null )
        for ( int i = 0 ; i < this.values.length ; i++ )
          this.values[i] = null;

      if ( this.to_source_map != null )
        for ( int i = 0 ; i < this.to_source_map.length ; i++ )
          this.to_source_map[i] = -1;
    }

    /**
     * Create a copy of the array
     *
     * No data will be copied unless the {@link source} array is
     * altered.
     *
     * @return a new array
     */
    public ValueArray copy () {
      return new ValueArray.with_source (this);
    }

    /**
     * Create a new array with the specified number of elements
     * pre-allocated
     */
    public ValueArray (int length = 0) {
      GLib.Object ();

      if ( length > 0 )
        this.insert_padding (0, length);
    }

    private ValueArray.with_source (ValueArray source) {
      GLib.Object (source: source);
    }
  }
}
