import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
// Only validation builds may explicitly opt into a debug-signed release.
val allowDebugReleaseSigning = providers.gradleProperty("allowDebugReleaseSigning")
    .map { it.toBoolean() }.getOrElse(false)

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } &&
        !keystorePropertiesFile.exists() && !allowDebugReleaseSigning) {
        throw GradleException(
            "Release signing is required. Configure android/key.properties with the " +
                "existing QuotaDash release key, or use the trusted GitHub Actions build. " +
                "Debug signing is only allowed with -PallowDebugReleaseSigning=true for validation."
        )
    }
}

android {
    namespace = "cn.imyxx.cliproxy_dash"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "cn.imyxx.cliproxy_dash"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (allowDebugReleaseSigning) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
