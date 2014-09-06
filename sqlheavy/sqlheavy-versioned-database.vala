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
        try {
          script_name = this.schema + "/Create.sql";
          this.run_file (GLib.File.new_for_uri (script_name));
        }
        catch ( SQLHeavy.Error e ) {
          GLib.critical ("Unable to run creation script `%s' (%s: %d).", script_name, e.message, e.code);
        }

        if ( (version = this.user_version) == 0 )
          this.user_version = version = 1;
      }

      try {
        SQLHeavy.Transaction? trans = null;

        while ( true ) {
          script_name = "%s/Update-to-%d.sql".printf (this.schema, version + 1);
          GLib.File script = GLib.File.new_for_uri (script_name);

          if ( trans == null )
            trans = this.begin_transaction ();

          trans.run_file (script);

          this.user_version = ++version;
        }

        if ( trans != null )
          trans.commit ();
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to run update script `%s' (%s: %d).", script_name, e.message, e.code);
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
