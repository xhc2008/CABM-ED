@echo off
chcp 65001 >nul

echo 停止 Python 进程...
taskkill /F /FI "WINDOWTITLE eq 后端 - FastAPI*" >nul 2>&1

echo 停止 Node 进程...
taskkill /F /FI "WINDOWTITLE eq 前端 - Vue*" >nul 2>&1

echo.
echo ====================================
echo 所有服务已停止
echo ====================================
echo.
echo ====================================
echo 正在启动氛围查看器...
echo ====================================
echo.

echo [1/2] 启动后端服务器...
start "后端 - FastAPI" cmd /k "cd backend && python app/main.py"
timeout /t 3 /nobreak >nul

echo [2/2] 启动前端开发服务器...
start "前端 - Vue" cmd /k "cd frontend && npm run dev"

echo.
echo ====================================
echo 启动完成！
echo 后端: http://localhost:8000
echo 前端: http://localhost:5000
echo ====================================
echo.
