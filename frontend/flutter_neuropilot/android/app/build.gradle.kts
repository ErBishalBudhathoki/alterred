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
val devGoogleServicesDefault = "$credsDir/google-services-dev.json"
val prodGoogleServicesDefault = "$credsDir/google-services-prod.json"
val anyGoogleServicesFallback = file(credsDir).listFiles()
    ?.firstOrNull { it.name.startsWith("google-services") && it.extension == "json" }?.path

val devGoogleServices = localProps.getProperty("firebase.google_services.dev")
    ?: (if (file(devGoogleServicesDefault).exists()) devGoogleServicesDefault else anyGoogleServicesFallback ?: devGoogleServicesDefault)
val prodGoogleServices = localProps.getProperty("firebase.google_services.prod")
    ?: (if (file(prodGoogleServicesDefault).exists()) prodGoogleServicesDefault else anyGoogleServicesFallback ?: prodGoogleServicesDefault)

// Fallback to local file if not found in credentials dir
val finalDevGoogleServices = if (file(devGoogleServices).exists()) devGoogleServices else "google-services.json"
val finalProdGoogleServices = if (file(prodGoogleServices).exists()) prodGoogleServices else "google-services.json"

println("Using Dev Google Services: $finalDevGoogleServices")
println("Using Prod Google Services: $finalProdGoogleServices")

tasks.register<Copy>("copyGoogleServicesDev") {
    val src = file(finalDevGoogleServices)
    if (src.exists()) {
        from(src)
        into("src/development")
        rename { "google-services.json" }
    }
}

tasks.register<Copy>("copyGoogleServicesProd") {
    val src = file(finalProdGoogleServices)
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
        targetSdk = 34 // Force targetSdk to 34 for emulator stability
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

tasks.configureEach {
    if (name.startsWith("process") && name.endsWith("GoogleServices")) {
        if (name.contains("Development")) {
            dependsOn("copyGoogleServicesDev")
        } else if (name.contains("Production")) {
            dependsOn("copyGoogleServicesProd")
        }
    }
}
