$ErrorActionPreference = 'Stop'

# Keep local Windows builds aligned with the Codemagic Gradle configuration.
@'
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def path = properties.getProperty("flutter.sdk")
        assert path != null, "flutter.sdk not set in local.properties"
        return path
    }()
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "9.3.1" apply false
    id "org.jetbrains.kotlin.android" version "2.4.20" apply false
}
include ":app"
'@ | Set-Content -Encoding UTF8 android/settings.gradle

@'
plugins {
    id "com.android.application"
    id "org.jetbrains.kotlin.android"
    id "dev.flutter.flutter-gradle-plugin"
}
android {
    namespace "com.serein.agent"
    compileSdk flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId "com.serein.agent"
        minSdk 23
        targetSdk flutter.targetSdkVersion
        versionCode 1
        versionName "1.0.0"
    }
}
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
flutter { source "../.." }
'@ | Set-Content -Encoding UTF8 android/app/build.gradle

@'
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
kotlin.code.style=official
android.builtInKotlin=false
android.newDsl=false
'@ | Set-Content -Encoding UTF8 android/gradle.properties

@'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-9.5.0-all.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
'@ | Set-Content -Encoding ASCII android/gradle/wrapper/gradle-wrapper.properties

@'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:name="${applicationName}" android:label="Serein Agent" android:icon="@drawable/ic_launcher" android:usesCleartextTraffic="false">
        <activity android:name=".MainActivity" android:exported="true" android:launchMode="singleTop" android:theme="@style/LaunchTheme" android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode" android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
        </activity>
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
</manifest>
'@ | Set-Content -Encoding UTF8 android/app/src/main/AndroidManifest.xml

New-Item -ItemType Directory -Force android/app/src/main/res/drawable | Out-Null
@'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="48dp" android:height="48dp" android:viewportWidth="48" android:viewportHeight="48">
    <path android:fillColor="#183A35" android:pathData="M0,0h48v48h-48z" />
    <path android:fillColor="#E4C98A" android:pathData="M6,34L18,17l7,9 6,-7 11,15z" />
    <path android:fillColor="#FFFFFF" android:pathData="M11,37h26v3h-26z" />
</vector>
'@ | Set-Content -Encoding UTF8 android/app/src/main/res/drawable/ic_launcher.xml

Get-ChildItem android/app/src/main/res -Directory -Recurse | Where-Object { $_.Name -like 'mipmap-*' } | ForEach-Object {
    $file = Join-Path $_.FullName 'ic_launcher.xml'
    if (Test-Path $file) { Remove-Item $file -Force }
}
Write-Host 'Android Gradle files restored; duplicate mipmap XML launcher resources removed.'
