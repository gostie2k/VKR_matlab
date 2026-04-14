function [y_strobe, mu_log, e_log] = gardner_canonical_rice(sig, sps_rx, K1, K2)
% gardner_canonical_rice — каноническая реализация петли Gardner по схеме Rice
% Адаптация закомментированного референс-блока из parse_deb_data.m советника
% Piecewise parabolic Farrow + Mod-1 NCO + PI-фильтр
%
% Вход:
%   sig    — комплексный вектор отсчётов с приёмного RRC (sps_rx на символ)
%   sps_rx — отсчётов на символ (обычно 2)
%   K1, K2 — коэффициенты PI-фильтра (отрицательные, K0 = -1 учтён)
%
% Выход:
%   y_strobe — комплексный вектор стробированных символов (1 на символ)
%   mu_log   — лог дробной задержки во времени
%   e_log    — лог сигнала ошибки в strobe-моменты

N = length(sig);

% --- Линия задержки Farrow: x_dl(1) = свежий, x_dl(4) = старый ---
x_dl = complex(zeros(4, 1));

% --- Состояние NCO ---
CNT = 1;
mu = 0;
W = 1/sps_rx;
underflow = 0;

% --- TED shift register (2 элемента) ---
% TEDBuff(1) — XI с прошлого такта (будущий mid)
% TEDBuff(2) — XI с позапрошлого такта (будущий strobe_prev)
TEDBuff = complex(zeros(2, 1));

% --- Состояние PI-фильтра ---
vi = 0;

% --- Логи ---
y_strobe = complex(zeros(N, 1));
mu_log = zeros(N, 1);
e_log = zeros(N, 1);
k_out = 0;

for n = 1:N
    
    % --- 1. Обновление линии задержки ---
    x_dl(4) = x_dl(3);
    x_dl(3) = x_dl(2);
    x_dl(2) = x_dl(1);
    x_dl(1) = sig(n);
    
    % --- 2. Piecewise parabolic Farrow (схема из parse_deb_data.m) ---
    % Формулы: x(n:-1:n-3) = [x_dl(1); x_dl(2); x_dl(3); x_dl(4)]
    % v2 = 1/2 * [ 1, -1, -1,  1] * x
    % v1 = 1/2 * [-1,  3, -1, -1] * x
    % v0 = x_dl(3)  (= x[n-2])
    v2 = 0.5*( x_dl(1) - x_dl(2) - x_dl(3) + x_dl(4));
    v1 = 0.5*(-x_dl(1) + 3*x_dl(2) - x_dl(3) - x_dl(4));
    v0 = x_dl(3);
    XI = (v2*mu + v1)*mu + v0;
    
    % --- 3. TED и PI-фильтр (только на такте underflow) ---
    if underflow == 1
        % Gardner TED (для комплексного сигнала):
        % e = Re{ TEDBuff(1) · conj(TEDBuff(2) - XI) }
        %   = Re{ y_mid · conj(y_strobe_prev - y_strobe_curr) }
        diff = TEDBuff(2) - XI;
        e = real(TEDBuff(1)) * real(diff) + imag(TEDBuff(1)) * imag(diff);
        
        % PI-фильтр
        vp = K1*e;
        vi = vi + K2*e;
        v_pi = vp + vi;
        
        % Обновление шага NCO
        W = 1/sps_rx + v_pi;
        
        % Выход: текущий XI — это strobe-отсчёт
        k_out = k_out + 1;
        y_strobe(k_out) = XI;
        e_log(k_out) = e;
    end
    
    % --- 4. NCO: декремент регистра ---
    CNT_next = CNT - W;
    if CNT_next < 0
        CNT_next = CNT_next + 1;
        underflow = 1;
        mu = CNT / W;         % новое mu для следующего такта
    else
        underflow = 0;
        % mu не меняется
    end
    CNT = CNT_next;
    
    % --- 5. Обновление TED shift register (ПОСЛЕ использования) ---
    TEDBuff(2) = TEDBuff(1);
    TEDBuff(1) = XI;
    
    mu_log(n) = mu;
end

y_strobe = y_strobe(1:k_out);
e_log = e_log(1:k_out);

end