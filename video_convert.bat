@echo off
setlocal enabledelayedexpansion

REM ==== このバッチは、動画をまとめて変換するツール ====
REM - H.264でエンコード.
REM - 1080p（長辺基準でリサイズ）.
REM - 映像ビットレート 2500kbps
REM - 音声は -14LUFS（±1dB, Peak -1dB）で正確に2pass補正.
REM - ffmpeg 最新版で動作確認推奨.
REM ==============================================

set "ffmpeg=%~dp0ffmpeg.exe"

REM ==== ffmpeg チェック ====
where ffmpeg >nul 2>nul
if errorlevel 1 (
    REM .カレントフォルダにffmpeg.exeがあるか見る.
    if exist "%~dp0ffmpeg.exe" (
        set "ffmpeg=%~dp0ffmpeg.exe"
    ) else (
        echo [エラー] ffmpeg が見つかりません！
        echo ffmpeg をインストールするか、バッチファイルと同じフォルダに ffmpeg.exe を置いてください。
        echo ダウンロードページを開きます...
        start https://www.gyan.dev/ffmpeg/builds/#release-builds
        pause
        exit /b
    )
) else (
    set "ffmpeg=ffmpeg"
)

REM ==== メイン処理 ====
for %%F in (%*) do (
    set "input=%%~F"
    set "filename=%%~nF"
    set "output=%%~dpF!filename!_1080p_-14LUFS.mp4"
    set "tempjson=tmp_!filename!.json"

    echo === 測定中: !input! ===

    REM 1pass目: ラウドネス測定（stderrをテキストファイルに保存）
    ffmpeg -i "!input!" -af "loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json" -f null - 2> "!tempjson!"

    REM JSON形式の測定結果から値を抽出.
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_i" "!tempjson!"') do set input_i=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_tp" "!tempjson!"') do set input_tp=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_lra" "!tempjson!"') do set input_lra=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"input_thresh" "!tempjson!"') do set input_thresh=%%b
    for /f "tokens=1,* delims=:" %%a in ('findstr /C:"target_offset" "!tempjson!"') do set offset=%%b

    REM .空白削除しておく.
    set "input_i=!input_i: =!"
    set "input_tp=!input_tp: =!"
    set "input_lra=!input_lra: =!"
    set "input_thresh=!input_thresh: =!"
    set "offset=!offset: =!"

    REM .数値が正常値かざっくりチェックして、異常なら1passに切り替え.
    set /a bad_data=0

    for %%Z in (!input_i! !input_tp! !offset!) do (
        REM .数値として範囲外だったら bad_data フラグを立てる.
        set "val=%%Z"
        set /a test_val=100 + %%Z 2>nul || set /a bad_data=1
    )

    REM .測定値が -inf（無限小）になってたら、2pass補正は使えないので.
    REM .安全のために1passモードに自動で切り替えます.
    echo !input_i! | findstr "inf" >nul && set bad_data=1
    echo !input_tp! | findstr "inf" >nul && set bad_data=1
    echo !offset! | findstr "inf" >nul && set bad_data=1

    if defined bad_data (
        echo *** 音声ラウドネス測定に失敗したため、1pass補正に切り替えます ***
        "!ffmpeg!" -i "!input!" ^
        -vf "scale='if(gt(a,1),1920,-2)':'if(gt(a,1),-2,1080)'" ^
        -c:v libx264 -b:v 2500k -preset medium -profile:v high -level 4.1 ^
        -af "loudnorm=I=-14:TP=-1.0:LRA=11" ^
        -c:a aac -b:a 192k ^
        "!output!"
    ) else (
        echo === 補正中: !input! ===
        "!ffmpeg!" -i "!input!" ^
        -vf "scale='if(gt(a,1),1920,-2)':'if(gt(a,1),-2,1080)'" ^
        -c:v libx264 -b:v 2500k -preset medium -profile:v high -level 4.1 ^
        -af "loudnorm=I=-14:TP=-1.0:LRA=11:measured_I=!input_i!:measured_TP=!input_tp!:measured_LRA=!input_lra!:measured_thresh=!input_thresh!:offset=!offset!" ^
        -c:a aac -b:a 192k ^
        "!output!"
    )

    REM .一時ファイル削除.
    del "!tempjson!"

    echo === 完了: !output! ===
    echo.
)

pause
