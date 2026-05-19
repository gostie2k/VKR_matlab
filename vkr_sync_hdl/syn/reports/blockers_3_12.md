# Этап 3.12 — блокеры OOC-синтеза (для согласования)

**Контекст.** Out-of-context-синтез всех модулей петли символьной
синхронизации в Vivado 2023.2 на xc7z020clg484-1 (speed grade −1),
целевая тактовая 100 МГц. К конфигурационным портам от AXI-Lite shim
(`reg_k1`, `reg_k2`, `reg_w_nom`, `reg_clamp`, `reg_agc_target`,
`ctrl_*`, а также `k1`, `k2`, `clamp_lim` подмодуля PI и
`agc_bypass`, `p_target` подмодуля AGC) применён `set_false_path`,
поскольку в реальной интеграции они драйвятся статическими регистрами
в той же clock-области и не являются потоковыми сигналами.

После применения `false_path` остаются два реальных блокера и серия
сопутствующих timing-нарушений по подмодулям.

---

## Блокер №1 — `sync_top` не синтезируется

```
ERROR: [Synth 8-91]   ambiguous clock in event control
                      rtl/sync_top.v:150
ERROR: [Synth 8-6156] failed synthesizing module 'sync_top'
                      rtl/sync_top.v:22
```

### Источник

```verilog
rtl/sync_top.v:66    wire rst = reset | ctrl_soft_reset;
…
rtl/sync_top.v:149   reg strobe_d1, strobe_d2;
rtl/sync_top.v:150   always @(posedge clk or posedge reset) begin
rtl/sync_top.v:151       if (rst) begin
rtl/sync_top.v:152           strobe_d1 <= 0; strobe_d2 <= 0;
rtl/sync_top.v:153       end else begin
rtl/sync_top.v:154           strobe_d1 <= nco_strobe;
rtl/sync_top.v:155           strobe_d2 <= strobe_d1;
rtl/sync_top.v:156       end
rtl/sync_top.v:157   end
```

В sensitivity list заявлен асинхронный фронт `reset`, в теле
проверяется `rst = reset | ctrl_soft_reset`. Vivado не считает это
синтезируемым: либо асинхронный сброс — это ровно `reset` и в теле
должно быть `if (reset)`, либо в sensitivity должно быть оба фронта
(`posedge reset or posedge ctrl_soft_reset`) и в теле остаётся
`if (rst)`. В симуляции XSim проглатывает оба варианта,
синтезатор — нет.

Блокирует полностью OOC-синтез `sync_top` на 100 МГц и контрольный
прогон на 150 МГц.

### Варианты исправления (одна точечная правка строки 150–151)

| № | Правка                                                                                       | Что теряем                                                            |
|---|----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| A | `if (rst)` → `if (reset)`                                                                    | этот блок не дёргается soft-reset'ом (но он формирует только delay-line; soft-reset проходит дальше через `.reset(rst)` на подмодулях) |
| B | `always @(posedge clk or posedge reset or posedge ctrl_soft_reset)`, `if (rst)` оставить    | синтезируется, но добавляется второй асинхронный фронт                |
| C | Синхронный сброс: `always @(posedge clk) begin if (rst) … end`                              | теряется асинхронная инициализация двух флопов (для delay-line это безболезненно) |

Архитектурно эквивалентны (А) и (С): двухтактная delay-line всё
равно «успокаивается» за два такта после снятия любого сброса.
В подобных блоках в проекте уже используется синхронный паттерн
(см. `vi_reg`, `v_pi_out` в PI-фильтре — реагируют на `e_valid`,
а не на reset напрямую).

---

## Блокер №2 — `sync_loop_filter_pi`: реальный внутренний timing-fail

После `false_path` на `k1/k2/clamp_lim` критический путь смещается
вглубь модуля и остаётся **WNS = −0.635 нс** при цели 10 нс.

```
Source:           prod_k2_r/CLK         (внутри DSP48E1 P-register)
Destination:      v_pi_out_reg[11]/D
Slack (VIOLATED): −0.635 ns
Data Path Delay:  10.628 ns
                     logic  4.963 ns (46.7 %)
                     route  5.665 ns (53.3 %)
Logic Levels:     21    (CARRY4 = 15,  LUT2 = 1,  LUT3 = 2,
                          LUT4 = 1,   LUT5 = 2)
```

Это содержательная цепочка одного такта в `sync_loop_filter_pi.v`:

```
DSP48E1.P-reg (prod_k2_r)
    │
    ▼  >>>15 + sign-extend  (комбинационно)
k2e_full
    │  (защёлкивается в k2e_s1 на e_valid)
    ▼
vi_sum   = vi_reg + k2e_s1                  ← 32-bit adder
vi_sat   = saturate(vi_sum, ±clamp_pos)     ← 32-bit compare
v_pi_sum = vp_s1   + vi_sat                 ← 32-bit adder
v_pi_clp = saturate(v_pi_sum, ±clamp_pos)   ← 32-bit compare
v_pi_trunc = v_pi_clp[15:0]
    │
    ▼
v_pi_out_reg
```

Две полноразрядные арифметики adder→sat→adder→sat подряд в одном
такте — это и есть 15 CARRY4 в одной цепи. На xc7z020 speed -1
эта цепь физически не помещается в 10 нс. `false_path` тут не
работает: путь регистр-регистр.

### Варианты исправления

| № | Правка                                                                                                                                 | Цена                                                                  |
|---|----------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| 1 | Вставить регистр между `vi_sat` и `v_pi_sum`. Один такт латентности петли.                                                            | +1 такт замкнутой петли (≈ +0.5 sps_rx), теоретически смещение µ_lock на самую малость. Нужно перепроверить V3-MER. |
| 2 | Свернуть оба clamp'а в один общий 32→16-битный saturating-shift на выходе, зарегистрировать только финальный compare.                  | Одна правка, без изменения логики управления. Требует ручной перенос anti-windup в один общий сатуратор. |
| 3 | Сохранить как есть, понизить целевую fmax PL-домена до достижимой ≈ 1000 / 10.635 ≈ 94 МГц.                                            | Не меняет RTL. Но 100 МГц — штатная частота reference-проекта AD9361. |

Архитектурно «правильный» — вариант 1 (pipeline-stage). Для ВКР,
если хочется обойтись без правки RTL, формально достаточен (3) с
оговоркой в дневнике.

---

## Сопутствующие timing-фейлы по подмодулям (информационно)

После `false_path` на конфиг-портах:

| Модуль                | WNS, нс  | Источник пути                  | Логические уровни |
|-----------------------|---------:|---------------------------------|------------------:|
| sync_agc              |  −0.433  | `in_q[15] → accum_reg[32]/D`   | 14 (11 CARRY4 + DSP)  |
| sync_farrow_parab     |  −1.519  | `t_mul_mu_i_i_18/C → xi_s3_i_reg[14]/D` | 10 (5 CARRY4 + 2 DSP) |
| sync_mod1_nco         | **−47.27** | `w_step[1] → mu_out_reg[0]/D` | **136 (111 CARRY4!)** |
| sync_ted_gardner      |  −0.224  | `diff_s1_q_reg[16] → e_out_reg[3]` | 9 (5 CARRY4 + 2 DSP)  |
| sync_loop_filter_pi   |  −0.635  | см. блокер №2                  | 21 (15 CARRY4)       |

Особенно жёстко — `sync_mod1_nco` (**−47 нс, 136 уровней**). Это
полноразрядное деление `mu_full = (cnt_reg << W_MU) / w_step`,
развёрнутое в гигантскую CARRY-цепочку. По CLAUDE.md
(«известные факты, не перепроверять #1»):

> `sync_mod1_nco.v` использует `mu_simple = cnt_reg[W_CNT-2 -: W_MU]`
> (аппроксимация µ ≈ 2·CNT через сдвиг). Замена на полное деление
> не требуется — это штатное проектное решение.

Если штатно используется `mu_simple` (сдвиг), а не `mu_full`
(деление), значит в RTL вариант с делением присутствует как
неиспользуемый, но синтезатор всё равно собирает обе ветки и
показывает критический путь по делителю. Это надо посмотреть
отдельно: либо deadcode-elimination не сработал, либо `mu_full`
где-то всё-таки замыкается на выход.

`sync_agc`, `sync_farrow_parab`, `sync_ted_gardner` — близко к
цели (от −0.22 до −1.52 нс), типично закрывается одной
retiming-вставкой; разбирать после блокеров.

---

## Что прошу согласовать

1. **`sync_top.v:150–151`** — какой из вариантов A/B/C применить
   (рекомендация: А или С — точечная правка одной-двух строк).
2. **`sync_loop_filter_pi.v`** — pipeline-вставка (вариант 1)
   или понижение целевой fmax PL-домена с оформлением в дневнике
   (вариант 3).
3. **`sync_mod1_nco.v`** — посмотреть, действительно ли
   деление dead-code, и удалить его из RTL (либо переключить
   на `mu_simple` явно), чтобы синтезатор не строил 136-уровневую
   цепь.

После согласования — могу выполнить точечные правки и пересобрать.
RTL до согласования не трогаю (правила работы в репо, п. 2–3 в
CLAUDE.md).

---

## Что лежит в `syn/`

```
syn/
├── constraints/
│   ├── sync_top_ooc.xdc            # 100 МГц + false_path на reg_*, ctrl_*
│   ├── sync_top_ooc_150mhz.xdc     # 150 МГц + false_path
│   ├── sync_loop_filter_pi_ooc.xdc # 100 МГц + false_path на k1,k2,clamp_lim
│   └── sync_agc_ooc.xdc            # 100 МГц + false_path на agc_bypass,p_target
├── scripts/
│   ├── run_ooc_synth.tcl           # OOC-синтез одного top-модуля
│   ├── run_all_ooc.sh              # 7 прогонов master
│   └── extract_metrics.py          # парсер отчётов
└── reports/
    ├── <module>_100mhz_{util,util_hier,timing,timing_paths,clocks,drc,method}.rpt
    ├── critical_warnings.txt
    ├── summary_3_12.md             # автогенерация (sync_top пуст из-за блокера)
    └── blockers_3_12.md            # ЭТОТ ФАЙЛ
```
