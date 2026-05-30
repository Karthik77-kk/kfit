allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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

// Force plugin library subprojects to compile against SDK 36+.
// flutter_plugin_android_lifecycle (Flutter 3.44.0) requires compileSdk >= 36;
// older plugins (e.g. file_picker 8.x) default to android-34 and need this override.
// Only targets library plugins — the :app subproject uses flutter.compileSdkVersion directly.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)
                ?.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
