plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.github.avbox.osc"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    defaultConfig {
        minSdk = 33
        consumerProguardFiles("proguard-rules.pro", "proguard-python.pro")
        multiDexEnabled = true
        ndk {
            abiFilters += setOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    packaging {
        jniLibs.useLegacyPackaging = true
        resources.excludes += setOf("META-INF/DEPENDENCIES", "META-INF/beans.xml")
    }

    sourceSets.getByName("main").java.directories += "src/python/java"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
        unitTests.isIncludeAndroidResources = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
    api(fileTree("libs") { include("*.jar") })
    // AGP 9 rejects local AAR runtime dependencies in a library because they
    // cannot be embedded into the resulting AAR. The final host app packages
    // this file directly; AVBox only needs it on the compile classpath here.
    compileOnly(files("libs/LibRtmp-Client-for-Android-v3.2.0.m2.aar"))

    implementation("org.nanohttpd:nanohttpd:2.3.1")
    implementation("org.fourthline.cling:cling-core:2.1.2")
    implementation("org.fourthline.cling:cling-support:2.1.2")
    compileOnly("javax.enterprise:cdi-api:2.0")
    compileOnly("javax.inject:javax.inject:1")
    compileOnly("javax.annotation:javax.annotation-api:1.3.2")
    compileOnly("javax.servlet:javax.servlet-api:4.0.1")
    implementation("androidx.appcompat:appcompat:1.8.0")
    implementation("androidx.media:media:1.8.0")
    implementation("com.squareup.okhttp3:okhttp:5.5.1")
    implementation("com.squareup.okhttp3:okhttp-dnsoverhttps:5.5.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    ksp("androidx.room3:room3-compiler:3.0.3")
    implementation("androidx.room3:room3-runtime:3.0.3")
    implementation("androidx.sqlite:sqlite-bundled:2.7.1")
    implementation("com.squareup.okio:okio:3.18.2")
    implementation("com.google.code.gson:gson:2.15.0")
    implementation("com.thoughtworks.xstream:xstream:1.4.21") {
        exclude(group = "xmlpull", module = "xmlpull")
        exclude(group = "xpp3", module = "xpp3_min")
    }
    implementation("com.tencent:mmkv:2.4.3")
    implementation("com.github.ctiao:DanmakuFlameMaster:0.9.25")

    implementation("androidx.media3:media3-exoplayer:1.11.1")
    implementation("androidx.media3:media3-exoplayer-dash:1.11.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.11.1")
    implementation("androidx.media3:media3-exoplayer-rtsp:1.11.1")
    implementation("androidx.media3:media3-datasource:1.11.1")
    implementation("androidx.media3:media3-datasource-rtmp:1.11.1")
    implementation("androidx.media3:media3-database:1.11.1")
    implementation("androidx.media3:media3-ui:1.11.1")
    implementation("org.jellyfin.media3:media3-ffmpeg-decoder:1.9.0+1")
    implementation("androidx.media3:media3-effect:1.11.1")
    implementation(project(":avboxQuickjs"))
    implementation(project(":avboxPyramid"))

    implementation("com.github.getActivity:XXPermissions:28.3")
    implementation("org.jsoup:jsoup:1.24.1")
    implementation("commons-io:commons-io:2.22.0")
    implementation("com.googlecode.juniversalchardet:juniversalchardet:1.0.3")
    implementation("com.google.zxing:core:3.5.4")
    implementation("com.github.thegrizzlylabs:sardine-android:0.9") {
        exclude(group = "xpp3", module = "xpp3")
    }

    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3:1.5.0-alpha29")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("io.coil-kt.coil3:coil-compose:3.6.3")
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.6.3")
    implementation("com.materialkolor:material-kolor:5.0.1")
    implementation(project(":avboxBackdrop"))
    implementation("io.github.kyant0:capsule:2.1.3")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")

    testImplementation("junit:junit:4.13.2")
    testImplementation(platform("androidx.compose:compose-bom:2026.09.00"))
    testImplementation("androidx.compose.ui:ui-test-junit4")
    testImplementation("androidx.compose.ui:ui-test-manifest")
    testImplementation("org.robolectric:robolectric:4.17")
    testImplementation("androidx.test:core:1.7.0")
    testImplementation("androidx.test.ext:junit:1.3.0")
}

configurations.configureEach {
    exclude(group = "io.antmedia", module = "rtmp-client")
}
