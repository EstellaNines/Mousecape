"""Build the existing targets with CLT; the GUI fallback uses installed 1813 resources."""
import json
import pathlib
import plistlib
import shlex
import shutil
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
project = root / "Mousecape"
build = root / "build"
build.mkdir(exist_ok=True)
objects = json.loads(subprocess.check_output([
    "plutil", "-convert", "json", "-o", "-", str(project / "Mousecape.xcodeproj/project.pbxproj")
]))["objects"]
parents = {child: key for key, obj in objects.items() for child in obj.get("children", [])}


def resolve(key):
    parent = resolve(parents[key]) if key in parents else project
    return parent / objects[key].get("path", "")


include_dirs = {project / "mousecloak", project / "mousecloak/CGSInternal", project / "mousecloak/vendor"}
include_dirs.update(resolve(key).parent for key, obj in objects.items()
                    if obj.get("lastKnownFileType") == "sourcecode.c.h")


def compile_target(name, output, arch=None, framework_dir=None):
    target = next(obj for obj in objects.values()
                  if obj.get("isa") == "PBXNativeTarget" and obj["name"] == name)
    phase = next(objects[key] for key in target["buildPhases"]
                 if objects[key]["isa"] == "PBXSourcesBuildPhase")
    gui = name == "Mousecape"
    prefix = project / ("Mousecape/Mousecape-Prefix.pch" if gui else "mousecloak/mousecloak-Prefix.pch")
    flags = ["xcrun", "clang", "-fblocks", "-fobjc-weak", "-Wno-deprecated-declarations"]
    if arch:
        flags += ["-arch", arch]
    for path in sorted(include_dirs):
        flags += ["-I", str(path)]
    objdir = build / "objects" / name
    objdir.mkdir(parents=True, exist_ok=True)
    compiled = []
    for key in phase["files"]:
        entry = objects[key]
        source = resolve(entry["fileRef"])
        assert source.is_file(), source
        obj = objdir / (key + ".o")
        arc = entry.get("settings", {}).get("COMPILER_FLAGS", "-fobjc-arc" if gui else "-fno-objc-arc")
        subprocess.run(flags + shlex.split(arc) + ["-include", str(prefix), "-c", str(source), "-o", str(obj)], check=True)
        compiled.append(str(obj))
    link = ["xcrun", "clang"] + (["-arch", arch] if arch else []) + compiled
    for framework in ["Cocoa", "QuartzCore", "ApplicationServices", "SystemConfiguration", "ServiceManagement", "Security"]:
        link += ["-framework", framework]
    if framework_dir:
        link += ["-F", str(framework_dir), "-framework", "Sparkle", "-Wl,-rpath,@executable_path/../Frameworks"]
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(link + ["-o", str(output)], check=True)


if sys.argv[1] == "--cli":
    compile_target("mousecloak", build / "mousecloak")
    subprocess.run([str(build / "mousecloak"), "--help"], check=True, stdout=subprocess.DEVNULL)
    print(build / "mousecloak")
else:
    source_app = pathlib.Path("/Applications/Mousecape.app")
    source_info = plistlib.loads((source_app / "Contents/Info.plist").read_bytes())
    if source_info["CFBundleVersion"] != "1813":
        raise SystemExit("The resource fallback requires the original installed Mousecape 1813.")
    app = build / "Mousecape.app"
    if app.exists():
        shutil.rmtree(app)
    # shortcut: reuses compiled 1813 UI resources and Intel Sparkle; use full Xcode when UI resources change or for distribution.
    for directory in ["Resources", "Frameworks"]:
        shutil.copytree(source_app / "Contents" / directory, app / "Contents" / directory, symlinks=True)
    compile_target("Mousecape", app / "Contents/MacOS/Mousecape", "x86_64", app / "Contents/Frameworks")
    compile_target("mousecloak", app / "Contents/MacOS/mousecloak", "x86_64")
    helper_name = "com.alexzielenski.mousecloakhelper"
    helper = app / "Contents/Library/LoginItems" / (helper_name + ".app")
    compile_target(helper_name, helper / "Contents/MacOS" / helper_name, "x86_64")
    info = plistlib.loads((project / "Mousecape/Mousecape-Info.plist").read_bytes())
    info.update(CFBundleExecutable="Mousecape", CFBundleIdentifier="com.alexzielenski.Mousecape",
                CFBundleName="Mousecape", LSMinimumSystemVersion="10.13")
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
    helper_info = plistlib.loads((project / "mousecloakHelper/Info.plist").read_bytes())
    helper_info.update(CFBundleExecutable=helper_name, CFBundleIdentifier=helper_name,
                       CFBundleName=helper_name, LSMinimumSystemVersion="10.13")
    (helper / "Contents/Info.plist").write_bytes(plistlib.dumps(helper_info))
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True)
    subprocess.run([str(app / "Contents/MacOS/mousecloak"), "--help"], check=True, stdout=subprocess.DEVNULL)
    print(app)
