namespace SQLHeavy {
  /**
   * A class used to represent a database and its schema
   *
   * The {@link schema} should be a directory which
   * contains a Create.sql script to create the database and set the
   * [[http://www.sqlite.org/pragma.html#version|user_version]].
   *
   * Each time the database is opened, it will check for scripts
   * named Update-to-%d.sql to update the schema to the version
   * number represented by %d (i.e., user_version + 1), and execute
   * them when appropriate.
   *
   * This provides an easy way to keep your database schema up to data
   * when you update your program.
   */
  public class VersionedDatabase : SQLHeavy.Database {
    /**
     * Location of database schema directory
     */
    public string schema { get; construct; }

    construct {
      try {
        init();
      } catch (Error err) {
        GLib.critical("Unable to initialize versioned database: %s", err.message);
      }

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
    public VersionedDatabase (string? file, string directory) throws SQLHeavy.Error {
      Object (filename: file ?? ":memory:", schema: directory);
    }
  }
}
