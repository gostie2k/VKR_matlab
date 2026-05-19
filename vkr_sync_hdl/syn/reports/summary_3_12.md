# Этап 3.12 — OOC-синтез петли символьной синхронизации

**Дата:** см. время в `.rpt`.  
**Тулза:** Vivado 2023.2 (-mode batch).  
**FPGA part:** xc7z020clg484-1 (Zynq-7020, CLG484, speed grade -1).

Out-of-context-синтез выполнен с post-route timing: `synth_design → opt_design → place_design → route_design`. Каждый из шести RTL-модулей синтезирован как самостоятельный top-уровень при целевой частоте 100 МГц (период 10.000 нс); дополнительно для `sync_top` проведён контрольный прогон при 150 МГц (период 6.667 нс) — оценка запаса архитектуры.

## 1. Утилизация по модулям при 100 МГц

| Модуль                | LUT  | LUTRAM | FF   | BRAM, kb | DSP48E1 | WNS, нс | Fmax, МГц |
|-----------------------|------|--------|------|----------|---------|---------|-----------|
| sync_agc              |  113 |      0 |   66 |        0 |       4 |  -0.433 |      95.8 |
| sync_farrow_parab     |  298 |      0 |  320 |        0 |       6 |  -1.519 |      86.8 |
| sync_mod1_nco         |  508 |      0 |   29 |        0 |       0 | -47.265 |      17.5 |
| sync_ted_gardner      |   49 |      0 |  148 |        0 |       2 |  -0.224 |      97.8 |
| sync_loop_filter_pi   |  186 |      0 |   52 |        0 |       2 |  -0.635 |      94.0 |
| sync_top              |    - |      - |    - |        - |       - |       - |         - |

## 2. Иерархическая утилизация sync_top (100 МГц)

_(иерархический отчёт пуст — см. raw report sync_top_100mhz_util_hier.rpt)_

## 3. Критический путь sync_top при 100 МГц

_(не удалось извлечь — см. sync_top_100mhz_timing_paths.rpt)_

## 4. Особенности инференса

Раздел заполняется вручную по результатам ручного осмотра отчётов утилизации (см. секцию «Особенности инференса» в README/диалоге).

## 5. Запас по частоте

Контрольный прогон sync_top при 150 МГц:
- WNS: не извлечён

## 6. Критические warning'ы и DRC

| Источник | Сообщение |
|----------|-----------|
| sync_agc_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_farrow_parab_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_farrow_parab_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_farrow_parab_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_mod1_nco_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_mod1_nco_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_mod1_nco_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_ted_gardner_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_ted_gardner_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_ted_gardner_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_loop_filter_pi_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_top_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_top_100mhz_log.txt | ERROR: [Synth 8-91] ambiguous clock in event control [/home/t-kudimov/temp/matmodel/vkr_sync_hdl/rtl/sync_top.v:150] |
| sync_top_100mhz_log.txt | ERROR: [Synth 8-6156] failed synthesizing module 'sync_top' [/home/t-kudimov/temp/matmodel/vkr_sync_hdl/rtl/sync_top.v:2 |
| sync_top_100mhz_log.txt | ERROR: [Common 17-69] Command failed: Synthesis failed - please see the console or run log file for details |
| sync_top_150mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_top_150mhz_log.txt | ERROR: [Synth 8-91] ambiguous clock in event control [/home/t-kudimov/temp/matmodel/vkr_sync_hdl/rtl/sync_top.v:150] |
| sync_top_150mhz_log.txt | ERROR: [Synth 8-6156] failed synthesizing module 'sync_top' [/home/t-kudimov/temp/matmodel/vkr_sync_hdl/rtl/sync_top.v:2 |
| sync_top_150mhz_log.txt | ERROR: [Common 17-69] Command failed: Synthesis failed - please see the console or run log file for details |

## 7. Особенности OOC-ограничений

В реальной интеграции (Block Design + AXI-Lite shim) конфигурационные порты `reg_k1`, `reg_k2`, `reg_w_nom`, `reg_clamp`, `reg_agc_target`, а также управляющие `ctrl_soft_reset`, `ctrl_enable`, `ctrl_agc_bypass` драйвятся статическими регистрами в той же clock-области и обновляются один раз за сеанс. В OOC-режиме они получают артефактный `set_input_delay 2.0 ns`, что приводит к ложному критическому пути через комбинационное насыщение PI-фильтра. Для устранения этого артефакта соответствующие порты объявлены `set_false_path` в `sync_top_ooc.xdc`, `sync_top_ooc_150mhz.xdc`, `sync_loop_filter_pi_ooc.xdc`, `sync_agc_ooc.xdc`.

В интегрированной системе данные ограничения избыточны: регистры AXI-Lite shim'а и регистры подмодулей принадлежат одной clock-области, и timing между ними учитывается стандартными правилами синхронизатора без дополнительных ограничений.

## 8. Открытые вопросы

Модули с WNS < 0 (после false_path на конфиг-портах) требуют ручного решения:
- **sync_agc** (sync_agc_100mhz): WNS = -0.433 нс при цели 100 МГц.
  Источник: `in_q[15]`. Назначение: `accum_reg[32]/D`.
  Data path 9.384 нс, 14 уровней логики.
- **sync_farrow_parab** (sync_farrow_parab_100mhz): WNS = -1.519 нс при цели 100 МГц.
  Источник: `t_mul_mu_i_i_18/C`. Назначение: `xi_s3_i_reg[14]/D`.
  Data path 11.464 нс, 10 уровней логики.
- **sync_mod1_nco** (sync_mod1_nco_100mhz): WNS = -47.265 нс при цели 100 МГц.
  Источник: `w_step[1]`. Назначение: `mu_out_reg[0]/D`.
  Data path 56.183 нс, 136 уровней логики.
- **sync_ted_gardner** (sync_ted_gardner_100mhz): WNS = -0.224 нс при цели 100 МГц.
  Источник: `diff_s1_q_reg[16]/C`. Назначение: `e_out_reg[3]/D`.
  Data path 10.169 нс, 9 уровней логики.
- **sync_loop_filter_pi** (sync_loop_filter_pi_100mhz): WNS = -0.635 нс при цели 100 МГц.
  Источник: `prod_k2_r/CLK`. Назначение: `v_pi_out_reg[11]/D`.
  Data path 10.628 нс, 21 уровней логики.
