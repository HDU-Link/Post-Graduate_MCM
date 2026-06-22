clear; clc; close all;
%% 1. 加载数据
load('附件2-风电机组采集数据.mat'); farms = {'WF_1', 'WF_2'};
%% 2. 参数设置
rho = 1.225;                                                                % 空气密度 kg/m^3
R = 63;                                                                     % 风轮半径 m
%% 3. 收集所有风机的数据
time_data = data_TS_WF.WF_2.WT{1}.time;
Pref = []; V = []; Tshaft = []; Ft = []; pitch = [];
omega_r = []; lambda = []; Ct = [];
for j = 1:2
    for i = 1:100
        Pref_ij = data_TS_WF.(farms{j}).WT{i}.inputs(:, 1);
        V_ji = data_TS_WF.(farms{j}).WT{i}.inputs(:, 2);
        Tshaft_ji = data_TS_WF.(farms{j}).WT{i}.outputs(:, 1);
        Ft_ji = data_TS_WF.(farms{j}).WT{i}.outputs(:, 2);
        pitch_ji = data_TS_WF.(farms{j}).WT{i}.states(:, 1);
        omega_r_ji = data_TS_WF.(farms{j}).WT{i}.states(:, 2);
        lambda_ji = omega_r_ji .* R ./ V_ji;                                % 叶尖速比
        Ct_ji = 2*Ft_ji./ (pi*rho*R^2*V_ji.^2);
        Pref = [Pref; Pref_ij]; V = [V; V_ji]; Tshaft = [Tshaft; Tshaft_ji];
        Ft = [Ft; Ft_ji]; pitch = [pitch; pitch_ji];
        omega_r = [omega_r; omega_r_ji];
        lambda = [lambda; lambda_ji]; Ct = [Ct; Ct_ji];
    end
end
clear j i Pref_ij V_ji Tshaft_ji Ft_ji pitch_ji omega_r_ji lambda_ji Ct_ji data_TS_WF farms
%% 4. 主轴扭矩的表达式 T_{shaft}(t+1) = η*P_ref(t)/w_r
Tshaft_pred = Pref./omega_r; Tshaft_pred = [Tshaft(1);Tshaft_pred(1:end-1)]; 
eta = (Tshaft_pred' * Tshaft) / (Tshaft_pred' * Tshaft_pred);
%% 5. 拟合 Ct(lambda, pitch) 的表达式
%% 5.1 多项式拟合 Ct = a0 + a1*λ + a2*β + a3*λ^2 + a4*λ*β + a5*β^2 + a6*λ^3 + a7*β^3
X_poly = [ones(2000*200,1), lambda, pitch, lambda.^2, lambda.*pitch, pitch.^2, lambda.^3, pitch.^3];
theta_poly = X_poly \ Ct;                                                   % 最小二乘解
fprintf('多项式拟合系数:');
fprintf('a0 = %.6f,', theta_poly(1));fprintf('a1 = %.6f (λ),', theta_poly(2));
fprintf('a2 = %.6f (β),', theta_poly(3));fprintf('a3 = %.6f (λ²),\n', theta_poly(4));
fprintf('a4 = %.6f (λβ),', theta_poly(5));fprintf('a5 = %.6f (β²),', theta_poly(6));
fprintf('a6 = %.6f (λ³),', theta_poly(7));fprintf('a7 = %.6f (β³)', theta_poly(8));
Ct_pred_poly = theta_poly(1) + theta_poly(2)*lambda + theta_poly(3)*pitch + ...
               theta_poly(4)*lambda.^2 + theta_poly(5)*lambda.*pitch + ...
               theta_poly(6)*pitch.^2 + theta_poly(7)*lambda.^3 + theta_poly(8)*pitch.^3;
%% 5.2 非线性模型拟合 Ct = c1*(c2*(1/(λ+c3*β)-c4/(β**3+1))-c5*β-c6)*exp(-c7*(1/(λ+c3*β)-c4/(β**3+1))+c8*λ
ct_model = @(c, x) c(1)*(c(2)*(1./(x(:,1)+c(3)*x(:,2))-c(4)./(x(:,2).^3+1))-c(5)*x(:,2)-c(6)) ...
    .* exp(-c(7)*(1./(x(:,1)+c(3)*x(:,2))-c(4)./(x(:,2).^3+1)))+c(8)*x(:,1);
c0 = [0.5, 116, 0.08, 0.035, 0.4, 5, 21, 0.0068];                           % 初始猜测值
opts = optimoptions('lsqcurvefit', 'Display', 'iter', 'MaxFunctionEvaluations', 1000);
c_fitted = lsqcurvefit(ct_model, c0, [lambda(:), pitch(:)], Ct(:), [], [], opts);
fprintf('\n非线性模型拟合系数:\n');
fprintf('c1 = %.6f\n', c_fitted(1));fprintf('c2 = %.6f\n', c_fitted(2));
fprintf('c3 = %.6f\n', c_fitted(3));fprintf('c4 = %.6f\n', c_fitted(4));
fprintf('c5 = %.6f\n', c_fitted(5));fprintf('c6 = %.6f\n', c_fitted(6));
fprintf('c7 = %.6f\n', c_fitted(7));fprintf('c8 = %.6f\n', c_fitted(8));
Ct_pred_nl = ct_model(c_fitted, [lambda, pitch]);
%% 6. 计算预测值及误差
Tshaft_pred = eta*Tshaft_pred;                                              % 主轴扭矩预测
Ft_pred_poly = 0.5*pi*rho*R^2*Ct_pred_poly.*V.^2;                           % 塔架推力预测（使用多项式拟合）
Ft_pred_nl = 0.5*pi*rho*R^2*Ct_pred_nl.*V.^2;                               % 塔架推力预测（使用非线性拟合）
%% 7. 误差分析
% 7.1 主轴扭矩误差
MAE_T = mean(abs(Tshaft - Tshaft_pred));
RMSE_T = sqrt(mean((Tshaft - Tshaft_pred).^2));
MAPE_T = mean(abs((Tshaft - Tshaft_pred)./Tshaft)) * 100;
R2_T = 1 - sum((Tshaft - Tshaft_pred).^2) / sum((Tshaft - mean(Tshaft)).^2);
fprintf('\n【主轴扭矩拟合误差】\n');
fprintf('MAE:  %.4e N·m，', MAE_T);fprintf('RMSE: %.4e N·m\n', RMSE_T);
fprintf('MAPE: %.2f%%，', MAPE_T);fprintf('R²:   %.4f\n', R2_T);
% 7.2 塔架推力误差（多项式拟合）
MAE_F_poly = mean(abs(Ft - Ft_pred_poly));
RMSE_F_poly = sqrt(mean((Ft - Ft_pred_poly).^2));
MAPE_F_poly = mean(abs((Ft - Ft_pred_poly)./Ft)) * 100;
R2_F_poly = 1 - sum((Ft - Ft_pred_poly).^2) / sum((Ft - mean(Ft)).^2);
fprintf('\n【塔架推力拟合误差（多项式拟合）】\n');
fprintf('MAE:  %.4e N，', MAE_F_poly);fprintf('RMSE: %.4e N\n', RMSE_F_poly);
fprintf('MAPE: %.2f%%，', MAPE_F_poly);fprintf('R²:   %.4f\n', R2_F_poly);
% 7.3 塔架推力误差（非线性拟合）
MAE_F_nl = mean(abs(Ft - Ft_pred_nl));
RMSE_F_nl = sqrt(mean((Ft - Ft_pred_nl).^2));
MAPE_F_nl = mean(abs((Ft - Ft_pred_nl)./Ft)) * 100;
R2_F_nl = 1 - sum((Ft - Ft_pred_nl).^2) / sum((Ft - mean(Ft)).^2);
fprintf('\n【塔架推力拟合误差（非线性拟合）】\n');
fprintf('MAE:  %.4e N，', MAE_F_nl);    fprintf('RMSE: %.4e N\n', RMSE_F_nl);
fprintf('MAPE: %.2f%%，', MAPE_F_nl);    fprintf('R²:   %.4f\n', R2_F_nl);
%% 8. 绘制结果图
figure('Position', [100, 100, 1000, 600]);
% 8.1 主轴扭矩 - 时间序列（随机选1000个点展示）
subplot(221);n_show = min(10000, length(Tshaft));show_idx = randi(length(Tshaft), n_show, 1);
scatter(Tshaft(show_idx)/1e6, Tshaft_pred(show_idx)/1e6, 5, 'filled');hold on;
plot([min(Tshaft/1e6), max(Tshaft/1e6)], [min(Tshaft/1e6), max(Tshaft/1e6)], 'r--', 'LineWidth', 2);
xlabel('实测 T_{shaft} (MN·m)');ylabel('预测 T_{shaft} (MN·m)');
title(['主轴扭矩 (R² = ', num2str(R2_T, '%.4f'), ')']);grid on;axis equal;
% 8.2 塔架推力 - 时间序列（选1000个点展示）
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
% Ct拟合曲面（多项式拟合）
figure(2);scatter3(lambda, pitch, Ct, 3, Ct, 'filled');hold on;
lambda_grid = linspace(min(lambda), max(lambda), 300);
pitch_grid = linspace(min(pitch), max(pitch), 300);
[Lg, Pg] = meshgrid(lambda_grid, pitch_grid);
Ct_surface = theta_poly(1) + theta_poly(2)*Lg + theta_poly(3)*Pg + ...
             theta_poly(4)*Lg.^2 + theta_poly(5)*Lg.*Pg + ...
             theta_poly(6)*Pg.^2 + theta_poly(7)*Lg.^3 + theta_poly(8)*Pg.^3;
surf(Lg, Pg, Ct_surface, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
xlabel('λ');ylabel('β (deg)');zlabel('C_t');title('Ct(λ,β) 拟合结果');
colormap('jet');grid on;view(45, 30);
%% 9. 输出最终公式
fprintf('【主轴扭矩公式】');fprintf('T_{shaft} = %.6f P_ref/ω_r\n', eta);
fprintf('【塔架推力公式】F_t = 0.5πρR²·C_t(λ,β)·V²，其中:\n');
fprintf(' C_t = %.6f(%.6f/λ* - %.6fβ - %.6f)exp(-%.6f/λ*) + %.6fλ，\n', [c_fitted(1:2),c_fitted(5:8)]);
fprintf(' 1/λ* = 1/(λ + %.6fβ) - %.6f/(β³ + 1),λ = ω_r·R/V\n', c_fitted(3:4));
%% 10. 输出计算结果
clear c0 Ct Ft lambda omega_r opts pitch R rho time_data Tshaft V Ct_pred_nl Ct_pred_poly
clear eta c_fitted theta_poly X_poly Lg Pg lambda_grid Ct_surface n_show pitch_grid show_idx
xlswrite('附件6-问题二答案表.xlsx', num2cell(reshape(Tshaft_pred,2000,200)), '主轴扭矩', 'B2');
xlswrite('附件6-问题二答案表.xlsx', num2cell(reshape(Ft_pred_nl,2000,200)), '塔架推力', 'B2');