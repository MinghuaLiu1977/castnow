plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.castnow.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.castnow.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24//flutter.minSdkVersion
        targetSdk = 34//flutter.targetSdkVersion
        versionCode = 1//flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // 自定义 APK 输出文件名逻辑
    applicationVariants.all {
        val variant = this
        variant.outputs.map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                val versionName = project.findProperty("flutter.versionName") as? String 
                    ?: variant.versionName 
                    ?: "1.0.0"
                
                val buildType = variant.buildType.name
                
                val newName = if (buildType == "release") {
                    "CastNow_v${versionName}.apk"
                } else {
                    "CastNow_v${versionName}_${buildType}.apk"
                }
                
                output.outputFileName = newName
            }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 修复 Kotlin 和 Android 核心库缺失的关键依赖
    implementation(kotlin("stdlib"))
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
