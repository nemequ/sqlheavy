namespace SQLHeavy {
  /**
   * A convenience class used to represent a database and script(s) for the schema
   */
  public class VersionedDatabase : SQLHeavy.Database {
    public string schema { get; construct; }

    construct {
      var version = this.user_version;
      string script_name;

      if ( version == 0 ) {
        script_name = GLib.Path.build_filename (this.schema, "Create.sql");
        try {
          this.run_script (script_name);
        }
        catch ( SQLHeavy.Error e ) {
          GLib.critical ("Unable to run creation script `%s' (%s: %d).", script_name, e.message, e.code);
        }
        if ( (version = this.user_version) == 0 )
          this.user_version = version = 1;
      }

      while ( true ) {
        script_name = GLib.Path.build_filename(this.schema, "Update-to-%d.sql".printf (version + 1));
        if ( !GLib.FileUtils.test (script_name, GLib.FileTest.EXISTS) )
          break;

        try {
          this.run_script (script_name);
        }
        catch ( SQLHeavy.Error e ) {
          GLib.critical ("Unable to run update script `%s' (%s: %d).", script_name, e.message, e.code);
          break;
        }
        this.user_version = ++version;
      }
    }

    /**
     * Create a VersionedDatabase
     *
     * @param file The filename of the database
     * @param directory the directory where the schema can be found
     */
    public VersionedDatabase (string file, string directory) throws SQLHeavy.Error {
      Object (filename: file, schema: directory);
    }
  }
}
