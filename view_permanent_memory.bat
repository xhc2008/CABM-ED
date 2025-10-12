@echo off
chcp 65001 >nul
echo 正在查看永久记忆存储...
echo.
set STORAGE_PATH=%APPDATA%\Godot\app_userdata\CABM-ED\ai_storage\permanent_memory.jsonl

if exist "%STORAGE_PATH%" (
    echo 文件位置: %STORAGE_PATH%
    echo.
    echo === 最近 10 条记忆 ===
    echo.
    powershell -Command "Get-Content '%STORAGE_PATH%' | Select-Object -Last 10 | ForEach-Object { $obj = $_ | ConvertFrom-Json; Write-Host \"[$($obj.timestamp)] $($obj.content)\" }"
    echo.
    echo === 统计信息 ===
    powershell -Command "$count = (Get-Content '%STORAGE_PATH%' | Measure-Object -Line).Lines; Write-Host \"总记忆条数: $count\""
) else (
    echo 永久存储文件不存在: %STORAGE_PATH%
    echo.
    echo 请先进行对话，系统会自动创建此文件。
)
echo.
pause
