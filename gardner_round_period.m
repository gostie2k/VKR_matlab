function [y_strobe, dper_log, e_log] = gardner_round_period(sig, sps_rx, K1, K2, quant_bits)
% gardner_round_period — реализация петли Gardner по схеме научного руководителя
% (parse_deb_data.m, строки 290..357)
%
% Round-period NCO без Farrow-интерполяции:
% strobe берётся при cnt == round(per), mid — при cnt == round(per/2).
% Период per корректируется PI-фильтром, дробная невязка dper
% переносится на следующий период (упрощённый аналог mod-1 NCO).
%
% Требует высокой передискретизации (sps_rx >= 8) — иначе round(per/2)
% и round(per) сливаются.
%
% Вход:
%   sig        — комплексный вектор отсчётов с приёмного RRC
%   sps_rx     — отсчётов на символ (рекомендуется 8..40)
%   K1, K2     — коэффициенты PI-фильтра (отрицательные).
%                У советника: K1 = -2^-2, K2 = -2^-8.
%   quant_bits — число бит квантования dper (как в референсе: 8).
%                Если 0 — без квантования (floating-point).
%
% Выход:
%   y_strobe — комплексный вектор стробированных символов
%   dper_log — лог невязки округления периода
%   e_log    — лог сигнала ошибки TED

if nargin < 5, quant_bits = 0; end

N = length(sig);
per_nom = sps_rx;

% --- Пределы ограничения периода (аналог clamp W в Rice-версии) ---
per_max = per_nom * 1.5;
per_min = per_nom * 0.5;
vi_lim  = per_nom * 0.5;

% --- Состояние ---
cnt   = 1;
per   = per_nom;
dper  = 0;
vi    = 0;

s_mid    = complex(0);   % mid-отсчёт текущего периода
s_strobe_prev = complex(0);   % предыдущий строб

% --- Логи ---
y_strobe = complex(zeros(N, 1));
dper_log = zeros(N, 1);
e_log    = zeros(N, 1);
k_out    = 0;

for n = 1:N

    % --- Захват mid-отсчёта на середине периода ---
    if cnt == round(per/2)
        s_mid = sig(n);
    end

    % --- Строб на конце периода ---
    if cnt == round(per)
        s_strobe = sig(n);

        % Gardner TED (только если есть валидные предыдущие данные)
        if k_out >= 1
            diff = s_strobe_prev - s_strobe;
            e = real(s_mid)*real(diff) + imag(s_mid)*imag(diff);
        else
            e = 0;
        end

        % PI-фильтр с anti-windup
        vp = K1 * e;
        vi = vi + K2 * e;
        vi = max(min(vi, vi_lim), -vi_lim);
        v_pi = vp + vi;

        % Обновление периода + перенос дробной части (как у советника)
        per = per_nom - v_pi + dper;
        per = max(min(per, per_max), per_min);
        dper = per - round(per);

        % Квантование dper (подготовка к фиксированной арифметике)
        if quant_bits > 0
            scale = 2^quant_bits;
            dper = round(dper * scale) / scale;
        end

        % Запись результатов
        k_out = k_out + 1;
        y_strobe(k_out) = s_strobe;
        e_log(k_out)    = e;
        dper_log(k_out) = dper;

        s_strobe_prev = s_strobe;
        cnt = 1;
    else
        cnt = cnt + 1;
    end
end

y_strobe = y_strobe(1:k_out);
e_log    = e_log(1:k_out);
dper_log = dper_log(1:k_out);

end