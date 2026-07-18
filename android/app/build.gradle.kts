plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin must be applied last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.trudido.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.trudido.app"
        minSdk = 24  // Required for video_player and other media features
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "store"
    productFlavors {
        create("playstore") {
            dimension = "store"
            // PlayStore build - donations hidden via Dart define
        }
        create("fdroid") {
            dimension = "store"
            // FDroid build - donations enabled via --dart-define=IS_FDROID=true
        }
    }

    // Load signing credentials from local key.properties (gitignored).
    // If you clone this repo, create android/key.properties:
    //   storePassword=yourpassword
    //   keyPassword=yourpassword
    //   keyAlias=youralias
    //   storeFile=your-keystore.jks
    val keystoreProps = mutableMapOf<String, String>()
    val keystorePropsFile = rootProject.file("../key.properties")
    if (keystorePropsFile.exists()) {
        keystorePropsFile.readLines().forEach { line ->
            val parts = line.split("=", limit = 2)
            if (parts.size == 2) {
                keystoreProps[parts[0].trim()] = parts[1].trim()
            }
        }
    }

    signingConfigs {
        create("release") {
            val storeFileProp = keystoreProps["storeFile"]
            if (storeFileProp != null) {
                storeFile = rootProject.file(storeFileProp)
                storePassword = keystoreProps["storePassword"]
                keyAlias = keystoreProps["keyAlias"]
                keyPassword = keystoreProps["keyPassword"]
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Only use signing config if keystore exists and is configured
            val releaseSigningConfig = signingConfigs.getByName("release")
            if (releaseSigningConfig.storeFile?.exists() == true) {
                signingConfig = releaseSigningConfig
            } else {
                // Fall back to debug signing so release builds work without a
                // production keystore (useful for testing optimized builds).
                signingConfig = signingConfigs.getByName("debug")
            }
            // Enable code shrinking, obfuscation, and optimization (standard for production)
            isMinifyEnabled = true
            // Remove unused resources to reduce APK size
            isShrinkResources = true
            // Apply ProGuard rules for proper minification
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("com.google.guava:guava:31.1-android")
}
