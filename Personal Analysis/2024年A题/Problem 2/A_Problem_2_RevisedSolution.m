clear; clc; close all;
%% 1. 加载数据
load('附件2-风电机组采集数据.mat'); farms = {'WF_1', 'WF_2'};
%% 2. 参数设置
rho = 1.225;                                                                % 空气密度 kg/m^3
R = 63;                                                                     % 风轮半径 m
%% 3. 收集所有风机的数据
time_data = data_TS_WF.WF_2.WT{1}.time;
Pref = []; Pref_his = []; V = []; Tshaft = []; Ft = [];
pitch = []; omega_r = []; lambda = []; Ct = [];
for j = 1:2
    for i = 1:100
        Pref_ji = data_TS_WF.(farms{j}).WT{i}.inputs(:, 1);
        if i>1
            Pref_his_ji = data_TS_WF.(farms{j}).WT{i-1}.inputs(:, 1);
        else
            Pref_his_ji = data_TS_WF.(farms{j}).WT{1}.inputs(:, 1);
        end
        V_ji = data_TS_WF.(farms{j}).WT{i}.inputs(:, 2);
        Tshaft_ji = data_TS_WF.(farms{j}).WT{i}.outputs(:, 1);
        Ft_ji = data_TS_WF.(farms{j}).WT{i}.outputs(:, 2);
        pitch_ji = data_TS_WF.(farms{j}).WT{i}.states(:, 1);
        omega_r_ji = data_TS_WF.(farms{j}).WT{i}.states(:, 2);
        lambda_ji = omega_r_ji .* R ./ V_ji;                                % 叶尖速比
        Ct_ji = 2*Ft_ji./ (pi*rho*R^2*V_ji.^2.*Pref_his_ji);
        Pref = [Pref; Pref_ji]; Pref_his = [Pref_his; Pref_his_ji]; V = [V; V_ji];
        Tshaft = [Tshaft; Tshaft_ji]; Ft = [Ft; Ft_ji];
        pitch = [pitch; pitch_ji]; omega_r = [omega_r; omega_r_ji];
        lambda = [lambda; lambda_ji]; Ct = [Ct; Ct_ji];
    end
end
clear j i Pref_ji Pref_his_ji V_ji Tshaft_ji Ft_ji pitch_ji omega_r_ji lambda_ji Ct_ji data_TS_WF farms
%% 4. 主轴扭矩的表达式 T_{shaft}(t+1) = η*P_ref(t)/w_r
Tshaft_pred = Pref./omega_r; Tshaft_pred = [Tshaft(1);Tshaft_pred(1:end-1)]; 
eta = (Tshaft_pred' * Tshaft) / (Tshaft_pred' * Tshaft_pred);
%% 5. 塔架推力的表达式
ct_model = @(c, x) c(1)*(c(2)*(1./(x(:,1)+c(3)*x(:,2))-c(4)./(x(:,2).^3+1))-c(5)*x(:,2)-c(6)) ...
    .* exp(-c(7)*(1./(x(:,1)+c(3)*x(:,2))-c(4)./(x(:,2).^3+1)))+c(8)*x(:,1);
c0 = [0.5, 116, 0.08, 0.035, 0.4, 5, 21, 0.0068];                           % 初始猜测值
opts = optimoptions('lsqcurvefit', 'Display', 'iter', 'MaxFunctionEvaluations', 1000);
c_fitted = lsqcurvefit(ct_model, c0, [lambda(:), pitch(:)], Ct(:), [], [], opts);
Ct_pred_nl = ct_model(c_fitted, [lambda, pitch]);
%% 6. 计算预测值及误差
Tshaft_pred = eta*Tshaft_pred;                                              % 主轴扭矩预测
Ft_pred_nl = 0.5*pi*rho*R^2*Ct_pred_nl.*V.^2.*Pref_his;                     % 塔架推力预测
%% 7. 误差分析
% 7.1 主轴扭矩误差
MAE_T = mean(abs(Tshaft - Tshaft_pred));
RMSE_T = sqrt(mean((Tshaft - Tshaft_pred).^2));
MAPE_T = mean(abs((Tshaft - Tshaft_pred)./Tshaft)) * 100;
R2_T = 1 - sum((Tshaft - Tshaft_pred).^2) / sum((Tshaft - mean(Tshaft)).^2);
fprintf('\n【主轴扭矩拟合误差】\n');
fprintf('MAE:  %.4e N·m，', MAE_T);fprintf('RMSE: %.4e N·m\n', RMSE_T);
fprintf('MAPE: %.2f%%，', MAPE_T);fprintf('R²:   %.4f\n', R2_T);
% 7.2 塔架推力误差
MAE_F_nl = mean(abs(Ft - Ft_pred_nl));
RMSE_F_nl = sqrt(mean((Ft - Ft_pred_nl).^2));
MAPE_F_nl = mean(abs((Ft - Ft_pred_nl)./Ft)) * 100;
R2_F_nl = 1 - sum((Ft - Ft_pred_nl).^2) / sum((Ft - mean(Ft)).^2);
fprintf('\n【塔架推力拟合误差】\n');
fprintf('MAE:  %.4e N，', MAE_F_nl);    fprintf('RMSE: %.4e N\n', RMSE_F_nl);
fprintf('MAPE: %.2f%%，', MAPE_F_nl);    fprintf('R²:   %.4f\n', R2_F_nl);
%% 8. 绘制结果图
figure('Position', [100, 100, 1000, 600]);
% 8.1 主轴扭矩 - 时间序列（随机选10000个点展示）
subplot(221);n_show = 10000;show_idx = randi(length(Tshaft), n_show, 1);
scatter(Tshaft(show_idx)/1e6, Tshaft_pred(show_idx)/1e6, 5, 'filled');hold on;
plot([min(Tshaft/1e6), max(Tshaft/1e6)], [min(Tshaft/1e6), max(Tshaft/1e6)], 'r--', 'LineWidth', 2);
xlabel('实测 T_{shaft} (MN·m)');ylabel('预测 T_{shaft} (MN·m)');
title(['主轴扭矩 (R² = ', num2str(R2_T, '%.4f'), ')']);grid on;axis equal;
% 8.2 塔架推力 - 时间序列
subplot(222); scatter(Ft(show_idx)/1e6, Ft_pred_nl(show_idx)/1e6, 5, 'filled');hold on;
plot([min(Ft/1e6), max(Ft/1e6)], [min(Ft/1e6), max(Ft/1e6)], 'r--', 'LineWidth', 2);
xlabel('实测 F_t (MN)');ylabel('预测 F_t (MN)');grid on;axis equal;
title(['塔架推力-非线性拟合 (R² = ', num2str(R2_F_nl, '%.4f'), ')']);
% 8.3 残差分布 - 主轴扭矩
subplot(223);residuals_T = (Tshaft - Tshaft_pred) / 1e6;
histogram(residuals_T, 50, 'FaceColor', 'b', 'EdgeColor', 'none');
xlabel('残差 (MN·m)');ylabel('频数');title('主轴扭矩残差分布');grid on;
% 8.4 残差分布 - 塔架推力
subplot(224);residuals_F = (Ft - Ft_pred_nl) / 1e6;
histogram(residuals_F, 50, 'FaceColor', 'r', 'EdgeColor', 'none');
xlabel('残差 (MN)');ylabel('频数');title('塔架推力残差分布');grid on;
%% 9. 输出最终公式
fprintf('【主轴扭矩公式】T_{shaft} = %.6f P_ref/ω_r\n', eta);
fprintf('【塔架推力公式】F_t = 0.5πρR²·C_t(λ,β)·V²·P_ref，其中:\n');
fprintf(' C_t = %.6f(%.6f/λ* - %.6fβ - %.6f)exp(-%.6f/λ*) + %.6fλ，\n', [c_fitted(1:2),c_fitted(5:8)]);
fprintf(' 1/λ* = 1/(λ + %.6fβ) - %.6f/(β³ + 1),λ = ω_r·R/V\n', c_fitted(3:4));
%% 10. 输出计算结果
clear c0 Ct Ft lambda omega_r opts pitch R rho time_data Tshaft V Ct_pred_nl 
clear Pref Pref_his eta c_fitted n_show show_idx
%xlswrite('附件6-问题二答案表.xlsx', num2cell(reshape(Tshaft_pred,2000,200)), '主轴扭矩', 'B2');
%xlswrite('附件6-问题二答案表.xlsx', num2cell(reshape(Ft_pred_nl,2000,200)), '塔架推力', 'B2');