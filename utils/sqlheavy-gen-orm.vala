namespace SQLHeavy {
  namespace ORM {
    public errordomain GeneratorError {
      OPTION,
      IO,
      DATA_TYPE
    }

    public class Generator {
      private static string? ns = null;
      [CCode (array_length = false, array_null_terminated = true)]
      private static string[] db;
      private static string? output_location = null;
      private static bool properties = false;
      private static bool document = false;

      private GLib.FileStream output;
      private int current_indent = 0;

      const GLib.OptionEntry[] options = {
        { "", 0, 0, GLib.OptionArg.FILENAME_ARRAY, ref db, "Database", "DATABASE" },
        { "namespace", 'n', 0, GLib.OptionArg.STRING, ref ns, "Namespace", "NAMESPACE" },
        { "output", 'o', 0, GLib.OptionArg.FILENAME, ref output_location, "Output", "FILE" },
        { "properties", 'p', 0, GLib.OptionArg.NONE, ref properties, "Write properties instead of methods", null },
        { "document", 'd', 0, GLib.OptionArg.NONE, ref document, "Write Valadoc comments", null },
        { null }
      };

      private void write_indent () {
        for ( int i = 0 ; i < this.current_indent ; i++ )
          this.output.putc ('\t');
      }

      private void write_line (string line) {
        this.write_indent ();
        this.output.puts (line);
        this.output.putc ('\n');
      }

      private void write_field (GLib.Type data_type, string name) {
        string? vala_name = null;
        string? getter_name = null;
        bool owned_get = false;
        GLib.StringBuilder pretty_name = new GLib.StringBuilder.sized (name.length);

        bool first = true;
        foreach ( unowned string segment in name.split_set ("_-") ) {
          if ( first ) {
            pretty_name.append_unichar (segment[0].toupper ());
            pretty_name.append (segment.offset (1));
            first = false;
          } else {
            pretty_name.append (@" $(segment)");
          }
        }

        if ( data_type == typeof (string) ) {
          owned_get = true;
          vala_name = "string";
        } else if ( data_type == typeof (int64) ) {
          vala_name = "int64";
        } else if ( data_type == typeof (double) ) {
          vala_name = "double";
        } else if ( data_type == typeof (GLib.ByteArray) ) {
          vala_name = "uint8[]";
          getter_name = "blob";
        } else {
          GLib.assert_not_reached ();
        }

        if ( !properties ) {
          if ( document ) {
            this.write_line ("/**");
            this.write_line (@" * Get $(pretty_name.str)");
            this.write_line (" */");
          }
          this.write_line (@"public $(vala_name) get_$(name) () throws SQLHeavy.Error {");
          this.current_indent++;
          this.write_line (@"return this.fetch_named_$(getter_name ?? vala_name) (\"$(name)\");");
          this.current_indent--;
          this.write_line ("}");

          this.output.putc ('\n');

          if ( document ) {
            this.write_line ("/**");
            this.write_line (@" * Set $(pretty_name.str)");
            this.write_line (" */");
          }
          this.write_line (@"public void set_$(name) ($(vala_name) value) throws SQLHeavy.Error {");
          this.current_indent++;
          this.write_line (@"this.put_named_$(getter_name ?? vala_name) (\"$(name)\", value);");
          this.current_indent--;
          this.write_line ("}");
        } else {
          if ( document ) {
            this.write_line ("/**");
            this.write_line (@" * $(pretty_name.str)");
            this.write_line (" */");
          }

          this.write_line (@"public $(vala_name) $(name) {");
          this.current_indent++;

          this.write_indent ();
          if ( owned_get )
            this.output.puts ("owned ");
          this.output.puts ("get {\n");
          this.current_indent++;

          this.write_line ("try {");
          this.current_indent++;
          this.write_line (@"return this.fetch_named_$(getter_name ?? vala_name) (\"$(name)\");");
          this.current_indent--;
          this.write_line ("} catch ( SQLHeavy.Error e ) {");
          this.current_indent++;
          this.write_line (@"GLib.error (\"Unable to retrieve field `$(name)': %s\", e.message);");
          this.current_indent--;
          this.write_line ("}");

          this.current_indent--;
          this.write_line ("}");

          this.write_indent ();
          this.output.puts ("set {\n");
          this.current_indent++;

          this.write_line ("try {");
          this.current_indent++;
          this.write_line (@"this.put_named_$(getter_name ?? vala_name) (\"$(name)\", value);");
          this.current_indent--;
          this.write_line ("} catch ( SQLHeavy.Error e ) {");
          this.current_indent++;
          this.write_line (@"GLib.error (\"Unable to set field `$(name)': %s\", e.message);");
          this.current_indent--;
          this.write_line ("}");

          this.current_indent--;
          this.write_line ("}");

          this.current_indent--;
          this.write_line ("}");
        }
      }

      private void visit_table (SQLHeavy.Table table) throws SQLHeavy.Error {
        GLib.StringBuilder class_name = new GLib.StringBuilder ();

        foreach ( string segment in table.name.split_set ("-_") ) {
          class_name.append_unichar (segment[0].toupper ());
          class_name.append (segment.offset (1));
        }

        this.write_line (@"public class $(class_name.str) : SQLHeavy.Row {");
        this.current_indent++;

        var field_count = table.field_count;
        for ( int idx = 0 ; idx < field_count ; idx++ ) {
          GLib.Type data_type;

          // Determination of Column Affinity
          // http://www.sqlite.org/datatype3.html
          string affinity = table.field_affinity (idx). up ();
          if ( affinity.str ("INT") != null ) {
            data_type = typeof (int64);
          } else if ( affinity.str ("CHAR") != null ||
                      affinity.str ("CLOB") != null ||
                      affinity.str ("TEXT") != null ||
                      affinity == "STRING" ) {
            data_type = typeof (string);
          } else if ( affinity.str ("BLOB") != null ||
                      affinity == "" ) {
            data_type = typeof (GLib.ByteArray);
          } else if ( affinity.str ("REAL") != null ||
                      affinity.str ("FLOA") != null ||
                      affinity.str ("DOUB") != null ) {
            data_type = typeof (double);
          } else {
            data_type = typeof (int64);
          }

          write_field (data_type, table.field_name (idx));

          this.output.putc ('\n');
        }

        if ( document ) {
            this.write_line ("/**");
            this.write_line (@" * Create or load a $(class_name.str)");
            this.write_line (" *");
            this.write_line (" * @param queryable the queryable to use");
            this.write_line (" * @param id the row ID to load, or 0 to create a new entry");
            this.write_line (" */");
          }
        this.write_line (@"public $(class_name.str) (SQLHeavy.Queryable queryable, int id = 0) throws SQLHeavy.Error {");
        this.current_indent++;

        this.write_line (@"var table = new SQLHeavy.Table (queryable, \"$(table.name)\");");
        this.write_line ("Object (table: table, id: id);");

        this.current_indent--;
        this.write_line ("}");

        this.current_indent--;
        this.write_line ("}");
      }

      private void visit_database (SQLHeavy.Database database) throws SQLHeavy.Error {
        var tables = database.get_tables ();
        bool first = true;
        foreach ( unowned SQLHeavy.Table table in tables.get_values () ) {
          if ( !first )
            this.output.putc ('\n');
          else
            first = false;

          this.visit_table (table);
        }
      }

      public void generate () throws SQLHeavy.Error, SQLHeavy.ORM.GeneratorError {
        if ( ns != null ) {
          foreach ( unowned string current_ns in ns.split (".") ) {
            this.write_line (@"namespace $(current_ns) {");
            this.current_indent++;
          }
        }

        if ( this.db.length < 1 )
          throw new GeneratorError.OPTION ("You must provide at least one database file.");

        foreach ( unowned string db_path in this.db ) {
          this.visit_database (new SQLHeavy.Database (db_path, SQLHeavy.FileMode.READ));
        }

        if ( ns != null ) {
          foreach ( unowned string current_ns in ns.split (".") ) {
            this.current_indent--;
            this.write_line ("}");
          }
        }
      }

      public Generator (ref unowned string[] args) throws SQLHeavy.ORM.GeneratorError, SQLHeavy.Error {
        try {
          var opt_context = new OptionContext ("- SQLHeavy ORM Generator");
          opt_context.set_help_enabled (true);
          opt_context.add_main_entries (options, null);
          opt_context.parse (ref args);
        } catch ( GLib.OptionError e ) {
          throw new GeneratorError.OPTION (e.message);
        }

        if ( (this.output = GLib.FileStream.open (output_location ?? "/dev/stdout", "w+")) == null )
          throw new GeneratorError.IO ("Unable to open `%s': %s", output_location, GLib.strerror (GLib.errno));
      }
    }
  }
}

private static int main (string[] args) {
  try {
    var generator = new SQLHeavy.ORM.Generator (ref args);
    generator.generate ();
  } catch ( SQLHeavy.ORM.GeneratorError e ) {
    GLib.stderr.printf ("Error: %s\n", e.message);
    return 1;
  } catch ( SQLHeavy.Error e ) {
    GLib.stderr.printf ("Error: %s\n", e.message);
    return 2;
  }

  return 0;
}
