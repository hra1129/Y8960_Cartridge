# Y8960 FM Sample (BRAND3 / CANCAN / OPLLRHY / MMIOTEST)

- [BRAND3](#brand3): OPM + OPL2 による「ブランデンブルク協奏曲 第3番」
- [CANCAN](#cancan): 全音源 (OPM / OPL2 / ADPCM / OPLL / SCC / SSG) による「天国と地獄」
- [OPLLRHY](#opllrhy): OPLL のリズム音 5 種 + メロディ 6ch によるオリジナル曲 (リズム音量の確認用)
- [MMIOTEST](#mmiotest): Memory Mapped I/O による SSG / OPLL / OPL2 / OPM / ADPCM の制御確認

## BRAND3

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

## CANCAN

Y8960 Cartridge の全音源を使って、オッフェンバック「天国と地獄」より
「地獄のギャロップ」(カンカン) を演奏する MSX-DOS 用サンプルです (約 72 秒)。

```
A>CANCAN
```

構成 (ハ長調、2/4 拍子) は次のとおりです。主題 16 小節を、音源を順に替えて演奏します。

| 区間 | 小節 | テンポ (♩=) | 内容 |
|---|---|---|---|
| イントロ | 4 | 168 | 全音源の伴奏 + クラッシュとスネアロール |
| 主題 1〜5 | 各 16 | 168 | SSG → SCC → OPLL → OPL2 → OPM の順にソロ (他の音源は休み) |
| 主題 6 | 16 | 184 | 全音源 (SSG / SCC のメロディは 1 オクターブ上) |
| コーダ | 2 | 150 | C - G - C |

ドラム (キック / スネア / クラッシュ) は ADPCM で全編に入ります。
ドラムの波形は mkcancan.py で合成し、起動時に ADPCM メモリへ転送します。

### パート割り当て

| 音源 | メロディ | ハーモニー | 和音 (裏拍) | ベース |
|---|---|---|---|---|
| SSG (SSG2 側) | A | B | - | C |
| SCC | A (のこぎり波) | B (矩形波) | C, D | E |
| OPLL | ch0 trumpet | ch1 clarinet | ch2〜4 piano | ch5 acoustic bass |
| OPL2 | ch1 lead | ch2 lead | ch3〜5 harpsichord | ch6 bass |
| OPM | ch0 brass | ch1 brass | ch2〜4 electric piano | ch5 bass |
| ADPCM | ドラム | | | |

ハーモニーは「メロディより短 3 度以上低い和音構成音のうち最も高い音」を自動で付けています。
定位はメロディとベースが中央、ハーモニーがやや左、和音が左・中央・右です。

### 音源へのアクセス

| 音源 | アクセス方法 |
|---|---|
| OPM | I/O 7Eh / 7Fh |
| OPL2 + ADPCM | I/O C0h / C1h (PAN: F6h〜FEh = ch1〜9、FFh = ADPCM) |
| OPLL | MMIO 7FF4h / 7FF5h (内蔵 MSX-MUSIC と重ならないように I/O 7Ch / 7Dh は使いません) |
| SSG | MMIO 7FF0h / 7FF1h の SSG2 側 (R#10h〜1Fh、PAN: 2Ch〜2Eh)。本体 PSG と競合しません |
| SCC | 9000h = 3Fh で 9800h〜 に SCC レジスタを出し、PAN は 9900h〜9904h |

- 演奏中は割り込みを禁止し、ENASLT でページ 1・2 をカートリッジのスロットに切り替えて、
  MMIO と SCC へ直接書き込みます (WRSLT は遅く、全音源が一斉に発音する拍で 1 フレームに収まらないため)。
  そのため演奏中に使うコードとデータはすべて 4000h 未満に置き、
  起動時の転送にしか使わない ADPCM データだけを最後尾 (4000h をまたいでもよい) に置いています。
  終了時は RAMAD1 / RAMAD2 (F342h / F343h) のスロットに戻します。
- SCC と SSG はソフトウェアでエンベロープ (減衰) をかけています。
- 終了時は全音源をキーオフ・消音し、SCC のバンクレジスタ (9000h) を 02h に戻します。

音色は [cancan.asm](cancan.asm) の `opm_patches` / `opl_patches` / `scc_patches` / `psg_patches`、
OPLL の音色と音量は [mkcancan.py](mkcancan.py) の `CHANNELS` (patch = INST << 4 | VOL)、
アレンジは mkcancan.py の `THEME` / `THEME_CHORDS` と `build_song()` で変更できます。

### ファイル

| ファイル | 内容 |
|---|---|
| CANCAN.COM | 実行ファイル |
| cancan.asm | 再生プログラム (Z80) |
| cancan.inc | 曲データ・音程表・SCC 波形・ADPCM ドラム (mkcancan.py が生成) |
| mkcancan.py | アレンジ・曲データ生成、ドラム合成と ADPCM エンコード |

### ビルド

```
python mkcancan.py
..\tool\zma.exe cancan.asm CANCAN.COM
```

曲データの形式は BRAND3 と同じです。音源 ch は 00h〜 が OPM、08h〜 が OPL2、20h〜 が OPLL、
30h〜 が SCC、40h〜 が SSG2、50h が ADPCM (ノート番号 1 = キック、2 = スネア、3 = クラッシュ)、
FFh が指揮者チャンネルです。

### 原曲と編曲

原曲は J.Offenbach (1819-1880) のオペレッタ「地獄のオルフェ」(1858) で、パブリックドメインです。
編曲 (主題の採譜、和声付け、構成) はこのサンプルのために作成したものです。

## OPLLRHY

Y8960 Cartridge の OPLL だけを使い、リズム音 5 種 (BD / SD / TOM / CYM / HH) と
メロディ 6ch で 8 ビートのオリジナル曲を演奏する MSX-DOS 用サンプルです (約 64 秒)。
リズム音とメロディの音量バランスの確認用です。ESC で停止します。

```
A>OPLLRHY
```

構成 (ハ長調、4/4 拍子、♩=120) は次のとおりです。

| 区間 | 小節 | 内容 |
|---|---|---|
| ドラムデモ | 6 | BD → SD → TOM → CYM → HH を 1 小節ずつ単独で鳴らし、最後に 5 種同時 |
| A | 8 | メロディ + 8 ビート (BD / SD / HH、頭にクラッシュ、最後にフィル) |
| B | 8 | ライドを CYM に替えたパターン |
| A | 8 | 再現 |
| エンディング | 2 | C の和音 + BD・CYM |

### パート割り当て

| ch | パート | 音色 | 定位 |
|---|---|---|---|
| 0 | メロディ | flute | 中央 |
| 1 | ハーモニー | clarinet | やや左 |
| 2〜4 | 和音 (4 分) | piano | 左 / 中央 / 右 |
| 5 | ベース (8 分) | acoustic bass | 中央 |
| 7〜9 | リズム | BD / SD・HH / TOM・CYM | 中央 |

- リズムの F-Number は MSX-MUSIC と同じ値 (16h〜18h = 20h, 50h, C0h / 26h〜28h = 05h, 05h, 01h)、
  音量は全て最大 (36h〜38h = 00h) です。
- リズムは 0Eh で「鳴らす楽器のビットだけ一度 0 にしてから 1 にする」書き方で、
  他の楽器の減衰を止めずに打ち直します (音符の終わりにキーオフはしません)。
- OPLL は MMIO 7FF4h / 7FF5h でアクセスします。演奏方法 (割り込み禁止、ページ 1・2 の切り替え、
  VSYNC 待ち) は CANCAN と同じです。

音色・音量・定位は [mkopllrhy.py](mkopllrhy.py) の `CHANNELS`、リズムの音量と定位は
`RHYTHM_VOLUME` / `RHYTHM_PAN`、アレンジはテーマとドラムパターンの定義で変更できます。

### ファイル

| ファイル | 内容 |
|---|---|
| OPLLRHY.COM | 実行ファイル |
| opllrhy.asm | 再生プログラム (Z80) |
| opllrhy.inc | 曲データ・リズム初期化表・音程表 (mkopllrhy.py が生成) |
| mkopllrhy.py | 作曲・曲データ生成 |

### ビルド

```
python mkopllrhy.py
..\tool\zma.exe opllrhy.asm OPLLRHY.COM
```

曲データの形式は CANCAN と同じです。音源 ch は 20h〜25h が OPLL ch0〜5、60h がリズム
(ノート番号 = 鳴らす楽器のビット 10h BD | 08h SD | 04h TOM | 02h CYM | 01h HH)、FFh が指揮者チャンネルです。

## MMIOTEST

SSG1 / SSG2 / OPLL / OPL2 / OPM / ADPCM を Memory Mapped I/O (7FF0h〜7FFFh) だけで鳴らし、
MMIO 経由の制御が正しく行われるかを耳で確認する MSX-DOS 用テストプログラムです。ESC で停止します。

```
A>MMIOTEST
```

テスト中は I/O Enabler2 (7FFFh) を 00h にして、OPL2 / OPM / SSG / TIMER の I/O ポートを切り離します。
そのため、鳴る音はすべて MMIO への書き込みによるものです。終了時に 7FFFh は起動前の値に戻します。
I/O Enabler1 (7FF6h、OPLL の I/O 7Ch / 7Dh) は読み出せないので変更しません (テストでは I/O 7Ch / 7Dh は使いません)。

| 順 | 音源 | MMIO | 内容 |
|---|---|---|---|
| 1 | SSG1 Ch.A | 7FF0h / 7FF1h (R#00h〜、PAN R#28h) | ド・ミ・ソ・ド (PAN 左・右・中央・中央) |
| 2 | SSG2 Ch.A | 7FF0h / 7FF1h (R#10h〜、PAN R#2Ch) | 同上 |
| 3 | OPLL ch1 | 7FF4h / 7FF5h (piano、PAN R#50h) | 同上 |
| 4 | OPLL リズム | 7FF4h / 7FF5h | BD → SD → TOM → CYM → HH → 全部 |
| 5 | OPL2 ch1 | 7FF2h / 7FF3h (PAN R#F6h) | ド・ミ・ソ・ド (PAN 左・右・中央・中央) |
| 6 | OPM ch1 | 7FFBh / 7FFCh (PAN は R#20h の RL) | 同上 |
| 7 | ADPCM メモリ書き込み | 7FF2h / 7FF3h | 約 8KB のチャイム音をアドレス 0 から書き込み、I/O C0h / C1h で読み戻して比較 |
| 8 | ADPCM 再生 | 7FF2h / 7FF3h (PAN R#FFh) | チャイム音を PAN 左・右・中央で 3 回 |

- 7 の結果は `verify (I/O C0h/C1h): OK`、不一致があれば `NG, errors=XXXXh (first at XXXXh: wrote XXh, read XXh)` と表示します。
  MMIO ではステータスを読めないため、書き込みは BUF_RDY を見ずに 1 バイトごとにソフトウェアウェイトを入れています。
  読み戻しだけは OPL2 の I/O ポートを一時的に有効にして行います (MSX-AUDIO を挿しているとポートが競合するので外してください)。
- MMIO を使うため、演奏中はページ 1 をカートリッジのスロットに切り替えます (ページ 2 は RAM のまま)。
  Y8960 BIOS がある場合は CANCAN と同じく RAM Mode=0 にします。

### ファイル

| ファイル | 内容 |
|---|---|
| MMIOTEST.COM | 実行ファイル |
| mmiotest.asm | テストプログラム (Z80) |
| mmiotest.inc | 音程表・ADPCM サンプル (mkmmiotest.py が生成) |
| mkmmiotest.py | 音程表と ADPCM サンプルの生成 (mkcancan.py の関数を使用) |

### ビルド

```
python mkmmiotest.py
..\tool\zma.exe mmiotest.asm MMIOTEST.COM
```

## SCCDIAG.COM (SCC 診断)

SCC ch.A の波形 RAM に鋸波を書き込んで読み戻し、ch.A を約 440Hz・音量 15 で約 3 秒鳴らします。
終了後に、読み戻した 32 バイトと、期待値と一致したかどうか (Wave RAM: OK / NG) を表示します。

```
SCCDIAG
```

ビルド:

```
..\tool\zma.exe sccdiag.asm SCCDIAG.COM
```
