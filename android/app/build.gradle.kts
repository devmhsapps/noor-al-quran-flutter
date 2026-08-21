plugins { id("com.android.application"); id("kotlin-android"); id("dev.flutter.flutter-gradle-plugin") }
android {
    namespace = "com.nooralquran"
    compileSdk = flutter.compileSdkVersion
    defaultConfig { applicationId = "com.nooralquran"; minSdk = 24; targetSdk = flutter.targetSdkVersion; versionCode = flutter.versionCode; versionName = flutter.versionName }
}
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter { source = "../.." }
