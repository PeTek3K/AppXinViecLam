plugins {
    id("com.android.application")
    kotlin("android")
    // Plugin Flutter phải sau Android & Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services cho Firebase
     id("com.google.gms.google-services") 
}

android {
    namespace = "com.example.appmobie"

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
        // Phải trùng với package đã đăng ký trong Firebase (Android package name)
        applicationId = "com.example.appmobie"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Ký debug tạm thời để chạy nhanh
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // để trống nếu chưa có lib nào đặc biệt
}

apply(plugin = "com.google.gms.google-services")
