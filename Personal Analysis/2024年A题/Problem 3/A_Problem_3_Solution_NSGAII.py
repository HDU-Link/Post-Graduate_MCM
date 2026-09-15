import numpy as np
import seaborn as sns
import scipy.io as sio
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.animation import PillowWriter
from scipy.optimize import minimize, Bounds, LinearConstraint
from pymoo.core.problem import Problem
from pymoo.algorithms.moo.nsga2 import NSGA2
from pymoo.operators.crossover.sbx import SBX
from pymoo.operators.mutation.pm import PM
from pymoo.operators.sampling.rnd import FloatRandomSampling
from pymoo.optimize import minimize
from pymoo.visualization.scatter import Scatter
sns.set_style("darkgrid"); colors = sns.color_palette("husl", 6)
plt.rcParams['font.sans-serif'] = ['Microsoft YaHei', 'SimHei']
# ============ 1. 数据读取 ============
data = sio.loadmat('附件2-风电机组采集数据.mat')
data_TS_WF = data['data_TS_WF'];
Time = data_TS_WF['WF_1'][0, 0]['WT'][0, 0][0, 0][0, 0][0][:, 0]
Pref = []; V = []; omega_r = []; Tshaft = []; Ft = []; pitch = [];
eta = 1.057738; Ct =[]; Pt = []; # 调度总功率
for i in range(100):
    WF1 = data_TS_WF['WF_1'][0, 0]['WT'][0, 0][0, i][0, 0]
    Pref.append(WF1[1][:, 0]); V.append(WF1[1][:, 1]);
    Tshaft.append(WF1[2][:, 0]); Ft.append(WF1[2][:, 1]);
    pitch.append(WF1[3][:, 0]); omega_r.append(WF1[3][:, 1]);
    Pt.append(sum(Pref[:][i]));
Ct = np.array([Ft[i] / (0.5 * np.pi*1.225*63**2 * V[i]**2 * Pref[i]) for i in range(100)])
Pref = np.array(Pref); V = np.array(V); omega_r = np.array(omega_r);
Tshaft = np.array(Tshaft); Ft = np.array(Ft); pitch = np.array(pitch);
Pt = np.sum(Pref, axis=0); Pt_ave = Pt / 100
# ============ 2. 疲劳指数 ============
# 提取波峰波谷函数
def extract_peaks_valleys(data):
    n = len(data); is_peak = np.zeros(n, dtype=bool); is_valley = np.zeros(n, dtype=bool)
    for i in range(1, n-1):
        if data[i] > data[i-1] and data[i] > data[i+1]:
            is_peak[i] = True
        elif data[i] < data[i-1] and data[i] < data[i+1]:
            is_valley[i] = True
    # 处理端点
    if n > 1:
        is_peak[0] = data[0] > data[1]; is_valley[0] = data[0] < data[1]
        is_peak[n-1] = data[n-1] > data[n-2]; is_valley[n-1] = data[n-1] < data[n-2]
    pv = data[is_peak | is_valley]
    return pv

# 三点式雨流计数法
def rainflow_3point(pv):
    X = pv.flatten().copy()
    amplitudes = []; means = []; counts = []
    if len(X) >= 3:
        S1 = X[0]; S2 = X[1]; S3 = X[2]
    else:
        return np.array([]), np.array([]), np.array([])
    idx = 3
    while len(X) >= 3:
        DeltaS1 = abs(S1 - S2); DeltaS2 = abs(S2 - S3)
        if DeltaS1 <= DeltaS2:
            amplitudes.append(DeltaS1); means.append((S1 + S2) / 2); counts.append(1)
            X = np.concatenate([X[:idx-3], X[idx:]])
            if len(X) < 3:
                if len(X) == 2:
                    amplitudes.append(abs(X[0] - X[1])); means.append((X[0] + X[1]) / 2)
                    counts.append(0.5)
                break
            S1 = X[0]; S2 = X[1]; S3 = X[2]; idx = 3
        else:
            if idx + 1 <= len(X):
                idx += 1; S1 = S2; S2 = S3; S3 = X[idx-1]
            elif idx == len(X):
                idx += 1; S1 = X[-2]; S2 = X[-1]; S3 = X[0]
            else:
                S1 = X[-1]; S2 = X[0]; S3 = X[1]
    return np.array(amplitudes), np.array(means), np.array(counts)

# 逐秒时序滑动计算瞬时&累积损伤
def calc_damage(data):
    m = 10                                                      # Wohler指数
    C = 9.77e70                                                 # S-N曲线常数
    sigma_b = 50000000                                          # 材料拉伸断裂最大载荷值
    N = 42565440.4361                                           # 设计寿命循环次数
    cum_damage_arr = np.zeros(100)
    for t in range(3, 11):
        seg_data = data[:t]
        pv_seg = extract_peaks_valleys(seg_data)
        amps, means_seg, cnts = rainflow_3point(pv_seg)
        if len(amps) > 0:
            S_seg = amps / (1 - means_seg / sigma_b)
            Nf_seg = C / (S_seg ** m)
            D_seg = np.sum(cnts / Nf_seg)
            cum_damage_arr[t-1] = max(D_seg, cum_damage_arr[t-2] if t > 1 else 0)
        else:
            cum_damage_arr[t-1] = cum_damage_arr[t-2] if t > 1 else 0
    for t in range(11, 101):
        seg_data = data[t-10:t]
        pv_seg = extract_peaks_valleys(seg_data)
        amps, means_seg, cnts = rainflow_3point(pv_seg)
        if len(amps) > 0:
            S_seg = amps / (1 - means_seg / sigma_b)
            Nf_seg = C / (S_seg ** m)
            D_seg = np.sum(cnts / Nf_seg)
            cum_damage_arr[t-1] = cum_damage_arr[t-2] + D_seg
        else:
            cum_damage_arr[t-1] = cum_damage_arr[t-2]
    return cum_damage_arr
# ============ 3. 优化调度 ============
class WindFarmOpt(Problem):
    def __init__(self, t, Pt_target, Pt_ave_t, omega_r_t, V_t, Ct_t, 
                 P_his, Pref_t, P_min=0, P_max=5000000, delta_P=1000000):
        self.t = t; self.Pt_target = Pt_target
        self.Pt_ave_t = Pt_ave_t; self.omega_r_t = omega_r_t
        self.V_t = V_t; self.Ct_t = Ct_t
        self.P_his = P_his; self.Pref_t = Pref_t
        self.P_min = P_min; self.P_max = P_max; self.delta_P = delta_P
        lb = np.maximum(P_min, Pt_ave_t - delta_P)
        ub = np.minimum(P_max, Pt_ave_t + delta_P)
        super().__init__(n_var=100, n_obj=2, n_constr=1, xl=lb, xu=ub)
    def _evaluate(self, X, out, *args, **kwargs):
        n_pop = X.shape[0]; n_turbines = 100
        F1 = np.zeros(n_pop)
        F2 = np.zeros(n_pop)
        G = np.zeros(n_pop)
        P_history = self.P_his[:, :self.t]  # (100, t)
        omega_history = self.omega_r_t[:, :self.t]  # (100, t)
        V_history = self.V_t[:, :self.t]  # (100, t)
        Ct_history = self.Ct_t[:, :self.t]  # (100, t)
        Ts_history = 1.057738 * P_history / (omega_history + 1e-10)  # (100, t)
        Ft_history = 0.5 * 1.225 * np.pi * 63**2 * V_history**2 * Ct_history * P_history  # (100, t)
        for pop_idx in range(n_pop):
            P = X[pop_idx, :]
            T_s = 1.057738 * P / (self.omega_r_t[:, self.t] + 1e-10)
            F_t = 0.5 * 1.225 * np.pi * 63**2 * self.V_t[:, self.t]**2 * self.Ct_t[:, self.t] * P
            damage_Ts_total = 0;damage_Ft_total = 0
            for i in range(n_turbines):
                Ts_seq = np.concatenate([Ts_history[i, :], [T_s[i]]])
                damage_Ts = calc_damage(Ts_seq)
                damage_Ts_total += damage_Ts[-1]
                Ft_seq = np.concatenate([Ft_history[i, :], [F_t[i]]])
                damage_Ft = calc_damage(Ft_seq)
                damage_Ft_total += damage_Ft[-1]
            F1[pop_idx] = damage_Ts_total; F2[pop_idx] = damage_Ft_total
            G[pop_idx] = np.sum(P) - self.Pt_target
        out["F"] = np.column_stack([F1, F2])
        out["G"] = np.column_stack([G])
def moo(t, Pref, P_his, omega_r_t, V_t, Ct_t, Pt_target, Pt_ave_t):
    problem = WindFarmOpt(t, Pt_target, Pt_ave_t, omega_r_t, V_t, Ct_t, P_his, Pref[:, t])
    res = minimize(problem, NSGA2(pop_size=10), termination=('n_gen', 10), seed=42, verbose=False)
    F = res.F;  pareto_idx = np.argmin(np.sum(F, axis=1))
    optimal_P = res.X[pareto_idx, :]; optimal_obj = F[pareto_idx, :]
    return optimal_P, optimal_obj
P_optimal = np.zeros((100, 2000)); obj_values_Ts = np.zeros(2000); obj_values_Ft = np.zeros(2000);
ref_values_Ft = np.zeros(2000); ref_values_Ts = np.zeros(2000)
P_optimal[:, 0] = np.ones(100) * Pt_ave[0]; P_opt_history = np.zeros_like(Pref); P_opt_history[:, 0] = Pref[:, 0]
rt_damage_tower = np.zeros((100, 100)); rt_damage_shaft = np.zeros((100, 100));
Ts = np.column_stack([2508044.70273628 * np.ones(100), 1.057738 * Pref[:, :100] / omega_r[:, :100]]);
Ft = 0.5 * np.pi * 1.225 * 63**2 * V[:, :101]**2 * Ct[:, :101] * Pref[:, :101];
for i in range(100):
    rt_damage_shaft[i, :] = calc_damage(Ts[i]);
    rt_damage_tower[i, :] = calc_damage(Ft[i]);
# ============ 4. 创建动画 ============
fig = plt.figure(figsize=(14, 10))
ax1 = plt.subplot2grid((3, 2), (0, 0), colspan=2)  # 功率分配
ax2 = plt.subplot2grid((3, 2), (1, 0), colspan=1)  # 塔架损伤
ax3 = plt.subplot2grid((3, 2), (1, 1), colspan=1)  # 主轴损伤
ax4 = plt.subplot2grid((3, 2), (2, 0), colspan=2)  # Pareto前沿
# 子图1: 100台风机的功率分配
x_pos = np.arange(100); bar_width = 0.5
bars_ref = ax1.bar(x_pos - bar_width/2, Pref[:, 0] / 1e6, bar_width,
                   label='参考功率', color=colors[0], alpha=0.7)
bars_opt = ax1.bar(x_pos + bar_width/2, P_optimal[:, 0] / 1e6, bar_width,
                   label='优化功率', color=colors[3], alpha=0.7)
ax1.set_xlabel('风机编号'); ax1.set_ylabel('功率 (MW)')
ax1.set_title('100台风机功率分配对比'); ax1.legend(loc='upper right')
ax1.grid(True, alpha=0.3); ax1.set_xlim(-1, 100); ax1.set_ylim(0, 6)
# 子图2: 塔架推力损伤
line_ref_Ft, = ax2.plot([], [], color=colors[4], linewidth=1.5, label='参考目标值')
line_opt_Ft, = ax2.plot([], [], color=colors[5], linewidth=1.5, label='优化目标值')
ax2.set_xlabel('时间 (s)'); ax2.set_ylabel('塔架累积疲劳损伤'); ax2.set_title('塔架推力目标函数')
ax2.legend(loc='upper right'); ax2.grid(True, alpha=0.3)
# 子图3: 主轴扭矩损伤
line_ref_Ts, = ax3.plot([], [], color=colors[4], linewidth=1.5, label='参考目标值')
line_opt_Ts, = ax3.plot([], [], color=colors[5], linewidth=1.5, label='优化目标值')
ax3.set_xlabel('时间 (s)'); ax3.set_ylabel('主轴累积疲劳损伤')
ax3.set_title('主轴扭矩目标函数'); ax3.legend(loc='upper right'); ax3.grid(True, alpha=0.3)
# 子图4: Pareto前沿
scat_pareto = ax4.scatter([], [], c='red', s=30, alpha=0.7)
ax4.set_xlabel('主轴扭矩疲劳损伤'); ax4.set_ylabel('塔架推力疲劳损伤')
ax4.set_title('Pareto前沿'); ax4.grid(True, alpha=0.3)
# 更新函数
def update(frame):
    current_time = frame % 100; t = current_time + 1
    P_opt, obj_val = moo(t, Pref, P_opt_history[:, :t+1],
                omega_r[:, :t+1], V[:, :t+1], Ct[:, :t+1], Pt[t], Pt_ave[t])
    P_opt_history[:, t] = P_opt; P_optimal[:, t] = P_opt
    obj_values_Ts[t] = obj_val[0] / 100; obj_values_Ft[t] = obj_val[1] / 100
    ref_values_Ft[t] = np.sum(rt_damage_tower[:, t-1]) / 100
    ref_values_Ts[t] = np.sum(rt_damage_shaft[:, t-1]) / 100
    # 更新子图1
    for bar, ref_val, opt_val in zip(bars_ref, Pref[:, current_time]/1e6, P_optimal[:, current_time]/1e6):
        bar.set_height(ref_val)
    for bar, opt_val in zip(bars_opt, P_optimal[:, current_time]/1e6):
        bar.set_height(opt_val)
    ax1.set_title(f'100台风机功率实时分配对比 (t={Time[current_time]:.0f}s)')
    # 更新子图2
    time_obj = Time[0:current_time+1]
    line_ref_Ft.set_data(time_obj, ref_values_Ft[0:current_time+1])
    line_opt_Ft.set_data(time_obj, obj_values_Ft[0:current_time+1])
    ax2.set_xlim(0, max(10, Time[current_time] + 1))
    max_val = max(obj_values_Ft[current_time], ref_values_Ft[current_time]) * 1.5
    ax2.set_ylim(0, max_val if max_val > 0 else 1e-10)
    # 更新子图3
    line_ref_Ts.set_data(time_obj, ref_values_Ts[0:current_time+1])
    line_opt_Ts.set_data(time_obj, obj_values_Ts[0:current_time+1])
    ax3.set_xlim(0, max(10, Time[current_time] + 1))
    max_val = max(obj_values_Ts[current_time], ref_values_Ts[current_time]) * 1.5
    ax3.set_ylim(0, max_val if max_val > 0 else 1e-10)
    # 更新子图4
    if t > 1 and obj_values_Ts[t] > 0 and obj_values_Ft[t] > 0:
        scat_pareto.set_offsets(np.column_stack([obj_values_Ts[1:t+1], obj_values_Ft[1:t+1]]))
        ax4.set_xlim(0, max(obj_values_Ts[1:t+1]) * 1.5 + 1e-12)
        ax4.set_ylim(0, max(obj_values_Ft[1:t+1]) * 1.5 + 1e-20)
    return bars_ref, bars_opt, line_ref_Ft, line_opt_Ft, line_ref_Ts, line_opt_Ts, scat_pareto
ani = animation.FuncAnimation(fig, update, frames=range(0, 100), 
                              interval=500, blit=False, repeat=False)
ani.save('wind_turbine_multiobjective.gif', writer=PillowWriter(fps=5))
plt.tight_layout()
plt.show()
