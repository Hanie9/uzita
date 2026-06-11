allprojects {
  repositories {
    val offlineRepo = rootProject.file("offline-maven-repo")
    if (offlineRepo.exists()) {
      maven(url = offlineRepo.toURI())
    }
    maven {
      url = uri("https://maven.neshan.org/artifactory/public-maven")
      content {
        includeGroup("neshan-android-sdk")
      }
    }
    maven(url = "https://maven.myket.ir")
    maven(url = "https://maven.tarazerp.ir")
    maven(url = "https://maven.aliyun.com/repository/google")
    maven(url = "https://maven.aliyun.com/repository/gradle-plugin")
    maven(url = "https://maven.aliyun.com/repository/public")
        maven(url = "https://maven.neshan.org/artifactory/public-maven")
        google()
        mavenCentral()
  }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
