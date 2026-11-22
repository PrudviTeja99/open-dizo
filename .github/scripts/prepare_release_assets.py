#!/usr/bin/env python3
import os
import re
import sys
import shutil
import hashlib

def get_version():
    ref = os.environ.get("GITHUB_REF", "")
    input_ver = os.environ.get("INPUT_VERSION", "")
    ver = ""
    if input_ver and input_ver.strip():
        ver = input_ver.strip().lstrip("v")
    elif ref.startswith("refs/tags/"):
        ver = ref.replace("refs/tags/", "").lstrip("v")
    else:
        pubspec_path = os.path.join(os.path.dirname(__file__), "..", "..", "flutter", "pubspec.yaml")
        if os.path.exists(pubspec_path):
            with open(pubspec_path, "r") as f:
                for line in f:
                    m = re.match(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", line.strip())
                    if m:
                        ver = m.group(1)
                        break
    if not ver:
        ver = "1.0.0"
    return ver

def prepare_assets():
    version = get_version()
    tag = f"v{version}"
    print(f"Determined release version: {version} (tag: {tag})")

    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    input_dir = os.path.join(root_dir, "release_assets")
    output_dir = os.path.join(root_dir, "final_assets")
    os.makedirs(output_dir, exist_ok=True)

    # 1. Find and copy APK
    apk_candidates = []
    if os.path.exists(input_dir):
        for root, _, files in os.walk(input_dir):
            for f in files:
                if f.endswith(".apk"):
                    apk_candidates.append(os.path.join(root, f))

    if apk_candidates:
        dest_apk = os.path.join(output_dir, f"dizo-watch-sync-{version}.apk")
        shutil.copy2(apk_candidates[0], dest_apk)
        print(f"Prepared APK: {dest_apk}")
    else:
        print("Warning: No APK file found in release_assets.")

    # 2. Find and copy Linux AppImage
    appimage_candidates = []
    if os.path.exists(input_dir):
        for root, _, files in os.walk(input_dir):
            for f in files:
                if f.endswith(".AppImage"):
                    appimage_candidates.append(os.path.join(root, f))

    if appimage_candidates:
        dest_appimage = os.path.join(output_dir, f"dizo-watch-sync-{version}-x86_64.AppImage")
        shutil.copy2(appimage_candidates[0], dest_appimage)
        os.chmod(dest_appimage, 0o755)
        print(f"Prepared AppImage: {dest_appimage}")
    else:
        print("Warning: No AppImage file found in release_assets.")

    # 3. Generate SHA256SUMS.txt
    sums_file = os.path.join(output_dir, "SHA256SUMS.txt")
    with open(sums_file, "w") as out_f:
        for filename in sorted(os.listdir(output_dir)):
            if filename == "SHA256SUMS.txt":
                continue
            file_path = os.path.join(output_dir, filename)
            if os.path.isfile(file_path):
                hasher = hashlib.sha256()
                with open(file_path, "rb") as f:
                    while chunk := f.read(65536):
                        hasher.update(chunk)
                digest = hasher.hexdigest()
                out_f.write(f"{digest}  {filename}\n")
                print(f"SHA256: {digest}  {filename}")

    # 4. Set GitHub Actions outputs
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output and os.path.exists(github_output):
        with open(github_output, "a") as f:
            f.write(f"version={version}\n")
            f.write(f"tag={tag}\n")

if __name__ == "__main__":
    prepare_assets()
