plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.assemblynativeactivity"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.assemblynativeactivity"
        minSdk = 24

        ndk {
            abiFilters += "x86_64"
            abiFilters += "arm64-v8a"
        }

        externalNativeBuild {
            cmake {
                cFlags += "-std=c17"
            }
        }
        targetSdk = 35
    }

    externalNativeBuild {
        cmake {
            path = file("CMakeLists.txt")
            version = "4.0.2"
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_24
        targetCompatibility = JavaVersion.VERSION_24
    }
    buildToolsVersion = "36.0.0"
    ndkVersion = "29.0.13113456 rc1"
}
