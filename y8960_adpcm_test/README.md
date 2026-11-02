# Y8960 ADPCM 切り分け用テストサンプル

ADPCM（ドラム）だけにノイズが混じる問題の切り分け用です。
エンコード／デコード算法はリポジトリの `opl2_patch/test002/gen_adpcm.py` と同一
（MAME ymdeltat / openMSX Y8950Adpcm 互換）。ニブルは上位先行で格納しています。

## ファイル

| ファイル | 内容 | バイト数 |
|---|---|---|
| SILENT.BIN | 無音（0 の信号をエンコード）約1秒 | 12,428 |
| SINE1K.BIN | 1kHz 正弦波、振幅16000（約 -6dBFS）約1秒 | 12,428 |
| SWEEP.BIN | 対数スイープ 100Hz→10kHz、振幅16000、約2秒 | 24,856 |
| *_ref.wav | 各BINを参照デコーダで再生した「正解」の音（24,858Hz / 16bit） | — |
| gen_test.py | このサンプル一式の生成スクリプト | — |
| ADPLAY.COM | 実機で BIN を再生する MSX-DOS 用ツール（下記） | 1,728 |
| adplay.asm | ADPLAY のソース（zma、`zma adplay.asm ADPLAY.COM`） | — |

## 再生ツール ADPLAY.COM

MSX-DOS からそのまま使えます（BASIC からは `CALL SYSTEM` 経由などで
DOS に落としてから実行してください）。

```
ADPLAY SINE1K.BIN           … ロードアドレス0・DELTA-N=8000h で1回再生
ADPLAY SWEEP.BIN /R         … リピート再生（DOS に戻る。止めるにはリセット）
ADPLAY SINE1K.BIN /D:4000   … DELTA-N を変えて再生（この例では約12.4kHz）
```

| オプション | 意味 | 既定値 |
|---|---|---|
| /A:xxxx | サンプルメモリへのロードアドレス（バイト単位・16進） | 0000 |
| /D:xxxx | DELTA-N（16進） | 8000 |
| /V:xx | R#12 音量（16進） | FF |
| /R | リピート再生して即 DOS へ戻る | — |

動作の流れ：System Controller（I/O 40h/41h、ID=02h）でカートリッジの存在を
確認 → 全スロットから「AB」ヘッダ＋ Enabler2（7FFFh）読み戻しでカートリッジの
スロットを特定して OPL2(+ADPCM) を有効化 → ファイルを 16KB ずつ読みながら
R#0F へ転送（BUF_RDY ポーリング）→ EOS まで再生して終了。

注意点（実装上の都合）：
- BUF_RDY をステータスでポーリングするには R#04 でマスクを外す必要があり、
  その間カートリッジは BUF_RDY=1 のあいだ /INT をアサートし続けます
  （BIOS の割り込みハンドラはこの要因をクリアしません）。そのため転送と
  再生のハードウェア操作区間は割り込み禁止で実行しています。ファイル
  読み込み（BDOS）は割り込み許可区間で行うのでディスクアクセスは通常通りです。
- 再生中（EOS 待ち）は割り込み禁止区間のためキー入力を受け付けません。
  途中で止めたい場合はリセットしてください（サンプルは最大でも約2秒です）。
- RAM モードになっていると MMIO 窓が使えずスロット検出に失敗します。
  その場合はリセット直後に実行してください。

## 共通の再生条件

- DELTA-N = 0x8000 → 実レート 24,857.95Hz（49.7159kHz × 32768/65536）
  - R#10 = 00h、R#11 = 80h
- R#12（音量）= FFh（test002 と同じ）
- R#08 = 00h（64K=0：256KBモード、ROM=0）
- R#04 = 00h（EOS / BUF_RDY のマスク解除。ポーリングする場合）
- パン R#FF はリセット直後の 128（中央）のまま
- スタートアドレスは全サンプル共通で 0（R#09 = 00h、R#0A = 00h）

## 手順（Y8950互換手順）

1. データ転送：R#09/0A にスタート、R#0B/0C にストップ（下表）を設定し、
   R#07 = 60h（REC + MEMORY DATA）にしてから、BUF_RDY を見ながら
   R#0F へ BIN の内容を先頭から順に書く。
2. 再生：R#07 = A0h（START + MEMORY DATA）。
   EOS で自動停止します（REPEAT=0）。

| サンプル | ストップ R#0B/0C（4バイト単位） |
|---|---|
| SILENT / SINE1K | 0C22h（R#0B=22h、R#0C=0Ch） |
| SWEEP | 1845h（R#0B=45h、R#0C=18h） |

## 判定の目安（参照デコードでの実測値）

- **SILENT**：正解はほぼ無音です。参照デコードの残留は最大 ±15 LSB
  （RMS 約 -70dBFS）。実機でこれより明確に聞こえるノイズ（ブー、ザー、
  周期音など）があれば、デコード以降（データ供給・出力段）の問題です。
- **SINE1K**：正解の SNR は約 32.6dB（4bit ADPCM として正常な範囲。
  *_ref.wav が「正常な汚さ」の基準です）。実機の録音が ref より明らかに
  荒い／音程がずれている／周期的なクリックが乗る場合はハード側です。
  なお録音同士を比べるときは、サンプルレート換算で 1kHz が再現されて
  いるかも確認してください（レートずれの検出）。
- **SWEEP**：正解は滑らかな上昇音です。途中で折り返す（エイリアス）、
  特定の周波数だけ荒れる、ギザギザに途切れる、といった症状が出る
  周波数帯があれば、その帯域が手がかりになります。

## 追加で有効な確認

- 再生後に R#0F 読み出し（メモリリードモード）で SRAM の内容を
  BIN と照合すると、書き込み時に化けていないかを分離できます。
- 同じサンプルを「直前に大音量サンプルを途中で止めた直後」に再生すると、
  デコーダ状態の初期化漏れ（容疑2）があれば頭のノイズが変わります。

## ADTEST.COM - SRAM write/read verify (added 2026-11-02)

Writes a file to the ADPCM memory exactly like ADPLAY, then reads the
whole memory back through the ADPCM data port (memory read mode) and
compares it byte by byte against the file.

    ADTEST SINE1K.BIN        (or any file, /A:xxxx works as in ADPLAY)

- All bytes match:  "Verify OK."
- Otherwise:        "NNNN mismatches." and the first mismatch as
                    "First mismatch at HHHHHH: wrote XX read YY."
- ADTEST v1.1 also saves every byte it read back into READBACK.BIN
  (same length as the input file), so the exact corruption pattern
  can be analyzed on a PC afterwards.
- ADTEST v1.2 fixes three bugs of v1.0/v1.1 (all in ADTEST itself,
  not in the hardware): the verify phase used R#07 = 60h (memory
  WRITE mode) instead of 20h (memory READ mode), so every data read
  returned 00h by design; the decimal mismatch count printed the
  address of an internal buffer instead of the count; and the file
  size was taken from the FCB, which MSX-DOS 2.20 rounds down to a
  256-byte multiple. v1.2 streams the file and counts the bytes
  actually transferred. Results from v1.0/v1.1 must be discarded.

STRESS.BIN is a full 256KB pseudo-random pattern for a thorough check
of the SRAM path (takes a while to verify; that is normal).

Interpretation: a mismatch here means data was corrupted on the way
into or out of the SerialSRAM (the ssram.v path) - the same path the
cartridge BIOS and the ADPCM playback both use.
