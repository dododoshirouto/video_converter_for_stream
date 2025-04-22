# Video Converter for Stream

配信者向けの動画変換スクリプト。

## 概要
配信用に最適化された動画ファイルを簡単に作成するためのスクリプトです。動画を1080pのmp4形式で-14LUFSの音量に調整し、軽量かつ高品質な配信向け動画を生成します。

## 機能
- 動画ファイルを配信用に最適化
- 1080p解像度、mp4形式、-14LUFS音量調整
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
