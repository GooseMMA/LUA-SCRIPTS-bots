@echo off
echo ============================
echo Forward 8080 -> 127.0.0.1:8080
echo ============================

netsh interface portproxy add v4tov4 ^
listenaddress=0.0.0.0 listenport=8080 ^
connectaddress=127.0.0.1 connectport=8080

netsh advfirewall firewall add rule ^
name="Open 8080" dir=in action=allow protocol=TCP localport=8080

echo.
echo DONE
echo.
ipconfig | findstr /i "IPv4"
echo.
echo Теперь открой на телефоне:
echo http://IP_КОМПА:8080
pause