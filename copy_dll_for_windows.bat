@echo off
chcp 65001 >nul
echo ========================================
echo Windows 导出后处理脚本
echo ========================================
echo.

REM 检查 EXE 是否存在
if not exist "CABM-ED.exe" (
    echo [错误] 找不到 CABM-ED.exe！
    echo 请先在 Godot 中导出 Windows 版本。
    pause
    exit /b 1
)

REM 检查 gdextension 文件是否存在
if not exist "addons\cosine_calculator\cosine_calculator.gdextension" (
    echo [错误] 找不到 cosine_calculator.gdextension 文件！
    pause
    exit /b 1
)

REM 检查 DLL 是否存在
if not exist "addons\cosine_calculator\bin\libcosine_calculator.windows.template_release.x86_64.dll" (
    echo [错误] 找不到 Release DLL 文件！
    echo 请先编译 Release 版本：
    echo   cd addons\cosine_calculator
    echo   scons platform=windows target=template_release
    pause
    exit /b 1
)

REM 清理旧的分发文件夹
if exist "dist" (
    echo [0/5] 清理旧的分发文件夹...
    rmdir /s /q "dist" >nul 2>&1
)

REM 创建分发文件夹结构
echo [1/5] 创建目录结构...
mkdir "dist\addons\cosine_calculator\bin" >nul 2>&1
echo ✓ 目录结构创建成功

REM 复制主文件
echo [2/5] 复制主文件...
copy /Y "CABM-ED.exe" "dist\" >nul
if exist "CABM-ED.pck" (
    copy /Y "CABM-ED.pck" "dist\" >nul
    echo ✓ 已复制 exe 和 pck 文件
) else (
    echo ✓ 已复制 exe 文件（pck 已嵌入）
)

REM 复制 gdextension 配置文件
echo [3/5] 复制 GDExtension 配置...
copy /Y "addons\cosine_calculator\cosine_calculator.gdextension" "dist\addons\cosine_calculator\" >nul
if %errorlevel% neq 0 (
    echo [错误] 复制 gdextension 文件失败！
    pause
    exit /b 1
)
echo ✓ GDExtension 配置复制成功

REM 复制 DLL
echo [4/5] 复制 C++ 插件 DLL...
copy /Y "addons\cosine_calculator\bin\libcosine_calculator.windows.template_debug.x86_64.dll" "dist\addons\cosine_calculator\bin\" >nul
if %errorlevel% neq 0 (
    echo [错误] 复制 DLL 失败！
    pause
    exit /b 1
)
echo ✓ C++ 插件 DLL 复制成功

REM 打包成 ZIP
echo [5/5] 打包成 ZIP...
if exist "CABM-ED-Windows.zip" del /q "CABM-ED-Windows.zip" >nul 2>&1

powershell -Command "Compress-Archive -Path 'dist\*' -DestinationPath 'CABM-ED-Windows.zip' -Force" >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] ZIP 打包失败，但文件已复制到 dist 文件夹
    echo 你可以手动压缩 dist 文件夹
) else (
    echo ✓ ZIP 打包成功：CABM-ED-Windows.zip
)

echo.
echo ========================================
echo 完成！分发包结构：
echo   dist\
echo   ├── CABM-ED.exe
if exist "CABM-ED.pck" (
    echo   ├── CABM-ED.pck
)
echo   └── addons\
echo       └── cosine_calculator\
echo           ├── cosine_calculator.gdextension
echo           └── bin\
echo               └── libcosine_calculator.windows.template_release.x86_64.dll
echo.
if exist "CABM-ED-Windows.zip" (
    echo ✓ ZIP 文件：CABM-ED-Windows.zip
    echo.
    echo 可以直接分发 ZIP 文件！
) else (
    echo 请手动压缩 dist 文件夹或分发整个 dist 文件夹！
)
echo ========================================
pause
