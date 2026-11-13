plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.chaquo.python")
}

android {
    namespace = "com.undcover.freedom.pyramid"
    compileSdk = 37

    defaultConfig {
        minSdk = 33
        ndk {
            abiFilters += setOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
}

chaquopy {
    defaultConfig {
        version = "3.11"
        val explicitBuildPython = (project.findProperty("buildPython") as String?)
            ?: System.getenv("CHAQUOPY_BUILD_PYTHON")
        val pathBuildPython = System.getenv("PATH")
            ?.split(File.pathSeparator)
            ?.asSequence()
            ?.map { File(it, "python3.11") }
            ?.firstOrNull { it.canExecute() }
            ?.absolutePath
        (explicitBuildPython ?: pathBuildPython)?.let { buildPython(it) }
        pip {
            options("-i", "https://repo.huaweicloud.com/repository/pypi/simple/")
            options("--extra-index-url", "https://chaquo.com/pypi-13.1")
            install("lxml")
            install("pyquery==2.0.2")
            install("requests")
            install(file("wheels/jsonpath-0.54-py3-none-any.whl").absolutePath)
            install("cachetools")
            install("pycryptodome")
            install("beautifulsoup4")
        }
    }
    sourceSets.getByName("main").setSrcDirs(listOf("src/python"))
}
