@echo off
chcp 65001 >nul
echo ========================================
echo Android 编译脚本
echo ========================================
echo.

REM 检查 NDK 环境变量
if "%ANDROID_NDK_ROOT%"=="" (
    echo [错误] 未设置 ANDROID_NDK_ROOT 环境变量！
    echo.
    echo 请设置 NDK 路径，例如：
    echo   set ANDROID_NDK_ROOT=C:\android-ndk-r27d
    echo.
    echo 或者：
    echo   set ANDROID_NDK_ROOT=C:\Users\你的用户名\AppData\Local\Android\Sdk\ndk\27.3.13750724
    echo.
    pause
    exit /b 1
)

echo NDK 路径: %ANDROID_NDK_ROOT%
echo.

REM 检查 NDK 是否存在
if not exist "%ANDROID_NDK_ROOT%\ndk-build.cmd" (
    echo [警告] NDK 路径可能不正确，找不到 ndk-build.cmd
    echo 继续尝试编译...
    echo.
)

REM 进入插件目录
cd addons\cosine_calculator

echo [1/2] 编译 ARM64 Debug 版本...
scons platform=android target=template_debug arch=arm64
if %errorlevel% neq 0 (
    echo [错误] ARM64 Debug 编译失败！
    cd ..\..
    pause
    exit /b 1
)
echo ✓ ARM64 Debug 编译成功

echo.
echo [2/2] 编译 ARM64 Release 版本...
scons platform=android target=template_release arch=arm64
if %errorlevel% neq 0 (
    echo [错误] ARM64 Release 编译失败！
    cd ..\..
    pause
    exit /b 1
)
echo ✓ ARM64 Release 编译成功

cd ..\..

echo.
echo ========================================
echo 编译完成！
echo.
echo 生成的文件：
dir /b addons\cosine_calculator\bin\*.android.*.so 2>nul
echo.
echo 现在可以在 Godot 中导出 Android APK 了。
echo ========================================
pause
