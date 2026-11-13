plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.github.avbox.quickjs.bridge"
    compileSdk = 37

    defaultConfig { minSdk = 33 }
    buildFeatures.buildConfig = false

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}

dependencies {
    api("wang.harlon.quickjs:wrapper-android:3.2.3")
    api("wang.harlon.quickjs:wrapper-java:3.2.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
}
