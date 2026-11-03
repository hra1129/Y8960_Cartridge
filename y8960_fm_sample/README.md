# Y8960 FM Sample (BRAND3)

Y8960 Cartridge の OPM (YM2151) と OPL2 (YM3812) を使って、
J.S.Bach「ブランデンブルク協奏曲 第3番 ト長調 BWV 1048」を演奏する MSX-DOS 用サンプルです。

現在は 第1楽章 (Allegro) と 第2楽章 (Adagio、2 和音のフリギア終止) を収録しています (約 5 分)。

## 使い方

```
A>BRAND3
```

- Y8960 Cartridge を自動検出し、OPL2 と OPM の I/O を有効にして (I/O Enabler2 = 7FFFh の bit0/bit2) 演奏します。
- ESC で停止します。
- 50Hz 機でも同じテンポで演奏します (MAIN-ROM 002Bh で判定)。
- 演奏中は割り込みを禁止し、VDP S#0 の VSYNC フラグをポーリングしてタイミングを取ります。

## パート割り当て

| パート | 音源 | ch | 音色 | 定位 |
|---|---|---|---|---|
| Violino I / II / III | OPM | 0 / 1 / 2 | strings | L / C / R |
| Viola I / II / III | OPM | 3 / 4 / 5 | strings | L / C / R |
| Violone (16') | OPM | 6 | contrabass (1 オクターブ下) | C |
| Violoncello I / II / III | OPL2 | 1 / 2 / 3 | cello | 48 / 128 / 208 |
| Violone (8') | OPL2 | 4 | cello | 128 |
| Cembalo (Violone と同じ譜) | OPL2 | 5 | harpsichord | 160 |

音色やバランスは [brand3.asm](brand3.asm) の `opm_patches` / `opl_patches`、
割り当ては [mksong.py](mksong.py) の `CHANNELS` で変更できます。

## ファイル

| ファイル | 内容 |
|---|---|
| BRAND3.COM | 実行ファイル |
| brand3.asm | 再生プログラム (Z80) |
| brand3.inc | 曲データ (mksong.py が生成) |
| mksong.py | LilyPond 楽譜 → brand3.inc 変換 |
| lyparse.py | LilyPond (Rosegarden 出力形式のサブセット) パーサ |
| Brandenburg_No3-BWV_1048.ly | 楽譜データ (第1・第2楽章) |

## ビルド

```
python mksong.py
..\tool\zma.exe brand3.asm BRAND3.COM
```

## 曲データの形式

`song_table` にチャンネル数と各チャンネルの { 音源 ch, 音色番号, 定位, ストリームアドレス } を並べます。
音源 ch は 0〜7 が OPM、8〜16 が OPL2 の ch1〜9、FFh がテンポ専用の指揮者チャンネルです。

| バイト | 意味 |
|---|---|
| 00h | 休符 (現在の音長) |
| 01h〜7Fh | 音符 (MIDI ノート番号、現在の音長) |
| 80h〜EEh | 音長 = 1〜111 tick (全音符 = 64 tick) |
| F0h ll hh | 音長 = hhll tick |
| F8h t6 t5 | テンポ: 1 フレームあたりの tick 数 × 256 (60Hz 用, 50Hz 用) |
| FFh | 終了 |

音符は最後の 1 tick でキーオフし (音長 2 tick 以上の場合)、同音の連打でも発音し直します。

## 楽譜データの出典

Brandenburg_No3-BWV_1048.ly は、Rosegarden の
[test/lilypond/baseline/Brandenburg_No3-BWV_1048.ly](https://github.com/tedfelix/rosegarden-official/blob/master/test/lilypond/baseline/Brandenburg_No3-BWV_1048.ly)
をそのまま使用しています。D. Michael McIntyre 氏による打ち込みで、ファイル内に
`copyright = "Public Domain"` と記載されています。

## 未実施

- 第3楽章 (Allegro、12/8) は未収録です (パブリックドメインの打ち込みデータが見つからないため)。
- 実機での音色・音量バランスの確認。
