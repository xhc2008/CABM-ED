#!/usr/bin/env python3
"""
Cosine Calculator C++ 插件构建脚本
自动克隆 godot-cpp 并编译插件
"""

import os
import sys
import platform
import subprocess
import argparse
from pathlib import Path

class CosineCalculatorBuilder:
    def __init__(self, project_root=None):
        if project_root:
            self.project_root = Path(project_root)
            self.plugin_dir = self.project_root / "addons" / "cosine_calculator"
        else:
            self.plugin_dir = Path.cwd()
            self.project_root = self.plugin_dir.parent.parent

        self.godot_cpp_dir = self.plugin_dir / "godot-cpp"
        self.arch = self.detect_architecture()
        self.platform = self.detect_platform()

        self.arch_repo_map = {
            "x86_64": "https://github.com/godotengine/godot-cpp.git",
            "arm64": "https://github.com/godotengine/godot-cpp.git",
            "loongarch64": "https://github.com/lsyes/godot-cpp.git"
        }

    def detect_architecture(self):
        machine = platform.machine().lower()
        arch_map = {
            "x86_64": "x86_64",
            "amd64": "x86_64",
            "aarch64": "arm64",
            "arm64": "arm64",
            "loongarch64": "loongarch64"
        }
        arch = arch_map.get(machine, machine)
        print(f"🔍 检测到系统架构: {arch}")
        return arch

    def detect_platform(self):
        system = platform.system().lower()
        platform_map = {
            "windows": "windows",
            "darwin": "macos",
            "linux": "linux"
        }
        platform_name = platform_map.get(system, "linux")
        print(f"🔍 检测到操作系统: {platform_name}")
        return platform_name

    def check_sconstruct(self):
        sconstruct_file = self.plugin_dir / "SConstruct"
        if not sconstruct_file.exists():
            print("❌ 找不到 SConstruct 文件")
            print("💡 正在创建基本的 SConstruct 文件...")
            return self.create_sconstruct()
        print("✅ 找到 SConstruct 文件")
        return True

    def create_sconstruct(self):
        sconstruct_content = '''#!/usr/bin/env python
import os

env = Environment(tools=["default"])

env.Append(CPPPATH=[
    "src",
    "godot-cpp/include",
    "godot-cpp/include/core",
    "godot-cpp/include/classes",
    "godot-cpp/gen/include",
    "godot-cpp/gdextension"
])

env.Append(LIBPATH=["godot-cpp/bin"])

env.Append(LIBS=["godot-cpp"])

env.Append(CCFLAGS=["-fPIC", "-std=c++17"])
env.Append(LINKFLAGS=["-fPIC"])

sources = [
    "src/cosine_calculator.cpp",
    "src/register_types.cpp"
]

# 创建 bin 目录
if not os.path.exists("bin"):
    os.makedirs("bin")

# 创建共享库
library = env.SharedLibrary(
    target="bin/libcosine_calculator{0}".format(env.get("suffix", "")),
    source=sources,
)

print("编译成功！")
Default(library)
'''

        try:
            with open(self.plugin_dir / "SConstruct", "w", encoding="utf-8") as f:
                f.write(sconstruct_content)
            print("✅ SConstruct 文件创建成功")
            return True
        except Exception as e:
            print(f"❌ 创建 SConstruct 文件失败: {e}")
            return False

    def run_command(self, cmd, cwd=None, check=True):
        if cwd is None:
            cwd = self.plugin_dir

        print(f"🚀 执行: {' '.join(cmd)}")
        try:
            result = subprocess.run(cmd, cwd=cwd, check=check,
                                  capture_output=True, text=True)
            if result.stdout:
                print(result.stdout)
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ 命令执行失败: {e}")
            if e.stderr:
                print(f"错误输出: {e.stderr}")
            return False

    def check_prerequisites(self):
        print("\n" + "="*50)
        print("🔧 检查前置要求")
        print("="*50)

        checks = []

        python_version = platform.python_version()
        print(f"✅ Python 版本: {python_version}")
        checks.append(True)

        try:
            subprocess.run(["scons", "--version"], capture_output=True, check=True)
            print("✅ SCons 已安装")
            checks.append(True)
        except:
            print("❌ SCons 未安装，请运行: pip install scons")
            checks.append(False)

        compiler_checks = {
            "windows": ["cl", "g++"],
            "linux": ["g++", "clang++"],
            "macos": ["clang++", "g++"]
        }

        compiler_found = False
        for compiler in compiler_checks.get(self.platform, []):
            try:
                subprocess.run([compiler, "--version"] if compiler != "cl" else [compiler],
                             capture_output=True)
                print(f"✅ 找到编译器: {compiler}")
                compiler_found = True
                break
            except:
                continue

        if compiler_found:
            checks.append(True)
        else:
            print("❌ 未找到 C++ 编译器")
            checks.append(False)

        if not self.check_sconstruct():
            checks.append(False)

        return all(checks)

    def setup_godot_cpp(self):
        print("\n" + "="*50)
        print("📥 设置 godot-cpp")
        print("="*50)

        if self.arch not in self.arch_repo_map:
            print(f"❌ 不支持的架构: {self.arch}")
            return False

        repo_url = self.arch_repo_map[self.arch]
        print(f"📦 使用仓库: {repo_url}")

        if not self.godot_cpp_dir.exists():
            print("📥 克隆 godot-cpp...")
            if not self.run_command(["git", "clone", repo_url, "godot-cpp"]):
                return False
            print("✅ godot-cpp 克隆完成")
        else:
            print("📁 godot-cpp 目录已存在")

        required_dirs = ["include", "src"]
        for dir_name in required_dirs:
            dir_path = self.godot_cpp_dir / dir_name
            if not dir_path.exists():
                print(f"❌ 缺少必要的目录: {dir_name}")
                return False

        print("✅ godot-cpp 设置完成")
        return True

    def compile_plugin(self, target="template_debug"):
        print(f"\n" + "="*50)
        print(f"🔨 编译 Cosine Calculator 插件 ({target})")
        print("="*50)

        bin_dir = self.plugin_dir / "bin"
        bin_dir.mkdir(exist_ok=True)

        cmd = [
            "scons",
            f"target={target}",
            f"platform={self.platform}",
            f"arch={self.arch}"
        ]

        if not self.run_command(cmd):
            print(f"❌ 插件 {target} 编译失败")
            return False

        print(f"✅ 插件 {target} 编译成功")
        return True

    def verify_build(self, target="template_debug"):
        print(f"\n" + "="*50)
        print(f"🔍 验证构建结果 ({target})")
        print("="*50)

        bin_dir = self.plugin_dir / "bin"

        extensions = {
            "windows": ".dll",
            "linux": ".so",
            "macos": ".dylib"
        }
        ext = extensions.get(self.platform, ".so")

        expected_filename = f"libcosine_calculator.{self.platform}.{target}.{self.arch}{ext}"
        expected_file = bin_dir / expected_filename

        if expected_file.exists():
            print(f"✅ {expected_filename}")
            file_size = expected_file.stat().st_size
            print(f"📊 文件大小: {file_size / 1024 / 1024:.2f} MB")
            return True
        else:
            print(f"❌ 未找到预期文件: {expected_filename}")
            print("📁 bin 目录内容:")
            for f in bin_dir.iterdir():
                print(f"    {f.name}")
            return False

    def build(self, targets=None):
        if targets is None:
            targets = ["template_debug", "template_release"]

        print("="*60)
        print("🚀 Cosine Calculator C++ 插件自动化构建")
        print("="*60)
        print(f"💻 平台: {self.platform}")
        print(f"🏗️  架构: {self.arch}")
        print(f"📁 项目根目录: {self.project_root}")
        print(f"📁 插件目录: {self.plugin_dir}")
        print()

        if not self.check_prerequisites():
            return False

        if not self.setup_godot_cpp():
            return False

        all_success = True
        for target in targets:
            if not self.compile_plugin(target):
                all_success = False
                continue

            if not self.verify_build(target):
                all_success = False

        print("\n" + "="*60)
        if all_success:
            print("🎉 Cosine Calculator C++ 插件构建完成！")
        else:
            print("⚠️  构建完成，但部分目标验证失败")

        return all_success

def main():
    parser = argparse.ArgumentParser(description="Cosine Calculator C++ 插件构建脚本")
    parser.add_argument("--project-root", help="项目根目录路径")
    parser.add_argument("--target", choices=["debug", "release", "both"],
                       default="both", help="编译目标类型")

    args = parser.parse_args()

    try:
        builder = CosineCalculatorBuilder(args.project_root)

        if args.target == "debug":
            targets = ["template_debug"]
        elif args.target == "release":
            targets = ["template_release"]
        else:
            targets = ["template_debug", "template_release"]

        success = builder.build(targets)

        sys.exit(0 if success else 1)

    except Exception as e:
        print(f"❌ 构建过程出现错误: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
