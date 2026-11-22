#!/usr/bin/env python3
import os
import re
import sys

def configure_android():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "flutter", "android"))
    if not os.path.exists(base_dir):
        print(f"Directory {base_dir} does not exist.")
        sys.exit(1)

    print(f"Configuring Android build settings in: {base_dir}")

    # 1. Update android/app/build.gradle or android/app/build.gradle.kts
    app_gradle_groovy = os.path.join(base_dir, "app", "build.gradle")
    app_gradle_kts = os.path.join(base_dir, "app", "build.gradle.kts")

    if os.path.exists(app_gradle_groovy):
        print("Patching app/build.gradle...")
        with open(app_gradle_groovy, "r") as f:
            content = f.read()
        content = re.sub(r'compileSdkVersion\s+.*', 'compileSdkVersion 36', content)
        content = re.sub(r'compileSdk\s*=\s*.*', 'compileSdk = 36', content)
        content = re.sub(r'minSdkVersion\s+.*', 'minSdkVersion 21', content)
        content = re.sub(r'minSdk\s*=\s*.*', 'minSdk = 21', content)
        with open(app_gradle_groovy, "w") as f:
            f.write(content)

    if os.path.exists(app_gradle_kts):
        print("Patching app/build.gradle.kts...")
        with open(app_gradle_kts, "r") as f:
            content = f.read()
        content = re.sub(r'compileSdk\s*=\s*.*', 'compileSdk = 36', content)
        content = re.sub(r'minSdk\s*=\s*.*', 'minSdk = 21', content)
        with open(app_gradle_kts, "w") as f:
            f.write(content)

    # 2. Patch root build.gradle or build.gradle.kts
    root_gradle_groovy = os.path.join(base_dir, "build.gradle")
    root_gradle_kts = os.path.join(base_dir, "build.gradle.kts")

    groovy_injection = """
subprojects { project ->
    def configureAndroid = {
        if (project.hasProperty("android")) {
            try {
                project.android {
                    compileSdkVersion 36
                }
            } catch (Exception e) {}
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
"""

    kts_injection = """
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
"""

    if os.path.exists(root_gradle_groovy):
        print("Injecting into build.gradle...")
        with open(root_gradle_groovy, "r") as f:
            content = f.read()
        if "configureAndroid" not in content:
            with open(root_gradle_groovy, "a") as f:
                f.write("\n" + groovy_injection + "\n")

    if os.path.exists(root_gradle_kts):
        print("Injecting into build.gradle.kts...")
        with open(root_gradle_kts, "r") as f:
            content = f.read()
        if "configureAndroid" not in content:
            with open(root_gradle_kts, "a") as f:
                f.write("\n" + kts_injection + "\n")

    # 3. gradle.properties
    gradle_props = os.path.join(base_dir, "gradle.properties")
    props_to_add = [
        "android.useAndroidX=true",
        "android.enableJetifier=true",
        "android.suppressUnsupportedCompileSdk=36",
    ]
    existing_props = ""
    if os.path.exists(gradle_props):
        with open(gradle_props, "r") as f:
            existing_props = f.read()
    
    with open(gradle_props, "a") as f:
        for prop in props_to_add:
            key = prop.split("=")[0]
            if key not in existing_props:
                f.write(f"\n{prop}\n")

    print("Android build configuration successfully applied.")

if __name__ == "__main__":
    configure_android()
