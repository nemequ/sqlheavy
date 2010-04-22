/**
 * Demonstrates a few of the user-defined functions SQLHeavy can
 * register.
 */
private static int main (string[] args) {
  try {
    var db = new SQLHeavy.Database ();
    // Register the common user-defined functions
    db.register_common_functions ();

    var test_string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur egestas, risus eu consectetur malesuada, lacus dolor lobortis arcu, id vulputate justo quam ut quam. Aenean nulla arcu, placerat eu pellentesque et, scelerisque non nunc. Praesent id mi metus. Aenean dignissim vestibulum dolor, ac blandit massa sodales a. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer sem nunc, faucibus vel vestibulum nec, luctus eu leo. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Pellentesque ultricies odio a turpis pharetra rhoncus. Curabitur ut lectus eu nisl elementum imperdiet sed at lectus. Cras vehicula urna sit amet arcu accumsan tristique. Proin ultrices, leo auctor tempor commodo, metus justo luctus lorem, a egestas urna purus sit amet dolor. Praesent ullamcorper elit et leo interdum porta.";

    GLib.stdout.puts ("Testing cryptographic hashes...\n");
    var stmt = db.prepare ("SELECT MD5(:data), SHA1(:data), SHA256(:data);");
    stmt.bind_named_string (":data", test_string);
    stmt.step ();
    GLib.stdout.printf ("   MD5: %s\n", stmt.fetch_string (0));
    GLib.stdout.printf ("  SHA1: %s\n", stmt.fetch_string (1));
    GLib.stdout.printf ("SHA256: %s\n", stmt.fetch_string (2));
    GLib.stdout.putc ('\n');

    GLib.stdout.puts ("Testing compression...\n");
    var data = (uint8[]) test_string.to_utf8 ();
    GLib.stdout.printf ("Original size: %d bytes\n", (int) test_string.size ());
    stmt = db.prepare ("SELECT COMPRESS(:data);");
    stmt.bind_named_blob (":data", data);
    var compressed = stmt.fetch_result_blob ();
    GLib.stdout.printf ("Compressed size: %d bytes\n", compressed.length);
    stmt = db.prepare ("SELECT DECOMPRESS(:data);");
    stmt.bind_named_blob (":data", compressed);
    GLib.stdout.puts ("Decompression " + (stmt.fetch_result_string () == test_string ? "successful" : "failed") + ".\n");
  }
  catch ( SQLHeavy.Error e ) {
    GLib.error ("%s", e.message);
  }

  return 0;
}