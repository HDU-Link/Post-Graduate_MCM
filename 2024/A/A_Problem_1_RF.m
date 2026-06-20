clear; clc; close all;tic;
%% 常数设置
global m C sigma_b N
m = 10;                                                                     % Wohler指数
C = 9.77e70;                                                                % S-N曲线常数
sigma_b = 50000000;                                                         % 材料拉伸断裂最大载荷值
N = 42565440.4361;                                                          % 设计寿命循环次数
%% 读取数据
[~, ~, raw_spindle] = xlsread('附件1-疲劳评估数据.xls', '主轴扭矩');spindle_data = cell2mat(raw_spindle(2:101, 2:101));
[~, ~, raw_tower] = xlsread('附件1-疲劳评估数据.xls', '塔架推力');tower_data = cell2mat(raw_tower(2:101, 2:101));
%% 计算指标
[eq_spindle, cum_spindle] = batch_calculate(spindle_data);                  % 计算主轴疲劳指标
[eq_tower, cum_tower] = batch_calculate(tower_data);                        % 计算塔架疲劳指标
%% 输出结果
fprintf('主轴等效疲劳载荷:');fprintf('%.6e ', eq_spindle);fprintf('\n');
fprintf('主轴累计疲劳损伤值:');fprintf('%.6e ', cum_spindle);fprintf('\n');
fprintf('塔架等效疲劳载荷:');fprintf('%.6e ', eq_tower);fprintf('\n');
fprintf('塔架累计疲劳损伤值:');fprintf('%.6e ', cum_tower);fprintf('\n');toc;
%% 绘制结果
subplot(221);hold on;plot(1:100,eq_spindle,'.-');plot(1:100,cell2mat(raw_spindle(102, 2:101)),'.-');title("主轴等效疲劳载荷");
subplot(222);hold on;plot(1:100,cum_spindle,'.-');plot(1:100,cell2mat(raw_spindle(103, 2:101)),'.-');title("主轴累计疲劳损伤值");
subplot(223);hold on;plot(1:100,eq_tower,'.-');plot(1:100,cell2mat(raw_tower(102, 2:101)),'.-');title("塔架等效疲劳载荷");
subplot(224);hold on;plot(1:100,cum_tower,'.-');plot(1:100,cell2mat(raw_tower(103, 2:101)),'.-');title("塔架累计疲劳损伤值");
clear i m C sigma_b N raw_spindle raw_tower
%% 函数：批量计算所有风机的疲劳指标
function [eq_loads, cum_damages] = batch_calculate(data_matrix)
    eq_loads = zeros(1, 100); cum_damages = zeros(1, 100);
    for i = 1:100
        [eq_loads(i), cum_damages(i)] = calculate_fatigue(data_matrix(:, i));
    end
end
%% 主函数：计算单台风机的疲劳损伤
function [equivalent_load, cumulative_damage] = calculate_fatigue(data_series)
    global m C sigma_b N
    peaks_valleys = extract_peaks_valleys(data_series);                     % 步骤1: 提取波峰波谷
    [amplitudes, means, counts] = rainflow_3point(peaks_valleys);           % 步骤2: 三点式雨流计数法
    S_i = amplitudes ./ (1 - means / sigma_b);                              % 步骤3: Goodman曲线修正
    equivalent_load = (sum(S_i.^m .* counts) / N)^(1/m);                    % 步骤4: 计算等效疲劳载荷                                             
    cumulative_damage = sum(counts ./ (C ./ (S_i.^m)));                     % 步骤5: 计算累计疲劳损伤值
end
%% 函数: 提取波峰波谷
function pv = extract_peaks_valleys(data)
    n = length(data); is_peak = false(n, 1); is_valley = false(n, 1);
    for i = 2:n-1
        if data(i) > data(i-1) && data(i) > data(i+1)
            is_peak(i) = true;
        elseif data(i) < data(i-1) && data(i) < data(i+1)
            is_valley(i) = true;
        end
    end
    is_peak(1) = data(1) > data(2); is_valley(1) = data(1) < data(2);
    is_peak(n) = data(n) > data(n-1); is_valley(n) = data(n) < data(n-1);
    pv = data(find(is_peak | is_valley));
end
%% 函数: 三点式雨流计数法
% 设定三个连续的应力状态点（S1, S2, S3）作为分析单元，
% 计算这两段相邻的应力变化量ΔS1 = |S1 - S2| 和 ΔS2 = |S2 - S3|，
% 当ΔS1 ≤ ΔS2时，此时将S1至S2视为一个有效循环进行计数，然后剔除S1、S2；
% 若ΔS1 > ΔS2，则当前三点组内不识别出循环，继续取S2, S3, S4(若无,则取S1)；
% 若最终只剩2个应力状态点，采用取半计数的形式，counts=0.5。
function [amplitudes, means, counts] = rainflow_3point(pv)
    X = pv(:); amplitudes = []; means = []; counts = []; idx = 3;
    S1 = X(1); S2 = X(2); S3 = X(3);
    while length(X) >= 3
        DeltaS1 = abs(S1 - S2); DeltaS2 = abs(S2 - S3);
        if DeltaS1 <= DeltaS2
            amplitudes = [amplitudes; DeltaS2];
            means = [means; (S1 + S2) / 2];
            counts = [counts; 1];
            X = [X(1:idx-3); X(idx:end)];
            if length(X) < 3
                if length(X) == 2
                    amplitudes = [amplitudes; abs(X(1) - X(2))];
                    means = [means; (X(1) + X(2)) / 2];
                    counts = [counts; 0.5];
                end
                break;
            end
            S1 = X(1); S2 = X(2); S3 = X(3); idx = 3;
        else
            if idx+1<=length(X)
                idx = idx + 1; S1 = S2; S2 = S3; S3 = X(idx);
            elseif idx==length(X)
                idx = idx + 1; S1 = X(end-1); S2 = X(end); S3 = X(1);
            else
                S1 = X(end); S2 = X(1); S3 = X(2);
            end
        end
    end
end