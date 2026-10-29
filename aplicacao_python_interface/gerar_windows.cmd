@echo off
setlocal
pushd "%~dp0"
where py >nul 2>nul
if errorlevel 1 goto use_python
py -3 tools\build_windows.py
goto finished
:use_python
python tools\build_windows.py
:finished
if errorlevel 1 goto failed
echo.
echo Executavel gerado em dist\FabulaTEA.exe
popd
pause
exit /b 0
:failed
echo.
echo Nao foi possivel gerar. Confira os erros acima e a instalacao do Python.
popd
pause
exit /b 1
