group = "com.rees46.rees46_flutter_sdk"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io")
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io")
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.rees46.rees46_flutter_sdk"

    compileSdk = 36

    flavorDimensions += "brand"

    productFlavors {
        create("rees46") {
            dimension = "brand"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        // The REES46 Android library is flavored on a `default` dimension
        // (rees46 / personaclick); this plugin has no such dimension. Tell Gradle
        // which flavor to consume. A no-op for the single-variant JitPack artifact;
        // required when the SDK is consumed from source (local `includeBuild`).
        missingDimensionStrategy("default", "rees46")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    // REES46 Android SDK.
    val rees46AndroidSdkVersion = "v2.38.0"
    add("rees46Implementation", "com.github.rees46:android-sdk:$rees46AndroidSdkVersion")

    // Used directly by the push presenter (NotificationCompat / ContextCompat). The native SDK
    // depends on the same version but as `implementation`, so it is not exposed transitively.
    implementation("androidx.core:core-ktx:1.13.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
