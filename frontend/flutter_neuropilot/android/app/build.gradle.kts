plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localProps = Properties().apply {
    val f = file("../local.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
}

val credsDir = localProps.getProperty("credentials.dir") ?: "../../credentials"
val devGoogleServices = localProps.getProperty("firebase.google_services.dev")
    ?: "$credsDir/google-services-dev.json"
val prodGoogleServices = localProps.getProperty("firebase.google_services.prod")
    ?: "$credsDir/google-services-prod.json"

tasks.register<Copy>("copyGoogleServicesDev") {
    val src = file(devGoogleServices)
    if (src.exists()) {
        from(src)
        into("src/development")
        rename { "google-services.json" }
    }
}

tasks.register<Copy>("copyGoogleServicesProd") {
    val src = file(prodGoogleServices)
    if (src.exists()) {
        from(src)
        into("src/production")
        rename { "google-services.json" }
    }
}

android {
    namespace = "com.bishal.altered"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.bishal.altered"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    flavorDimensions += listOf("default")
    productFlavors {
        create("development") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("production") {
            dimension = "default"
            applicationIdSuffix = ".prod"
            versionNameSuffix = "-prod"
        }
    }
}

flutter {
    source = "../.."
}

tasks.named("preBuild").configure {
    dependsOn("copyGoogleServicesDev")
    dependsOn("copyGoogleServicesProd")
}
