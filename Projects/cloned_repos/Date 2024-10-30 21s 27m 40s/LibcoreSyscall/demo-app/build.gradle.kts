@file:Suppress("UnstableApiUsage")

plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.example.test.app.syscalldemo"

    // a typical configuration for a test app
    // with a minSdk of 21, with kotlin and AndroidX, and some native code

    compileSdk = libs.versions.compileSdk.get().toInt()

    defaultConfig {
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        viewBinding = false
        buildConfig = true
        resValues = true
    }

    dependencies {
        compileOnly(libs.androidx.annotation)
        implementation(projects.coreSyscall)
    }

    // force Java 8
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

}
