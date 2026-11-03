-dontwarn javax.annotation.Nullable
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.OpenSSLProvider

# WorkManager creates this Room-generated database by reflection during
# AndroidX Startup. R8 otherwise removes its no-argument constructor, causing
# a fatal NoSuchMethodException before the app's Flutter activity starts.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
