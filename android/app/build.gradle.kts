import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import org.jetbrains.kotlin.konan.properties.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val agpMajorVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .substringBefore('.')
    .toInt()
val builtInKotlinProperty = providers.gradleProperty("android.builtInKotlin").orNull
val isBuiltInKotlinEnabled = agpMajorVersion >= 9 &&
        (builtInKotlinProperty == null || builtInKotlinProperty.toBoolean())
if (!isBuiltInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "com.aritxonly.hyperpiliplus"
    compileSdk = 37
    // Keep every native Flutter plugin on the installed, newest compatible NDK.
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.aritxonly.hyperpiliplus"
        // Deadliner's original soft-glass bar uses miuix-blur, whose Android
        // RuntimeShader path has an API 33 baseline.
        minSdk = maxOf(flutter.minSdkVersion, 33)
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packagingOptions {
        jniLibs.useLegacyPackaging = true
        resources.excludes += setOf("META-INF/DEPENDENCIES", "META-INF/beans.xml")
    }

    val keyProperties = Properties().also {
        val properties = rootProject.file("key.properties")
        if (properties.exists())
            it.load(properties.inputStream())
    }

    val signingStore = System.getenv("ANDROID_SIGNING_STORE_FILE")
        ?: keyProperties.getProperty("storeFile")
    if (project.hasProperty("requireReleaseSigning")) {
        require(!signingStore.isNullOrBlank()) { "Release signing keystore is required" }
        for ((env, property) in listOf(
            "KEYSTORE_PASSWORD" to "storePassword",
            "KEY_ALIAS" to "keyAlias",
            "KEY_PASSWORD" to "keyPassword",
        )) {
            require(!(System.getenv(env) ?: keyProperties.getProperty(property)).isNullOrBlank()) {
                "Release signing field $property is required"
            }
        }
    }
    val config = signingStore?.let {
        signingConfigs.create("release") {
            storeFile = file(it)
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: keyProperties.getProperty("storePassword")
            keyAlias = System.getenv("KEY_ALIAS") ?: keyProperties.getProperty("keyAlias")
            keyPassword = System.getenv("KEY_PASSWORD") ?: keyProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
        if (project.hasProperty("dev")) {
            resValues = true
        }
    }

    buildTypes {
        all {
            signingConfig = config ?: signingConfigs["debug"]
        }
        release {
            if (project.hasProperty("dev")) {
                applicationIdSuffix = ".dev"
                resValue(
                    type = "string",
                    name = "app_name",
                    value = "PiliPlus dev",
                )
            }
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            (output as ApkVariantOutputImpl).versionCodeOverride = flutter.versionCode
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
    implementation(
        files("../../third_party/avbox/app/libs/LibRtmp-Client-for-Android-v3.2.0.m2.aar"),
    )
    implementation(project(":avbox"))
    implementation("androidx.compose.material3:material3:1.5.0-alpha22")
    implementation("top.yukonga.miuix.kmp:miuix-ui-android:0.9.4")
    implementation("top.yukonga.miuix.kmp:miuix-blur-android:0.9.4")
    implementation("top.yukonga.miuix.kmp:miuix-icons-android:0.9.4")
    implementation("io.github.kyant0:shapes:1.2.0")
}
