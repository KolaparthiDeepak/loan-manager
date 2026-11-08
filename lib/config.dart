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

  // Supabase Auth is email-based; the app shows a USERNAME field and maps it to
  // "<username>@<authEmailDomain>" internally. No mail is sent for sign-in, so
  // this domain is just a stable namespace for accounts.
  static const String authEmailDomain = 'loan.app';}

/// Maps a username to the synthetic email used with Supabase Auth.
String usernameToEmail(String username) =>
    '${username.trim().toLowerCase()}@${AppConfig.authEmailDomain}';
