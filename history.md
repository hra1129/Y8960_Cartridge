# 作業履歴

## 2026-10-16 朝: IKAOPLL ステレオ化（作業途中）

### 目的と制約

- YM2413 (OPLL) クローン RTL の IKAOPLL をステレオ化する。
- `fpga/Y8960_Cartridge_TangPrimer25K/src/ikaopll` 以下の原本は一切変更しない。
- 原本に変更が必要なファイルは `fpga/Y8960_Cartridge_TangPrimer25K/src/ikaopll_patch` 以下へコピーし、コピー側を変更して使用する。
- PAN レジスタの仕様は `doc/spec/Y8960_Specifications.xlsx` の `OPLL-EX` シートに従う。

### 仕様から確認した内容

- PAN レジスタは `0x50`～`0x58`（CH1～CH9）。
- 各レジスタは 8 bit の PAN 値を保持する。
- `1` が左端、`128` が中央、`255` が右端。
- デフォルト値は `128`（中央）。

### 今朝実施した変更

1. `src/ikaopll_patch/IKAOPLL_reg.v`
   - `o_PAN[7:0]` 出力を追加。
   - レジスタアドレス `0x50`～`0x58` のデコード `reg50_58_en` を追加。
   - 9 チャンネル分の PAN 値を既存の `IKAOPLL_d9reg` で保持する `u_pan` を追加。
   - リセット時の PAN 値を `8'd128` に設定。
   - `0x50` 台を受け付けるため、アドレスレジスタ書き込み許可条件を `dbus_inlatch[7] == 1'b0` に拡張。

2. `src/ikaopll_patch/IKAOPLL.v`
   - 原本からコピーしてパッチ側へ追加。
   - `IKAOPLL_reg` の PAN 出力を内部信号 `pan` に接続。
   - PAN を `IKAOPLL_dac` へ渡す配線を追加。
   - モノラルの積算出力を左右独立の `o_ACC_SIGNED_L` / `o_ACC_SIGNED_R` に変更。

3. `src/ikaopll_patch/IKAOPLL_modules/IKAOPLL_dac.v`
   - 原本からコピーしてパッチ側へ追加。
   - `i_PAN[7:0]` 入力を追加。
   - 左右それぞれの積算器と 16 bit 符号付き出力を追加。
   - PAN が中央なら左右同音量、左側なら右を減衰、右側なら左を減衰させる処理を追加。
   - 既存のモノラル積算出力と同様に、左右出力にも 16 bit 飽和処理を実装。

4. `src/ikaopll_patch/opll.v`
   - 従来の OPLL 2 個構成 `dual_opll` を、ステレオ出力を持つ OPLL 1 個構成 `opllex` に変更。
   - 出力名を `sound_l_out` / `sound_r_out` に変更。
   - バスアドレス入力を 1 bit に変更。

5. `src/y8960_cartridge_tangprimer25k.v`
   - `dual_opll` の代わりに `opllex` を接続。
   - OPLL の左右出力を、それぞれ左・右のオーディオミキサーへ接続。

6. `Y8960_Cartridge_TangPrimer25K.gprj`
   - 原本側の `IKAOPLL.v` と `IKAOPLL_dac.v` の参照を、パッチ側のコピーへ変更。
   - 変更していない他の IKAOPLL モジュールは、引き続き原本側を参照する。

### 現在の状態

- 実装途中であり、ビルド、シミュレーション、実機確認はまだ行っていない。
- 原本の `src/ikaopll` 以下には変更を加えていない。
- 仕様確認用に作成した一時ファイル `.copilot_opll_spec.txt` がリポジトリ直下に残っている。
- 作業ツリーには OPLL ステレオ化以外の変更も存在する。特に `sn76489_audio` 関連ファイルの削除、`dual_dcsg` インスタンスの削除、PCB の `fp-info-cache` 変更がある。これらは OPLL 作業と混同せず、意図を確認してから扱うこと。

## 帰宅後に行うこと

1. PAN の計算とタイミングをレビューする。
   - `0x50`～`0x58` が各 CH1～CH9 に正しく対応すること。
   - 値 `1`、`128`、`255` で仕様どおり左端、中央、右端になること。
   - `pan_z` と対象チャンネルのサンプルが同じタイミングで処理されること。
   - リズムモード時の CH7～CH9／打楽器の定位が意図どおりか確認すること。

2. レジスタアクセスを確認する。
   - アドレス書き込み許可条件の拡張が、既存レジスタや未使用アドレスへ副作用を与えないこと。
   - リセット後、9 チャンネルすべての PAN が `128` になること。

3. RTL の整合性を確認する。
   - `IKAOPLL` のポート変更が全インスタンスへ反映されていること。
   - Gowin プロジェクトがパッチ側の `IKAOPLL.v` と `IKAOPLL_dac.v` のみを採用し、原本と二重定義にならないこと。
   - `opllex` の `bus_ready` の変更が、システムのバス・ハンドシェイク仕様に合っていること。

4. テストを追加または実施する。
   - 可能なら PAN レジスタ書き込みと左右出力を確認する簡単なシミュレーションを用意する。
   - 中央定位で従来のモノラル音量・波形が左右とも維持されることを比較する。
   - 左端／右端、最大振幅、リズム音を含むケースで、減衰と飽和処理を確認する。

5. FPGA プロジェクトをビルドし、構文、ポート接続、タイミング、リソース使用量を確認する。

6. 実機で確認する。
   - 起動直後は中央定位で従来どおり鳴ること。
   - CH ごとの PAN 書き込みが左右出力へ反映されること。
   - ノイズ、音切れ、左右の取り違え、音量変化がないこと。

7. 確認後の整理。
   - `.copilot_opll_spec.txt` が不要なら削除する。
   - OPLL 以外の作業ツリー変更を別作業として整理する。
   - 必要なら PAN レジスタ仕様と使用方法を正式なドキュメントへ追記する。

## 2026-10-16 夜: IKAOPLL ステレオ化の修正と検証

### 追加修正

- `src/ikaopll_patch/opll.v`
  - 1 bit 入力へ変更済みの `bus_address` に残っていた不正な `[0]` 参照を修正。
  - 未使用になったモノラル出力用の内部信号を削除。
- `src/ikaopll_patch/IKAOPLL_modules/IKAOPLL_dac.v`
  - PAN レジスタ出力は音源パラメータ入力段に整列している一方、DAC のキャリア音は 3 オペレータ周期後に現れることをシミュレーションで確認。
  - PAN を合計 3 周期遅延させ、DAC サンプルのチャンネルへ整列させた。
  - PAN 遅延段をリセット時に中央値 `128` へ初期化。
  - 左右へ加算するサンプル値を `dac_acc_sample_l` / `dac_acc_sample_r` として明示。

### 検証結果

- ModelSim によるパッチ版 IKAOPLL のコンパイル: エラー 0、警告 0。
- ModelSim による Gowin プロジェクト内の既存 Verilog 一括コンパイル: エラー 0、警告 0。
- PAN 専用シミュレーション:
  - `0x50`～`0x58` への書き込みを確認。
  - CH1～CH9 の全キャリアスロットで、対応する PAN 値が選択されることを確認。
  - リズム用の CH8 mod、CH9 mod、CH7 carrier、CH8 carrier、CH9 carrier の各スロットでも CH7～CH9 の PAN 値が一致することを確認。
  - PAN `1` では左がフルスケール、右が `1/128`。
  - PAN `128` では左右ともフルスケール。
  - PAN `255` では左が `1/128`、右がフルスケール。
  - すべて PASS。
- Gowin Synthesis:
  - 削除済みの SN76489 ソース 2 ファイルを Tcl 上で一時的に対象外として実行し、合成完了。
  - 今回変更した IKAOPLL 関連ファイルに警告なし。
  - SN76489 インスタンス削除に伴う未駆動信号、および既存の ADPCM/OPL2/System Controller などには警告が残っている。OPLL ステレオ化とは別件。
- `src/ikaopll` 以下の原本に変更がないことを確認。

### 残作業

1. 実機で CH ごとの左右定位、中央定位、リズム音を確認する。
2. SN76489 削除を確定する場合は、Gowin プロジェクトから削除済み 2 ファイルの参照と未駆動 DCSG 信号を別作業で整理する。
3. 必要なら PAN 専用シミュレーションをリポジトリ内の正式なテストとして追加する。

## 2026-10-16 夜: SN76489 のプロジェクト撤去

### 実施内容

- SN76489 のソースファイルを削除状態に維持した。
- `Y8960_Cartridge_TangPrimer25K.gprj` から SN76489 の Verilog/VHDL 参照を削除した。
- FPGAトップ階層から `dual_dcsg`、DCSG 用のバス信号、ready 信号、音声信号、およびミキサー加算を削除した。
- アドレスデコーダから DCSG/SN76489 用の I/O アドレス、メモリマップド I/O、イネーブル保持、ready 経路を削除した。
- アドレスデコーダおよび MSX slot のテストベンチから DCSG 用の定数、信号、テストを削除した。
- アドレスデコーダテストベンチに `led` 接続を追加し、実装の既定値（OPLL1/SSG 有効）に合わせて初期テストを修正した。また、チップセレクト幅を現行の 6 bit に統一した。

### 検証結果

- プロジェクト内 Verilog 一括コンパイル: エラー 0、警告 0。
- `y8960_address_decode/test001`: コンパイルおよび全テスト PASS。
- `msx_slot/test002`: コンパイルおよび全テスト PASS。
- ソースおよび Gowin プロジェクトファイルを検索し、`SN76489`、`DCSG`、`bus_dcsg`、`dual_dcsg` の参照がないことを確認した。

### 残作業

1. SN76489 参照を除去した Gowin プロジェクトで合成を再実行し、完了を確認する。
2. 実機で OPLL の左右定位、中央定位、リズム音を確認する。

## 2026-10-16 夜: OPLL等パワーPANとdualSSGステレオ対応

### 共通PAN変換テーブル

- `src/pan/pan_lut.v` を追加した。
- PAN `0` は `1` と同じ左端、`1` は左端、`128` は中央、`255` は右端とした。
- 添付資料の `L=cos(theta)`、`R=sin(theta)` に従う等パワーカーブを、Q1.8（1.0=`256`）の固定値テーブルにした。
- 左右ゲインを1ワードに格納した単一同期ROMとし、右側は左側カーブを反転した値を使用した。
- Gowin合成で各テーブルが1 BSRAMへ推論されることを確認した。
- 初期の組合せ`case`版は約270 LUT、2読出しROM版は2 BSRAMを使用したため不採用とした。最終版は1 BSRAMと3～19 LUT。

### OPLL

- `src/ikaopll_patch/IKAOPLL_modules/IKAOPLL_dac.v` の直線PAN演算を共通PAN ROMへ置き換えた。
- 左右それぞれをQ1.8ゲインで乗算し、中央では左右とも約0.707倍になる。
- 原本の `src/ikaopll` 以下は変更していない。

### dualSSG

- SSGレジスタポインタを6 bitへ拡張した。
- 仕様書どおり、SSG1 Ch.A～CのPANを`28h`～`2Ah`、SSG2 Ch.A～CのPANを`2Ch`～`2Eh`へ追加した。
- 6レジスタのリセット値をすべて`128`にした。
- 各SSGコアのA/B/C時分割ミキサーを左右独立化し、共通PAN ROMの左右ゲインを適用した。
- `dual_ssg` は2コアを合算した13 bitの左右出力を公開し、トップ階層の左右ミキサーへ個別接続した。

### 検証結果

- PAN ROM単体:
  - `0/1`、`128`、`255`のゲインを確認。
  - 全PAN値で左右ゲインが単調に変化することを確認。
  - 全PAN値で量子化後の合計パワー誤差が規定範囲内であることを確認。
- OPLL PANシミュレーション:
  - `50h`～`58h`のPANレジスタとチャンネル整列を確認。
  - 左端、等パワー中央、右端の左右ゲインを確認。
  - PASS。
- dualSSGシミュレーション:
  - 6個のPANレジスタのリセット値、書き込み、読み出しを確認。
  - PAN `0`、`1`、`128`、`255`の左右ゲインを確認。
  - PASS。
- Gowinプロジェクト内Verilog一括コンパイル: エラー0、警告0。
- Gowin Synthesis: 完了。PANテーブルは各インスタンス1 BSRAMへ推論。

## 2026-10-16 夜: OPL2 の1個構成化

### 目的と制約

- `dual_opl2`（OPL2 + ADPCM が2組入った構成）を1組構成へ変更し、モジュール名を `opl2` へ改名する。
- `fpga/Y8960_Cartridge_TangPrimer25K/src/opl2` 以下の原本は一切変更しない。
- 変更が必要なファイルは `fpga/Y8960_Cartridge_TangPrimer25K/src/opl2_patch` 以下のコピーのみ。

### 実施した変更

1. `src/opl2_patch/opl2.v`
   - モジュール名を `dual_opl2` から `opl2` へ改名した。
   - `jtopl2` と `adpcm` のインスタンスを各1個にした。
   - `bus_address` を2 bitから1 bitへ変更した（レジスタ/データ選択のみ）。
   - 出力ポートを `opl2_sound_out`、`adpcm_sound_out_l`、`adpcm_sound_out_r` へ単一化した。
   - 2個目用の49.7159kHz位相 `w_cen50_1`、バス調停、割り込み合成、ADPCMメモリI/Fの多重化を削除した。
   - ADPCMアドレスを24 bitから18 bitへ明示的に切り詰め、既存の truncate 合成警告を解消した。

2. `src/y8960_address_decode/y8960_address_decode.v`
   - 2個目のMSX-AUDIOマッピングを完全に削除した。
   - I/O `C2h`-`C3h` とメモリマップドI/O `7FEEh`-`7FEFh`（ミラー `3FEEh`-`3FEFh`）を廃止した。
   - I/O Enabler2 の bit1（`ff_opl2_2_io_en`）を廃止し、OPL2のイネーブルは bit0 のみとした。

3. `src/y8960_cartridge_tangprimer25k.v`
   - `dual_opl2` インスタンスを `opl2` へ置き換え、`bus_address[0]` のみを接続した。
   - OPL2とADPCMの音声信号を単一化した。
   - ADPCMの L 出力を左チャンネル、R 出力を右チャンネルへ振り分けた（従来は L+R を左右両方へ加算していた）。

4. テストベンチ
   - `src/opl2_patch/test001/tb.sv` を1個構成へ更新し、古い `adpcm_oe_n`/`adpcm_we_n` 形式のメモリモデルを現行の valid/ready 形式へ修正した。
   - `src/y8960_address_decode/test001/tb.sv` に、廃止した `C2h` が未マップ、`7FEEh` がSCCへフォールバックすることの確認を追加した。
   - `src/msx_slot/test002/tb.sv` から2個目のOPL2アクセスを削除した。

### 検証結果

- `src/opl2_patch/test001`: エラー0、警告0。ステータス読み出しと全レジスタ読み出しがPASS。
- `src/y8960_address_decode/test001`: all tests passed。エラー0、警告0。
- `src/msx_slot/test002`: all tests passed。エラー0、警告0。
- Gowinプロジェクト内Verilog一括コンパイル: エラー0、警告0。
- Gowin Synthesis: 完了。`opl2.v` の truncate 警告（Expression size 24 truncated to fit in target size 18）が解消した。

## 2026-10-17 朝: OPL2 ステレオ化

### 仕様

- `doc/spec/Y8960_Specifications.xlsx` の `OPL2+ADPCM` シートに従い、`F6h`～`FEh`をCH1～CH9のPANレジスタとした。
- PANの扱いはOPLL-EXと同じで、`0`/`1`が左端、`128`が中央、`255`が右端、初期値は`128`。
- 共通の等パワーPAN ROM `src/pan/pan_lut.v` を再利用した。

### 実施した変更

- 原本の `src/opl2` は変更せず、変更が必要な以下のファイルを `src/opl2_patch` へコピーして修正した。
  - `jtopl2.v`
  - `jtopl.v`
  - `jtopl_mmr.v`
  - `jtopl_op.v`
  - `jtopl_acc.v`
- `jtopl_mmr.v` に9本のPANレジスタを追加し、OPL2の18スロットを対応する9チャンネルのPAN値へ割り当てた。
- `jtopl_op.v` でPAN値をオペレータ演算と同じ6オペレータ周期だけ遅延し、音声サンプルと整列させた。
- `jtopl_acc.v` を左右独立のアキュムレータへ変更した。
  - PAN ROMは1個を時分割で使用する。
  - 同期ROMの1クロック遅延を、オペレータサンプルと加算制御の1オペレータ周期遅延で吸収した。
  - リズムモードでも各オペレータに元チャンネルのPANを適用する。
- `jtopl2.v`、`jtopl.v`、`opl2.v` の音声出力を左右独立にした。
- トップ階層の左右ミキサーへOPL2のL/R出力を個別接続した。
- Gowinプロジェクトでは、変更した5ファイルの参照を原本側から`src/opl2_patch`側へ差し替えた。

### 検証結果

- `src/opl2_patch/test001`:
  - PANレジスタ9本のリセット値`128`を確認。
  - `F6h`～`FEh`への書き込みを確認。
  - 全18スロットとCH1～CH9のPAN選択対応を確認。
  - PAN `0`、`1`、`128`、`255`で、入力`1024`に対してそれぞれ
    `L/R=1024/0`、`1024/0`、`724/724`、`0/1024`となることを確認。
  - エラー0、警告0。
- Gowinプロジェクト内Verilog 73ファイル一括コンパイル: エラー0、警告0。
- Gowin Synthesis: 完了。
  - `pan_lut` の `gain_table` がRAMとして推論されることを確認。
  - OPL2ステレオ化で追加したtruncate警告は0。
- `src/opl2` 以下に差分がないことを確認した。

## 2026-10-17 朝: 音源別ボリューム付き時分割ミキサー

### 仕様

- `doc/spec/Y8960_Specifications.xlsx` の `MemoryMappedIO` シートに従い、以下の音量レジスタを`msx_slot`へ追加した。
  - `7FF8h`: SSG Volume
  - `7FF9h`: OPLL Volume
  - `7FFAh`: OPL2 Volume
  - `7FFBh`: ADPCM Volume
  - `7FFCh`: SCC Volume
- 5レジスタの初期値はすべて`128`。
- bit7が`1`なら値にかかわらず100%、bit7が`0`なら`bit[6:0]/128`のゲインとした。
- RAM Mode=0、またはRAM Mode=1かつBANK1がROMバンク#0～#15のときだけVolumeレジスタを有効とした。

### 実施した変更

- `src/msx_slot/msx_slot.v`
  - 5本のVolumeレジスタと出力ポートを追加した。
  - 有効な`7FF8h`～`7FFCh`書き込みは`msx_slot`内で完結させ、Local BUSへ転送しないようにした。
  - レジスタが無効なBANK条件では従来どおりメモリアクセスとしてLocal BUSへ転送する。
- `src/mixer/mixier.v`
  - TOP階層にあった単純加算、固定×16ゲイン、24-bit飽和処理を移設した。
  - SSG、OPLL、OPL2、ADPCM、SCCの5音源を左右ミキシングする。
  - 5音源×左右の10回の乗算を10ステートで順次処理し、1個の符号付き乗算器を共有する構成とした。
  - 乗算結果を高精度のまま加算して最後に`/128`と従来の`×16`をまとめて`>>>3`で処理する。
- `src/y8960_cartridge_tangprimer25k.v`
  - TOP階層にベタ書きされていたミキサーを削除し、`mixier`インスタンスへ置き換えた。
  - `w_scc_ma`からVolumeレジスタのBANK有効条件を生成し、`msx_slot`へ渡した。
- Gowinプロジェクトへ`src/mixer/mixier.v`を追加した。

### 検証結果

- `src/mixer/test001`
  - 全音源100%、音源別ゲイン、bit7による100%クランプ、全音源ミュートを確認。
  - エラー0、警告0、全テストPASS。
- `src/msx_slot/test001`
  - 5レジスタの初期値`128`、書き込み、Local BUS抑止、無効時の値保持を確認。
  - エラー0、警告0、全テストPASS。
- `src/msx_slot/test002`
  - 既存の統合スロット／アドレスデコードテストが全てPASS。
- Gowinプロジェクト内Verilog 74ファイル一括コンパイル: エラー0、警告0。
- Gowin Synthesis: 完了。
  - ミキサーの乗算は`w_product_raw_0_s`という単一の`MULTALU27X18`へ推論された。
  - ミキサー実装による新規警告は0。

## 2026-10-17 夜: レジスタ仕様表との整合性確認と修正

### 背景

`doc/spec/Y8960_Specifications.xlsx` のレジスタ表が更新されたため、現在の実装との差分を全シート
(`modules` / `MemoryMappedIO` / `ssg` / `OPLL-EX` / `OPL2+ADPCM` / `SCC` / `MIXIER`) で突き合わせ、
表に合わせて実装を修正した。

### 仕様表の確認内容と判断

- Memory Mapped I/O のアドレスが全面的に変更されていた。
- ミラー (`3FE0h`-`3FFFh`) は廃止し、`7FE0h`-`7FFFh` のみでデコードする。
- OPLL の I/O ポートは `7Ch` / `7Dh` の 1 組のみとし、`7Ah` / `7Bh` は廃止する。リセット時は有効。
- SSG のチャンネル別音量レジスタ (`20h`-`26h`) と ADPCM PAN (OPL2 `FFh`) は未実装だったので今回実装する。

### 最新の Memory Mapped I/O マップ

| アドレス | 機能 |
| --- | --- |
| `7FF0h` / `7FF1h` | SSG Register Address / Write |
| `7FF2h` / `7FF3h` | OPL2 Register Address / Value |
| `7FF4h` / `7FF5h` | OPLL Register Address / Value |
| `7FF6h` | I/O Enabler1 (b0 = OPLL) |
| `7FF7h` | SSG Volume |
| `7FF8h` | OPLL Volume |
| `7FF9h` | OPL2 Volume |
| `7FFAh` | ADPCM Volume |
| `7FFBh` | SCC Volume |
| `7FFFh` | I/O Enabler2 (b7 = TIMER, b1 = SSG, b0 = OPL2) |

### 実施した変更

- `src/y8960_address_decode/y8960_address_decode.v`
  - OPLL の I/O ポートを `7Ch` / `7Dh` の 1 組へ統合した (`7Ah` / `7Bh` を廃止)。
  - `ff_opll1_io_en` / `ff_opll2_io_en` を `ff_opll_io_en` へ統合し、リセット時は有効 (`1'b1`) とした。
  - MMIO 定数を新アドレス (`7FF0h`-`7FFFh`) へ変更した。
  - MMIO ウィンドウ判定を `bus_address[15:5] == 11'b011_1111_1111` とし、`3FE0h`-`3FFFh` のミラーを廃止した。
  - I/O Enabler1 / Enabler2 を `bus_address[4:0]` の完全一致に変更した。
  - I/O Enabler2 の SSG ビットを b4 から b1 へ変更した。
- `src/msx_slot/msx_slot.v`
  - ミキサー音量レジスタのアドレスを `7FF8h`-`7FFCh` から `7FF7h`-`7FFBh` へ変更した。
- `src/ssg/ssg_core.v`
  - チャンネル別音量レジスタ `20h`-`22h` (SSG1) / `24h`-`26h` (SSG2) を追加した。初期値 `128`。
  - bit7 が `1` のときは `128` (100%) として扱う。
  - `w_out_level` (10bit) に音量を乗じて `>>7` し、その結果へ既存の PAN 乗算を適用する構成とした。
- `src/adpcm_patch/adpcm.v`
  - PAN レジスタ `FFh` を追加した。初期値 `128`。
  - `jt10_adpcm_drvB` の `pcm55_l` を使い、`pan_lut` のゲインを乗じて L / R を生成する。
- `src/y8960_cartridge_tangprimer25k.v`
  - `msx_slot` の `memory_io_en` を MMIO 全体の有効条件 (`w_mixer_reg_en`) へ統一した。
- `src/test001/run.bat` / `src/test001/gowin_pll_dummy.v` / `src/test001/gowin_clkdiv_dummy.v`
  - SN76489 削除および新規モジュール追加に追従していなかったファイルリストを `.gprj` に合わせて再構成した。
  - 動作していなかった `Gowin_PLL` のシミュレーションモデルを修正し、`Gowin_CLKDIV` のモデルを新規追加した。
- `src/ssg/test001/run.bat`
  - `pan_lut.v` のコンパイルが欠けていた既存の不具合を修正した。

### 検証結果

- `src/y8960_address_decode/test001`: 全テストPASS (エラー0、警告0)。
- `src/msx_slot/test001` / `test002`: 全テストPASS (エラー0、警告0)。
- `src/ssg/test001`: PAN に加えて音量レジスタのテストを追加し、全テストPASS (エラー0、警告0)。
- `src/mixer/test001`、`src/opl2_patch/test001`、`src/sfrom/test001`、`src/sfrom/test002`、`src/adpcm_test`: エラー0、警告0。
- `src/test001` (トップ階層): ファイルリスト修正後、エラー0、警告0で完走。
- Gowinプロジェクト内Verilog 76ファイル一括コンパイル: エラー0、警告0。
- Gowin Synthesis: エラー0で完了。Logic 6630/23040 (29%)、Register 5657/23280 (25%)、BSRAM 12/56 (22%)。

### 既知の課題 (今回のスコープ外)

- `src/timer/test001`、`src/timer/test002`、`src/i2s_audio/test001`、`src/ssram/test001`、
  `src/ssram/test002`、`src/system_controller/test001` は本件の変更対象外のソースで、
  以前から失敗している (ポート不一致、アサーションエラー)。
- ADPCM は `w_cen55` / `ff_adpcm_data` / `ff_adpcm_access` が未駆動のため合成で丸ごと最適化除去される。
  ADPCM 本体の結線は未完了で、今回追加した PAN も実機では未確認。
- 実機での左右定位および音量の確認は未実施。

## 2026-10-17 夜: Y8950互換のOPL2+ADPCM内部ミックス

### 仕様確認

- Y8950仕様書を確認し、EG-CONTROLは`1Bh`ではなく`12h`であることを確認した。
- EG-CONTROLはADPCM音声の出力レベルを制御し、式は`AUDIO OUT = VOICE * EG`。
- 現行のADPCMラッパーは`12h`を`reg_envelope_control`へ格納し、`jt10_adpcm_drvB.aeg_b`へ既に接続していた。
- OPL2とEG適用後のADPCMをOPL2ラッパー内で合成し、外部ミキサーでは1つのOPL2音源として扱う。

### 実施した変更

- `src/opl2_patch/opl2.v`
  - ADPCMの独立した外部音声出力ポートを削除した。
  - 左右それぞれでOPL2とADPCMを符号付き加算し、16-bitへ飽和してOPL2音声出力とした。
- `src/adpcm_patch/adpcm.v`
  - `cen55`の誤接続と、ADPCM再生用SRAM読み出しデータ／要求の未結線を修正した。
  - CPUからのADPCMメモリアクセスと再生コアの読み出し要求をラッパー内で調停するようにした。
  - これによりGowin合成でADPCMコアが最適化除去される問題を解消した。
- `src/mixer/mixier.v`
  - ADPCM音声入力とADPCM Volume入力を削除した。
  - 時分割ミキサーを5音源10ステートから4音源8ステートへ縮小した。
- `src/msx_slot/msx_slot.v`
  - ADPCM Volumeレジスタを削除した。
  - SCC Volumeを`7FFBh`から`7FFAh`へ移動し、ミキサーレジスタ範囲を`7FF7h`-`7FFAh`とした。
- `src/y8960_cartridge_tangprimer25k.v`
  - ADPCM音声とADPCM Volumeのトップ階層配線を削除した。
- `doc/spec/Y8960_Specifications.xlsx`
  - MemoryMappedIOは更新済みの`7FFAh: SCC Volume`、`7FFBh: Reserved`と実装を一致させた。
  - `OPL2+ADPCM`シートで重複していた`1Bh: EG CONTROL`を`N/A`へ修正し、Y8950互換のEG-CTRLは`12h`のみとした。

### 検証

- `src/opl2_patch/test001`
  - `12h`のEG-CONTROL書き込み、OPL2+ADPCMの正負加算、正負飽和を確認。
  - ADPCM再生コアからSRAMへの読み出し要求とデータ取り込みを確認。
- `src/mixer/test001`
  - 4音源化後の100%出力、音源別音量、全ミュートを確認。
- `src/msx_slot/test001`
  - SCC Volumeの`7FFAh`書き込みと、廃止した`7FFBh`がLocal BUSへ流れることを確認。
- `src/msx_slot/test002`
  - アドレスデコードとの統合テストを確認。
- 上記テストはいずれもエラー0、警告0、全テストPASS。
- トップ階層テスト: エラー0、警告0。
- Gowinプロジェクト内RTL 74ファイル一括コンパイル: エラー0、警告0。
- Gowin Synthesis: エラー0で完了。ADPCM関連の未駆動／最適化除去警告は解消。
  Logic 7204/23040 (32%)、Register 6118/23280 (27%)、BSRAM 13/56 (24%)。

## 2026-10-17 夜: OPLL左音声とレジスタ取りこぼしの修正

### 原因

- OPLLラッパーは外部バス要求をIKAOPLL内部の同期回路が処理する前に完了扱いとしていた。
- アドレス／データを内部処理完了まで保持していなかったため、後続アクセスの値で上書きされていた。
- 9チャネルレジスタはデータ要求受理後、対象チャネルのシリアル位置まで待って反映される。
  反映前に次のアドレスを渡すと、保留中の書き込みがキャンセルされていた。
- PAN値のシリアル列とDAC音声サンプルが1チャネル分ずれており、CH1の音声へ`50h`ではなく
  `51h`のPAN値が適用されていた。

### 実施した変更

- `src/ikaopll_patch/opll.v`
  - 外部バス要求を保持する32段・10-bit FIFOを追加した。
  - IKAOPLLへのCSを、内部のアドレス／データ要求受理まで保持するシーケンサへ変更した。
  - データ書き込みでは、9チャネルレジスタの対象位置への反映完了を待ってから次の要求を処理する。
  - 読み出し要求は即時完了として扱い、書き込みシーケンサを停止させないようにした。
  - FIFOは単一配列へまとめ、Gowinが1個のRAMとして推論できる形にした。
- `src/ikaopll_patch/IKAOPLL_reg.v`
  - 内部アドレス要求、データ要求、9チャネルレジスタ反映完了をラッパーへ通知する出力を追加した。
- `src/ikaopll_patch/IKAOPLL.v`
  - 上記の内部書き込み状態をラッパーへ中継する出力を追加した。
- `src/ikaopll_patch/IKAOPLL_modules/IKAOPLL_dac.v`
  - PANパイプラインを1段追加し、`50h`～`58h`とCH1～CH9の音声サンプルを一致させた。
- `src/ikaopll_patch/test001`
  - 連続したアドレス／データ書き込みによる発音テストを追加した。
  - 全9チャネルをPAN=`1`、`128`、`255`に設定し、左端、中央、右端の出力を確認した。
  - CH1だけを右端へ設定し、`50h`がCH1へ対応することを確認した。

### 検証結果

- OPLL単体テスト: エラー0、警告0。
  - PAN=`128`: L=7、R=7。
  - PAN=`1`: L=10、R=0。
  - PAN=`255`: L=0、R=430。
  - CH1のみ右端: L=0、R=50。
- トップ階層RTL一括コンパイル／シミュレーション: エラー0、警告0。
- Gowin Synthesis: エラー0で完了。
  - OPLL書き込みFIFOは単一RAMとして推論された。
  - BSRAMは13/56のままで、FIFO追加によるBSRAM使用数の増加はない。
- 原本の`src/ikaopll`は変更していない。

## 2026-10-17 夜: 音源コアのリセット中クロックイネーブル修正

### 原因

- トップ階層の`ff_enable`は、システムリセット中に`0`へ固定される。
- IKAOPLL内部のリセット同期段は`i_phiM_PCEN_n=0`のときだけ進むため、外部`enable=0`のままでは
  `reset_n=0`を内部へ取り込めなかった。
- JTOPL2はリセットを最低6回の`clk & cen`期間保持する必要があり、一部の内部リセット処理も
  `cenop`でゲートされているため、同様にリセット中の`enable=0`が不適切だった。
- ADPCM本体の主要レジスタは非同期リセットだが、複数の処理段が`cen`で進むため、同じ方針で
  リセット中のコアイネーブルを保証する必要があった。

### 実施した変更

- `src/ikaopll_patch/opll.v`
  - `w_core_enable = enable | ~reset_n`を追加した。
  - IKAOPLLのクロックイネーブルには`w_core_enable`を使用し、リセット中は必ず内部クロックを進める。
- `src/opl2_patch/opl2.v`
  - JTOPL2の`cen`へ`w_core_enable = enable | ~reset_n`を接続した。
- `src/adpcm_patch/adpcm.v`
  - ADPCMコアの`cen`へ`w_core_enable = enable | ~reset_n`を接続した。
- `src/ikaopll_patch/test001/tb.sv`
  - 外部`enable=0`のままリセットをアサートし、解除後に初期PANと発音を確認するテストへ変更した。

### 検証結果

- OPLL単体テスト: 外部`enable=0`でリセット後、全テストPASS。エラー0、警告0。
- OPL2+ADPCM単体テスト: 全テストPASS。エラー0、警告0。
- トップ階層RTL一括コンパイル／シミュレーション: エラー0、警告0。
- Gowin合成、配置配線、Bitstream生成: エラー0で完了。
- 原本の`src/ikaopll`、`src/opl2`、`src/adpcm`は変更していない。

## 2026-10-17 夜: OPLL FIFO縮小とPAN初期値の明示化

### 実施した変更

- `src/ikaopll_patch/opll.v`
  - OPLL書き込みFIFOを32段から8段へ縮小した。
  - ポインタを5-bitから3-bit、カウンタを6-bitから4-bitへ縮小した。
- `src/ikaopll_patch/IKAOPLL_reg.v`
  - PAN専用の9チャネルシフトレジスタ`IKAOPLL_panreg`を追加した。
  - 従来はリセット中のシフト動作でPAN値`128`を9段へ投入していたが、全9段をリセット時に
    明示的に`128`へ設定する構成へ変更した。
  - 未使用のシリアル位相でもPAN値を`128`とし、意図しない左端値`0`を出さないようにした。
- `src/ikaopll_patch/test001/tb.sv`
  - PANレジスタへ一度も書き込まずに発音し、初期定位が中央になるテストを追加した。
  - 8段FIFOが満杯の場合は空きができるまで待つよう、テスト側のタイムアウトを拡張した。

### 検証結果

- OPLL単体テスト: エラー0、警告0。
  - PAN未書き込み: L=7、R=7。
  - PAN=`128`: L=8、R=8。
  - PAN=`1`: L=430、R=0。
  - PAN=`255`: L=0、R=50。
  - CH1のみ右端: L=0、R=1160。
- トップ階層RTL一括コンパイル／シミュレーション: エラー0、警告0。
- Gowin Synthesis: エラー0で完了。
  - Register 6222、LUT 6640、ALU 674、BSRAM 13。
- 原本の`src/ikaopll`は変更していない。

### 実機確認

- リセット中のコアイネーブル修正を含むBitstreamをFPGAへ書き込み、ユーザー環境で動作を確認した。
- OPLL、OPL2、ADPCMのリセットが成立しない問題は解消した。
- ユーザー確認結果: 「無事動いた」。
- 全機能の確認は未完了のため、次回はADPCM再生、OPL2+ADPCM内部ミックス、SSG個別音量、SCC音量、I2S左右出力を確認する。

本日の作業はここで終了する。

## 2026-10-18 朝: 起動時 SPI ROM → SerialSRAM ブートコピー

### 仕様

- MSX リセット解除ごとに、SPI ROM `7E0000h`～`7FFFFFh`（128KB）を SerialSRAM `00000h`～`1FFFFh` へコピーする。
- コピー中は `wait_n=0`（`SLOT_WAIT=1` → `/WAIT=0`）として MSX 本体を待たせる。
- SerialSRAM メモリマップ:
  - `00000h`～`1FFFFh`: ROM（コピー後は書き込み禁止、SCC BANK#0～#15）
  - `20000h`～`3FFFFh`: RAM（SCC BANK#16～#31）
  - `40000h`～`7FFFFh`: ADPCM RAM
- RAM／ADPCM 領域は起動時に初期化しない（MSX リセットでも内容を保持）。

### 実施した変更

- `src/system_controller/system_controller.v`
  - 既存の未完成ブートコピー処理（`780000h` から 512KB、SRAM アドレス 1-bit）を作り直した。
  - SPI ROM へ `06h/00h`（ROM 選択）→ `00h` + アドレス 3byte → `02h`（バーストリード）を発行し、
    128KB 読み出し後に `07h`（Access End）で CS を解放する。
  - SPI ROM 読み出しと SerialSRAM 書き込みを 1byte バッファでオーバーラップさせた。
  - ROM／SRAM とも要求受理の翌クロックで ready が落ちるため、要求後に 1 クロックのギャップを挟んで ready を判定する。
  - `init_sram_bus_address` を 19-bit に修正。
- `src/y8960_cartridge_tangprimer25k.v`
  - `slot_wait` の極性を修正（`slot_wait = ~w_wait_n`）。従来はコピー完了後に MSX が永久 WAIT になる配線だった。
  - `w_init_sram_bus_address` を 19-bit に修正。
  - コピー中は SRAM アービタ（CPU／ADPCM）と system_controller 通常経路の ready／rdata_en をマスクした。
- `src/ikascc_patch/scc_bank.v`
  - RAM モードでも BANK#0～#15（`scc_ma[17]=0`）への書き込みを禁止し、BANK#16～#31 のみ書き込み可とした。
- `src/system_controller/test002/`（新規）
  - `system_controller` + `ip_spi_rom` + `ssram` + Flash／SRAM モデルによるブートコピー試験。
  - 旧 `test001` は旧アーキテクチャ（sfrom＋バースト I/F）向けで既にロード不能のため触っていない。

### 検証結果

- `system_controller/test002`: 全テスト PASS、エラー0、警告0。
  - 128KB 全バイト一致（電源投入相当、MSX リセット相当の 2 回）。
  - `20000h`、`40000h` の番兵値は上書きされない。
  - コピー完了後に SPI ROM CS が解放される。
  - コピー時間: 約 58ms。
  - `scc_bank` 書き込み保護: 互換モード全バンク RO、RAM モード #0～#15 RO／#16～#31 RW。
- トップ階層 RTL コンパイル／スモークシミュレーション: エラー0、警告0。
- Gowin 合成・配置配線・Bitstream 生成: 完了。
  - Logic 7312/23040、Register 6260、CLS 6466、BSRAM 19/56。

### 未解決・次にやること

- **MSX から SerialSRAM ROM 領域を読む経路が未完成**（既存の問題）。
  - `scc_bank` の `bus_ready`（`w_scc_bank_ready`）がどこにも接続されておらず、`y8960_address_decode` は SCC コアの即時 ready を使うため、
    SerialSRAM の読み出し完了前に `msx_slot` がサイクルを終える。
  - SCC コアの `o_ROMCS_n`（負論理）が `scc_memory_cs` として出ているが `scc_bank` では未使用。
  - このため合成で `scc_bank` が "swept" される（NL0002）。
  - SerialSRAM 読み出しレイテンシ（アービタ待ち最大 8clk＋QPI リード）が Z80 のメモリリードサイクルに収まるか、
    WAIT を使うかを含めて設計が必要。
- `ssram` は MSX リセットのたびに EQIO を再送するが、SRAM 側は既に QPI モードのため、実機で問題がないか要確認
  （必要なら RSTQIO を先行発行）。
- 実機での確認: 起動時 WAIT 解除、SPI ROM への 7E0000h イメージ書き込みとコピー結果。

## 2026-10-18: ブートコピー高速化と MSX → SerialSRAM 経路（上記ドラフトを置き換え）

### 合意した設計方針

- コピーは SPI ROM ストリーム読み出し＋ SerialSRAM バーストライトで高速化（クロックは 43MHz のまま）。
- MSX リードは `/WAIT` で待たせて SerialSRAM から読む。MSX ライトは 2 段ポステッドライト。
- SerialSRAM のアービトレーションは CPU 優先（ADPCM は空き時間）。
- MSX リセットのたびに再コピーする。

### 実施した変更

- `src/ssram/ssram.v`（全面改修）
  - `bus_burst` 入力を追加。連続アドレスの書き込みを CE# Low のまま継続（`c_state_burst_wait` で SCLK 停止して次バイト待ち）。
    バースト中に読み出し要求が来たら CE# High（約 46ns）を挟んで再開。
  - 初期化時に RSTIO（SQI モードの `FFh`）を送ってから EQIO を送る。MSX リセット時の再初期化でも SPI/SQI どちらの状態からでも復帰できる。
  - ready/ack を toggle ハンドシェイクに変更。`bus_rdata_en` は ready 復帰と同じクロックの 1clk パルス。
  - SCLK をレジスタ出力化（グリッチ防止。タイミングは従来の `ff_sclk_div` と同一）。
- `src/ssram/ssram_test_model.v`
  - RSTIO 対応、`VERBOSE` パラメータ追加。
  - 読み出しデータの駆動タイミングを `ssram.v` の実機パス（ダミー 6 ニブル＋`c_state_read_wait`）に合わせた
    （従来モデルは count 11/12 で駆動しており、どのパスとも合っていなかった）。
- `src/spi_rom/ip_spi_rom.v`
  - コマンド `0Bh`（ストリームリード）を追加。`stream_rdata/stream_valid/stream_ready/stream_stop` ポートで 1 バイトずつ受け渡す。
- `src/system_controller/system_controller.v`
  - ブートコピー FSM をストリーム＋バーストライト方式に変更。最終バイトで `stream_stop`、`06h/FFh` で ROM 選択解除。
- `src/ssram/sram_arbiter.v`（作り直し）
  - 8clk 周期の固定スロット方式を廃止。CPU 優先、受理時に owner を記録し `rdata_en` を振り分ける。
  - CPU: `{1'b0, cpu_address}`（00000h～3FFFFh）、ADPCM: `{1'b1, adpcm_address}`（40000h～7FFFFh）。
- `src/ikascc_patch/IKASCC_vrc_s.v`
  - `o_ROMCS_n` を `4000h`～`BFFFh` かつ SCC レジスタ窓以外のときだけアクティブにした（組合せ）。
- `src/ikascc_patch/scc.v`
  - IKASCC の `o_DB` は非選択時 `00h` のため、トップの AND 合成で他デバイスの読み出しデータを潰していた。
    `bus_rdata_en=0` のときは `FFh` を出すよう修正。
- `src/ikascc_patch/scc_bank.v`（作り直し）
  - 読み出し: 検出と同時に `/WAIT` を出し、SerialSRAM のデータを `msx_slot` に渡した時点で解除。
  - 書き込み: Z80 の書き込みサイクルは `/WAIT` が間に合わないため 2 段キューにポステッドライト。
    キュー満杯の間は `/WAIT` を出して次のバスサイクルを止める。キューのライトはリードより先に実行（リードアフターライト保証）。
  - 書き込み可能は RAM モードの BANK#16～#31 のみ（SerialSRAM `20000h`～`3FFFFh`）。ROM 領域へは書かない。
  - `bus_ready` 出力を廃止し `wait_n` 出力を追加。
- `src/y8960_cartridge_tangprimer25k.v`
  - stream／burst 配線、`slot_wait = ~(w_wait_n & w_scc_bank_wait_n)`、`scc_bank` の新ポート接続。

### 検証結果

- `system_controller/test002`: 全 PASS。
  - コピー時間 **約 26.06ms**（旧ドラフト 58ms）。128KB 全バイト一致（電源投入／MSX リセットの 2 回）。
  - コピー後の SerialSRAM 単発リード／ライト（ROM・RAM・ADPCM 領域）も一致。
- `ikascc_patch/test001`（新規）: 全 PASS。
  - `msx_slot`＋アドレスデコーダ＋SCC＋`scc_bank`＋アービタ＋`ssram`＋モデル、Z80 バスモデル（T2/Tw 立下りで `/WAIT` サンプル）。
  - 互換モード／RAM モードのバンク切替、全読み出しが `/WAIT` 付きで正しいデータ、リードアフターライト、連続 16 ライト、
    ROM バンク書き込み禁止、SCC レジスタ窓および `4000h`～`BFFFh` 外は SerialSRAM に触れない、
    ADPCM 同時読み出し（403 回、エラーなし）。
  - 読み出し時の WAIT は ADPCM 競合ありで最大 2 T-state。
- トップ階層 `test001`: コンパイル／エラボレーション エラー0、警告0。
- Gowin 合成・配置配線・Bitstream 生成: 完了、全クロック TNS 0。
  - Logic 7284/23040（32%）、Register 6317、CLS 6483（57%）、BSRAM 19/56、DSP 15.5/28。
  - clk_171m の最悪スラックは +0.089ns（`ssram` の `ff_powerup_wait`）。
  - `scc_bank` 除去の NL0002 警告は解消。

### 注意点・未確定事項

- 23AA04M の SQI 高速リードのダミーサイクル数はデータシート未確認（Microchip のサイトが取得不可）。
  `ssram.v` の実機実績（ダミー 6 ニブル＋実機専用 `c_state_read_wait`）を前提にしている。
- RSTIO 追加と SCLK のレジスタ化は実機での確認が必要。
- RAM モードで BANK0 に RAM バンク（#16～#31）を割り当てた場合、`4?FBh`～`4?FFh` へのモード／バンクレジスタ書き込みが
  SerialSRAM にも書かれる（従来の `scc_bank` と同じ挙動）。`IKASCC_vrc_s.v` のコメントにある「BANK0 is ROM only」に
  合わせるべきかは要確認。
- `ssram/test001`、`ssram/test002`、`system_controller/test001` は旧インターフェース（`clk_258m`、`sfrom` 等）向けで
  今回以前からロード不能。今回は触っていない。

### 実機で確認すること

- 起動時（電源投入／MSX リセット）の WAIT 解除と、SPI ROM `7E0000h` イメージが SCC バンク経由で読めること。
- RAM モードでの BANK#16～#31 読み書き、ADPCM 再生中の MSX アクセス。
## 2026-10-18 午前: 23AA04M データシート確認と BANK0 書き込み禁止

### データシート（DS20006862A）で確認した内容

- SQI 高速リード `0Bh`: コマンド 2 クロック＋アドレス 6 クロック＋ダミー 3 バイト（6 クロック）＋データ（Table 3-1、Figure 3-16）。
  `ssram.v` のダミー 6 ニブルは仕様どおり。
- RSTIO `FFh`: 「全 SIO High で 8 クロックなら、どのモードからでも受け付ける」（Table 3-1 Note 4）。`ssram.v` の RSTIO（SQI で 2 クロック）も SQI モード時の仕様どおり。
- AC 特性（143MHz 品）: TV（Clock Low からの Output Valid）最大 7ns、THO 最小 0ns、TCSD（CS Disable）最小 10ns。
  - SCLK 85.9MHz の Low 期間は 5.8ns で TV より短いため、データシートどおりのクロックでは取り込めない。
    `ssram.v` の実機専用 `c_state_read_wait` は、ニブル N を 1 クロック後（クロック N+1 の立上り）で取り込む補正になっている。
  - この取り込みは「TV＋基板・I/O 往復遅延 > 5.8ns」を前提にしている（THO 最小 0ns のため、データシート上の保証はない）。
    実機で読み出しが不安定な場合は、読み出し時だけ SCLK を下げるなどの対策が必要。

### 実施した変更

- `src/ssram/ssram_test_model.v`
  - 読み出しデータを、データシートどおりのクロック（14, 15, 以降は連続バイト）で、立下りから `T_V`（7ns）遅れて駆動するようにした。
    前回の「count 15/16 でゼロ遅延駆動」の暫定合わせは廃止した。
  - `T_V` の単位はシミュレータの分解能（`vsim -t 1ps`）。
- `src/system_controller/test002/tb.sv`: 他の tb と単位を揃えるため `timescale` 指定を削除した（周期は元から ps 値）。
- `src/ikascc_patch/scc_bank.v`: RAM モードで BANK0 に RAM バンク（#16～#31）を割り当てても、`4000h`～`5FFFh` への書き込みは SerialSRAM に書かない。
  モード／バンクレジスタ（`4?FBh`～`4?FFh`）への書き込みが RAM を壊さない。
- `src/ikascc_patch/test001/tb.sv`: BANK0=#18 での書き込み禁止（データ書き込み、レジスタ書き込みとも）の試験を追加した。

### 検証結果

- `ikascc_patch/test001`: 全 PASS（BANK0 試験を含む）。
- `system_controller/test002`: 全 PASS（コピー 26.06ms、128KB 一致）。
- トップ `test001`: エラー0、警告0。
- Gowin: Bitstream 生成完了、全クロック TNS 0。Logic 7275（32%）、CLS 6447（56%）、BSRAM 19/56。
  - clk_42m の Fmax は 42.970MHz で、制約 42.951MHz に対する余裕が小さい。
## 2026-10-18: System Controller を仕様書 (doc/spec/system_controller.md) に合わせて修正

### 仕様への合わせ込み (`src/system_controller/system_controller.v`)

- I/O 40h: 80h 書き込みで有効化（以前は 40h）。有効時のリードは 7Fh（以前は BFh）。
- I/O 41h: デバイス ID は 02h (Y8960 Cartridge)。`device_id` パラメータの既定値とトップ階層の指定を 61h から 02h に変更した。自 ID 選択時のリードは FDh。
- I/O 42h: ファンクションセレクトを新設。01h のときリードは FEh、それ以外は FFh。デバイスの選択が外れるか、無効化されると 00h に戻る。
- I/O 43h-47h: Config ROM Reader/Writer（アドレス L/M/H、コマンド、データ）。以前は 42h-46h で、1 つずれていた。アドレスは 24bit。
- 「応答しない」は `bus_rdata_en=0` で実現した。対象は、無効時の 40h-4Fh、他 ID 選択時の 41h-4Fh、ファンクション 01h 以外の 43h-4Fh、および 48h-4Fh。
- 46h のリードは FFh を返す（仕様に記載がないため）。04h-FFh のコマンドは無視する。

### Config ROM 操作の作り直し

- 以前の FSM には、次の不具合があった。
  - ブートコピー後に ROM が非選択のまま（`06h` に FFh）で、CS が出なかった。
  - 消去時に Write Enable を出していなかった。
  - `ip_spi_rom` が ready を落とすコマンドの直後に、次のコマンドを取りこぼしていた。
- ブートコピーと同様に、コマンド列を順に発行するシーケンサーにした。各コマンドの後に 1 クロックのギャップを置く。
  - 共通: `06h` / データ `00h`（ROM 選択）→ `00h` / アドレス L, M, H
  - 読み出し: `01h` → データポートのリード → `47h` にラッチ
  - 書き込み: `03h` → データ（WREN + Page Program）→ `07h`（CS を戻して書き込み実行）
  - セクター消去: `08h`（WREN）→ `09h`（D8h、64KB ブロック消去）。ユーザー指示により 64KB 単位とした。
  - チップ消去: `04h` → データ書き込み（WREN + 60h）
- 書き込み・消去はコマンドを発行するだけ。完了は MSX 側が読み出しコマンドでポーリングして確認する（ユーザー指示）。
- `src/spi_rom/ip_spi_rom.v`: 03h (burst write) で、アドレス下位バイトの 00h 強制をやめた。Page Program に実アドレスを送るので、1 バイト単位で書ける（ユーザー指示）。

### 検証

- 新規 `system_controller/test003`: 全 PASS。
  - 確認内容: 有効化/無効化、デバイス ID、ファンクション、無応答の確認、アドレスレジスタ、ROM 読み出し、ページ途中アドレスへの 1 バイト書き込み、ブロック消去の範囲、予約コマンドの無視。
  - 書き込み・消去の完了確認はポーリングで行った。
- `system_controller/test002`（ブートコピー）: 全 PASS。
- トップ `test001`: エラー 0。
- Gowin: Bitstream 生成完了、全クロック TNS 0。Logic 7271（32%）、CLS 6497（57%）、BSRAM 19/56。clk_42m の Fmax は 43.524MHz。
- 旧 `system_controller/test001` は旧仕様（ID 61h、旧インターフェース）のままで、使用しない。
### ステータス読み出しコマンドと更新ツール

- `system_controller`: コマンド `04h`（ステータス読み出し）を追加した。
  - 中身は `ip_spi_rom` の `05h` → データリード → `07h`。結果は 47h に入り、bit0 が BUSY。
  - test003 は BUSY ポーリングで完了を待つ形にして、全 PASS。
- コマンドのビジー時間（シミュレーション）: 00h 2.35µs、01h 2.77µs、02h 2.37µs、04h 1.40µs。
- 注意: `msx_slot` は I/O に WAIT を出さない。シーケンサー動作中の I/O アクセスは捨てられ、リードは FFh になる。
  - ソフト側で対処する。46h に書いた後は、40h が 7Fh を返すまでポーリングする。仕様書にも記載した。
  - ハードで WAIT を出す案は未実施。
- `tool/y8960upd.asm` → `Y8960UPD.COM`（ZMA でビルド、`tool/build.bat`）。仕様は `tool/y8960upd.md`。
  - 引数なし: 使い方と、Cfg/BIOS のバージョン（7DFF00h / 7DFF10h）を表示する。
  - `/C file`: Config データ（最大 7D0000h）を書く。
  - `/B file`: BIOS データ（128KB 固定）を 7E0000h に書く。
  - 書き込みの流れ: ヘッダーのシグネチャ確認 → 64KB ブロック消去 → 書き込み（FFh はスキップ）→ ベリファイ。
  - バージョン領域: 32 バイトを退避し、7D0000h ブロックを消去して、両方のバージョンを書き戻す。
  - FCB を使うので MSX-DOS1 でも動く。
  - Python の Z80 エミュレータ（BDOS とコントローラのモック）で動作を確認済み。実機は未確認。
- BIOS の更新後は、リセットしてブートコピーさせる必要がある。

## 2026-10-18 午後: 実機で MSX が起動しない件の調査（SX-2）

### 症状

- 最新 RTL を書き込んだカートリッジを装着すると MSX が起動しない。`slot_wait = 1'b0`（WAIT なし）にしても同じ。

### 見つかった不具合と修正

- `msx_slot` は、自スロット以外も含むすべての I/O サイクルでトランザクションを有効（`ff_active`）にする。その間に `bus_rdata_en` が来ると、データを取り込んでデータバスを駆動していた。
- WAIT なしでは、SerialSRAM の読み出し応答がサイクル終了後に届く。特にブートコピー中は約 26ms 待たされる。
  遅れた応答がたまたま実行中の別の I/O サイクル（VDP 98h のリードなど）に乗ると、データバスを駆動してバス競合になる。
  - `msx_slot.v`: データを受け付けるのは、まだ続いているリードサイクル（`!ff_write` かつ RD がアクティブ）のときだけにした。
  - `scc_bank.v`: `bus_io` 入力を追加。I/O サイクル中は `bus_rdata_en` を出さない。トップと `ikascc_patch/test001` の接続も更新。

### 検証

- `ikascc_patch/test001` に WAIT なしのケースを追加した。
  - 後続の I/O リード/ライトやメモリライトで、データバスを駆動しないことを確認する。
  - SerialSRAM を止めた状態（ブートコピー中の再現）も含む。
  - 旧コードではエラーが出ること（98h リード中の駆動）を確認した。新コードは ALL PASS。
- `msx_slot/test001`、`msx_slot/test002`、`system_controller/test002`、`system_controller/test003`、`y8960_address_decode/test001`、トップ `test001`: すべてエラー 0。
- Gowin: 全クロック TNS 0。clk_42m の Fmax は 44.893MHz。ビルドはトップの `slot_wait = 1'b0`（ユーザー変更）のまま。

### 未解決（WAIT ありで起動しない場合の候補）

- ブートコピー（`sram_ready`、SPI ROM ストリーム）や SerialSRAM の読み出しが完了せず、`/WAIT` が解除されない。
- SPI ROM `7E0000h` に古いデータが残っていて、4000h に "AB" ヘッダーが見え、MSX がそれを実行してしまう。
- WAIT なしでは、SerialSRAM の読み出しデータが間に合わないため、ROM 内容は正しく見えない（今回の修正は、バス競合の防止だけ）。

## 2026-10-18 午後: System Controller の検出失敗と読み出しバスの修正

### 実機からの報告

- 自作 MSX1 で、40h の読み出しが有効化の前後とも 120（この機種の未接続ポートの値）となる。
- PLAY で音は出るが、40h の OUT が受理されているかは未確認。

### 調査結果と修正

- 既存の System Controller 単体テストは、MSX スロットやトップの読み出しデータ合成を通していなかった。
  トップ `test001` も従来はリセット後に終了するだけだったため、検出失敗を検査できていなかった。
- トップに実際の I/O サイクルによる検出テストを追加すると、40h の OUT は受理され、
  System Controller 自体は 7Fh を返すが、MSX 側で 00h を読む不具合が再現した。
  実機の 120 そのものを再現したわけではない。
- `timer/msx_timer.v`:
  - 未選択でもアドレス下位 2bit に応じて `bus_rdata_en` を出していた。
    選択された有効なリード、または受理済みのタイマーコア・リードの完了時だけに限定した。
  - コアの遅延応答はデータ到着時にラッチする。
  - 応答していないときの `bus_rdata` は、トップの AND 合成の中立値 FFh にする。
- `opl2_patch/opl2.v`:
  - 応答していない間も保持データ（リセット直後は 00h）を出力し、AND 合成で他デバイスのデータを潰していた。
    `bus_rdata_en=0` のときは FFh を出すよう修正した。原本 `src/opl2` は変更していない。

### 検証

- トップ `test001`: 40h=7Fh、41h=FDh、42h=FEh を実際の MSX データバスで確認。
  I/O 上位アドレスが 80h の場合、有効化解除後の 40h～43h、無関係な 98h の非駆動も確認。PASS。
- `timer/test002`: 4 コアのモードレジスタ読み戻し、非選択時・valid なしの非応答を追加確認。
  既存のタイマー・割り込みテストもエラー 0。
- `opl2_patch/test001`: 非応答時 FFh のアサーションを追加。既存テストもエラー 0。
- Gowin: ビットストリーム生成完了。全クロックの Setup/Hold TNS 0、clk_42m の Fmax は 43.623MHz。
  現在のトップは通常の WAIT 接続 `slot_wait = ~(w_wait_n & w_scc_bank_wait_n)`。今回は変更していない。
- 修正後 RTL の実機確認は未実施。BASIC の `OUT &H40,128:PRINT INP(&H40)` で期待値は 127。

## 2026-10-18 午後: BIOS 更新イメージのヘッダー修正

- 実機で 40h から 127 が読めることを確認。その後、`Y8960UPD /B MSXSSE.ROM` が valid image ではないとして拒否された。
- `tool/bios/MSXSSE.ROM` はサイズ 20030h（48 バイトヘッダー＋128KB 本体）で、本体も元の `y8960bas.rom` と一致していた。
  ただし `Y8960_BIOS_IMAGE` に続く 16 バイトが、仕様の 00h ではなくスペース（20h）で埋められていた。
- ユーザー選択により仕様と更新ツールは変更せず、`tool/bios/header.bin` の識別文字列・バージョン末尾の埋めを 00h に修正した。
  バージョン文字列 `MSXSSE_v0.5.0` は維持し、既存の `mk.bat` で `MSXSSE.ROM` を再生成した。
- 再生成後、識別領域32バイトの完全一致、バージョン16バイトの00h埋め、ファイルサイズ、本体128KBの不変を確認済み。
  実機での BIOS 書き込み・ベリファイはこれから。

## 2026-10-18 午後: BIOS 書き込み後の Verify error の診断追加

- 実機で消去の OK 表示後、最初の 7E0000h チャンクのベリファイに失敗した。
  旧表示はチャンクの開始位置しか示さず、正確な不一致位置・実読値は不明。
- `tool/y8960upd.asm` を変更し、不一致アドレス、期待値、実読値、
  直前の完了待ちで最後に取得した SR1 を表示するようにした。Y8960UPD.COM を再アセンブル済み。
- PC の Z80 エミュレータで、7E0000h、7E0100h、7E4001h の不一致とステータス値を注入し、
  正確な表示、異常終了、バージョン領域を更新しないことを確認した。
  実際の MSXSSE.ROM の正常書き込み・ベリファイおよび Config バージョン保持もモック上で確認した。
- 実機の不一致原因は未特定。消去の OK は BUSY=0 の確認であり、消去成功の実証ではない。
  RTL や Flash の保護設定は推測で変更せず、更新版の実読値を得て切り分ける。
- 更新失敗で BIOS が未完成の可能性があるため、復旧ができるまで MSX のリセットには注意が必要。

## 2026-10-18 午後: DIPSW[1] による切り離し起動と再接続

- 実機の診断表示は `Verify error at 7E0002h: expected 5Fh, read 5Bh (last SR1=00h).`。
  先頭の 41h、42h は一致し、次のバイトは bit2 のみ異なる。Flash の書き込み・消去・読み出し、
  または MSX/FPGA データ経路のどこで欠落したかは未特定。SR1=00h だけでは保護解除や消去成功を断定できない。
- 電源再投入後に MSX が起動しなくなったため、ユーザー依頼により DIPSW[1] で
  カートリッジの I/O と ROM/RAM を切り離し、DOS 起動後にリセットせず接続できるようにした。
  未完成の BIOS が起動障害の原因である可能性はあるが、実証はまだ。
- PCB の SW2 は DIPSW1 と GND の接続。OFF/open=1、ON/GND=0 とし、
  制約ファイルで DIPSW[1] の FPGA 内蔵プルアップを有効化した。
- トップで 2 段同期と約 1.5ms のチャタリング除去を行う。初期状態は切り離し。
  接続は /RD と /WR が共に非アクティブのときだけ許可し、途中のサイクルを新規アクセスとして受け付けない。
- 切り離し中は msx_slot へ渡す /RD・/WR を非アクティブにし、データ出力・方向出力・WAIT・割り込みを無効化。
  msx_slot の slot_enable で既存トランザクションと読み出しラッチを破棄し、
  ミキサー MMIO を含む新規バス操作を遮断する。リセット時も ff_rdata_en を確実にクリアする。
- DIP 切り替えによる全体リセットや BIOS 再コピーは行わない。Flash → SerialSRAM コピーは
  切り離し中も継続し、既存の System Controller 設定や音量設定は保持する。
- 復旧手順: 新 RTL を FPGA に書き込み、DIPSW[1] OFF で MSX を DOS まで起動、
  その後 ON にして診断を続行する。更新処理中には切り替えない。
  Verify error 自体は未修正なので、まず 43h/45h の非破壊読み戻し等で bit2 の経路を切り分ける。
  BIOS 更新・ベリファイ成功までは次回起動も OFF とする。更新した BIOS の SRAM 反映には後のリセットが必要。
  詳細手順を tool/y8960upd.md に追記。

### 検証

- トップ test001: OFF 起動中の I/O・メモリアクセス遮断、WAIT/INT/データ出力停止、
  チャタリング除去、読み書き途中での接続禁止、駆動中の読み出しを切り離した際の出力解除、
  リセットなしの設定保持・40h=7Fh の再検出を確認。約26msの起動コピー完了と接続後の ROM 読み出しも確認。
  従来の 40h～42h 検出および無関係ポートの非駆動も含め、エラー・警告 0。
- msx_slot/test001・test002、および ikascc_patch/test001 の既存回帰テストもすべて PASS。
- Gowin: ビットストリーム生成成功。Setup/Hold TNS 0、clk_42m Fmax 43.823MHz。
  出力: fpga/Y8960_Cartridge_TangPrimer25K/impl/pnr/Y8960_Cartridge_TangPrimer25K.fs。
- 新しい切り離し機能の実機検証、および Verify error の原因特定はこれから。

## 2026-10-18 夕方: Verify error（7E0002h: 期待 5Fh / 実読 5Bh）の原因分析と消去チェック追加

### 分析
- 不一致は 7E0002h のみが判明しており、41h・42h は一致、5Fh が 5Bh（bit2 のみ 0）。
- NOR Flash の書き込みは 1→0 しか行えない（旧データ AND 新データ）。旧 BIOS の初期化アドレスが
  415Bh（新は 415Fh）だったとすると、「消去が効かず、旧データの上に新データを書いた」結果と完全に一致する。
  起動時の Flash 7E0000h に旧 "AB" イメージが残っていたことも既知。
- OUT/IN 経路の bit2 欠落は否定的: 40h の 7Fh 読み出し（bit2=1）は正常。OUT (47h),A 直前のバス値は
  オペランド 47h（bit2=1）なので、データ取り込みが早すぎても 0 にはならない。また 41h は正しく書けている。
- RTL の SPI フレームを検証するため、`system_controller/test003` に厳密な SPI フレームモニタを追加した
  （CS# 立ち上がりでバイト境界か、CS# high 時間 50ns 以上）。結果は以下の通りで、すべて仕様通り:
  - 消去: WREN `06` 単独フレーム、続けて `D8 20 00 00`
  - 書き込み: `06`、`02 20 00 10 5A`
  - ステータス: `05 xx`
  - 読み出し: `0B addr dummy data`
  - ALL PASS、エラー 0。したがって RTL のコマンド列に起因する可能性は低い。
- 消去・書き込みが無視される原因の候補（実機の確認が必要）:
  - Flash 側の保護: SR2 の CMP=1（BP=000 と組み合わさると全領域保護）、SR3 の WPS=1（個別ブロックロック）など。
    SR1=00h でも BP は 0 だが、これらは否定できない。
  - なお、書き込みも無視されていれば Flash は旧データのまま。

### 修正（Y8960UPD.COM）
- 従来の消去 "OK" は「BUSY=0 を読めた」だけで、Flash がコマンドを無視しても OK になっていた。
- `rom_wait_ready` で BUSY=1 の観測を記録する。消去後に一度も BUSY=1 を観測できなければ、
  `Erase was not accepted (BUSY never set, SR1=xxh). The ConfigROM may be write protected.` で中止する。
  64KB 消去は数ms 以上かかるので、正常時に誤検出することはない。
- 消去後に各ブロック先頭 256 バイトの FFh チェックを行い、
  `Erase check failed at xxxxxxh: read yyh (last SR1=zzh).` で中止する。
- いずれも、書き込みとバージョン更新の前に止まる。旧 BIOS をさらに壊すことはない。
- Z80 エミュレータのモックで確認: 保護（無視）、非ブランク、旧データ上への正常更新、従来のベリファイ診断。すべて PASS。
- 再アセンブル済み（2576 バイト）。RTL の変更はなし（ビットストリームの再生成は不要）。

### 次の確認
- 新しい Y8960UPD.COM で `/B MSXSSE.ROM` を実行する。
  - `Erase was not accepted` が出た場合: Flash の保護が原因。System Controller に
    SR2/SR3（必要なら JEDEC ID）の読み出しコマンドを追加し、保護ビットを確認する（仕様変更が必要）。
  - `Erase check failed` が出た場合: 消去は受理されたが、別アドレスが消えている、または不完全。
## 2026-10-18 17時台: 実機結果（消去は正常、ランダムな 1bit 化け）
- DIPSW[1] による切り離しが有効な RTL で再ビルド・書き込みしていた。OFF（開放）だと切り離し状態になり、40h が 255 になっていた。
  スイッチを ON（GND）にして認識できた。
- 新しい Y8960UPD の結果: 消去は BUSY 観測・ブランクチェックとも合格。その後
  `Verify error at 7E0015h: expected 39h, read 19h (last SR1=00h)`。
  - 前回不一致だった 7E0002h（5Fh）は今回一致した。前回の「消去が無視された」という仮説は外れで、
    前回もランダムな 1bit 化け（1→0）だったと考えられる。
  - 5Fh→5Bh は bit2、39h→19h は bit5 の欠落。5Fh の bit2 は前後のビットも 1 なので、SPI のサンプリングタイミングずれでは説明しにくい。
- 表示の不具合を修正: display_address の CR で "Erase   : " / "Write   : " のラベルが上書きされていた。
  progress_label を CR の後に毎回表示するようにした（2585 バイト）。
- 次の切り分け（BASIC から）:
  1. 47h の書き込み・読み返しのループバックで、MSX→FPGA のバス取り込みを確認する。
  2. 7E0015h を繰り返し読む。39h と 19h が混在すれば読み出し側の問題。
     毎回 19h の場合は、Flash に 19h と書かれた（書き込み側）か、このアドレスを毎回同じように誤読する（読み出し側）かを
     このテストだけでは区別できない。別の読み出し手段（例: SPI クロックを下げた読み出し）での確認が追加で必要。
## 2026-10-18 17時台後半: スロット応答タイミングと入力レベルの検討
- 実機結果: `Erase check failed at 7E0000h: read 41h`。BUSY は観測されたが 7E0000h は消えていなかった。
  FFh→41h は 1→0 化けが 6bit 必要で、読み出し化けでは説明しにくい。消去アドレス（OUT 45h,7Eh）が化けて、別ブロックを消去した可能性が高い。
- 読み出し応答のタイミング（テクハン Appendix A.7 の I/O サイクル図と RTL から見積もり）:
  - /RD 立ち下がりからデータと BUSDIR の出力までは約 4 クロック（42.95MHz、100ns 弱）。
  - Z80 のサンプリング（T3 立ち下がり、セットアップ min 80ns）までの余裕は約 350ns ある。BUSDIR の min200ns も満たす。
- 基板確認: U4〜U7 は 74LVC8T245。B 側（MSX 側）の VCCB は +5V なので、MSX からの入力の VIH は 0.7×VCCB = 3.5V。
  TTL や NMOS Z80 の High 出力（2.4〜3.4V 程度）ではマージンが不足し、MSX→カートリッジ方向（データ、アドレス、制御）で 1→0 化けが起き得る。
- RTL 上の書き込みデータの取り込み: msx_slot は p_slot_data を同期化せずに 1 段の FF で取り込む。
  System Controller が受け取るのは、FPGA が /WR（と /IORQ）の立ち下がりを検出した次のクロックの値で、
  立ち下がりの約 23〜47ns 後に 1 回だけサンプリングしている。ストローブ側のリンギングやグリッチ、
  あるいはデータ線の遅れがあれば、タイミング起因でも同じような化けが起こり得る。電圧が原因とはまだ断定できない。
- 次の確認（Flash は触らない）:
  1. 47h のループバックテストで、MSX→FPGA の経路に化けがあるかを確認する（電圧とタイミングの区別はできない）。
  2. 電圧の確認はオシロで単独に行う。OUT 中のスロット側 D0〜D7 の High レベルと、74LVC8T245 の FPGA 側出力を測る。
  3. タイミングの確認は /WR とデータ線を同時に観測し、/WR 立ち下がり後 50ns 付近のデータの安定とストローブのリンギングを見る。
- 原因が判明するまで、Y8960UPD による書き込みは中止する（誤ったアドレスを消去・書き込みする危険があるため）。
## 2026-10-18 18時: ループバックテストの結果
- 47h に書いて読み返すと、1→0 方向の化けが頻繁に起きる。化けるのは主に bit7・bit5・bit1・bit0 で、bit6・bit4 は一度も化けていない。
  データ線ごとに化けやすさが違うので、配線やタイミングなど物理的な要因が疑わしい。
- RTL の確認: トップの読み出しデータは全デバイスの AND で合成しているが、timer・opl2・scc・scc_bank・sysctrl は
  応答しないとき FFh を出す。ssg_core が FFh 以外を保持するのは自身の読み出し直後だけ。RTL 上の競合は見つからなかった。
- ユーザーの指摘: OPLL や PSG の音が正常に鳴っているので、書き込み側が頻繁に化けているとは考えにくい。
- 次の確認（すべて読み出し・47h のみ、Flash は触らない）:
  1. 41h（FDh を返す）と 42h（FEh を返す）を繰り返し読む。書き込みデータを経由しない固定値なので、読み出し経路だけを独立に確認できる。
     FDh と FEh を合わせると、化けやすい bit7・bit5・bit1・bit0 をすべて 1 として観測できる。
  2. 47h に 1 回書いて 5 回読み返す。読み値がばらつけば読み出し側。5 回とも同じ誤った値の場合は、
     書き込み時の化けと「毎回同じように化ける読み出し」を区別できないので、このテスト単独では判定不能とする。
     1. で読み出しが常に正しい場合に限り、書き込み側の可能性が高いと判断する。
## 2026-10-18 18時半: 書き込みデータ取り込みタイミングの修正（msx_slot）
- 実機結果:
  - 41h/42h の固定値読み出し 1000 回: 化け 0。ただし確認できたのは FDh・FEh の 2 値だけで、
    47h の読み出しと同じデータ・条件ではないので、読み出し経路全体が正常とまでは言えない。
  - 47h に 1 回書いて 5 回読み返し: U ERR 0（読み返しは毎回一致）、C ERR 31（約 3%）。
    5 回とも同じ誤値なので、書き込み時の化けと「毎回同じように化ける読み出し」は区別できない。
  - 化けるのは 1→0 の向きだけで、bit7・5・3・1・0。
  - 書き込み時の取り込みで化けている、というのは有力な仮説にとどまり、未確定。
- 仮説: msx_slot は /WR 検出の直後、/WR 立ち下がりから約 23〜47ns で書き込みデータを 1 回だけサンプリングしていた。
  スロット上のデータが /WR より遅れて確定する場合（本体のバッファが /WR で開く、配線長差など）に、確定前の値を取り込む。
- 修正（src/msx_slot/msx_slot.v）:
  - 書き込みトランザクションの開始を /WR 検出から 4 クロック後（約 93〜116ns）に遅らせ、その時点のデータを使う（c_wr_delay=3）。
  - 読み出しは /WAIT が必要になり得るので、従来どおり即時に開始する。
  - 3.58MHz の Z80 では /WR は I/O で約 700ns、メモリで約 280ns 続くので、余裕がある。
- テスト: msx_slot/test001 に write_late_data を追加した。データが /WR の 60ns 後に確定するケースを I/O・メモリで 24 件確認する。
  修正後は全 PASS。旧タイミング（c_wr_delay=0）では 24 件とも FAIL することも確認した。
  msx_slot/test002 とトップの test001 も PASS。Gowin でビルド済み（18:33）。
- ユーザーの指摘（OPLL・PSG が正常に聞こえる）について: OPLL も同じタイミングで取り込んでいるので影響は受け得る。
  約 3% の化けは音色やボリュームの細かい誤りになり、気付きにくい可能性がある。
  PLAY 文の PSG は本体内蔵の PSG。音の確認に使った本体が別機種なら、本体側のタイミング差も考えられる（未確認）。
- 判定方法: 新ビットストリームで②を再実行する。C ERR が 0 になれば仮説を支持する。
  0 にならなければ、47h の読み出し応答側（データ出力の開始・終了、BUSDIR の切り替え）も含めて調べ直す。

## 2026-10-18 夜: 書き込みタイミング修正の実機確認と、DIPSW[1]=ON 起動時の暗転
- 実機確認: 修正版 RTL でループバックテスト②が U ERR 0 / C ERR 0 になった。書き込み取り込みタイミングの仮説を支持する。
- 新たな症状: DIPSW[1]=ON のまま電源を入れると画面が暗転して停止する。OFF で起動し、暗転のタイミングを過ぎてから ON にすると問題は起きない。
- RTL の確認:
  - ブートコピー中は wait_n=0 になる（system_controller の `wait_n = ff_init_done`）。トップでは ff_slot_connected でゲートされる。
  - この WAIT 動作は、BIOS 更新に失敗する前のビルド（WAIT 接続あり）でも同じだった。そのビルドでは、カートリッジを装着したまま起動し、BASIC と Y8960UPD を使えていた。
  - 起動しなくなったのは BIOS 更新に失敗した後で、RTL は同じだった。
  - 書き込みデータの取り込みが化けていたので、Flash 7E0000h～ の BIOS 本体と、消去・書き込みのアドレスがともに化けていた可能性がある。
    （確認できている化け: 7E0002h 5Fh→5Bh、7E0015h 39h→19h、消去後も 7E0000h が 41h のまま）
  - 起動時、この壊れた BIOS が SerialSRAM へコピーされる。7E0000h の "AB" が正しく書けていれば、MSX は初期化アドレスを呼び出す。
    初期化中は画面が表示オフのため、そのまま暗転して停止すると考えられる。
    OFF で起動すると ROM の初期化は呼ばれないので、後から ON にしても止まらない。
- 結論（仮説）: VDP とのバス競合を示す証拠はない。Flash 上の不完全な BIOS の実行が最も有力。RTL の変更は行わない。
- 次の確認:
  1. OFF で起動し、DOS で ON にしてから `Y8960UPD /B MSXSSE.ROM` を実行する（取り込み修正済み RTL で）。
  2. 成功したら、ON のまま電源を入れ直す。起動すれば仮説は確定。
  3. それでも暗転する場合は、ブートコピー中の WAIT（約 26ms）など RTL 側を調べる。

### 結果（2026-10-18 夜、ユーザー確認）
- 上記の手順 1～2 で BIOS を書き込み、Verify を含めて成功した。
- ON のまま電源を入れ直しても正常に起動した。仮説（不完全な BIOS が原因）が確認できた。
- 書き込んだ BIOS の `CALL MUSIC:PLAY#2,"V15CDEFG"` で音が出た。
- GitHub に commit/push 済み。
- 未確認: Y8960UPD による FPGA デザインデータの書き込み。

## 2026-10-19 朝: SCC のステレオ化（9900h～9904h: Ch.A～E PAN）
- 仕様: Y8960_Specifications.xlsx の MemoryMappedIO シート。9900h～9904h は WO。1=左端、128=中央、255=右端、デフォルト 128。
- 原本 src/ikascc は変更しない。変更が必要なファイルは src/ikascc_patch にコピーして修正した。
  - IKASCC.v: `o_SOUND_CH[39:0]`（Ch.A～E の 8bit signed）と `o_SCCREG_EN` を追加した。
  - IKASCC_player_s.v: 各チャンネルの音（`ch1_sound`～`ch5_sound`）を `o_SOUND_CH` として出力するようにした。
  - gprj と、test001 系の run.bat の参照先を patch 版に変更した。
- scc.v:
  - PAN レジスタ ff_pan_a～ff_pan_e を追加した。書き込み条件は、SCC レジスタウィンドウ（バンク 2 が 3Fh）かつ RAM Mode=0（scc_ma[18]=0）。仕様の「RAM Mode=0 の時のみ利用可能」に合わせた。
  - IKASCC は A7～A0 しかデコードしないため、9900h～9904h の書き込みは CS をマスクして IKASCC に渡さない（RAM Mode に関係なく。RAM Mode=1 で PAN が無効でも波形を壊さない）。
    → 9800h～9804h（Ch.A 波形）へのミラー書き込みは起きない。9905h～ と読み出しは従来のミラー動作のまま。
  - パン処理: 10 ステップ（Ch.A～E × L/R）の時分割で、pan_lut 1 個と乗算器 1 個で処理する。等パワー則で、中央は各 181/256（-3dB）。SSG/OPLL/OPL2 と同じ。
  - 出力は sound_l_out / sound_r_out（11bit signed）。全チャンネルを片側に振り切ったときの最大振幅は従来のモノラル出力と同じ（±640）。
- mixier.v: SCC 入力を scc_l / scc_r に分けた。
- 既知の仕様差（従来から、今回は未変更）: IKASCC_vrc_s の SCCREG_EN は RAM モードを見ていない。そのため RAM モードでもバンク 2=3Fh なら 9800h～98FFh の SCC レジスタにアクセスできる。仕様では「RAM Mode=0 の時のみ」。PAN（9900h～9904h）は今回、RAM Mode=0 の条件を付けた。
- 検証:
  - 新規 src/ikascc_patch/test002: PAN の初期値、ウィンドウ外への書き込みの無視、波形 RAM の非破壊、9905h のミラー、L/R の演算値、実 IKASCC 出力の左右切り替え、RAM Mode=1 での PAN 書き込み無視（9800h も非破壊）と RAM Mode=0 復帰後の書き込み。すべて OK。RAM Mode 条件を外すと 3 件 FAIL することも確認した。
  - mixer/test001（L/R 別値を追加）、ikascc_patch/test001、トップの test001 もすべて OK。
  - Gowin ビルド（RAM Mode 条件追加後、06:22）: 全クロック Setup/Hold TNS 0。clk_42m の Fmax は 43.057MHz（制約 42.951MHz、余裕は小さい。最悪パスは既存の OPL2 の EG）。DSP 16/28、Logic 32%。
- 次: 実機で SCC の各チャンネルの PAN を確認する。FPGA の更新が必要。

## 2026-10-19 朝: ADPCM の PAN（OPL2+ADPCM FFh）とマスターボリューム（7FFEh）
- 仕様: Y8960_Specifications.xlsx
  - OPL2+ADPCM のレジスタ FFh = ADPCM PAN。1=左端、128=中央、255=右端、デフォルト 128。
  - MemoryMappedIO の 7FFEh = Master Volume。0=無音～128=最大、bit7=1 なら 128 扱い。有効条件は他の音量レジスタ（7FF7h～7FFAh）と同じ。
- ADPCM PAN（src/adpcm_patch/adpcm.v）:
  - FFh の reg_pan と pan_lut による L/R ゲインは 10/17 に実装済みだったが、L/R で乗算器を 2 個使っていた。今回、1 個の乗算器を L/R でクロックごとに交互に使い、結果をレジスタに保持する形に変えた。
  - jt10_adpcm_drvB の pcm55_l と pcm55_r は同じ値なので（alr_b=11 で両方とも同じ pcmgain）、モノラルの ADPCM 出力に L/R ゲインをかけて定位を作っている。中央は各 181/256（-3dB）で、SSG/OPLL/OPL2/SCC と同じ等パワー則。
- マスターボリューム:
  - msx_slot.v: 7FFEh に ff_master_volume（初期値 128）を追加し、master_volume ポートで出力する。7FFBh～7FFDh は Reserved のまま（ローカルバスへ転送）。
  - mixier.v: ステートを 8 から 10 に増やした（0-3: Lch の各音源×音量、4: Lch ミックス×マスター、5-8: Rch、9: Rch×マスター）。乗算器は 1 個のまま共有する。
    各音源をミックスして 24bit に飽和させた値に、マスターゲイン（/128）をかける。ゲインは最大 1.0 なので、再飽和は不要。
  - トップで msx_slot と mixier を接続した。
- 検証:
  - 新規 src/adpcm_patch/test001: PAN の初期値 128、PAN=128/1/255/0 の L/R 値、フルスケール（+32767/-32768）。すべて OK。
  - mixer/test001: マスター 64/1/255（bit7 クランプ）/0、フルスケール時の 100%/75%。すべて OK。
  - msx_slot/test001: 7FFEh の初期値と書き込み、7FFBh～7FFDh で値が変わらないこと、無効時の非書き込み、ローカルバスへ転送しないこと。すべて OK。msx_slot/test002 も OK。
  - opl2_patch/test001、ikascc_patch/test001・test002、トップの test001: すべて OK。
  - Gowin ビルド（06:36）: 全クロック Setup/Hold TNS 0。DSP 15/28（ADPCM の乗算器共有で 16→15）、Logic 33%。
    clk_42m の Fmax は 42.960MHz（制約 42.951MHz）。余裕はほぼない。最悪パスは既存 SCC の半周期パス（msx_slot アドレス → IKASCC 波形 RAM、立ち上がり→立ち下がり、slack +0.003ns）で、今回の変更箇所ではない。
- 次: 実機で ADPCM の PAN とマスターボリュームを確認する。FPGA の更新が必要。

## 2026-10-19 朝: `Y8960UPD /C Y8960CFG.BIN` が valid image ではないとして拒否された件（調査中）
- 実機の症状: `/C Y8960CFG.BIN` を実行すると `This file is not a valid image for this option.` と表示される。
- PC 側の tool/config/Y8960CFG.BIN（6:58 生成）を確認した結果:
  - サイズは 848,780 バイト（ヘッダー 48 バイト＋本体 848,732 バイト）。上限 7D0000h 未満。
  - 先頭 32 バイト（`Y8960_TP25K_CARTRIDGE`＋00h 埋め）は、Y8960UPD.COM 内の config_signature と完全に一致した。
  - バージョン文字列は `Y8960_v0.9.1`（00h 埋め）。
  - BIOS のときのようなスペース埋めの問題はない。
- このメッセージが出るのは、先頭 48 バイトを読めなかった場合か、識別子が一致しなかった場合のみ。
  このエラーで終了したときは、Flash の消去・書き込みは始まっていない。
- 仮説: MSX 側に転送されたファイルが PC 側のものと異なる（古いファイル、転送の失敗、サイズの違いなど）か、DOS での読み出しに問題がある。まだ断定できない。
- 帰宅後の確認:
  1. 最新の Y8960CFG.BIN を MSX 側へコピーし直し、DOS の DIR でサイズが 848,780 バイトになっていることを確認する。
  2. `Y8960UPD /C Y8960CFG.BIN` を再実行する。
  3. それでも拒否される場合は、MSX 側のファイルの先頭 48 バイトを確認する。Y8960UPD のファイル読み出し（FCB／_RDBLK）も調べる。

## 2026-10-20 朝: SCC の RAM Mode と BANK#63／PAN レジスタの問題の修正
- 報告（第三者）: RAM Mode=1 で BANK2=#63 にしたとき、9900h～9904h への書き込みが PAN にも SCC にも届かず、消えてしまう。BANK1 の SCC（7800h～）には PAN がない。
- 仕様の追記: RAM Mode=1 では、SCC バンク（#63）を BANK1 には出せるが BANK2 には出せない。
- 原因:
  1. IKASCC_vrc_s.v の SCC レジスタ窓の判定で、BANK2=#63 の項が RAM Mode を見ていなかった。そのため RAM Mode=1 でも 9800h～9FFFh が SCC 窓になっていた。
  2. scc.v は、PAN への書き込みだけを RAM Mode=0 に限定していた。一方で、SCC コアへの書き込みは PAN アドレスとして無条件に止めていた。この組み合わせで、9900h～9904h への書き込みが消えていた。
- ユーザーの決定:
  - A: RAM Mode=1 の BANK1 にある SCC にも、7900h～7904h に PAN を出す。
  - B: #63 だけを未接続にする（#32～#62 は従来どおり #0～#31 のミラーのまま）。
- 修正:
  - ikascc_patch/IKASCC_vrc_s.v:
    - SCC 窓を「RAM Mode=0 かつ BANK2=#63 の 9800h～9FFFh」または「RAM Mode=1 かつ BANK1=#63 の 7800h～7FFFh」に限定した（同期版・非同期版とも）。
    - 選択中のバンクが #63 なら、SCC 窓の外でも ROMCS_n をインアクティブにした。つまり #63 は SCC 窓以外では未接続になる。読み出しは応答なし（FFh）、書き込みは無視、SRAM にもアクセスしない。対象は BANK0、BANK3、RAM Mode=0 の BANK1、RAM Mode=1 の BANK2、および 8000h～97FFh／6000h～77FFh。
  - ikascc_patch/scc.v:
    - PAN アドレスを、SCC 窓の中の x900h～x904h（A10～A8=001）で判定するようにした。RAM Mode=0 では 9900h～9904h、RAM Mode=1 では 7900h～7904h になる。
    - RAM Mode による PAN の書き込み制限を削除した。窓の判定が正しくなったので、窓の中の PAN アドレスへの書き込みは必ず PAN に入る。
- 検証（ModelSim）:
  - ikascc_patch/test002 に以下のテストを追加し、すべて OK。
    - RAM Mode=1 で BANK2=#63: PAN と波形 RAM が変わらないこと、ROMCS_n=1（未接続）、読み出しが FFh になること。
    - RAM Mode=1 で BANK2=#31: SRAM が選択され、MA が 3Fh になること。
    - RAM Mode=1 で BANK1=#63: 7800h が SCC であること、6000h が未接続であること、7900h～7904h が PAN に入ること、波形 RAM が壊れないこと、7905h が 7805h のミラーであること。
    - RAM Mode=0 に戻した後: 7900h が無視されること、BANK1=#63 と 8000h が未接続であること、9900h～9904h が PAN に入ること。
  - ikascc_patch/test001: 「BANK2=#63 の 9000h は #31 のミラーとして読める」という旧仕様の期待値を、「未接続（SRAM にアクセスしない・ウェイトなし・応答なし）」に変更した。ALL TESTS PASSED。
  - トップの test001: PASS。
  - Gowin による合成はまだ行っていない（ユーザーが実施する）。
- 次:
  - 仕様書の 9900h～9904h の行に、RAM Mode=1 では 7900h～7904h になることを追記する（ユーザーが実施）。
  - 合成し、実機で確認する。

## 2026-10-20 朝の終了: 仕様書の確認と帰宅後の作業
- ユーザーが MemoryMappedIO シートを更新した。7902h の誤記、6000h～77FFh の範囲、PAN の読み出し未定義、予約領域のアクセス禁止、BANK#32～#62 のミラー表記を確認した。7900h～7904h の PAN の仕様書への追記は完了。
- 07:25 のユーザー決定（未実装）:
  - RAM Mode=1、BANK1 に BANK#63 を出現させた場合でも、7FF0h～7FFFh には通常のメモリマップド I/O の機能を残す。
  - 仕様書 G59 の「上の表に記載の動作を継承」はこの意図によるもの。ここを SCC ミラーに合わせて削除するのではなく、RTL を新しい仕様に合わせる。
- 現在の RTL と残作業:
  1. トップの w_mixer_reg_en は RAM Mode=1、BANK1=#63 で無効になる。#63 を識別する情報は現在の scc_ma（RAM Mode とバンク番号の下位5ビット）だけでは #31 と区別できないため、mapper からの情報伝達も含めて修正する。#31 の RAM 上の 7FF0h～7FFFh を誤って I/O にしないこと。
  2. msx_slot の音量レジスタ、アドレスデコーダの各音源・制御レジスタを含め、7FF0h～7FFFh の機能を一貫して有効にする。同範囲へのアクセスが SCC モードレジスタのミラーにも届く二重書き込みを防ぐ。未使用・予約アドレスの扱いは表に従う。
  3. テストに RAM Mode=1、BANK1=#63 のメモリマップド I/O、SCC 非破壊、#31 の RAM アクセス維持、モード・バンク切り替えを追加して検証する。
- 仕様書との未解決の差分（帰宅後に意図を確認して整理する）:
  - E81 は「SCC の出現条件以外では BANK#31 のミラー」に変更されたが、今朝修正した RTL は #63 の SCC 窓以外を未接続にしている。ミラーへ戻す指示はまだ確定していない。
  - BANK#64～#255 は仕様書では未接続だが、現 RTL はバンクレジスタの下位6ビットのみ保持するため、64刻みで折り返す（例: #64 は #0、#127 は #63）。仕様と実装のどちらへ合わせるか未決定。
  - 9905h～9FFFh／7905h～7FEFh は仕様書でアクセス禁止・将来予約とした。現 RTL では SCC のミラー動作が残っているが、ソフトウェアはアクセスしない領域として扱う。
- 注意: 以前の説明にあった「バンク前半 2000h 分」は誤り。SCC 窓の前の領域は 1800h バイト（8000h～97FFh／6000h～77FFh）。
- 今朝の修正済み RTL の ModelSim 結果は前節のとおり PASS。上記の新しい 7FF0h～7FFFh 要件は未実装・未検証。合成・実機確認もまだ行っていない。
- ユーザーの外出に合わせて作業を終了。今回の終了記録では RTL を追加変更していない。帰宅後は最新の仕様書を再読し、上記の要件から再開する。

## 2026-10-20 夜: メモリマップド I/O の常時有効化と BANK2 SCC のモード制限撤廃
- ユーザーが対応方針を承認し、実装を開始した。今回の指示は朝の条件に優先する。
  - 7FF0h～7FFFh のメモリマップド I/O は、RAM Mode と BANK1 に選択した BANK# に関係なく出現する。
  - BANK2 に BANK#63 を選択した場合、RAM Mode の値に関係なく SCC が出現する。
  - BANK1 の SCC は従来どおり RAM Mode=1 かつ BANK#63 の場合に出現する。BANK1/BANK2 を同時に SCC にでき、同じ音源・波形・PAN レジスタを共有する。
- 実装:
  - y8960_cartridge_tangprimer25k.v: w_mixer_reg_en を定数 1 にし、msx_slot の音量レジスタとアドレスデコーダのメモリマップド I/O を常時有効にした。既存のモジュールの enable 入力は保持し、バンク識別用の新しい信号は追加していない。
  - y8960_address_decode.v: 書き込み窓を 7FF0h～7FFFh として明示し、未割り当てアドレスへの書き込みは SCC に転送せず、ready を返して終了する。これにより 7FFBh～7FFDh は書き込み無視となり、背後の SRAM や SCC モードレジスタへの二重書き込みを防ぐ。音量書き込みは従来どおり msx_slot 内で完結する。
  - IKASCC_vrc_s.v: BANK2 の SCC 窓条件から RAM Mode=0 の制限を削除した。同期版・非同期版は共通の窓条件を使う。
  - scc.v: PAN の動作はそのまま利用し、コメントを新しい BANK2 の条件に合わせた。BANK2 の PAN は両モードで 9900h～9904h、BANK1 は RAM Mode=1 で 7900h～7904h。
  - WO レジスタへの読み出し機能は追加していない。7FF0h～7FFFh の読み出し経路は従来どおりメモリ/SCC 側を使う。SCC 窓外の #63 の未接続動作、#32～#62 のミラー、6ビットのバンク番号による折り返しは今回変更していない。
  - 原本の ikascc は変更していない。SCC 関連の変更は ikascc_patch 内のみ。
- 検証（ModelSim）:
  - ikascc_patch/test001: MSX スロットから RAM Mode=0/1 と BANK1=#0～#63 の全128組み合わせを検証。全16アドレスの書き込み、音源選択、I/O Enabler、各音源音量、Master Volume、ウェイトなし、SCC 非選択、CPU 側 SRAM アクセスなし、背後の SRAM 非破壊を確認した。7FEFh の通常 RAM/SCC 動作も確認。既存の SRAM・ADPCM 競合・WAIT テストを含め ALL TESTS PASSED。
  - ikascc_patch/test002: RAM Mode=1 の BANK2 から波形・PAN・周波数を書けること、BANK1/BANK2 の同時出現と共有、各窓からの PAN 書き込みと左右の演算値、BANK2=#31 への切り替え、RAM Mode=0 復帰後の動作を確認。すべて PASS。
  - y8960_address_decode/test001: 予約領域の書き込み無視と ready 応答、7FEFh/7FF0h 境界、既存デコードを確認。PASS。
  - msx_slot/test001・test002: PASS。
  - トップ test001: System Controller 検出、DIP 切り離し、ブートコピー、ROM 読み出しの回帰テスト PASS。
- 合成・配置配線と実機確認は未実施。Gowin EDA の合成はユーザーが行う。
- 仕様書そのものは今回編集していない。旧「RAM Mode=0 または BANK1 が ROM のときのみ」の I/O 条件と、BANK2 SCC の RAM Mode 制限が残っていれば、今回の決定に合わせて更新が必要。

## 2026-10-20 深夜: IKAOPM (OPM, YM2151 互換) の追加
- 仕様: I/O 7Eh（アドレス）/7Fh（データ、読み出しはステータス）、MMIO 7FFBh（アドレス）/7FFCh（データ）、7FFDh（OPM 音量、初期値 128）、7FFFh bit2（OPM I/O 許可、初期値 0）。
- ユーザーの決定: busy の扱いは /WAIT とステータス読み出しの両方を使う。IRQ は /INT に接続する。ステータス読み出しは I/O 7Fh のみ（MMIO は書き込み専用で、背後の ROM/RAM の読み出しを妨げない）。
- 実装:
  - 新規 src/ikaopm_patch/opm.v: IKAOPM（原本は無変更。FULLY_SYNCHRONOUS=1, FAST_RESET=1, USE_BRAM=0）のラッパー。
    - 16段の書き込みキューを持ち、IKAOPM へ1件ずつ送る。送出後の待ち時間は、アドレス書き込みで 8 phiM、データ書き込みで 80 phiM（YM2151 の busy 64 phiM ＋余裕）。
    - キューが満杯の間は /WAIT を出す。
    - 7Fh のステータス bit7 = (キューに未処理あり | 送出中 | 待ち時間中) | IKAOPM の busy。bit1/0 はタイマーフラグ。
    - o_IRQ_n は /INT へ。
  - y8960_address_decode.v: bus_opm_cs/bus_opm_ready、ff_opm_io_en（7FFFh bit2）、7Eh-7Fh と 7FFBh/7FFCh のデコードを追加。
  - msx_slot.v: 7FFDh の opm_volume を追加。
  - mixier.v: 12ステートに拡張（L: SSG/OPLL/OPL2/SCC/OPM→Master、R も同様）。乗算器は1個のまま共用。
  - トップ: u_opm を追加。/WAIT・rdata・rdata_en・/INT・ミキサーに接続。
  - gprj に opm.v を追加。test001/run.bat に IKAOPM のソースを追加。
- 検証（ModelSim、すべて PASS）:
  - 新規 ikaopm_patch/test001:
    - リセット直後の busy とその解除、7Eh/7FFCh 読み出しでデータを返さないこと。
    - キュー満杯時の /WAIT と解除。
    - タイマーA の IRQ とフラグ解除。
    - I/O と MMIO の混在書き込みによるキーオンで L/R に音が出ること、RL=L のみで R が無音になること。
  - mixer/test001（OPM 単独・音量・ミュート・全音源合計）。
  - y8960_address_decode/test001（OPM I/O の無効・有効・再無効、MMIO の cs、7FFDh は cs なしで ready）。
  - msx_slot/test001・test002、ikascc_patch/test001（7FFDh の音量と 7FFFh bit2 を含む）、トップ test001。
- 未実施: 合成・配置配線（IKAOPM はロジック規模が大きく、USE_BRAM=0 なので、リソースとタイミングの確認が必要）と実機確認。
- 仕様書の MMIO 行の注記に「RAM Mode=0 または BANK1 が ROM のときのみ」が残っていれば、常時有効の仕様に合わせて更新が必要。
- 23:12 ユーザー報告: 合成は問題なく完了し、FPGA への書き込みまで完了。音を出しての実機確認は後日（未確認）。
- 次回: 実機で OPM の発音、7Eh/7Fh（7FFFh bit2=1）と 7FFBh/7FFCh からの書き込み、ステータス読み出し、タイマー割り込み、7FFDh の音量を確認する。

## 2026-10-21 朝: メモリマップド I/O の出現条件と I/O Enabler 初期値の修正
- ユーザー指示（仕様書 O11～O26 の注記に一致。10/20 夜の「常時有効」は取り消し）:
  - 7FF0h～7FFFh のメモリマップド I/O は、RAM Mode=0 のとき、または RAM Mode=1 で BANK1 が ROM バンク (#0～#15) のときだけ出現する。
  - RAM Mode=1 で BANK1 が #16～#31 のときは、その RAM バンクの 7FF0h～7FFFh を通常どおり読み書きできる。
  - 7FF6h/7FFFh の初期値は 0 で、TIMER/SSG/OPLL/OPL2/OPM の I/O はすべて無効で起動する。ADPCM は OPL2 の I/O（C0h-C1h）経由なので OPL2 の Enabler で制御される。
- 実装:
  - トップ: w_mixer_reg_en = ~w_scc_ma[5] | ~w_scc_ma[4] に戻した（10/20 夜より前の式）。scc_ma は {RAM Mode, 現在のアドレスで選ばれた BANK#[4:0]} で、アドレスに対して組み合わせ回路で出力される。
    - バンクレジスタの下位5ビットで判定するため、#32～#47（#0～#15 のミラー）は ROM 扱いで MMIO が出現する。
    - #48～#62（#16～#30 のミラー）と #63 は出現しない。BANK1=#63（SCC）では、7FF0h～7FFFh への書き込みは SCC 側（モードレジスタのミラー）へ届く。
  - y8960_address_decode.v: ff_opll_io_en/ff_ssg_io_en の初期値とリセット値を 1→0 に変更した。
- 検証（ModelSim、すべて PASS）:
  - y8960_address_decode/test001: 全 I/O の初期無効と、memory_io_en=0 のとき 7FF0h～7FFFh が SCC/メモリ側へ行き、Enabler が変わらないことを確認。
  - ikascc_patch/test001: テストベンチの w_mixer_reg_en をトップと同じ式にした。RAM Mode=0/1 × BANK1=#0～#63 の全組み合わせで次を確認した。
    - MMIO が有効なバンクでは従来どおりの動作になる。
    - RAM バンク（#16～#31、#48～#62）では、SRAM への16バイトの書き込みと読み返しができ、音源 cs・音量・Enabler が変化しない。
    - #63 では SRAM へ書き込まれず、SCC へ届く。
  - msx_slot/test001・test002、ikascc_patch/test002、トップ test001。
- 注意: これまで OPLL/SSG の I/O は起動時に有効だった。今後は BIOS（CALL MUSIC など）や利用ソフトが 7FF6h/7FFFh で有効化する必要がある。リポジトリ内にはこのレジスタに書き込むソフトは見当たらない。
- 合成・実機確認は未実施。

## 2026-10-26 夕方: 7FFFh（I/O Enabler2）の読み出し対応
- 仕様変更（互換性向上のため）: 7FFFh を WO から RW にする。読み出せるのは、書き込みが有効な条件（RAM Mode=0、または BANK1 が ROM バンク #0～#15）のときだけ。
- ユーザーの決定: 未定義ビット bit6～bit3 は 0 として読む。
- 読み出し値: { TIMER, 0000, OPM, SSG, OPL2 }
- 実装:
  - y8960_address_decode.v:
    - bus_rdata/bus_rdata_en 出力を追加。
    - memory_io_en=1 で 7FFFh を読み出したときは、デコーダ自身が ready を返し、次のクロックで rdata_en と読み出し値を出す。このアクセスは SCC/SRAM へ回さない（w_mem_plain から除外）。
    - それ以外のときの rdata は FFh（各音源の rdata と AND で合成するため）。
    - memory_io_en=0 の場合は、従来どおり SCC/SRAM（RAM バンクの内容、BANK1=#63 なら SCC 側）を読む。
    - 7FF0h～7FFEh の読み出しは従来どおりメモリ側を読む。
  - トップ: w_bus_decode_rdata/_en を rdata の AND 合成と rdata_en の OR 合成に追加した。
- 検証（ModelSim、すべて PASS）:
  - y8960_address_decode/test001: リセット値 00h、各種書き込み値の読み返し（未定義ビットが 0 になること）、module cs が立たないこと、ready、rdata_en が1クロックで解除されること、memory_io_en=0 のときは SCC 側へ回ることを確認。
  - ikascc_patch/test001: RAM Mode=0/1 × BANK1=#0～#63 の全組み合わせで、MMIO が有効なバンクでは 7FFFh が 07h と読め、SRAM アクセスが発生しないことを確認。RAM バンクでは従来どおり SRAM の内容が読めることを確認。
  - msx_slot/test002、ikascc_patch/test002、トップ test001。
- 合成・実機確認は未実施。

## 2026-10-26 夜: Windows 更新ツールを Y8960 / TangPrimer25K 向けに移植
- ユーザーが tool_for_windows にコピーした V9968 向けツールを変更した。FPGA RTL と仕様書は今回変更していない。
- GOWIN Programmer V1.9.12.03 の --help で、69 が「exFlash Erase,Program,Verify thru GAO-Bridge Arora V」であることを確認。対象 FPGA はプロジェクトと同じ GW5A-25A、JTAG は既存ツールと同じ 2.5MHz。
- 方針の確認:
  - Config と BIOS のバージョンが同じ 64KB 消去ブロックにある。CLI の公開操作では Flash を読み出して他方のバージョンを保存できないため、MSX 版と同じ個別更新をそのまま移植することはできない。
  - ユーザーが「Config と BIOS の両ファイルを指定し、両方を更新する方式」を選択した。両ファイルを必須にし、両本体の消去・書き込み・ベリファイに成功した後だけ、両バージョンをまとめて書き込む。
- 実装:
  - プロジェクト・名前空間・実行ファイル・表示・CLI パス保存先を Y8960UpdWin に変更。
  - Config: シグネチャ Y8960_TP25K_CARTRIDGE、ヘッダ 48 バイト、本体 1～7D0000h バイト、書き込み先 000000h。
  - BIOS: シグネチャ Y8960_BIOS_IMAGE、ヘッダ 48 バイト、本体は正確に 128KB、書き込み先 7E0000h。リポジトリの tool/bios/MSXSSE.ROM がヘッダ付きの入力ファイル。
  - バージョンブロック: 7D0000h～7DFFFFh を FFh で初期化し、7DFF00h に Config、7DFF10h に BIOS の各16バイトを配置。
  - 本体またはバージョンの失敗後は後続処理・再起動を行わない。本体の失敗時はバージョンを書き換えない。途中まで更新された Flash のロールバックはできない旨を説明書に記載。
  - 接続確認と書き込み直前の再スキャンで GW5A-25A を要求し、型番なし・他型番混在は拒否する。
  - 成功時は --run 1 で再起動。再起動だけ失敗した場合は書き込み成功と区別して USB 再接続を案内する。
  - readme とビルドスクリプト・gitignore を更新。旧 V9968 配布 exe は削除し、Y8960UpdWin.exe をビルド出力した。
- 検証:
  - VS2022 MSBuild の Release ビルド成功。
  - tests/Y8960UpdWin.Tests.csproj: 偽 CLI のみで 89 チェック PASS。実機へのアクセスは行っていない。
  - 実際の配布 Config/BIOS の読み込み、シグネチャ・サイズ境界、ヘッダ除去、両バージョンの配置、GUI 操作からの実行順・アドレス・--run 69 を検証。
  - Config/BIOS/バージョンそれぞれの失敗での中断、バージョン保護、直前スキャン失敗、再起動だけの失敗通知も検証。
- 実機での Arora V GAO-Bridge 書き込みは未検証。元の V9968 ツールの実機確認結果は引き継がない。

### 追記: 実機接続時に検出失敗 → 修正
- 現象: TangPrimer25K 接続中でも「Y8960 Cartridge is not detected」。
- 原因: programmer_cli --scan は 1 台のデバイスに対し IDCODE 互換の全型番を
  `Name: GW5A-25A GW5A-25B GW5AS-25A GW5AS-25B GW5AR-25A GW5AR-25B (One of them)` と列挙する。
  判定が「型番がちょうど 1 個」を要求していたため拒否していた。
- 修正 (ProgrammerCli.IsTargetDevice):
  - GW5A-25A を含むこと。
  - 列挙された全型番が GW5A/GW5AS/GW5AR-25A/B 系であること。
  - "N device(s) found" がある場合は N=1 であること。
- テスト: 実機の scan 出力を受理するケースと、2 台検出・GW5A-25A なしを拒否するケースを追加。偽 CLI の scan 出力も実機形式に変更。92 チェック PASS。build.bat 成功。

### 追記: Arora V GAO-Bridge の選択にパッケージ名を指定
- ユーザーの実機ログでは検出に成功したが、操作 69 の開始時に
  `Error: No gao bridge files found for this development board` が発生した。
  CLI の終了コードは 0 だったが、出力の Error を検出して後続処理を中断できている。
- インストール済み Programmer の `aroravgaobridge.json` と FPGA プロジェクトの部品型番を確認。
  TangPrimer25K のパッケージ付き型番 `GW5A-25A-MBGA121N` は
  `0001281B_S.fs` に対応し、ブリッジファイルも存在する。
- 書き込み時の `--device` を `GW5A-25A` から `GW5A-25A-MBGA121N` に変更。
  検出判定と再起動は従来の型番指定を維持する。
- Config・BIOS・バージョンの全書き込みでパッケージ名が付くことと、
  終了コード 0 のブリッジエラーを失敗と扱うことをテスト。93 チェック PASS。
  Release ビルド成功、配布 EXE とビルド出力の SHA256 一致も確認。
- 指定された `tool\config\Y8960CFG.BIN` と `tool\bios\MSXSSE.ROM` の読み込み検査は成功。
  実機への書き込みは実行していない。修正版での実機確認はユーザーに依頼する。

### 追記: GAO-Bridge 操作をやめ、操作 56 (C Bin, ブリッジなし) に変更
- パッケージ名付き `--device GW5A-25A-MBGA121N` は CLI の argparse で拒否された（選択肢は GW5A-25A 等のみ）。
- CLI の内部文字列を調査した結果、`get_gao_bridge_fs` は `--fsFile` の .fs ヘッダ
  `//Device-package:` からブリッジを選んでいた。.bin にはヘッダがないため失敗する。
  操作 67～69 は .fs ビットストリーム専用。
- ユーザー了承のうえ、実機で読み出し専用の検証を実施（消去・書き込みなし。最後に --run 1 で再起動）。
  - ヘッダ付き .fs を作ると GAO-Bridge は読み込めた。
    しかし操作 67 (ブリッジ経由ベリファイ) は、GOWIN 生成の impl\pnr .fs でもページ 0 から不一致。
  - 操作 66 (ブリッジなしベリファイ) は Flash を読めた。
    impl\pnr .fs はページ 5、tool\config .fs はページ 4 で不一致。両者の最初の差分は 1197 バイト目 (ページ 4)。
    よって Flash には別ビルドが入っている模様で、ページ単位の生ビット比較が正しく動いていると判断。
  - .fs のビット列は .bin とバイト単位で完全一致することを確認。
- 書き込みを `--run 56` (exFlash C Bin Erase,Program,Verify Arora V)、`--device GW5A-25A` に変更。
  V9968 版の `--run 39` も C Bin 系だった。
- 操作 56 での実機書き込みは未検証。ユーザーがツールで確認する。

### 追記: 操作 56 の失敗を受け、通常の exFlash 操作 54 に変更
- ユーザーのログでは、操作 56 が終了アドレス 0、約 0.44 秒で
  `Error: Program and Verify Flash Failed!` を返した。終了コードは 0。
- ユーザーに USB 切断を依頼してオフライン SVF 生成を試したが、操作 56 は
  `Error: Unsupported.` となり、書き込みデータの検証には使えなかった。
  `--acFile` / `--mcuFile` 単独も今回の操作では入力として受理されず、
  これらを代替引数にする根拠は得られなかった。
- USB 再接続と読み出し専用テストの許可を得て、操作 66 で正負対照を実施。
  - Config 本体の先頭 1024 バイトを .bin で渡すと `Verify Flash successfully.`。
  - 同じデータを .fs にしても成功。
  - .fs の 512 バイト目を 1 ビット変更した負対照はページ 2 で失敗。
  - .binx は正常な代替入力と確認できなかったため採用しない。
  - テスト後は `--run 1` の成功を確認。消去・Flash 書き込みは実行していない。
- 上記により、先の「.bin が正しく解釈されない」という推測は訂正する。
  正負対照で確認したのは先頭範囲の入力解釈と読み出しであり、
  全領域の一致や GAO-Bridge 不一致の根本原因は断定しない。
  操作 56 で処理長が 0 となる内部原因も未確定。
- ユーザー了承のうえ、通常のビットストリーム経路の
  `--run 54` (exFlash Erase,Program,Verify Arora V) に変更。
  `--device GW5A-25A`、`--fsFile`、ヘッダ除去済みのデータ、各アドレス、書き込み順は維持。
- 偽 CLI を操作 54 の検査に対応させ、Config 失敗時は今回と同じエラー文と
  終了コード 0 を返すよう変更。後続書き込みの中断と成功扱いしないことを確認。
  94 チェック PASS、Release ビルド成功、配布 EXE とビルド出力の SHA256 一致。
- 操作 54 による Config・BIOS・バージョンの実機書き込みは未検証。
  ユーザーが修正版ツールで確認する。
## 2026/10/27 夜: ADPCM が鳴らない件の調査（コード未修正）
- 外部テスターから「FM 音源 (OPLL/OPL2/OPM) は鳴るが ADPCM が鳴らない」と報告。
- 一時テストベンチ（セッション作業領域、リポジトリ外）で `adpcm_patch/adpcm.v` を確認。
  - R#07=A0h / E0h とも `chon=0`、出力 0、メモリ読み出しなし。
  - 待機中・メモリ書き込み後のステータスはともに 06h（Y8950 なら BUF_RDY=bit3 が 1）。
- 主原因: jt10_adpcm_drvB の `acmd_up_b`（再生開始の 1 クロックパルス）が
  R#07 bit6 (REC) に直結されている。A0h の通常再生では開始されない。
- 残る互換性問題:
  1. アドレス単位: Y8950 は R#09-0Ch が 16bit・4 バイト単位（終了は 4 バイト末尾まで含む）。
     現状は再生側 256 バイト単位、CPU 側 32 バイト単位・13bit。
  2. ステータス配置: Y8950 は IRQ=bit7, EOS=bit4, BUF_RDY=bit3, PCM_BSY=bit0。
     現状は EOS が bit0、BUF_RDY が立たない（BIOS 等の待ちで停止の恐れ）。
  3. R#08 (ROM/64K)、メモリ読み出しの空読み 2 回、R#04 マスク/フラグリセットが未対応。

### やるべきこと（ユーザーの了承待ち）
1. R#07 書き込み（START=1）で acmd_up_b に 1 クロックパルスを生成。
2. アドレスを Y8950 準拠（4 バイト単位・16bit）に統一。jt10 カウンタの変更が必要なら
   `src/adpcm` は変更せず `adpcm_patch` にコピーして修正、.gprj も更新。
3. ステータス/BUF_RDY/EOS/PCM_BSY、R#04、空読みを openMSX の動作に合わせる。
4. ModelSim テスト追加（メモリ書き込み→A0h 再生→出力・EOS・アドレス範囲確認）。
- 修正範囲（1 のみか全部か）はユーザーに確認中。

## 2026/11/01: LINE OUT 出力レベル改善、ADPCM の Y8950 互換化
### 出力レベル (+18dB)
- `mixer/mixier.v` が 5 系統の合算後に `>>>3` (-18dB) していたため、
  16bit フルスケール音源 1 系統でも -24dBFS、FM 1 音では -42〜-49dBFS 程度だった。
- ユーザーの選択により `>>>3` を削除 (+18dB)。合算値は saturate_24 でクリップする。
  音量レジスタ 128 (×1) で 16bit フルスケール音源は -6dBFS。多数音源を同時に最大音量で鳴らすとクリップし得る。
- `mixer/test001/tb.sv` の期待値を更新。全 14 チェック OK。

### ADPCM (Y8950 互換化、修正範囲: 全部)
- `adpcm_patch/jt10_adpcmb_cnt.v` を新規コピーして修正し、.gprj も差し替えた。
  - 開始アドレスを 4 バイト単位に変更。
  - 終了アドレスは 4 バイト末尾まで含む。
  - リピート時もループ終端ごとに EOS を出す。
- `adpcm_patch/adpcm.v` を書き直した (openMSX Y8950Adpcm の動作に準拠)。
  - R#07 の START 書き込みで再生開始パルスを生成。再生は START & MEMDATA & !REC (A0h)。
  - ステータスを IRQ=bit7, EOS=bit4, BUF_RDY=bit3, bit2-1=1, PCM_BSY=bit0 とした。
    リセット時は全フラグがマスクされ、読み値は 06h。
  - R#04:
    - マスクとフラグを実装。
    - bit7 で全フラグをリセットする (マスクは保持)。
  - BUF_RDY:
    - 待機中とメモリ転送モード中は 1 を保持。
    - 書込み・読出し時は、SRAM への処理が完了するまで 0。
  - 再生終了時 (リピートなし) に R#07 の START 等をクリアし、PCM_BSY も 0 にする。
  - 再生していない間と SP-OFF 時は出力を 0 にする。
  - R#07=60h のメモリ書込み:
    - stop を書くと EOS を立て、ポインタは start に戻る。
  - R#07=20h のメモリ読出し:
    - 2 回の空読みの後、プリフェッチしたデータを返す。
    - stop を越えると 0 を返して EOS を立てる。
  - R#08:
    - bit1 (64K) で 16bit アドレスにマスクする。
    - bit0 (ROM) では読出しが 0 になり、書込みは無視する。
  - 未対応: CPU 直接合成 (START のみ) と録音 (REC)。
- `opl2_patch/opl2.v`:
  - マスクされていない ADPCM フラグ (`adpcm_irq`) を /INT に OR した (Y8950 と同じ動作)。
  - フラグはリセット時にマスクされているので、既存ソフトに影響はない想定。
- テスト:
  - `adpcm_patch/test001` (PAN) OK。
  - `adpcm_patch/test002` を新規作成。対象はステータス/マスク、60h 書込み、20h 読出し、
    64K/ROM、A0h 再生 (アドレス範囲 start*4〜stop*4+3、出力、EOS、PCM_BSY)、SP-OFF、リピート。全 OK。
  - `opl2_patch/test001` を新実装に合わせて修正し、OK。
  - トップの `test001` はエラーなく実行できた。
- 実機は未確認。ユーザーが合成して確認する。

### 残課題
- 実機での ADPCM 再生確認 (MSX-AUDIO BIOS や対応ソフト)。
- 出力レベルの実機確認。音割れする場合は、ゲインを +12dB 程度に戻すことを検討する。
- ミキサー (clk_42m) と I2S (clk_24m) の間のオーディオバスに同期化がない。
  まれにノイズが出る可能性があり、必要なら対策する。

## 2026/11/01: ミキサーから I2S へのクロック載せ替え
- 上記の未同期オーディオバスに対応。ミキサーが左右両方の演算を完了したときに
  `audio_valid` を出し、同じ演算サイクルの左右の値を受け渡す。
- `i2s_audio/audio_cdc.v` を追加。I2S 右チャンネル開始時の要求を 42MHz 側へ同期し、
  完成済みの 24bit × 2ch をビットごとの 2 本のトグル信号で伝送する。
  24MHz 側は全ビットの遷移を 2 段同期してから左右を同時に更新するため、
  クロックドメイン間の各ビットの到着順序に依存しない。
  同期段は GOWIN の `syn_preserve` で保持する。
- 受け渡しが完了するまで次の要求は出さない。遅延時は前回のステレオサンプルを
  維持する。I2S 左チャンネル開始時に右チャンネルの値も固定し、1 フレーム内で
  左右が異なるサンプルにならないようにした。
- I2S 側リセットの解除を 24MHz クロックに同期。GOWIN プロジェクトとトップレベル
  テストのファイル一覧に `audio_cdc.v` を追加。DSP / 乗算器の追加はない。
- ModelSim:
  - I2S の 24bit シリアル出力、先頭・末尾の 0、フレーム途中の値変更とリセットを確認。
  - CDC の各ビットの遅延、転送中の再要求、リセット、各種ビットパターンを異なる
    クロック比で確認。I2S / CDC の故障注入でテストが失敗を返すことも確認。
  - 実際のミキサー→CDC→I2S を 2 種類のクロック比で検証。それぞれ通常 225 フレーム、
    転送遅延中 3 フレームの保持と復帰、再生途中のリセットを確認。
  - 既存ミキサーテスト 14 項目とトップレベルテストが PASS。
- 前回の「I2S 96kHz」という記述を訂正。現在の PLL 設定は I2S クロック約 24.16193MHz、
  LRCLK 約 94.38kHz。今回クロック設定は変更していない。
- GOWIN 合成・配置配線と実機音声は未確認。同期回路の配置・タイミングと音声を確認する。

## 2026/11/01: ADPCM の音がノイズになる問題を修正
- 症状: 実機で ADPCM ドラムがノイズのように聞こえる。録音では約 20ms の短い高域のバーストになっていた。
- 原因: `opl2_patch/opl2.v` で ADPCM 用の約 49.7kHz の cen (`w_cen50`) を
  `ff_clk50_cnt == 0` から生成していた。カウンタは `enable` (42.95MHz の 12 クロックに
  1 回) のときだけ進むため、`w_cen50` は 12 クロック連続で High になっていた。
  `jt10_adpcmb_cnt` はそのすべてのクロックでアドレスを進める一方、デコーダは `enable`
  のクロックでしかニブルを取り込まない。そのためニブルが大量に抜け、再生速度も
  最大 12 倍速になっていた。
- 修正: `assign w_cen50 = enable && (ff_clk50_cnt == 10'd0);` とし、enable と同じクロックの
  1 パルスにした。
- 検証 (ModelSim):
  - 実機と同じ enable/cen 条件で、最後の 1 ニブルを除き、参照デコーダ
    (MAME/openMSX 方式) とデコード値がビット一致した。
    修正前は 3000 ニブル中 667〜999 個しか消費されず、全不一致。最終出力と参照の相関は 0.141 から 0.977 に改善。
  - 回帰テスト `opl2_patch/test002` を追加。BUF_RDY をポーリングしながら 600 バイトを書き込み、
    1200 ニブルの処理数と、最後の 1 ニブルを除くデコード値、再生時間、ADPCM の出力レベルを確認する。
    最後のニブルの値は再生終了時にクリアされるため照合対象外。修正前の RTL では失敗することも確認。
  - `opl2_patch/test001` はエラーなく実行、トップの `test001` は PASS。
  - 補足: シミュレーション中に jtopl2 の出力が X だと、`saturate_16` の出力が 7FFFh に見える。
    test002 は ADPCM のラッチ値のうち X でない値を計測している。
- 既存の `adpcm_patch/test002` は enable=1 で動かしていたため、このバグを検出できなかった。
- 未対応: CPU からの直接合成モード (R#07=80h、R#0Fh のデータを再生)。必要なら今後対応する。

### 本日の終了時点
- LINE OUT は、ユーザーから期待どおりの音量で出ているように見えるとの報告があった。
- 22:32 の GOWIN 配置配線ログでは配置配線とビットストリーム生成の完了を確認。
  タイミングの適合と修正版の実機音声は未確認。
- ADPCM の修正版について、問題を指摘した方による実機での音質確認結果を待つ。

## 2026/11/03: ADPCM ノイズの最終修正 (ssram.v の読み出しタイミング) — v0.9.7
- ユーザーが修正 (コミット c23c04a「v0.9.7 Bugfix ADPCM」)。修正後、実機で ADPCM が正常な音で鳴ることを確認済み。
- 原因: `ssram/ssram.v` (シリアル SRAM) の読み出しデータ取り込みタイミングの setup/hold 不足。
  従来は `!ff_sclk_div` (SCLK High 期間の途中、半シリアル周期早い位置) でサンプルしており、
  hold 側のマージンが基板の往復遅延に依存していた。ADPCM はサンプルメモリを SRAM から
  読み出すため、読み出し誤りがノイズとして現れた。
- 修正内容:
  - サンプル位置を SCLK High 期間の終わり (`ff_sclk_div == 1`、SCLK が立ち下がる直前のエッジ) に変更。
    SRAM が次のニブルを出すのはその立ち下がり後なので、誤って次のニブルを取り込まない。
    FPGA_MSXtR の ssram (`w_sclk_sample`) と同じサンプル位相。
  - これに合わせて取り込みステートを 1 つ前にずらした
    (上位ニブル: `c_state_read_wait`、下位ニブル: `c_state_read0`)。
  - `ifdef SIM` による分岐を削除し、シミュレーションと実機で常に
    `c_state_dummy5` → `c_state_read_wait` → `c_state_read0` の同じ経路を通るようにした。
- 11/01 の `opl2.v` の `w_cen50` 修正 (再生アドレスが最大 12 倍速で進む問題) も有効なまま。
  実機のノイズには、こちらの SRAM 読み出しタイミングが関係していた。

### 同時期の関連更新 (ユーザー作業)
- コミット 805d900: 更新ツールの Config/BIOS イメージを ZX0 ブロック圧縮形式に対応。
  - ヘッダ +31 を形式マーカー (00h: 非圧縮、01h: ZX0 ブロック圧縮) とした。
    16KB ブロック単位で圧縮し、効果がないブロックは無圧縮で格納する。
  - `tool/zx0pack.exe` (ソースは `tool/zx0pack`) を追加。`Y8960UPD.COM` と `Y8960UpdWin` は両形式に対応。
    仕様は `tool/y8960upd.md`、`tool_for_windows/readme.md` を参照。
- コミット c23c04a: `tool/config/mk.bat`、`tool/bios/mk.bat` で非圧縮版
  (`Y8960CFG_UNCOMPRESS.BIN`、`MSXSSE_UNCOMPRESS.ROM`) も生成するようにした。
- コミット b186a49: ADPCM 切り分け用の実機テスト一式 `y8960_adpcm_test/` を追加。
  再生ツール `ADPLAY.COM`、テストツール `ADTEST.COM`、テスト用 BIN と参照 WAV、生成スクリプト。

### 残課題
- CPU からの直接合成モード (R#07=80h) は未対応。必要なら対応する。

## 2026/11/03: ADPCM の CPU 合成モード (R#07=80h) を実装
- Y8950 の「CPU からの直接合成」に対応した。動作は openMSX の Y8950Adpcm に合わせた。
  - R#07 の START=1、REC=0、MEMORY DATA=0 で開始。ADPCM データはサンプルメモリではなく
    R#0F に書いた値を使う。
  - 上位ニブル (各バイトの最初のニブル) をデコードした時点で R#0F の値を確定し、BUF_RDY=1 にする。
    R#0F に書き込むと BUF_RDY=0。CPU は BUF_RDY を待って次のバイトを書く。
  - データが補給されない場合は、最後に書かれた R#0F の値を使い続ける (openMSX と同じ)。
  - 終了アドレスの判定はせず、EOS は出ない。R#07 を書き換えるまで鳴り続ける。PCM_BSY=1。
  - ADPCM メモリ (SRAM) へのアクセスは発生しない。DELTA-N、R#12 (音量)、SP-OFF、PAN は通常再生と同じ。
  - 注意: 待機中の BUF_RDY は 1 のため、R#07=80h の直後に 1 バイト目を書いてから
    BUF_RDY 待ちを始める必要がある (Y8950 / openMSX と同じ)。
- 変更ファイル:
  - `adpcm_patch/jt10_adpcm_drvB.v` を新規コピー (原本 `src/adpcm` は無変更)。
    `cpu_mode` 入力を追加し、`nibble_sel`、`chon` を出力。.gprj と各テストのファイル一覧を差し替えた。
  - `adpcm_patch/jt10_adpcmb_cnt.v`: `cpu_mode` 時は終了アドレス判定を行わない。
  - `adpcm_patch/adpcm.v`: 再生 (acmd_on_b) と出力ゲートを START & ~REC にした。
    CPU 合成モードでは、次に上位ニブルをデコードするまでデコーダ入力データが R#0F に追従し、
    上位ニブルのデコード直後に BUF_RDY をセットする。乗算器の追加はない。
- 検証 (ModelSim):
  - 回帰テスト `opl2_patch/test003` を追加。実機と同じ enable タイミングで、R#07=80h の後に
    test002 と同じ 600 バイトを BUF_RDY ポーリングで R#0F に供給する。
    1200 ニブルすべてのデコード値が参照と一致すること、ニブル周期 (1728 クロック)、
    EOS が出ないこと、PCM_BSY=1、SRAM アクセスなし、出力レベル、停止後の PCM_BSY=0 と出力 0 を確認。
  - 一時的に CPU 合成モードを無効にした RTL では test003 が失敗する (BUF_RDY timeout) ことを確認。
  - `adpcm_patch/test001`、`adpcm_patch/test002`、`opl2_patch/test001`、`opl2_patch/test002`、
    トップの `test001` も PASS。
- GOWIN 合成と実機確認はユーザーが実施済み。ADCPU で音が出ることを確認 (2026/11/03)。
- サンプルプログラム `y8960_adpcm_test/ADCPU.COM` (ソース `adcpu.asm`、`zma adcpu.asm ADCPU.COM`) を追加。
  - MSX-DOS 用。`ADCPU <file> [/D:xxxx] [/V:xx] [/R]`。ファイル全体をメイン RAM に読み込み、
    R#07=80h で BUF_RDY を待ちながら 1 バイトずつ R#0F に書いて鳴らす。ESC で停止。
  - 最初のデコードと CPU の書き込みの競合を避けるため、先頭バイトは START 前と START 後の 2 回書く。
    最後に詰め物 (80h) を 1 バイト送り、それが取り込まれたら停止する。
  - BUF_RDY のマスクを外すと /INT が出続けるため、再生中は割り込み禁止。ESC は PPI から直接読む。
  - ファイルサイズは FCB ではなく RDBLK で実際に読めたバイト数を使う (MSX-DOS 2.20 対策)。
  - 実機で ADCPU による再生 (音が出ること) を確認済み (2026/11/03)。

## 2026/11/03: SSG1 の Read 遮断をパラメータで切り替え
- 問題: カートリッジ版では MSX 本体の PSG と I/O A0h〜A2h が重なる。`dual_ssg #(.BUILTIN(0))` で
  core0 (SSG1) は Read に応答しなかったが、core1 (SSG2) はレジスタポインタが SSG1 側 (R#0〜15 など)
  を指していても A0h〜A2h の Read に FFh で応答していた (bus_rdata_en=1)。BIOS のジョイスティック
  読み出し (R#14 @A2h) などで本体 PSG とバス競合する。
- 対策:
  - `ssg/ssg_core.v` にパラメータ `read_others` を追加。0 のときは「A2h の Read で、ポインタが自コアの
    レジスタ (R#0〜15 (+16)、gain/pan) を指す場合」だけ応答する。既定値 1 は従来どおり。
  - `ssg/dual_ssg.v`: core1 の `read_others` に `BUILTIN` を渡す。
    BUILTIN=1 (MSXtR/MSX2++ 内蔵): SSG1/SSG2 とも Read 可 (従来どおり)。
    BUILTIN=0 (カートリッジ): SSG1 の Read と A0h/A1h の Read は一切バスを駆動しない。SSG2 の Read は可。
  - トップ `y8960_cartridge_tangprimer25k.v` は従来どおり `.BUILTIN(0)` (コメントを追記)。
- 検証 (ModelSim):
  - 新規 `ssg/test002`: BUILTIN=0/1 の 2 インスタンスに同じバスサイクルを与え、SSG1 の全レジスタ、
    gain/pan、A0h/A1h の Read でカートリッジ版がバスを駆動しないこと、SSG2 の Read は値が正しいことを確認。PASS。
    修正を無効にすると 24 件失敗することも確認。
  - `ssg/test001` (BUILTIN=1、OK 40 件)、トップ `test001` も PASS。
- GOWIN 合成と実機確認は未実施 (ユーザーが行う)。

## 2026/11/03: OPM + OPL2 演奏サンプル BRAND3 (ブランデンブルク協奏曲第3番)
- 新規 `y8960_fm_sample/`。MSX-DOS 用 `BRAND3.COM`。OPM 7ch + OPL2 5ch で第1楽章 + 第2楽章を演奏 (約 5 分)。
- 楽譜: suzumidi の MIDI は再配布不可のため不採用。Rosegarden のテストデータ
  `Brandenburg_No3-BWV_1048.ly` (D. Michael McIntyre、Public Domain、10 パート、137 小節) を使用。
- `lyparse.py` (LilyPond サブセットのパーサ) と `mksong.py` (→ `brand3.inc` 生成)。
  データ形式はチャンネル別ストリーム (1 音 1 バイト、音長変更時のみ長さバイト)。19KB。
- テンポは指揮者チャンネルの F8h コマンドで、「1 フレームあたり tick 数 × 256」を小数アキュムレータで加算。
  60Hz/50Hz 用の値をデータに持つ (実行時の除算なし)。Allegro: 16 分音符 = 8 フレーム。最終小節で ritardando、
  楽章間に休み、Adagio の最後はフェルマータ相当。
- 割り当て: Vn I〜III / Va I〜III → OPM ch0〜5 (L/C/R)、Violone 16' → OPM ch6、Vc I〜III → OPL2 ch1〜3
  (PAN 48/128/208)、Violone 8' → OPL2 ch4、Cembalo → OPL2 ch5。
- 検証: Python の Z80 エミュレータ (pip `z80`) で COM を実行し、全 12ch のキーオン音高列が楽譜と一致、
  同時発音のフレームが一致、50Hz 時の演奏時間 (×5/6)、ESC 停止時の全キーオフを確認。
- 未実施: 第3楽章 (PD の打ち込みデータが無い。IMSLP の Bach-Gesellschaft 版から打ち込む必要あり)。
- 実機での演奏をユーザーが確認済み。

## 2026/11/03: 全音源演奏サンプル CANCAN (天国と地獄)
- `y8960_fm_sample/` に MSX-DOS 用 `CANCAN.COM` を追加。オッフェンバック「地獄のギャロップ」を
  OPM / OPL2 / ADPCM / OPLL / SCC / SSG の全音源で演奏 (約 72 秒、27ch + 指揮者)。
- 構成: イントロ 4 小節 (全音源) → 主題 16 小節を SSG → SCC → OPLL → OPL2 → OPM のソロで順に → 全音源 (テンポアップ) → コーダ。
  ドラムは ADPCM (キック / スネア / クラッシュを `mkcancan.py` で合成・エンコードし、起動時に転送)。
- `mkcancan.py`: 主題とコード進行からハーモニー / 和音 / ベース / ドラムを生成し、`cancan.inc` を出力
  (ストリーム形式は BRAND3 と同じ。音程表 5 種、SCC 波形、ADPCM サンプル表も生成)。
- `cancan.asm` (BRAND3 の再生部を拡張):
  - OPLL は MMIO 7FF4h/7FF5h、SSG は SSG2 側 (MMIO 7FF0h/7FF1h、R#10h〜)、SCC は 9000h=3Fh で 9800h〜。
    各 PAN レジスタで定位。SCC / SSG はソフトウェアエンベロープ。
  - WRSLT では全音源が一斉に鳴る拍の処理が 1 フレームに収まらない見積もりだったため、演奏中は ENASLT で
    ページ 1・2 をカートリッジに切り替えて直接書き込む。演奏中に使うコード・データは 4000h 未満
    (ADPCM データだけ最後尾)、終了時に RAMAD1/RAMAD2 へ戻す。
  - zma のラベルは大文字小文字を区別しないため、`adpcm_data` と `ADPCM_DATA`、ローカルラベル `opll_fnum` と
    `OPLL_FNUM` が衝突した (定数名 / ラベル名を変更して回避)。
- 検証: Z80 エミュレータで ADPCM 転送データの一致、全 27ch のキーオン音高列 (ADPCM は開始アドレス) が
  楽譜と一致、同時発音フレームの一致、演奏中の WRSLT 0 回 / ページ 1・2 の RAM 非参照
  (切り替え中は RAM をゴミで埋めて確認)、最悪フレーム約 44.7k T ステート (NTSC 1 フレーム約 59.7k)、
  50Hz、ESC 停止、終了時に全音源が消音されることを確認。
- 実機での演奏をユーザーが確認済み (2026/11/03)。

## 2026/11/03: 音源間の音量バランス調整
- 報告: 全体的に ADPCM が大きく、FM 音源が小さい。
- 原因 (1ch 最大音量時のピーク、ミキサー入力の 16bit 換算):
  ADPCM ±32767 (0dB) / OPM ±8191 (-12dB) / OPL2 ±4095 (-18dB) / OPLL ±2550 (-22dB、MOVOL=10) /
  SCC ±512 (-36dB)。
  openMSX の Y8950 実装では FM 1ch 最大 ±2047、ADPCM 最大 ±2040 (32767×255>>12) でほぼ同じだが、
  `opl2_patch/opl2.v` は ADPCM の 16bit フルスケールを FM 出力にそのまま加算しており、約 +18dB 大きかった。
- 修正 (いずれもシフトのみ。乗算器は増やしていない):
  - `opl2_patch/opl2.v`: ADPCM を `>>> 3` してから FM と加算 (Y8950 と同じく ADPCM 最大 ≒ FM 1ch)。
  - `ikaopll_patch/opll.v`: `i_ACC_SIGNED_MOVOL` を 10 → 15 (1ch ±3825、リズムと同じ)。
  - `mixer/mixier.v`: 1ch ピークを OPM (±8191) に揃える。OPLL ×2、OPL2 ×2、SCC ×64 (従来 ×4)。
    1ch あたりマスター音量 128 で約 -18dBFS。多数チャンネル同時発音で飽和する場合はマスター音量で下げる想定。
- 検証 (ModelSim): `mixer/test001` (期待値を新スケールに更新)、`opl2_patch/test001` (Y8950 mix の期待値を更新)、
  `opl2_patch/test002`/`test003`、`ikaopll_patch/test001`、トップ `test001` すべて PASS。
- GOWIN 合成と実機確認は未実施 (ユーザーが行う)。

## 2026/11/03: SCC / SSG の音量調整 (音量バランス調整の続き)
- 報告: CANCAN で ADPCM と OPL2/OPLL/OPM のバランスは改善したが、SCC がほとんど聞こえず、SSG もかなり小さい。
- 分析:
  - SCC: 1ch 最大 (vol=15) は ±120、中央定位で ±85 (シミュレーションで実測)。×64 で OPM と同等のピークだったが、
    OPM は pan_lut を通らず L/R 両方にフルで出る (+3dB) うえ、キャリアが複数あると加算されるため相対的に小さい。
  - SSG: 13bit 符号なし (DC 成分付き) を ×1 で入力していた。1ch の AC 振幅は ±512 で、OPM より約 -24dB。
  - 参考: openMSX の既定バランスは PSG 1ch ≒ SCC 1ch ≒ FM 1ch (PSG 0.5×21000、SCC 0.93×11500、FM-PAC 1.0×13000)。
- 修正 (`mixer/mixier.v`、乗算器の追加なし):
  - SSG に DC カットを追加。1 次ハイパス `dc += (x - dc) >> 16` を 3.58MHz (clk/12、L/R は state 0/6) で更新
    (fc ≒ 8.7Hz)。音量レジスタ書き換えによる PCM 再生 (可聴帯域) は残る。DC オフセットでヘッドルームを食わなくなる。
  - スケール: SSG ×32 (AC ±512 → ±16384)、SCC ×128 (±120 → ±15360)。OPLL/OPL2 ×2、OPM ×1 は変更なし。
- 検証 (ModelSim): `mixer/test001` を更新 (従来ケースは DC 状態を force で 0 に固定して期待値を再計算、
  DC カットのステップ応答・収束・負方向ステップのテストを追加)。全 PASS。トップ `test001` も PASS。
- GOWIN 合成と実機確認は未実施 (ユーザーが行う)。大きすぎる場合は mixier.v のシフト量で調整する。
## 2026/11/03: SCC がプツプツノイズにしか聞こえない問題の修正
- 報告: SSG は改善したが、SCC はプツプツノイズが聞こえるだけで楽器音に聞こえない。
- 原因: `ikascc_patch/scc.v` で IKASCC の `i_MCLK_PCEN_n` (負論理のクロックイネーブル) に正論理の `enable` を
  そのまま接続していた。IKASCC が 12 クロック中 11 クロックで動作 (約 39.4MHz) し、発振周波数が 11 倍になっていた。
  高音域はエイリアスまたは可聴域外になり、ソフトウェアエンベロープによる音量変化だけがクリックとして聞こえていた。
  前回 SCC を ×128 にしたことで目立つようになった。OPLL (`opll.v`) と OPM (`opm.v`) は `~w_core_enable` で正しく接続済み。
- 修正: `scc.v` で `.i_MCLK_PCEN_n( ~enable )` に変更。
- 検証 (ModelSim): FREQ=100h (期待 435.2Hz) のゼロクロス回数が、修正前 478 回/100ms、修正後 43 回/100ms。
  `ikascc_patch/test002` に発振周波数チェック (50ms で 20〜23 周期) を追加。`ikascc_patch/test001`/`test002`、
  トップ `test001` すべて PASS。
- GOWIN 合成と実機確認は未実施 (ユーザーが行う)。
## 2026/11/03: SCC が鳴らない問題の修正 (極性修正の続き)
- 報告: 極性修正後、SCC の音が出ない。
- CANCAN 側: SCC 関連 (バンク 3Fh、波形、PAN、周波数、音量、988Fh=1Fh) の書き込み順序・アドレス、
  `cancan.inc` の波形・周波数テーブル、song_table の割り当て (30h-34h) を確認。ソフト側の問題は見つからず。
- 原因: IKASCC 同期版は、CS を検出した enable (T0) の次の enable (T1、約 280ns 後) にレジスタへ書き込むが、
  `IKASCC_player_s.v` の周波数・音量・チャンネル enable・test レジスタのデコードは T1 時点の生の `i_ABLO` と
  `i_SCCREG_EN` (RAMCTRL_ASYNC=1 のため生アドレスの組み合わせ回路) を使っていた。`msx_slot.v` は `bus_ready` の
  次のクロックで valid を下げ、アドレスは次のバスサイクルの値に追従するため、T1 には別アドレスになっていて
  書き込みが失われていた。極性が逆のときは T1 が T0 の 1 クロック後だったため偶然書けていた。
  波形 RAM (T0 で処理) とバンクレジスタ (T0 でラッチしたアドレスを使用) は影響なし。
  また、次のアドレスの下位が E0h 以上だと test レジスタへ誤書き込みする危険もあった。
- 修正 (`ikascc_patch/IKASCC_player_s.v`): T0 で `i_ABLO_Z`/`i_DB_Z` と一緒に `i_SCCREG_EN_Z` をラッチし、
  周波数・音量・mute・test レジスタの書き込みデコードをラッチ値で行う。`freq_changed` は生の /WR とアドレスではなく
  書き込み要求 (`freq_lo_wr | freq_hi_wr`) から生成する。
- 検証 (ModelSim): `ikascc_patch/test002` に msx_slot と同じバスタイミング (ready の次のクロックで valid を下げ、
  アドレスを 01E5h に変える) の書き込み・読み出しタスクを追加し、CANCAN と同じ手順の書き込みで FREQ/VOL/TEST、
  発振周波数、波形 RAM の書き込み・読み出しを確認。修正前の player_s では失敗し、修正後は PASS。
  `ikascc_patch/test001`、トップ `test001` も PASS。
- GOWIN 合成と実機確認は未実施 (ユーザーが行う)。

## 2026/11/03: SCC が鳴らない問題の調査 (継続中)
- 報告: 上記修正後も実機で SCC が鳴らない (前回の録音と同じ状況)。
- シミュレーション (ModelSim): `ikascc_patch/test001` の実機相当 Z80 バスモデル (/WR Low は約 1T) を一時コピーし、
  msx_slot → address_decode → scc の経路で CANCAN と同じ書き込みを流して確認。
  - bankreg2=3Fh、FREQ=100h、VOL=14、mute=1 と正しく書き込まれ、波形 RAM も期待値どおり。
  - ch1 の出力は波形どおりに変化し、`scc.v` の `sound_l_out` も -68 〜 +62 で 50ms あたり 21 周期 (期待値約 22) 発振。
  - 書き込みを止めていない ch2-5 は vol/freq がリセットされないためシミュレーションでは X になり、パン合成結果を
    X にする (実機は FF 初期値 0 のため問題にならないはず)。
  - このバスモデルでは「短い /WR で書き込みが落ちる」現象は再現しなかった。実機の信号タイミングとの差はあり得るため、
    仮説は未確認 (SCCDIAG の読み戻し結果で判断する)。
- 合成結果 (impl、11/03 22:52、最新ソースで合成済み): タイミング違反なし (TNS=0)。ただし clk_42m の最悪経路は
  `ff_slot_address` → `u_mem_chN/ramstyle_block.wavedata_ram` (posedge → negedge の半周期経路) でスラック 0.000。
  原本 IKASCC は `IKASCC_player_memory_s` に FAST_CLOCK を渡していないため、低速クロック用の negedge 版
  (block_slow) で合成されている。波形 RAM は FF (u_mem_ch1: REG 272) で実装。
- ミキサー (`mixier.v`)、`msx_slot.v` の SCC 音量 (初期値 128)、トップの接続、アドレスデコードに問題は見つからず。
- 実機での切り分け用に `y8960_fm_sample/sccdiag.asm` (SCCDIAG.COM) を作成:
  7FFAh=80h (SCC ミキサー音量)、9000h=3Fh、ch.A 波形 RAM に鋸波を書き込んで読み戻し、ch.A を約 440Hz・音量 15 で
  約 3 秒鳴らし、読み戻し値と OK/NG を表示する。
- TODO: SCCDIAG の実機結果で切り分ける。
  - 読み戻し NG → 書き込み/読み出し経路 (msx_slot、IKASCC の波形 RAM) の問題。
  - 読み戻し OK で無音 → 発振・出力側 (negedge 波形 RAM のタイミング、パン合成、ミキサー) の問題。
    FAST_CLOCK=1 (posedge の block_fast) を patch 側で渡す対策を検討する。
- SCCDIAG の実機結果: 無音、Wave RAM: NG。読み戻し値 (F3 E1 F3 AF 32 83 F9 35 ...) は Y8960 BASIC ROM の
  バンク 2 付近のコード (`tool/bios/y8960bas.rom` の 058ACh 付近とほぼ一致、ビルド差あり) で、9800h が SCC ではなく
  マッパー SRAM を読んでいた = BANK2 が 3Fh になっていない。
- 原因 (確定): Y8960 BASIC ROM が `ld a,1 / ld (4FFBh),a` で RAM Mode=1 にし (ROM 内 14 か所)、そのまま DOS が起動する。
  RAM Mode=1 では BANK2 のレジスタは 4FFEh で、9000h への書き込みは無視されるため、CANCAN / SCCDIAG の
  `9000h=3Fh` が効いていなかった。FPGA 側の問題ではなかった。
- 修正 (ソフト側):
  - `cancan.asm`: `set_scc_bank2` を追加し、4FFEh (RAM Mode=1) と 9000h (RAM Mode=0) の両方に BANK2 を書く
    (それぞれ他方のモードでは無視される)。scc_init で 3Fh、shutdown で 02h。RAM Mode 自体は変更しない
    (BIOS が RAM Mode=1 を前提にしており、SRAM アドレスも RAM Mode で変わるため)。
  - `sccdiag.asm`: 同様に 4FFEh と 9000h の両方に書く。
  - CANCAN.COM / SCCDIAG.COM を再ビルド。
- 課題: BIOS が RAM Mode=1 のまま DOS / ゲームに制御を渡すと、9000h=3Fh で SCC を使う一般の SCC 対応ソフトが
  SCC を使えない。BIOS の終了時に RAM Mode=0 に戻すかどうか要検討 (ユーザー判断)。
- 今回の FPGA 修正 (`scc.v` の極性、`IKASCC_player_s.v` のアドレスラッチ) はシミュレーションで効果を確認済みなので維持。

## 2026/11/03 作業終了時点の状況 (SCC が鳴らない件)
- 状況: 原因は BIOS が RAM Mode=1 のまま DOS を起動していたことと判明。CANCAN.COM / SCCDIAG.COM は
  4FFEh と 9000h の両方に BANK2 を書くよう修正・再ビルド済みだが、実機では未確認。
- BIOS 担当者に「RAM Mode=0 に戻してから DOS を起動できないか」を確認中 (ユーザー経由)。
- 本日の未コミット変更 (コミットはユーザーが行う):
  - FPGA: `mixer/mixier.v` (SSG DC カット、各音源スケール)、`opl2_patch/opl2.v` (ADPCM >>>3)、
    `ikaopll_patch/opll.v` (MOVOL=15)、`ikascc_patch/scc.v` (i_MCLK_PCEN_n の極性)、
    `ikascc_patch/IKASCC_player_s.v` (レジスタ書き込みデコードをラッチ値で行う)、各テストベンチ。
  - ソフト: `y8960_fm_sample/cancan.asm`、`sccdiag.asm` (新規)、README.md、CANCAN.COM、SCCDIAG.COM。
- 次回やること:
  1. 実機で SCCDIAG を実行し、`Wave RAM: OK` と 440Hz の発音を確認する。
  2. CANCAN.COM で SCC が楽器音として鳴るか、音量バランス (SCC ×128、SSG ×32) が適切かを確認する。
     必要なら `mixier.v` のシフト量で調整する。
  3. BIOS 担当者の回答を受けて、RAM Mode の扱いを決める。RAM Mode=0 で DOS が起動するようになれば、
     一般の SCC 対応ソフト (9000h=3Fh) もそのまま動く。サンプルの 4FFEh への書き込みは両対応のため残してよい。
  4. FPGA の SCC 修正 (極性、アドレスラッチ) を入れた合成結果で、他の音源やバスアクセスに問題がないかを確認する。

## 2026/11/04: CANCAN に RAM Mode=0 への暫定切り替えを追加
- BIOS 担当者が、DOS 起動前に RAM Mode=0 に戻すことを約束した。それまでの暫定対応として、CANCAN の冒頭で
  Y8960 BIOS を検出したら RAM Mode=0 にする。
- `cancan.asm`: `bios_ram_mode_off` を追加。find_and_enable で見つけたスロットの 4010h から 8 バイトを RDSLT で読み、
  "MSSE8960" (Y8960 BIOS の各バンク +0010h にあるシグネチャ) と一致したら WRSLT で 4FFBh=00h を 1 回書く。
- 安全性の根拠:
  - SRAM アドレスは `scc_ma[17:13]` (バンク番号) だけで決まり、RAM Mode では変わらない。バンクレジスタの値も
    保持されるので、切り替えても見えている内容は変わらない。
  - BIOS は バンク切り替えの前に必ず `ld (4FFBh),1` を書いている (ROM 内 14 か所)。RAM Mode=0 でも 4FFBh への
    書き込みは有効なので、BIOS が動けば自分で RAM Mode=1 に戻す。
  - BANK0 (4000h-5FFFh) は常に読み出し専用なので、4FFBh への書き込みが SRAM を壊すことはない。
- `set_scc_bank2` (4FFEh と 9000h の両方に書く) はそのまま残す。RAM Mode=0 では 4FFEh への書き込みは無視される。
- CANCAN.COM を再ビルド (`bios_ram_mode_off` は 021Dh、4000h 未満)。実機では未確認。
- BIOS が修正されたら、`bios_ram_mode_off` は不要になる (残しても害はない)。

## 2026/11/04: SCC のメモリ書き込み取りこぼしを修正 (ポステッドライト)
- 実機での症状: 起動ごとに SCC が鳴ったり鳴らなかったりする。鳴っても SCC パートだけでたらめな演奏になる。
- 原因: scc.v が `bus_ready = cs & enable` で、enable (3.58MHz, 12 クロックごと) が来るまで書き込みを受け付けなかった。
  Z80 のメモリ書き込みでは /WR が約 280ns (12 クロック) しかなく、msx_slot のアクセス開始は /WR から約 5 クロック後。
  enable が来る前に /WR が終わると valid が落ちて書き込みが消える (12 位相中 5 位相)。カートリッジと本体のクロックは
  非同期で位相がゆっくり動くので、起動ごとにバンク切り替えや周波数・音量の書き込みが消えたり消えなかったりする。
  I/O 書き込みはウェイトで /WR が長く、他の音源は即座に ready を返すので影響しない。
  (以前は enable の極性が逆で、ほぼ毎クロック enable だったので顕在化していなかった)
- 修正 (`ikascc_patch/scc.v`): 書き込みは即座に ready を返してアドレス・データをラッチし (ff_wr_pending)、次の enable で
  IKASCC と PAN レジスタに渡す。IKASCC は enable でサンプルした /CS の立ち下がりで書き込みを検出するため、書き込みの次の
  enable では /CS を非アクティブにする (ff_wr_gap)。その期間に来た書き込みは、さらに次の enable で渡す。
  /CS は o_ROMCS_n (scc_bank) のために組み合わせのまま。読み出しは従来どおり enable で ready。
- test002 に `write_z80` (valid を最大 7 クロックで落とす) を追加し、enable の 12 位相すべてで FREQ/VOL/PAN/波形 RAM を
  確認。修正前は位相 0-4 で FAIL、修正後は PASS。ikascc test001・test002、トップ test001 すべて PASS。
- 合成と実機確認は未実施。

## 2026/11/04 朝 作業終了時点の状況
- scc.v のポステッドライト修正を合成したところ、タイミング違反が出た。ユーザーが合成パラメーターを変えて再合成中。
  - パラメーターで解消しない場合は、scc.v の追加ロジックを見直す必要がある。候補は次のとおり。
    - `w_core_address` / `w_core_wdata` のマルチプレクサが IKASCC の入力に直結している。
    - `w_core_cs` → IKASCC_vrc_s の `o_ROMCS_n` → scc_bank という組み合わせ経路が長くなった。
    - 以前から、波形 RAM が立ち下がりエッジ版のため半周期の経路でスラックが 0ns だった。
  - タイミングレポートで、違反している経路の始点と終点を確認するところから再開する。
- 実機確認は未実施（帰宅後）。
  - CANCAN.COM（RAM Mode=0 暫定コード入り）と新しい FPGA で、起動を繰り返しても SCC が毎回正しく鳴るか。
  - SCCDIAG の結果と、SCC の音量バランス（×128）。
- メモリマップド I/O（7FF0h-7FFFh）にある他の音源ポートも、短い /WR で取りこぼさないか気になる。
  ソースを読んだ範囲での見立ては次のとおり（シミュレーション未確認）。
  - OPLL（opll.v）: `w_capture = cs & valid & ~seen & (queue != 8)`。enable を待たずに即座にキューへ入れるので大丈夫そう。
    ただし、キュー（8 段）が満杯のときは capture せず /WAIT も出さないので、その間の書き込みは消える可能性がある。
  - OPM（opm.v）: 即座にキューへ入れる。満杯時は wait_n で待たせる仕組みがあるので大丈夫そう。
  - OPL2（opl2.v）: `ff_ready` は書き込みでは 1 のままなので即座に受け付ける（読み出し待ち中を除く）。
  - SSG（ssg_core.v）: `bus_ready = bus_valid` で即座に受け付ける。
  - ミキサー音量・IO_EN（msx_slot.v / y8960_address_decode.v）: 即座に受け付ける。
  - 次回、test002 の `write_z80` と同じ「valid を最大 7 クロックで落とす」書き込みで、各ポートを確認するテストを
    トップ階層か各モジュールに追加する。OPLL はキュー満杯時の扱いも確認する。

## 2026/11/04 夜: SCC 波形 RAM のタイミング違反を修正
- 合成結果: clk_42m で Setup 違反 474 本 (WNS -1.509ns, TNS -388.858ns)。全経路が
  `u_msx_slot/ff_slot_address` → IKASCC 波形 RAM (CE/D) の立ち上がり→立ち下がり (半周期 11.6ns) 経路。
- 原因: 波形 RAM が `negedge` 版 (`block_slow`) になっていた。原本 IKASCC.v は IMPL_TYPE=0 で FAST_CLOCK=1 を
  IKASCC_player_s に渡すが、player_s が IKASCC_player_memory_s に FAST_CLOCK を渡していない (原本の渡し忘れ)。
  RAMCTRL_ASYNC=1 なので、アドレスデコード → /CS → ram_wrrq / アドレス選択 → RAM が組み合わせで半周期に入る。
  以前からスラック 0ns で、ポステッドライトのマルチプレクサ追加で違反になった。
- 修正:
  - `ikascc_patch/IKASCC_player_s.v`: 4 つの memory に `.FAST_CLOCK(FAST_CLOCK)` を渡す (posedge RAM、全周期 23.3ns)。
  - `ikascc_patch/scc.v`: posedge RAM では CPU 読み出しデータが 1 クロック遅れるので、読み出しの `bus_ready` と
    `bus_rdata_en` を `ff_rd_seen` (アクセス 2 クロック目から 1) で遅らせる。読み出しの ready は enable を待たなくなった。
- ikascc test001・test002 (read_slot / write_z80 含む)、トップ test001 すべて PASS。再合成と実機確認は未実施。
- 実機確認: 再合成後、SCC が毎回正しく鳴ることを確認した。

## 2026/11/04 夜: ADPCM が小さく聞こえる件
- 症状: SCC が鳴るようになったら、ADPCM が以前より小さく聞こえる（FM パートでも）。
- ADPCM の経路（opl2.v の ADPCM、sram_arbiter、mixier.v）は変更していない。今日の FPGA 変更は SCC だけ。
- 仮説: SCC が初めて鳴るようになり相対的に小さく聞こえる。SCC ×128 は SCC が鳴らない状態で決めた値で、
  CANCAN の SCC 5ch は OPM 1ch フル出力の約 6 倍と見積もられ大きすぎる。ALL パートでは 24bit 飽和の可能性もある。
- 切り分け: CANCAN の scc_init でミキサー SCC 音量 (7FFAh) を 64 に設定（shutdown で 128 に戻す）。
  これで良ければ mixier.v の SCC 倍率を ×128 → ×64 に変更し、CANCAN の設定は外す。- 結果: SCC を 64 にしても ADPCM だけ控えめなまま。SCC の相対音量が原因ではない。
- 最新 BIOS (tool/bios/y8960bas.rom) のミキサー書き込みを調査:
  - 初期化で 7FFEh/7FF7h-7FFAh/7FFDh にすべて 80h (128) を書く。
  - そのほかは、スタックに退避した値を書き戻す処理と、CALL 拡張命令 (引数 6 個、129 以上はエラー) だけ。
  - 7FF6h/7FFFh への書き込みは I/O Enabler で、音量には関係しない。
  - BIOS が音量を 128 以外のまま残す経路は見当たらない。
- ADPCM の経路 (opl2.v/adpcm.v/sram_arbiter.v/mixier.v) は、バランス良好と確認した 11/03 の版から変わっていない。
- CANCAN: SCC 64 の試験設定を外し、mixer_init で 6 本のミキサー音量 (7FF7h-7FFAh, 7FFDh, 7FFEh) を
  すべて 128 に設定するようにした (書き込み専用で読み戻せないため、終了時の復元はしない)。
- ADPCM が小さく聞こえる原因は未特定。- 実機 (mixer_init 版): SSG と SCC が大きく、ADPCM のスネアが潰れて聞こえる。録音 (d:\RECORD\A\20250602020610.WAV) を解析した:
  - 区間 RMS: SSG 0.111 / SCC 0.139 / OPLL 0.089 / OPL2 0.075 / OPM 0.048。ALL 区間はピーク 0.98 (飽和寸前)。
  - 高域 (2 階差分) の 99.9% 値: SCC 区間 0.25 / SSG 0.17 / OPM 0.03。SCC と SSG の倍音がスネア帯域を覆っている。
  - OPM 1ch フル出力 = 1 とした見積もり: スネア 22000 (>>>3, x2, 中央 0.7) ≒ 0.47、SSG 1ch ≒ 2、SCC 1ch ≒ 1.3。
  - SCC 書き込み (9800h-) は SRAM 調停を通らないので、ADPCM の読み出しには影響しない。
- 修正 (要再合成):
  - `mixer/mixier.v`: SSG x32 → x16、SCC x128 → x64。
  - `opl2_patch/opl2.v`: ADPCM `>>>3` → `>>>2` (OPL2 6ch + ADPCM = ±32762 で 16bit に収まる)。
  - mixer test001 と opl2 test001 の期待値を新倍率で更新し、両方 PASS。- 再合成後の実機 (SSG x16, SCC x64, ADPCM >>>2): 「すごくノイズ」。録音 (Desktop\20250602023404.WAV) を解析:
  - キック/スネアの打点ごとに約 0.22 秒、平坦で大きな広帯域ノイズ (RMS 0.17)。以前の録音は打点から減衰する正常な形。
  - ADPCM データが壊れてデコーダが乱数状の値を出している特徴。音量 2 倍だけではこの波形にならない。
  - タイミング違反なし。ただし SerialSRAM (SQI, SCLK 85.9MHz) の sram_sio に I/O タイミング制約がなく、
    配置配線ごとに取り込み余裕が変わる可能性がある (前回の「スネアが潰れた」もその一端かもしれない)。
- 切り分け: CANCAN に adpcm_verify を追加。ロード後にメモリ読み出しモードで 2 回読み戻し、不一致数を 16 進で表示。
  2 回とも同じ数 → 書き込みで破損。回ごとに違う → 読み出しが不安定。0 → データは正常 (再生経路を調べる)。- 実機の adpcm_verify: 3074h 3074h (12444 バイト中 12404 不一致、2 回とも同数)。ほぼ全バイト破損で、書き込み時点で壊れている。
  BIOS (SerialSRAM 上) は起動できているので読み出しは動いている。
- 怪しい点: 今朝タイミング違反対策で PnR の Map_Option を 2 → 1 に変更している (impl/..._process_config.json)。
  SerialSRAM の sio/sclk は I/O タイミング制約がなく、書き込みのセットアップは SCLK 半周期 (約 5.8ns) しかない。
  ssram/arbiter/adpcm の RTL は ADPCM が正常だった 11/03 から変わっていない。
- 次: Map_Option を 2 に戻して再合成し、verify が 0000 になるか確認する。直れば SRAM I/O の制約を追加する。
## 2026/11/04 夜: ADPCM メモリ破損の原因特定 (SerialSRAM の TCSH 違反)
- Map_Option を 2 に戻しても verify は 306Ah 306Ah (ほぼ全バイト不一致) で直らず。配置の問題ではなかった。
- トップレベル RTL で CANCAN と同じ手順 (メモリ書き込みモードでロード → 読み戻し ×2) を再現 (src/test002 として追加)。
  論理は正しく、書き込み・読み戻しとも全一致。
- 原因: ssram.v の単発 BYTE WRITE 終了時、最後の SCLK 立ち下がりと CE# 立ち上がりが同じクロックエッジだった。
  23AA04M の TCSH (CS Hold Time) は min 3ns なのに実質 0ns。パッドのスキューで CE# が先に上がると書き込みが確定しない。
  - ブートコピーはバースト書き込みなので最後の 1 バイト以外は確定し、BIOS は正常に起動する。
  - ADPCM の書き込みは全て単発書き込みなので、ほぼ全滅する。ビルドごとに症状が変わったのもスキュー依存のため。
  - CPU からの SRAM 単発書き込み (RAM Mode など) も同じ影響を受けていたはず。
- 修正: ssram.v に c_state_write2 を追加。write1 で SCLK を止めて CE# は Low のまま、次のステートで CE# を上げる (TCSH 約 11.6ns)。
- ssram_test_model.v に TCSH チェックを追加 (書き込みコマンドの CS# 立ち上がりで検査し、tcsh_errors を数える)。
  - 修正前の ssram.v では 201 件の違反 (ADPCM 200 + ブートコピーの最終バイト)、修正後は 0 件。
- 回帰: src/test001 PASS、src/test002 PASS。
  ssram/test001 と test002 は以前から古いポート構成のためロードエラー (今回の変更とは無関係)。
- 未修正: 読み出し終了 (read2) と EQIO 終了でも同じエッジで CE# を上げているが、読み出しは動作しているので変更していない。
- 次: 再合成して CANCAN の verify が 0000 0000 になるか確認する。直ったら音量バランス (SSG ×16, SCC ×64, ADPCM >>>2) を再評価し、
  verify 診断コードを削除する。
## 2026/11/04 夜: 実機確認 OK
- ssram.v の TCSH 修正を合成した実機で、ADPCM が正常に鳴ることを確認。音量バランスも期待通り (SSG ×16, SCC ×64, ADPCM >>>2 で確定)。
- CANCAN から verify 診断コード (adpcm_verify / print_verify / put_hex16 と関連変数・メッセージ) を削除。mixer_init は残す。
- 残課題:
  - MMIO 音源の短い /WR のテスト (OPLL キュー満杯を含む)。
  - 修正版 BIOS が出たら、CANCAN の bios_ram_mode_off を残すか判断する。
  - ssram の読み出し終了・EQIO 終了でも CE# と最後の SCLK 立ち下がりが同じエッジ (動作はしているが TCSH は満たしていない)。
  - ssram/test001, test002 が古いポート構成のままでロードできない。
- 次回 (11/05): FM 音源 (OPL2 7FF2h-7FF3h / OPM) を Memory Mapped I/O 経由で鳴らして、正しく鳴るか確認する。
  CANCAN の OPL2 は現在 I/O ポート (C0h/C1h) でアクセスしている。MMIO 版の確認手段 (CANCAN の切り替え、または専用サンプル) を検討する。
## 2026/11/05 朝: OPL2 PAN が 1ch ずれる不具合の修正
- 外部から指摘: v0.9.10 で OPL2 の PAN レジスタ (F6h-FEh) が 1ch ずれて効く (ch1←F7h, ch2←F8h, …, ch8←FEh, ch9←F6h)。
  SSG / SCC / OPLL の PAN は正常。
- 原因: opl2_patch/jtopl_acc.v で、op2x_d / sum_en_d / zero_d は cenop で 1 スロット遅延させているのに、
  pan は遅延なしで pan_lut (毎 clk 更新) に入れていた。そのため op2x_d に掛かるゲインが次スロット (= 次 ch) の PAN になっていた。
- 修正: jtopl_acc.v に pan_d (cenop で pan を取り込む、リセット値 128) を追加し、pan_lut には pan_d を入力。
- テスト: opl2_patch/test004 を追加 (1ch ずつ鳴らし、その ch の PAN=0、他 ch=255 で L のみに出ることを確認)。
  - 修正前は全 ch が R に出て FAIL (不具合を再現)、修正後は全 ch L=4085 / R≒5 で PASS。
  - 注意: シミュレーションでは一度もキーオンしていないスロットの op_result が X になり、アキュムレータ全体が X になる。
    test004 では初期化時に全 ch を一度キーオン/オフしている。
  - 回帰: opl2_patch/test001 (PAN ゲイン含む)、test002、test003 すべて PASS。
- 次: 再合成して実機で OPL2 の PAN を確認 (リズムモード、ADPCM の FFh も)。その後 FM 音源の MMIO アクセス確認。
- 実機で OPL2 PAN の修正を確認し、v0.9.11 としてリリース (https://github.com/hra1129/Y8960_Cartridge/releases/tag/v0.9.11)。
- 次: FM 音源 (OPL2 / OPM / OPLL) の Memory Mapped I/O アクセス確認。

## 2026/11/05 夜: OPLL リズム音のレベルが実チップの半分
- 外部から指摘: 実チップは RO 出力の時点でリズムがメロディの 2 倍のゲインになっている (MO:RO は外部で 1:1 に混ぜる)。
  Y8960 ではアキュムレータ出力を使っているので 2 倍になっていないのではないか。
- シミュレーションで確認 (1 フレーム 18 サイクルを観測):
  - リズム 5 サンプルは cyc13-17 で生成されて累算される。percussion SR が同じ値を次フレームの cyc0,1,2,6,7 で RO に再送する
    (実チップの RO はリズムを 2 回出力)。しかし dac_acc_en=0 なので再送分は累算されない。メロディは cyc3-5, 9-11 で 1 回ずつ。
  - よってアキュムレータではリズムが実チップの半分。指摘どおり。
  - 再送サイクルの PAN はメロディ ch の値なので、再送サイクルを累算する方式は PAN が崩れる。
- 修正: ikaopll_patch/IKAOPLL_modules/IKAOPLL_dac.v で、ro_ctrl_z のサイクルの加算値を 2 倍 (<<<1) にした (dac_acc_add_l/r)。乗算器の追加なし。
  実チップは前フレームと今フレームのサンプルの和なので厳密には 2 タップの平均だが、ゲインは同じ。
- 確認: プローブでリズムのサイクルだけ addL = 2 × smpL、メロディはそのまま。ikaopll_patch/test001 PASS。
- 注意: メロディ 6ch とリズム 5ch がすべて最大だと 16bit 飽和の可能性がある (アキュムレータは 17bit で飽和処理あり)。
- 次: 再合成して実機でリズムのバランスを確認。
- 確認用に OPLL サンプル OPLLRHY.COM を作成 (y8960_fm_sample/opllrhy.asm, mkopllrhy.py, opllrhy.inc)。
  - ドラムデモ (BD → SD → TOM → CYM → HH → 全部、各 1 小節) の後、メロディ 6ch + リズムの 8 ビート曲 (A-B-A + エンディング、約 64 秒)。
  - OPLL は MMIO 7FF4h/7FF5h。演奏方式は CANCAN と同じ。リズムの F-Number は MSX-MUSIC と同じ値、音量は全て最大。
  - ビルド: python mkopllrhy.py → ..\tool\zma.exe opllrhy.asm OPLLRHY.COM (2845 バイト)。実機未確認。
- 次: 再合成した FPGA で OPLLRHY を鳴らし、リズムとメロディのバランスを確認。
- 実機で OPLLRHY によりリズム音量の修正を確認し、v0.9.12 としてリリース (https://github.com/hra1129/Y8960_Cartridge/releases/tag/v0.9.12)。
- 次: FM 音源 (OPL2 / OPM / OPLL) の Memory Mapped I/O アクセス確認。

## MMIOTEST (Memory Mapped I/O テストプログラム)

- y8960_fm_sample/mmiotest.asm, mkmmiotest.py, mmiotest.inc, MMIOTEST.COM を新規作成。
- 7FFFh=00h で OPL2/OPM/SSG の I/O を切り離し、MMIO (7FF0h〜7FFFh) だけで
  SSG1 / SSG2 / OPLL ch1 / OPLL リズム / OPL2 ch1 / OPM ch1 を鳴らす (ド・ミ・ソ・ド、PAN 左・右・中央・中央)。
- ADPCM は MMIO でメモリへ書き込み (ソフトウェアウェイト)、I/O C0h/C1h で読み戻して比較し OK/NG を表示、
  その後 PAN 左・右・中央で再生。
- 7FF6h (OPLL I/O Enabler) は読み出せないため変更しない。終了時・ESC 中断時は 7FFFh を起動前の値に戻す。
- Z80 エミュレータで MMIO 書き込み列・音程・PAN・verify (正常/不一致)・ESC 中断を確認済み。
- README.md に MMIOTEST の節を追加。
- 実機で全テスト (SSG1/SSG2/OPLL/リズム/OPL2/OPM/ADPCM) の発音を確認済み。

## 2026/11/09: Y8950 と Y8960 の ADPCM 録音比較

- Y8960 の ADPCM に少しノイズが混じって聞こえるため、`work/Y8950_cut.wav` と `work/Y8960_cut.wav` を比較した。
- 両録音は 48 kHz・16 bit・ステレオ。比較した再生開始後の約 0.25 秒では、Y8960 は Y8950 より 200 Hz〜3 kHz で約 5 dB、6〜10 kHz で約 20 dB 大きかった。音量差を考慮しても高域は相対的に約 15 dB 強い。両録音にクリッピングはない。
- 周波数ピークは両機で共通するものが多く、再生音に伴う高域成分の差が聞こえ方に影響している可能性がある。原因は未特定であり、SRAM 応答遅延が原因とする根拠も得られていない。
- Y8960 にはデジタル・アナログともに出力ローパスフィルターがないため、高域が残りやすい可能性がある。ADPCM の補間処理や両機の出力経路の違いも含め、対処は明日検討する。
- 次回は Y8960 録音の高域を抑えて Y8950 と比較し、周波数特性の違いが聞こえる差を説明できるか確認する。今回は RTL の変更やフィルター追加は行っていない。
## 2026/11/13: ADPCM リミッタ二重ラップ修正と補間器の厳密化

- ダッシュボードの残件 2 件を src/adpcm_patch のコピーで修正 (原本 src/adpcm は未変更)。
- jt10_adpcmb.v (新規コピー): d3 が 32767 を超える (最大 46080) と加算結果が ±65536 を越えて折り返し、
  元の符号判定をすり抜けていた。加算を 18 bit に広げて ±32767/-32768 に飽和させるよう修正。
- jt10_adpcmb_interpol.v (新規コピー・本体書き換え): 前区間長で割った傾きを次区間に流用していたため、
  65536/DELTA-N が整数でないと段差・平坦部が生じていた。cnt の位相 (phase) を使い
  x[n-1] + floor((x[n]-x[n-1]) * phase / 65536) を 16 段のシフト加算で求める厳密な線形補間に変更。
  乗算器・除算器は不使用。jt10_adpcm_div.v は不要になったため gprj から削除。
- jt10_adpcmb_cnt.v に phase 出力を追加し、jt10_adpcm_drvB.v で補間器へ接続。
- gprj と各テストの run.bat (adpcm_patch/test001-002, opl2_patch/test001-004, src/test001-002) を更新。
- ModelSim で参照モデル (飽和デコーダ + 厳密補間) と 5 信号 x 5 DELTA-N でビット一致を確認。
  6-8 kHz / 1-2.5 kHz 帯域比: chime 3A0E -26.3 -> -34.8 dB、tone 7000 -29.0 -> -39.3 dB、
  square 0C00 -7.4 -> -26.9 dB。DELTA-N=5555 (CANCAN) はほぼ変化なし。既存回帰テストは全て PASS。
- 次: GOWIN で合成しリソース・タイミングを確認、実機で各 DELTA-N の音質 (スネアの立ち上がり等) を確認。
  出力 FIR LPF は引き続き最終仕上げとして保留。
## 2026/11/13: ADPCM 再生の連続リスタート時の「ジー」音を修正

- SMORES.COM (タイトル画面で GRAPH キーを押し続ける) で「ジーー」と鳴る問題を解析。
  キーを押している間、R#07=01h (RESET) → R#04 → R#09-0Ch → R#07=A0h (START) を
  約 150 us 周期で繰り返し書き込んでいる。
- 原因: 補間器は chon=0 の間に止まるだけで、前回の再生の最後の値を保持していた。
  RESET 中は adpcm.v が出力を 0 にし、START 直後は保持していた値が出力される。
  この 0 と保持値の切り替えが約 6.6 kHz の矩形波になっていた。
  START から次の RESET まで 3 cen55 未満のため、次のサンプルに進まず、保持値はいつまでも消えない。
  元の jt10 の補間器も cen55 && chon でゲートするだけなので、以前から同じ問題があった。
- 修正: jt10_adpcmb_interpol.v に chon 入力を追加し、chon=0 の間は x_prev / pcminter を 0 にクリア
  (デコーダが chon=0 で x1 を 0 にするのと同じ扱い)。jt10_adpcm_drvB.v から chon を接続。
- standard.smp と同じレジスタ書き込み列を ModelSim で再現: 修正前は押下中に 0/-177/-334/-480 のパルス、
  修正後は 0。通常再生の出力は変化なし、補間のビット一致・既存回帰テストも全て PASS。
- 次: 合成して実機で SMORES の GRAPH 押下中に無音になることを確認。

## 2026/11/13: ADPCM 出力 LPF (25 タップ FIR) を追加

- SMORES の standard.smp 末尾 (370-515 ms) の「ブー」は約 100 Hz のノコギリ波 (倍音 200/400 Hz, 約 -26 dB) で、
  ADPCM データ自体に含まれている。実機 Y8950 は出力のアナログ LPF で高域が丸まるため目立たない、と解釈し、
  Y8950 相当の固定 LPF を ADPCM 経路 (ミキサ手前、PAN 乗算の前) に追加した。
- src/adpcm_patch/adpcm_lpf.v (新規): 25 タップ線形位相 FIR。Kaiser 窓 (beta=5), fc=5.5 kHz,
  fs=3579545/72 (cen55)。補間後の cen55 固定レートのサンプル列にかけるので、
  カットオフは Hz 単位で固定 (DELTA-N に依存しない)。
  係数 Q15 (k=0..12, 左右対称, 合計 32768): 28, 78, 96, -7, -283, -645, -825, -458, 716, 2632, 4830, 6591, 7262。
  対称ペアを先に加算し、13 bit 係数を MSB からシフト加算 (乗算器・除算器は不使用)。1 サンプル 197 clk
  (cen55 間隔は 864 clk)。出力は丸めて 16 bit に飽和。
- 特性 (量子化後): 1 kHz 0.0 dB, 4 kHz -1.4 dB, 6 kHz -8.6 dB, 7 kHz -16.2 dB, 8 kHz -28.9 dB。
- SMORES 再現シミュレーション: 6-8 kHz / 1-2.5 kHz 帯域比 -21.6 -> -35.9 dB (Y8950 録音は -33.4 dB)。
  ただし約 100 Hz の「ブー」の基本波・低次倍音は通過域なので、音は丸くなるが消えはしない見込み。
- DELTA-N 依存性の確認: デコーダ + 補間器 + LPF の RTL に ADPCM 化した白色雑音を通し、LPF 前後の伝達関数を
  DELTA-N = 1800h/3A0Eh/51F0h/7000h/C000h/FFFFh (ADPCM fs 4.7-49.7 kHz) で測定。8 kHz までは全条件で
  設計値と 0.3 dB 以内で一致 (最大差は -62 dB の 10 kHz で 1.1 dB)。カットオフは再生レートによらず一定。
- adpcm.v: w_pcm と PAN 乗算の間に u_lpf を挿入。gprj と各 run.bat に adpcm_lpf.v を追加。
- テスト: adpcm_patch/test003 (新規, LPF 単体: インパルス・DC・飽和・ランダムを参照モデルと比較) PASS。
  adpcm_patch/test002 は cen55 を 1/32 clk に加速していたため LPF の処理 (197 clk) が間に合わず、
  1/256 clk に変更し、停止後のゼロ確認待ちを LPF の 25 サンプル分延長。opl2_patch/test003 も同様に待ちを延長。
  既存回帰テスト (adpcm_patch 001-003, opl2_patch 001-004, src/test001-002) は全て PASS。
- 次: GOWIN で合成しリソース・タイミングを確認、実機で SMORES や CANCAN の音質を確認。
- 実機で確認し v0.9.14 としてリリース (https://github.com/hra1129/Y8960_Cartridge/releases/tag/v0.9.14)。
  SMORES の「ブー」(約 100 Hz, データ由来) は残るが、CANCAN 等は LPF により聴きやすくなった。
