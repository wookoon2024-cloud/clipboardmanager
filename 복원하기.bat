@echo off
echo [복원 중] ClipboardManager.exe 파일로 복원하고 있습니다...
certutil -decode ClipboardManager_Base64.txt ClipboardManager.exe
echo [완료] 복원이 완료되었습니다!
pause