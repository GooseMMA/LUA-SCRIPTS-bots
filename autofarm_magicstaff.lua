@echo off
echo ============================
echo Disable port forward 8080
echo ============================

netsh interface portproxy delete v4tov4 ^
listenaddress=0.0.0.0 listenport=8080

netsh advfirewall firewall delete rule ^
name="Open 8080"

echo.
echo DONE
pause