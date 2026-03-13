# Suppress warnings for optional TLS provider classes referenced by okhttp's platform code
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE

# Keep home widget provider and plugin classes so R8 does not strip them.
-keep class com.labyrinth.course_block.widget.TodayWidgetProvider { *; }
-keep class es.antonborri.home_widget.** { *; }

# device_calendar relies on Gson/reflection for some Android-side models.
# Without keeping these classes, R8 can obfuscate fields/methods and break
# release-only flows like retrieveCalendars(), which this app uses before
# writing events into the system calendar.
-keep class com.builttoroam.devicecalendar.** { *; }
