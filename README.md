# Video Converter for Stream

配信者向けの動画変換スクリプト。

## 概要
簡単に動画ファイルを配信に最適化するためのスクリプトです。


## 機能
- 1080p
- 2500kbps
- mp4 h264
- -14LUFS(peak-1dB,2pass)
- GPU対応の高速変換オプション

## インストール

1. リポジトリをダウンロードします。
   - [ここをクリックしてZIPでダウンロード](https://github.com/dododoshirouto/video_converter_for_stream/archive/refs/heads/main.zip)
   - ダウンロードしたZIPファイルを解凍します。

2. ffmpegをインストールします。
   - [ffmpeg公式サイト](https://ffmpeg.org/download.html)からお使いのOS向けのインストーラーをダウンロードします。
   - インストーラーを実行し、画面の指示に従ってインストールを完了します。

## 使い方

動画ファイルを`video_convert.bat`または`video_convert_gpu.bat`にドラッグ＆ドロップするだけで変換が開始されます。

- `video_convert.bat`: CPUを使用して変換
- `video_convert_gpu.bat`: GPUを使用して高速に変換

## 必要環境
- ffmpeg

## ライセンス
MITライセンスです。詳しくは [LICENSE](LICENSE) を参照してください。
