# Этап 3.13 — Разведка имеющихся материалов

Дата: 2026-05-20.
Назначение: оценить, какие готовые наработки в репозитории и в системе
можно переиспользовать для упаковки sync_top в IP-Catalog и
интеграции в reference-проект ADI для AD9361.

---

## 1. Резюме

В репозитории **отсутствуют** RTL-обёртки AXI-Lite/AXI-Stream,
директории `ip/`, `bd/`, любые XCI/XACT/`component.xml` пакеты,
а также интеграционные XDC. Существует только пакет «голых» RTL
из шести модулей (`rtl/sync_top.v` + 5 подмодулей), порты sync_top
**уже подготовлены** к интеграции: 32-бит AXI-Stream slave/master,
параллельная регистровая карта 8×{16…33 бит} от внешнего AXI-Lite
shim, отдельные `clk/reset`, debug-выходы. В дневнике этап 3.13
**полностью оформлен как проектное (paper) задание** на 11
параграфов с уже принятыми архитектурными решениями: размещение в
датапасе `axi_ad9361 → axi_iqcor → axi_decim_cic → axi_decim_fir
→ sync_top → axi_dmac`, регистровая карта по 0x43C0_0000,
33-битный AGC_TGT с обнулённым старшим битом, шаблон AXI4-Lite
по Xilinx PG118 (IPIF). Сама реализация (Verilog `sync_top_axi_lite`,
IP-пакет, Block Design) **явно отнесена к этапу 4.1 Главы 4**.
В системе обнаружена клонированная ADI HDL-репа `~/git/27.03/hdl/`
с проектом `projects/fmcomms2/zed/` (это и есть reference-flow
AD-FMCOMMS2/3-EBZ на ZedBoard), а также `library/axi_ad9361` и
`library/axi_dmac`.

---

## 2. Инвентаризация RTL-обвязки sync_top

| Ожидаемый элемент | Найден | Имя файла или примечание |
|---|---|---|
| AXI4-Stream **slave** на входе (sample-stream) | ✓ частично | `rtl/sync_top.v:31-34`: `s_axis_tdata[31:0]={I[15:0],Q[15:0]}`, `s_axis_tvalid`, `s_axis_tready` (всегда =1, без backpressure). `tlast` нет, `tkeep` нет. |
| AXI4-Stream **master** на выходе (символы) | ✓ частично | `rtl/sync_top.v:36-38`: `m_axis_tdata[31:0]`, `m_axis_tvalid`. **Нет `m_axis_tready`** — выходной поток pure-source, downstream обязан быть всегда ready (FIFO в Block Design). |
| AXI4-Lite **slave** на конфигурацию | ✗ не shim, ✓ как «параллельная развёртка» | `rtl/sync_top.v:40-48`: `ctrl_soft_reset`, `ctrl_enable`, `ctrl_agc_bypass`, `reg_k1`, `reg_k2`, `reg_w_nom`, `reg_clamp`, `reg_agc_target[32:0]`. **AXI-Lite shim `sync_top_axi_lite` отсутствует в `rtl/`** — это и есть ключевая работа этапа 4.1. |
| Clock / Reset | ✓ | `rtl/sync_top.v:28-29`: `clk`, `reset` (асинхронный, активный высокий). Внутри `wire rst = reset \| ctrl_soft_reset` объединяет hardware-reset и soft-reset из CTRL[0]. |
| Debug-выходы | ✓ | `rtl/sync_top.v:50-52`: `debug_w[15:0]`, `debug_mu[11:0]`. По дневнику собираются в регистр DEBUG (0x1C) как `{debug_w, debug_mu}`. |
| AXI-Lite shim / register-bank wrapper (`sync_top_axi_lite.v`, `*_regfile.v` и т.п.) | ✗ | В `rtl/` файлов с такими именами **нет**. Единственное упоминание `sync_top_axi_lite` — комментарий в `rtl/sync_top.v:10` и текст дневника. |
| AXI-Stream FIFO / buffer обёртка | ✗ | Нет. Поскольку `m_axis_tready` отсутствует, в Block Design между sync_top и axi_dmac понадобится Xilinx `axis_data_fifo` (готовый IP, не пользовательский RTL). |
| CDC модуль | ✗ | Нет. По дневнику (раздел «Тактирование») предполагается единый клок `s_axi_aclk = fclk0 = 100 МГц` для sync_top и axi_dmac — CDC не требуется. Если потребуется (вход с axi_decim_fir на другой частоте), нужен `axis_clock_converter` (готовый IP). |

Дублирующая старая копия `sync_top.v` лежит в `vkr_sync_hdl/files (4)/`
вместе с другими файлами Главы 3.5 — это исторический snapshot,
не отдельная ветка реализации.

---

## 3. Имеющиеся директории и артефакты

### 3.1 Что есть в репозитории `vkr_sync_hdl/`

```
rtl/                        — 6 .v-файлов петли, готовые ко включению в IP
constraints/                — только sync_farrow_parab_ooc.xdc (OOC-этап 3.12)
scripts/                    — TCL-скрипты для симуляции (NCO, Farrow, top); упаковки/BD НЕТ
sim/                        — тестбенчи, стимулы, debug_v3/D5..D7p
syn/                        — отчёты OOC-синтеза этапа 3.12 (закрыт)
sync_farrow_parab/          — Vivado project subdir для V2 (старое, не IP-package)
vivado_prj_top/             — Vivado project subdir для V3 (sync_top sim)
matlab/, files (4)/         — справочные материалы
sync_params.vh              — параметры для симуляции (K1/K2/W_NOM/N_STIM)
```

### 3.2 Чего **нет** в репозитории

- `ip/`, `ip_repo/`, `vivado_ip/`, `ip_catalog/` — директорий упакованных IP нет.
- `bd/`, `block_design/`, `vivado_bd/` — Block Design-артефактов нет.
- `component.xml`, `*.xact` — XML-метаданных IP-Packager нет.
- Интеграционных XDC (без суффикса `_ooc`) — нет; все XDC помечены OOC.
- Скрипт Tcl для `package_project` / `create_bd_design` — нет.
- `regmap.csv` / `addr_map.h` / адресной таблицы в машинно-читаемом виде — нет (только Таблица 7 в .docx).

### 3.3 ADI HDL — клон в системе

Найдено: `~/git/27.03/hdl/`. По датировке директории (27 марта)
ориентировочно соответствует ветке `hdl_2024_R1` или ближе; точную
ветку нужно подтвердить через `git -C ~/git/27.03/hdl log -1`,
но для разведки достаточно факта наличия. Ключевое:

- `~/git/27.03/hdl/projects/fmcomms2/zed/system_bd.tcl` — Tcl Block Design AD-FMCOMMS2/3-EBZ на ZedBoard (целевая платформа ВКР).
- `~/git/27.03/hdl/projects/fmcomms2/zed/system_top.v` — обёртка верхнего уровня.
- `~/git/27.03/hdl/projects/fmcomms2/zed/system_constr.xdc` — XDC платы.
- `~/git/27.03/hdl/library/axi_ad9361/` — IP-обёртка трансивера.
- `~/git/27.03/hdl/library/axi_dmac/` — DMA-контроллер.
- Также есть `projects/adrv9361z7035/` (альтернативная платформа).

Клонировать дополнительно ничего не нужно; на этапе 4.1 sync_top
вставляется в `system_bd.tcl` после `axi_decim_fir`.

---

## 4. Этап 3.13 в Diary_VKR_Ch3.docx — анализ полноты

Полный извлечённый текст: `syn/reports/diary_stage_3_13_current.txt`
(~10 KiB, 89 содержательных строк, без рисунков). Это **полностью
оформленный этап**, не черновик.

Фактическая структура (все подразделы написаны связным текстом):

1. **Цель этапа** ✓
2. **HDL Reference Design ADI: краткое описание архитектуры** ✓ (с явной отсылкой к § 1.6.3 Главы 1)
3. **Архитектура AXI-Lite обёртки sync_top_axi_lite** ✓ (FSM IDLE→WRITE→RESPONSE и IDLE→READ→RESPONSE, шаблон PG118)
4. **Регистровая карта в адресном пространстве AXI-Lite** ✓ (Таблица 7, базовый адрес 0x43C0_0000)
5. **Особенность представления AGC_TGT** ✓ (33-й бит ≡ 0)
6. **Формирование IP-пакета для Vivado IP Catalog** ✓ (s_axis / m_axis / s_axil, ассоциация clk/reset, параметры W_DATA/W_MU/W_COEF/W_NCO)
7. **Структура Block Design в Vivado** ✓ (`axi_ad9361 → axi_iqcor → axi_decim_cic → axi_decim_fir → sync_top → axi_dmac`, AXI Interconnect к M_AXI_GP0, fclk0 = 100 МГц)
8. **Стратегия натурных испытаний (Глава 4)** ✓ (три режима: digital loopback, AD9361 internal loopback, внешний источник)
9. **Контрольные результаты** ✓ (Рисунки 27, 28, 29 — заголовки; сами изображения в дневнике не отрисованы)
10. **Выводы по этапу 3.13** ✓ (четыре абзаца сводки)

**Имена ADI IP, фактически упомянутые в тексте этапа 3.13:**
`axi_ad9361`, `axi_iqcor`, `axi_decim_cic`, `axi_decim_fir`,
`axi_dmac`, `axi_interconnect`. Имена `util_cpack`/`util_upack` в
дневнике **не упомянуты** — в reference-flow ADI для AD9361 их
функцию покрывает связка `axi_ad9361 → axi_dmac`, и в датапасе
магистральной работы они не требуются.

**Чего в тексте дневника нет (и где, вероятно, не должно быть):**

- Псевдокода / синтаксиса портов AXI4-Lite (AWADDR/WDATA/...) — это работа этапа 4.1.
- Готового Tcl-скрипта `package_ip.tcl` или `create_bd.tcl` — отнесено к этапу 4.1.
- Конкретного выбора платы (ZedBoard vs ADRV9361-Z7035) — стоит «в зависимости от доступного оборудования».
- Результатов натурных испытаний — отнесены к этапам 4.2–4.4.

Иными словами, paper-часть этапа 3.13 уже закрыта; остаётся
**только** реализация (= этап 4.1) — Verilog AXI-Lite shim,
Tcl IP-packaging, Tcl Block Design + validate_bd_design.

---

## 5. Упоминания этапа 3.13 / IP-Catalog / Block Design в других .docx

| Файл | Релевантные находки |
|---|---|
| `Kudimov_VKR.docx` (основной текст ВКР) | 6× «AXI-Lite», 1× «axi_ad9361», 1× «Block Design», 12× «reference». Все упоминания — на уровне постановочной части (Введение, § 1.6.1–1.6.3), без технических деталей. Этап 3.13 явно дублируется только в **дневнике**. |
| `Kudimov_VKR_Glava2.docx`, `Kudimov_VKR_Glava2_v2.docx` | Глава 2 (исследовательская); упоминаний этапа 3.13/AXI-Lite/IP-Catalog **нет**. |
| `Diary_VKR_Ch2.docx` | Дневник Главы 2; релевантных упоминаний **нет**. |
| `vkr_ch3_diary_parts/VKR_Diary_Ch3_Stage_3_*.docx` | Это сохранённые ревизии отдельных этапов 3.5/3.7/3.9/3.10/3.11/3.12. Отдельного файла `*Stage_3_13*` **нет** — этап существует только в сводном `Diary_VKR_Ch3.docx`. |

Никаких дополнительных решений или вариантов архитектуры
AXI-Lite shim вне дневника не зафиксировано.

---

## 6. Ожидаемые IP-блоки ADI reference-flow (Zynq-7020 + AD-FMCOMMS3-EBZ, ZedBoard)

На основании структуры `~/git/27.03/hdl/projects/fmcomms2/zed/`
и общедоступной документации wiki.analog.com:

**Базовая инфраструктура PS/PL:**
- `processing_system7` (Xilinx) — Zynq PS, источник `FCLK_CLK0` (100 МГц), `M_AXI_GP0`, прерывания.
- `axi_interconnect` / `axi_smc` — AXI-инфраструктура.
- `proc_sys_reset` — synchronous reset distribution.

**Тракт AD9361 (RX/TX):**
- `axi_ad9361` — основной интерфейс к трансиверу (LVDS DDR), выдаёт два RX-канала и принимает два TX-канала.
- `util_ad9361_adc_fifo`, `util_ad9361_dac_fifo` — async FIFO для перехода между `l_clk` AD9361 и `dma_clk`.
- `axi_iqcor` — коррекция I/Q дисбаланса (на каждый канал).
- `axi_decim_cic`, `axi_decim_fir` — RX-децимация; `axi_interp_cic`, `axi_interp_fir` — TX-интерполяция.

**DMA:**
- `axi_dmac` (RX-направление, S2MM) — забирает символы в DDR.
- `axi_dmac` (TX-направление, MM2S) — подаёт сэмплы из DDR в DAC-цепочку.

**Прочее:**
- `axi_dac_clkgen` (если нужен внешний DAC clock) — для AD-FMCOMMS3 обычно не требуется.
- `sys_concat_intc` — объединение прерываний DMAC.

**Куда вставляется sync_top:**
В RX-датапасе **после** `axi_decim_fir` (выход matched-filter с
sps_rx = 2), **перед** RX-`axi_dmac`. По дневнику между sync_top
и axi_dmac должен стоять синхронизирующий буфер (на практике —
Xilinx `axis_data_fifo` ~256–512 слов), потому что sync_top
выдаёт `m_axis_tvalid` спорадически (раз в 2 такта = по стробу),
а DMAC ожидает burst-friendly поток. **TX-датапас не
модифицируется.**

---

## 7. Точечные вопросы к пользователю

Ничего критически-неопределённого разведка не выявила. Уточняющие
вопросы возникают только по этапу 4.1 (реализация):

1. **Целевая плата для демонстрации.** Дневник оставляет выбор
   «ZedBoard или ADRV9361-Z7035». ZedBoard имеется в репе как
   `~/git/27.03/hdl/projects/fmcomms2/zed/`. Уточнить, что использовать.
2. **Версия ADI HDL.** В системе клон `~/git/27.03/hdl/` (от 27.03).
   Для этапа 3.13 (paper) это безразлично, но для 4.1 нужна
   фиксация ветки/тэга (`hdl_2023_R1` vs `hdl_2024_R1`) —
   reference-flow между ветками меняется (имена сигналов
   `dac_clk`/`adc_clk`).
3. **m_axis_tready.** Текущий sync_top — pure-source без backpressure.
   В IP-Catalog этот порт лучше **добавить** (по стандарту AXI4-Stream
   master) и игнорировать (assign на 1'b1 внутри), либо явно объявить
   в `component.xml`, что master без `tready`. Это уже вопрос
   реализации этапа 4.1.

---

## 8. Рекомендация по следующему шагу

**Вариант (а):** в этапе 3.13 фиксируется paper-результат уже
имеющийся в дневнике; никаких правок RTL/Tcl этапа 3.13 не
требуется. Перейти к этапу 4.1 как к реализационному, который
включает:

1. **Написать `rtl/sync_top_axi_lite.v`** — Verilog AXI4-Lite slave
   shim (8 регистров, FSM по шаблону PG118), формирующий все
   `ctrl_*` / `reg_*` сигналы текущего интерфейса sync_top.
   Сохранить совместимость с регистровой картой Таблицы 7
   дневника (адреса 0x00–0x1C, значения сброса).
2. **Написать `rtl/sync_top_wrapper.v`** (опционально) — top-level
   обёртка `sync_top_axi_lite + sync_top`, экспортирующая наружу
   только `s_axis_*`, `m_axis_*`, `s_axil_*`, `aclk`, `aresetn`.
   Альтернатива — пакетировать `sync_top_axi_lite + sync_top` без
   дополнительной обёртки, инстанцируя их рядом в `component.xml`.
3. **Написать `scripts/package_sync_ip.tcl`** — Tcl IP-Packager,
   объявляющий стандартные шинные интерфейсы Xilinx
   (`xilinx.com:interface:axis_rtl:1.0`,
   `xilinx.com:interface:aximm_rtl:1.0`), параметры
   (W_DATA/W_MU/W_COEF/W_NCO), ассоциацию clk↔интерфейсы.
4. **Написать `scripts/create_demo_bd.tcl`** — минимальный
   Block Design `PS7 + AXI Interconnect + sync_top + axis_data_fifo`
   с заглушками `s_axis` и `m_axis` (или Tcl-вставка sync_top в
   `system_bd.tcl` из `projects/fmcomms2/zed/`).
5. **Прогнать `validate_bd_design`** — без выхода на bitstream;
   зафиксировать в дневнике этапа 4.1, что IP-блок состыковался
   с reference-проектом без ошибок DRC.

Вариант (б) (использовать имеющийся shim) **неприменим**: shim
отсутствует.

Вариант (в) (требуются уточнения) **не блокирует** работу: ответы
на три вопроса § 7 нужны только в момент написания Tcl-скрипта
Block Design в этапе 4.1, а до этого можно начинать с
`sync_top_axi_lite.v` независимо от платы и версии ADI HDL.

**Итог:** этап 3.13 в текущем виде закрыт по содержанию (paper
exercise). К запуску этапа 4.1 готовы все архитектурные решения —
требуется только реализация AXI-Lite shim, Tcl-упаковка и
демонстрационный Block Design.
