# SeekerClaw ProGuard Rules

# Keep nodejs-mobile JNI bridge
-keep class io.niccolobocook.nodejsmobile.** { *; }

# Keep Kotlin coroutines
-keepnames class kotlinx.coroutines.** { *; }

# Keep kotlinx.serialization — required for Compose Navigation type-safe routes
# R8 strips/renames @Serializable companion serializers, causing runtime crash:
# "Serializer for class 'a' is not found"
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep `serializer()` on all @Serializable classes (our route objects)
-keep,includedescriptorclasses class com.seekerclaw.app.**$$serializer { *; }
-keepclassmembers class com.seekerclaw.app.** {
    *** Companion;
}
-keepclasseswithmembers class com.seekerclaw.app.** {
    kotlinx.serialization.KSerializer serializer(...);
}
