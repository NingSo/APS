import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.compose.compiler)
}
android {
  namespace = "com.ningso.aps"
  compileSdk = libs.versions.compileSdk.get().toInt()
  defaultConfig {
    applicationId = "com.ningso.aps"
    minSdk = libs.versions.minSdk.get().toInt()
    targetSdk = libs.versions.targetSdk.get().toInt()
    versionCode = 1
    versionName = "0.1.0"
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
  }
  buildTypes {
    debug { applicationIdSuffix = ".debug"; versionNameSuffix = "-debug" }
    release { isMinifyEnabled = false }
  }
  buildFeatures { compose = true; buildConfig = true }
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
  }
  packaging.resources.excludes += setOf("META-INF/INDEX.LIST", "META-INF/io.netty.versions.properties")
  testOptions { animationsDisabled = true }
}
kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_21 } }
configurations.configureEach { exclude(group = "androidx.profileinstaller", module = "profileinstaller") }
dependencies {
  implementation(project(":proxycore"))
  implementation(libs.androidx.core)
  implementation(libs.androidx.activity.compose)
  implementation(libs.androidx.lifecycle.compose)
  implementation(libs.androidx.lifecycle.viewmodel)
  implementation(libs.compose.foundation)
  implementation(libs.compose.material3)
  implementation(libs.compose.ui)
  implementation(libs.kotlinx.coroutines.android)
  implementation(libs.zxing.core)
  testImplementation(libs.junit)
  testImplementation(libs.kotlinx.coroutines.test)
  androidTestImplementation(libs.compose.test)
  androidTestImplementation("androidx.test.ext:junit:1.3.0")
  androidTestImplementation("androidx.test:runner:1.7.0")
  debugImplementation(libs.compose.tooling)
  debugImplementation(libs.compose.test.manifest)
}
