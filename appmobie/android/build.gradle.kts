import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// --- Repos dùng chung cho tất cả modules
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- Đổi thư mục build (theo template Flutter)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


// ❗ KHÔNG cần khối `plugins { id("com.android.application") ... }` ở file project-level
//   (tránh xung đột version AGP). Phần đó để ở module app.
