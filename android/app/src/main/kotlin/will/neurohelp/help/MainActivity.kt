package will.neurohelp.help

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity statt FlutterActivity: Der BiometricPrompt von
// Android braucht eine FragmentActivity. Ohne das schlaegt die App-Sperre
// zur Laufzeit fehl (Konzept, Abschnitt 13).
class MainActivity : FlutterFragmentActivity()
