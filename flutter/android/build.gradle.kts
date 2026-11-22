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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


subprojects {
    val configureAndroid = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            for (m in android.javaClass.methods) {
                if ((m.name == "compileSdkVersion" || m.name == "setCompileSdkVersion" || m.name == "setCompileSdk") && m.parameterTypes.size == 1) {
                    try {
                        if (m.parameterTypes[0] == java.lang.Integer.TYPE || m.parameterTypes[0] == java.lang.Integer::class.java) {
                            m.invoke(android, 36)
                        } else if (m.parameterTypes[0] == String::class.java) {
                            m.invoke(android, "android-36")
                        }
                    } catch (e: Exception) {}
                }
            }
        }
    }
    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

