plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.prestige_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    ndkVersion = "27.0.12077973" // Ajoutez ou modifiez cette ligne

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.prestige_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Ajouter ce bloc pour renommer les fichiers de sortie
    applicationVariants.all {
        val variant = this // 'this' fait référence à la variante (ex: release, debug)
        outputs.all {
            // 'this' ici fait référence à la sortie (l'APK)
            // Nous changeons le nom du fichier de sortie.
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            // Construire le nouveau nom, par exemple : prestige-release-1.0.0+1.apk
            outputImpl.outputFileName = "prestige-${variant.name}-${variant.versionName}.apk"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
