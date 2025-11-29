@echo off
chcp 65001 >nul
echo ========================================
echo Windows 导出后处理脚本
echo ========================================
echo.

REM 复制主文件
echo [1/3] 复制主文件...
mkdir "dist" >nul 2>&1
copy "CABM-ED.exe" "dist\"
copy "CABM-ED.pck" "dist\"

REM 复制插件文件
echo [2/3] 复制插件文件...
mkdir "dist\addons\cosine_calculator\bin" >nul 2>&1
mkdir "dist\addons\jieba\bin" >nul 2>&1
mkdir "dist\addons\jieba\config" >nul 2>&1

copy "addons\cosine_calculator\cosine_calculator.gdextension" "dist\addons\cosine_calculator\"
copy "addons\cosine_calculator\bin\libcosine_calculator.windows.template_debug.x86_64.dll" "dist\addons\cosine_calculator\bin\"

copy "addons\jieba\jieba.gdextension" "dist\addons\jieba\"
copy "addons\jieba\bin\libjieba.windows.template_debug.x86_64.dll" "dist\addons\jieba\bin\"
xcopy "addons\jieba\config" "dist\addons\jieba\config\" /E /I /Y

REM 打包
echo [3/3] 打包...
powershell -Command "Compress-Archive -Path 'dist\*' -DestinationPath 'CABM-ED-Windows.zip' -Force"

echo.
echo ========================================
echo 完成！分发包：CABM-ED-Windows.zip
echo ========================================
pause