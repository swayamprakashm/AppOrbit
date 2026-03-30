plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.apporbit"

    // ✨ Standards: Updated to match modern Android and plugin requirements
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✨ UPGRADED: From 8 to 17 to match your JDK 21 compiler warnings
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            // ✨ FIX: Modern DSL for setting the JVM target to 17
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.example.apporbit"
        // ✨ Security: Min SDK 24 is excellent for Biometrics and Firebase support
        minSdk = 24
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Add 'isMinifyEnabled = true' here later if you want to shrink your APK
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✨ FIREBASE: Using the BOM (Bill of Materials) ensures all Firebase plugins work together
    implementation(platform("com.google.firebase:firebase-bom:32.8.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")

    // ✨ UI & ANIMATIONS: Native support for Lottie
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.airbnb.android:lottie:6.4.0")

    // ✨ SECURITY: Essential for the local_auth fingerprint functionality
    implementation("androidx.biometric:biometric:1.1.0")
}