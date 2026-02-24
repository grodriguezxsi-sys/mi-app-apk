plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.myapp"
    compileSdk = 36 // Versión actualizada para 2026
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // IMPORTANTE: Este ID debe coincidir con el de tu consola de Firebase
        applicationId = "com.example.myapp"
        
        // CONFIGURACIÓN PARA FIREBASE Y GPS:
        minSdk = flutter.minSdkVersion    // Requerido para estabilidad de Firebase y Geolocator
        targetSdk = 36 // Requerido por Google Play en 2026
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ACTIVACIÓN DE MULTIDEX: Necesario para apps con muchas librerías (Firebase)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Usamos la firma de debug para esta prueba rápida del APK
            signingConfig = signingConfigs.getByName("debug")
            
            // Optimizaciones de salida
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // --- BLOQUE AGREGADO PARA CAMBIAR EL NOMBRE DEL APK ---
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.ApkVariantOutputImpl
            output.outputFileName = "XSIM-v${variant.versionName}.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Librería necesaria para soportar multiDexEnabled
    implementation("androidx.multidex:multidex:2.0.1")
}
