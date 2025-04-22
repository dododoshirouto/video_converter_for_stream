@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM === ffmpeg チェック ===
where ffmpeg >nul 2>nul
if errorlevel 1 (
    if exist "%~dp0ffmpeg.exe" (
        set "ffmpeg=%~dp0ffmpeg.exe"
    ) else (
        echo [エラー] ffmpeg が見つかりません！
        start https://ffmpeg.org/download.html
        pause
        exit /b
    )
) else (
    set "ffmpeg=ffmpeg"
)

REM === GPU自動判定（優先：NVENC → QSV → AMF → CPU） ===
%ffmpeg% -hide_banner -encoders | findstr /i "h264_nvenc" >nul
if %errorlevel%==0 (
    set "encoder=h264_nvenc"
    set "enc_extra=-rc cbr -minrate 2500k -maxrate 2500k -bufsize 5000k"
    set "enc_preset=p3"
    echo NVIDIA GPU を検出、NVENC を使用します。
) else (
    %ffmpeg% -hide_banner -encoders | findstr /i "h264_qsv" >nul
    if %errorlevel%==0 (
        set "encoder=h264_qsv"
        set "enc_extra=-look_ahead 0 -g 250"
        set "enc_preset=7"
        echo Intel GPU を検出、QSV を使用します。
    ) else (
        %ffmpeg% -hide_banner -encoders | findstr /i "h264_amf" >nul
        if %errorlevel%==0 (
            set "encoder=h264_amf"
            set "enc_extra="
            set "enc_preset=balanced"
            echo AMD GPU を検出、AMF を使用します。
        ) else (
            set "encoder=libx264"
            set "enc_extra="
            set "enc_preset=medium"
            echo GPU が検出できなかったため、CPU（libx264）で変換します。
        )
    )
)

REM === メイン処理 ===
for %%F in (%*) do (
    set "input=%%~F"
    set "filename=%%~nF"
    set "output=%%~dpF!filename!_1080p_-14LUFS.mp4"
    set "tempjson=tmp_!filename!.json"
    set "bad_data="

    echo === 測定中: !input! ===

    "!ffmpeg!" -i "!input!" -af "loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json" -f null - 2>"!tempjson!"

    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_i" "!tempjson!"') do set input_i=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_tp" "!tempjson!"') do set input_tp=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_lra" "!tempjson!"') do set input_lra=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_thresh" "!tempjson!"') do set input_thresh=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"target_offset" "!tempjson!"') do set offset=%%b

    REM 空白除去
    set "input_i=!input_i: =!"
    set "input_tp=!input_tp: =!"
    set "input_lra=!input_lra: =!"
    set "input_thresh=!input_thresh: =!"
    set "offset=!offset: =!"

    REM 不要な記号除去（" と ,）
    for %%V in (input_i input_tp input_lra input_thresh offset) do (
        set "val=!%%V!"
        set "val=!val:"=!"
        set "val=!val:,=!"
        call set "%%V=%%val%%"
    )

    REM === infチェック ===
    echo !input_i!   | findstr /i "inf" >nul && set bad_data=1
    echo !input_tp!  | findstr /i "inf" >nul && set bad_data=1
    echo !offset!    | findstr /i "inf" >nul && set bad_data=1

    if defined bad_data (
        echo *** 無効な測定値を検出。1passモードに切り替えます ***
        "!ffmpeg!" -i "!input!" ^
        -vf "scale='if(gt(a,1),1920,-2)':'if(gt(a,1),-2,1080)'" ^
        -c:v %encoder% -preset %enc_preset% %enc_extra% -b:v 2500k ^
        -af "loudnorm=I=-14:TP=-1.0:LRA=11" ^
        -ar 44100 -c:a aac -b:a 192k ^
        "!output!"
    ) else (
        echo === 2pass補正中: !input! ===
        "!ffmpeg!" -i "!input!" ^
        -vf "scale='if(gt(a,1),1920,-2)':'if(gt(a,1),-2,1080)'" ^
        -c:v %encoder% -preset %enc_preset% %enc_extra% -b:v 2500k ^
        -af "loudnorm=I=-14:TP=-1.0:LRA=11:measured_I=!input_i!:measured_TP=!input_tp!:measured_LRA=!input_lra!:measured_thresh=!input_thresh!:offset=!offset!" ^
        -ar 44100 -c:a aac -b:a 192k ^
        "!output!"
    )

    del "!tempjson!"
    echo === 完了: !output! ===
    echo.
)

pause
