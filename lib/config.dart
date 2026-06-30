// Supabase connection config.
//
// supabaseUrl is your project URL.
// supabaseAnonKey is the PUBLIC anon / publishable key (safe to ship in the app
// — Row Level Security protects the data). It is NOT the secret key.
// Find it in: Supabase Dashboard -> Settings -> API -> "anon public" (or the
// "Publishable key" starting with sb_publishable_...).
class AppConfig {
  static const String supabaseUrl = 'https://hqcvkqiuwdbirqyrlrsv.supabase.co';

  // anon / public key (safe to ship — RLS protects data).
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxY3ZrcWl1d2RiaXJxeXJscnN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MjAxNjUsImV4cCI6MjA5ODM5NjE2NX0.neECtfWrvnNmBM_hR3mKums23DiQBrsRDHwxvFIaTHk';
}
