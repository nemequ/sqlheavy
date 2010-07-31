namespace SQLHeavy {
  /**
   * A record that can be altered or removed
   */
  public interface MutableRecord : SQLHeavy.Record {
    /**
     * Put a value into a field of a record
     *
     * @param field the index of the field
     * @param value the value of the field
     */
    public abstract void put (int field, GLib.Value value) throws SQLHeavy.Error;

    /**
     * Put a value into a named field of a record
     *
     * @param field the name of the field
     * @param value the value of the field
     */
    public virtual void set (string field, GLib.Value value) throws SQLHeavy.Error {
      this.put (this.field_index (field), value);
    }

    /**
     * Put a string value into a field of a record
     *
     * @param field index of the field to put data into
     * @param value value to put into the field
     * @see set_string
     */
    public virtual void put_string (int field, string? value) throws SQLHeavy.Error {
      if ( value == null )
        this.put_null (field);
      else
        this.put (field, (!) value);
    }

    /**
     * Put a string value into a named field of a record
     *
     * @param field name of the field to put data into
     * @param value value to put into the field
     * @see put_string
     */
    public virtual void set_string (string field, string? value) throws SQLHeavy.Error {
      this.put_string (this.field_index (field), value);
    }

    /**
     * Put a null value into a field of a record
     *
     * @param field index of the field to put data into
     * @see set_null
     */
    public virtual void put_null (int field) throws SQLHeavy.Error {
      var gv = GLib.Value (typeof (void *));
      gv.set_pointer (null);
      this.put (field, gv);
    }

    /**
     * Put a null value into a named field of a record
     *
     * @param field index of the field to put data into
     * @see put_null
     */
    public virtual void set_null (string field) throws SQLHeavy.Error {
      this.put_null (this.field_index (field));
    }

    /**
     * Put an integer value into a field of a record
     *
     * @param field index of the field to put data into
     * @param value value to put into the field
     * @see set_int
     */
    public virtual void put_int (int field, int value) throws SQLHeavy.Error {
      this.put (field, value);
    }

    /**
     * Put an integer value into a named field of a record
     *
     * @param field name of the field to put data into
     * @param value value to put into the field
     * @see put_int
     */
    public virtual void set_int (string field, int value) throws SQLHeavy.Error {
      this.put_int (this.field_index (field), value);
    }

    /**
     * Put a 64-bit integer value into a field of a record
     *
     * @param field index of the field to put data into
     * @param value value to put into the field
     * @see set_int64
     */
    public virtual void put_int64 (int field, int64 value) throws SQLHeavy.Error {
      this.put (field, value);
    }

    /**
     * Put a 64-bit integer value into a named field of a record
     *
     * @param field name of the field to put data into
     * @param value value to put into the field
     * @see put_int64
     */
    public virtual void set_int64 (string field, int64 value) throws SQLHeavy.Error {
      this.put_int64 (this.field_index (field), value);
    }

    /**
     * Put a double-precision floating point value into a field of a record
     *
     * @param field index of the field to put data into
     * @param value value to put into the field
     * @see set_double
     */
    public virtual void put_double (int field, double value) throws SQLHeavy.Error {
      this.put (field, value);
    }

    /**
     * Put a double-precision floating point value into a named field of a record
     *
     * @param field name of the field to put data into
     * @param value value to put into the field
     * @see put_double
     */
    public virtual void set_double (string field, double value) throws SQLHeavy.Error {
      this.put_double (this.field_index (field), value);
    }

    /**
     * Put a blob value into a field of a record
     *
     * @param field index of the field to put data into
     * @param value value to put into the field
     * @see set_blob
     */
    public virtual void put_blob (int field, uint8[] value) throws SQLHeavy.Error {
      var ba = new GLib.ByteArray.sized (value.length);
      ba.append (value);
      this.put (field, ba);
    }

    /**
     * Put a blob value into a field of a record
     *
     * @param field name of the field to put data into
     * @param value value to put into the field
     * @see put_blob
     */
    public virtual void set_blob (string field, uint8[] value) throws SQLHeavy.Error {
      this.put_blob (this.field_index (field), value);
    }

    /**
     * Put a timestamp value into a field of a record
     *
     * @param field index of the field to put data into
     * @param value value to put into the field
     * @see set_time_t
     */
    public virtual void put_time_t (int field, time_t value) throws SQLHeavy.Error {
      this.put_int64 (field, value);
    }

    /**
     * Put a timestamp value into a named field of a record
     *
     * @param field name of the field to put data into
     * @param value value to put into the field
     * @see put_time_t
     */
    public virtual void set_time_t (string field, time_t value) throws SQLHeavy.Error {
      this.put_time_t (this.field_index (field), value);
    }

    /**
     * Write any changes to the record to the database
     *
     * @see put
     */
    public abstract void save () throws SQLHeavy.Error;

    /**
     * Delete the record from the database
     */
    public abstract void delete () throws SQLHeavy.Error;
  }
}
