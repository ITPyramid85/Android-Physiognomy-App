import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(keyPropertiesFile.inputStream())
}

android {
    namespace = "kr.co.taoist.gwansang"
    compileSdk = flutter.compileSdkVersion
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
        applicationId = "kr.co.taoist.gwansang"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // x86_64 라이브러리를 넣으면 LDPlayer가 arm64 대신 x86_64를 고르고,
        // libflutter / MediaPipe 가 빠져 실행되지 않는다. 에뮬레이터는 arm64 변환으로 실행한다.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file("${keyProperties["storeFile"]}")
            storePassword = keyProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // mediapipe_face_mesh 와 hand_landmarker 가 동일한 JNI 라이브러리를 중복 제공하므로
    // 첫 번째 발견된 버전을 사용하도록 지정 (두 패키지 모두 같은 0.10.x 버전 사용)
    packaging {
        jniLibs {
            // LDPlayer는 x86_64를 우선 선택한다. x86_64용 libflutter/MediaPipe가 없으므로
            // arm64-v8a만 남긴다. 에뮬레이터는 arm64 변환 계층으로 이 라이브러리를 실행한다.
            excludes += setOf(
                "lib/armeabi/**",
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
            )
            pickFirst("lib/arm64-v8a/libmediapipe_tasks_vision_jni.so")
        }
    }
}

flutter {
    source = "../.."
}

// image-generator 가 tasks-vision 클래스를 중복 포함한다.
// HandLandmarker 는 tasks-vision 에만 있으므로 image-generator 는 제외한다.
configurations.configureEach {
    exclude(group = "com.google.mediapipe", module = "tasks-vision-image-generator")
}
