@echo off
setlocal
set APP_HOME=%~dp0
python "%APP_HOME%scripts\bootstrap_gradle.py"
if errorlevel 1 exit /b 1
if defined JAVA_HOME (set "JAVA_CMD=%JAVA_HOME%\bin\java.exe") else (set "JAVA_CMD=java.exe")
"%JAVA_CMD%" -Dorg.gradle.appname=gradlew -classpath "%APP_HOME%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
exit /b %ERRORLEVEL%
