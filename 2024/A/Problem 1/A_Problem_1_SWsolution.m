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
%% 逐秒时序损伤计算
rt_damage_spindle = zeros(100, 100); rt_damage_tower = zeros(100, 100);
for i = 1:100
    rt_damage_spindle(:, i) = calc_time_series_damage(spindle_data(:, i));
    rt_damage_tower(:, i) = calc_time_series_damage(tower_data(:, i));
end
toc;
%% 输出附件5表格
xlswrite('附件5-问题一答案表.xlsx', num2cell(rt_damage_spindle), '主轴疲劳数据', 'B2');
xlswrite('附件5-问题一答案表.xlsx', num2cell(rt_damage_tower), '塔架疲劳数据', 'B2');
%% 绘制图像
figure('Position', [100, 425, 1100, 300]);
for i = 1:10
    subplot(2,5,i);plot(1:100, rt_damage_spindle(1:100,10*i), 'linewidth', 2);
    title(['WT', num2str(i*10)]);xlabel("时间/秒");ylabel("主轴累计疲劳损伤程度");
end
figure('Position', [100, 50, 1100, 300]);
for i = 1:10
    subplot(2,5,i);plot(1:100, rt_damage_tower(1:100,10*i), 'linewidth', 2);
    title(['WT', num2str(i*10)]);xlabel("时间/秒");ylabel("塔架累计疲劳损伤程度");
end
clear i m C sigma_b N raw_spindle raw_tower
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
function [amplitudes, means, counts] = rainflow_3point(pv)
    X = pv(:); amplitudes = []; means = []; counts = []; idx = 3;
    if length(X) >= 3
        S1 = X(1); S2 = X(2); S3 = X(3);
    end
    while length(X) >= 3
        DeltaS1 = abs(S1 - S2); DeltaS2 = abs(S2 - S3);
        if DeltaS1 <= DeltaS2
            amplitudes = [amplitudes; DeltaS1];
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
%% 函数：逐秒时序滑动计算瞬时&累积损伤
function cum_damage_arr = calc_time_series_damage(data)
    global m C sigma_b
    cum_damage_arr = zeros(1, 100);
    for t = 3:10
        seg_data = data(1:t);
        pv_seg = extract_peaks_valleys(seg_data);
        [amps, means_seg, cnts] = rainflow_3point(pv_seg);
        S_seg = amps ./ (1 - means_seg / sigma_b);
        Nf_seg = C ./ (S_seg.^m);
        D_seg = sum(cnts ./ Nf_seg);
        cum_damage_arr(t) = max(D_seg, cum_damage_arr(t-1));                % 单调递增函数
    end
    for t = 11:100
        seg_data = data(t-9:t);
        pv_seg = extract_peaks_valleys(seg_data);
        [amps, means_seg, cnts] = rainflow_3point(pv_seg);
        S_seg = amps ./ (1 - means_seg / sigma_b);
        Nf_seg = C ./ (S_seg.^m);
        D_seg = sum(cnts ./ Nf_seg);
        cum_damage_arr(t) = cum_damage_arr(t-1) + D_seg;                    % 滑动窗口叠加值
    end
end