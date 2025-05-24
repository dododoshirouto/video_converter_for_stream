:
@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM === User Settings ============================
set "TARGET_WIDTH=1280"
set "TARGET_HEIGHT=720"
set "TARGET_FPS=30"
set "VIDEO_BITRATE=2000k"
set "AUDIO_BITRATE=320k"
set "AUDIO_SAMPLE_RATE=48000"
set "LOUDNORM_I=-14"
set "LOUDNORM_TP=-1.0"
set "LOUDNORM_LRA=11"
set "PIXEL_FORMAT=yuv420p"
REM =====================================================

REM === find ffmpeg ===
call :find_ffmpeg
if not defined ffmpeg (
    echo [ERROR] ffmpeg not found!
    start https://ffmpeg.org/download.html
    winget install ffmpeg -h --no-upgrade --authentication-mode silent --force
)

REM === Detect GPU Encoder ===
call :detect_gpu_encoder

REM === Convert Main Process ===
for %%F in (%*) do (
    call :process_video "%%~F"
)

pause
exit /b

:find_ffmpeg
where ffmpeg >nul 2>nul
if errorlevel 1 (
    if exist "%~dp0ffmpeg.exe" (
        set "ffmpeg=%~dp0ffmpeg.exe"
    )
) else (
    set "ffmpeg=ffmpeg"
)
exit /b

:detect_gpu_encoder
%ffmpeg% -hide_banner -encoders | findstr /i "h264_nvenc" >nul
if %errorlevel%==0 (
    set "encoder=h264_nvenc"
    set "enc_extra=-rc cbr -minrate %VIDEO_BITRATE% -maxrate %VIDEO_BITRATE% -bufsize 5000k"
    set "enc_preset=p3"
    echo [INFO] use NVIDIA GPU

    :: find nvenc
    where ffmpeg >nul 2>nul
    if errorlevel 1 (
        winget install -e --id Nvidia.CUDA -h --no-upgrade --authentication-mode silent --force
    )

    exit /b
)
%ffmpeg% -hide_banner -encoders | findstr /i "h264_qsv" >nul
if %errorlevel%==0 (
    set "encoder=h264_qsv"
    set "enc_extra=-look_ahead 0 -g 250"
    set "enc_preset=7"
    echo [INFO] use Intel GPU
    exit /b
)
%ffmpeg% -hide_banner -encoders | findstr /i "h264_amf" >nul
if %errorlevel%==0 (
    set "encoder=h264_amf"
    set "enc_extra="
    set "enc_preset=balanced"
    echo [INFO] use AMD GPU
    exit /b
)

set "encoder=libx264"
set "enc_extra="
set "enc_preset=medium"
echo [INFO] use libx264 (GPU encoder not fond)
exit /b

:process_video
set "input=%~1"
set "filename=%~n1"
set "output=%~dp1%filename%_%TARGET_HEIGHT%"
set "tempjson=tmp_%filename%.json"
set "bad_data="

echo === Check audio levels: %input% ===
"%ffmpeg%" -i "%input%" -af "loudnorm=I=%LOUDNORM_I%:TP=%LOUDNORM_TP%:LRA=%LOUDNORM_LRA%:print_format=json" -f null - 2>"%tempjson%"

for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_i" "%tempjson%"') do set input_i=%%b
for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_tp" "%tempjson%"') do set input_tp=%%b
for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_lra" "%tempjson%"') do set input_lra=%%b
for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_thresh" "%tempjson%"') do set input_thresh=%%b
for /f "tokens=1,* delims=:" %%a in ('findstr /C:"target_offset" "%tempjson%"') do set offset=%%b

REM Remove faild datas
for %%V in (input_i input_tp input_lra input_thresh offset) do (
    set "val=!%%V!"
    set "val=!val: =!"
    set "val=!val:"=!"
    set "val=!val:,=!"
    call set "%%V=%%val%%"
)

REM inf check
echo !input_i!   | findstr /i "inf" >nul && set bad_data=1
echo !input_tp!  | findstr /i "inf" >nul && set bad_data=1
echo !offset!    | findstr /i "inf" >nul && set bad_data=1

if defined bad_data (
    echo *** Value error : Use 1pass mode ***
    "%ffmpeg%" -i "%input%" ^
        -vf "fps=%TARGET_FPS%,scale='if(gt(a,1),%TARGET_WIDTH%,-2)':'if(gt(a,1),-2,%TARGET_HEIGHT%)'" ^
        -c:v %encoder% -pix_fmt %PIXEL_FORMAT% -preset %enc_preset% %enc_extra% -b:v %VIDEO_BITRATE% ^
        -af "loudnorm=I=%LOUDNORM_I%:TP=%LOUDNORM_TP%:LRA=%LOUDNORM_LRA%" ^
        -ar %AUDIO_SAMPLE_RATE% -c:a aac -b:a %AUDIO_BITRATE% ^
        "%output%.mp4"
) else (
    echo === 2pass normalize : %input% ===
    "%ffmpeg%" -i "%input%" ^
        -vf "fps=%TARGET_FPS%,scale='if(gt(a,1),%TARGET_WIDTH%,-2)':'if(gt(a,1),-2,%TARGET_HEIGHT%)'" ^
        -c:v %encoder% -pix_fmt %PIXEL_FORMAT% -preset %enc_preset% %enc_extra% -b:v %VIDEO_BITRATE% ^
        -af "loudnorm=I=%LOUDNORM_I%:TP=%LOUDNORM_TP%:LRA=%LOUDNORM_LRA%:measured_I=!input_i!:measured_TP=!input_tp!:measured_LRA=!input_lra!:measured_thresh=!input_thresh!:offset=!offset!" ^
        -ar %AUDIO_SAMPLE_RATE% -c:a aac -b:a %AUDIO_BITRATE% ^
        "%output%_-14LUFS.mp4"
)

del "%tempjson%"
echo === Complete : %output% ===
echo.
exit /b
