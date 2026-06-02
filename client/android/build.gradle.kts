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
    fun configureNamespace(proj: Project) {
        val android = proj.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android)
                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val manifestFile = proj.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val packageRegex = """package=["']([^"']+)["']""".toRegex()
                        val match = packageRegex.find(manifestFile.readText())
                        val packageName = match?.groups?.get(1)?.value
                        if (packageName != null) {
                            setNamespace.invoke(android, packageName)
                            println("Dynamically set namespace for project :${proj.name} to $packageName")
                        } else {
                            val defaultNamespace = "com.qlix.${proj.name.replace('-', '.').replace('_', '.')}"
                            setNamespace.invoke(android, defaultNamespace)
                            println("Dynamically set default namespace for project :${proj.name} to $defaultNamespace")
                        }
                    } else {
                        val defaultNamespace = "com.qlix.${proj.name.replace('-', '.').replace('_', '.')}"
                        setNamespace.invoke(android, defaultNamespace)
                        println("Dynamically set default namespace for project :${proj.name} to $defaultNamespace")
                    }
                }
            } catch (e: Exception) {
                // Method might not exist in older AGP versions, ignore
            }
        }
    }

    if (project.state.executed) {
        configureNamespace(project)
    } else {
        project.afterEvaluate {
            configureNamespace(project)
        }
    }
}


