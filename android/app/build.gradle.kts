import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 3.13.0 — CLÉ D'ENVOI (Google Play). Lue, dans cet ordre, dans les variables d'environnement (CI : secrets GitHub,
// voir .github/workflows/play.yml) puis dans android/key.properties (poste du développeur ; fichier JAMAIS commité,
// ignoré par android/.gitignore) :
//   ANDROID_KEYSTORE_PATH     / storeFile      chemin du fichier .jks (relatif à android/app ou absolu)
//   ANDROID_KEYSTORE_PASSWORD / storePassword  mot de passe du fichier
//   ANDROID_KEY_ALIAS         / keyAlias       alias de la clé
//   ANDROID_KEY_PASSWORD      / keyPassword    mot de passe de la clé
// Si l'un manque (ou si le fichier n'existe pas) : signature avec la clé DEBUG, comme avant la 3.13.0 (APK d'essai,
// CI sans secrets, builds locaux), avec un avertissement dans le journal ; Google Play refuse un tel paquet.
val proprietesCle = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

fun reglageCle(variable: String, propriete: String): String? =
    System.getenv(variable)?.takeIf { it.isNotBlank() } ?: proprietesCle.getProperty(propriete)?.takeIf { it.isNotBlank() }

val cheminCle = reglageCle("ANDROID_KEYSTORE_PATH", "storeFile")
val motDePasseFichierCle = reglageCle("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val aliasCle = reglageCle("ANDROID_KEY_ALIAS", "keyAlias")
val motDePasseCle = reglageCle("ANDROID_KEY_PASSWORD", "keyPassword")

// 3.13.1 — API CIBLE. Google Play exige targetSdk 36 (Android 16) depuis le 31/08/2026 ; Flutter 3.32.8 propose 35.
// SEUL le build Google Play passe à 36 (play.yml : flutter build appbundle --android-project-arg=pharmacienTargetSdk=36) ;
// les APK construits sur le PC du pharmacien (terminaux Sunmi) et par ci.yml restent en 35 : comportements d'Android 16
// (retour prédictif activé par défaut, bord à bord imposé, orientation sur grand écran) inchangés pour eux, et aucune
// plateforme « Android 16 » à installer sur le poste (docs/NOTE_VERSION_3.13.1.md). Même principe que Prestige
// Inventaire (propriété prestinvTargetSdk).
val apiCiblePlay: Int? = (findProperty("pharmacienTargetSdk") as String?)?.trim()?.toIntOrNull()

android {
    namespace = "com.example.prestige_app"
    compileSdk = apiCiblePlay ?: 35
    ndkVersion = flutter.ndkVersion

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.dici.prestige_app"
        minSdk = 21 // Recommandé
        targetSdk = apiCiblePlay ?: flutter.targetSdkVersion
        // Une seule source pour le numéro de version : `version:` de pubspec.yaml (nom + numéro de build).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    applicationVariants.all {
        val variant = this
        outputs.all {
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            outputImpl.outputFileName = "prestige-${variant.name}-${variant.versionName}.apk"
        }
    }

    val fichierCle = cheminCle?.let { file(it) }
    val cleEnvoiComplete = fichierCle != null && fichierCle.exists() &&
        motDePasseFichierCle != null && aliasCle != null && motDePasseCle != null

    signingConfigs {
        if (cleEnvoiComplete) {
            create("release") {
                storeFile = fichierCle
                storePassword = motDePasseFichierCle
                keyAlias = aliasCle
                keyPassword = motDePasseCle
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (cleEnvoiComplete) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "Prestige Pharmacien : clé d'envoi absente ou incomplète (ANDROID_KEYSTORE_* / android/key.properties) " +
                        "— paquet release signé avec la clé DEBUG (essais seulement, refusé par Google Play)."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}