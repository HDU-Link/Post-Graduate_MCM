import numpy as np
import seaborn as sns
import scipy.io as sio
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.animation import PillowWriter
from scipy.optimize import minimize, Bounds, LinearConstraint
sns.set_style("darkgrid"); colors = sns.color_palette("husl", 6)
plt.rcParams['font.sans-serif'] = ['Microsoft YaHei', 'SimHei']
# ============ 1. 数据读取 ============
data = sio.loadmat('附件2-风电机组采集数据.mat')
data_TS_WF = data['data_TS_WF']; n_turbines = 100; n_time = 2000
Time = data_TS_WF['WF_1'][0, 0]['WT'][0, 0][0, 0][0, 0][0][:, 0]
Pref = []; V = []; omega_r = []; Tshaft = []; Ft = []; pitch = [];
eta = 1.057738; Ct =[]; Pt = []; # 调度总功率
for i in range(100):
    WF1 = data_TS_WF['WF_1'][0, 0]['WT'][0, 0][0, i][0, 0]
    Pref.append(WF1[1][:, 0]); V.append(WF1[1][:, 1]);
    Tshaft.append(WF1[2][:, 0]); Ft.append(WF1[2][:, 1]);
    pitch.append(WF1[3][:, 0]); omega_r.append(WF1[3][:, 1]);
    Pt.append(sum(Pref[:][i]));
Ct = np.array([Ft[i] / (0.5 * 3.1415926*1.225*63**2 * V[i]**2) for i in range(100)])
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
    """三点式雨流计数法"""
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
    """逐秒时序滑动计算瞬时&累积损伤"""
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
def optimize_Ts(t, Pref, P_his, omega_r_t, Pt_target, Pt_ave_t, P_min=0, P_max=5000000, delta_P=1000000):
    Ts_his = np.column_stack([2508044.70273628 * np.ones(100),
                                  1.057738 * P_his[:, :t] / omega_r_t[:, :t]]);
    Rt_damage_tower = np.zeros((100, 100));
    # 约束1: sum(P) = Pt
    constraint_eq = LinearConstraint(np.ones((1, 100)), np.array([Pt_target]), np.array([Pt_target]))
    # 约束2: 0 <= P <= 5000000, |P - Pt_ave| <= 1000000
    lb = np.maximum(P_min, Pt_ave_t - delta_P);  ub = np.minimum(P_max, Pt_ave_t + delta_P)
    # 目标函数
    def obj(P):
        T_s = 1.057738 * P / omega_r_t[:, t]
        for i in range(100):
            Rt_damage_tower[i, :] = calc_damage(np.concatenate([Ts_his[i], np.array([T_s[i]])]))
        return np.sum(Rt_damage_tower[:, t-1])
    result = minimize(obj, Pt_ave_t* np.ones(100), # 初值亦可选Pref[:, t]
                      bounds=Bounds(lb, ub), constraints=constraint_eq,
                      method='SLSQP', options={'maxiter': 1000, 'ftol': 2e-6})
    return result.x, result.fun
def optimize_Ft(t, Pref, P_his, C_t, V_t, Pt_target, Pt_ave_t, P_min=0, P_max=5000000, delta_P=1000000):
    Ft_his = 0.5 * np.pi * 1.225 * 63**2 * V_t[:, :t]**2 * C_t[:, :t] * P_his[:, :t];
    Rt_damage_tower = np.zeros((100, 100));
    # 约束1: sum(P) = Pt
    constraint_eq = LinearConstraint(np.ones((1, 100)), np.array([Pt_target]), np.array([Pt_target]))
    # 约束2: 0 <= P <= 5000000, |P - Pt_ave| <= 1000000
    lb = np.maximum(P_min, Pt_ave_t - delta_P);  ub = np.minimum(P_max, Pt_ave_t + delta_P)
    # 目标函数
    def obj(P):
        F_t = 0.5 * np.pi * 1.225 * 63**2 * V_t[:, t]**2 * C_t[:, t] * P
        for i in range(100):
            Rt_damage_tower[i, :] = calc_damage(np.concatenate([Ft_his[i], np.array([F_t[i]])]))
        return np.sum(Rt_damage_tower[:, t-1])
    result = minimize(obj, Pt_ave_t* np.ones(100), #初值亦可选Pref[:, t]
                      bounds=Bounds(lb, ub), constraints=constraint_eq,
                      method='SLSQP', options={'maxiter': 1000, 'ftol': 2e-6})
    return result.x, result.fun
P_optimal = np.zeros((100, 2000)); obj_values = np.zeros(2000); ref_values = np.zeros(2000)
P_optimal[:, 0] = np.ones(100) * Pt_ave[0]; P_opt_history = np.zeros_like(Pref); P_opt_history[:, 0] = Pref[:, 0]
rt_damage_tower = np.zeros((100, 100)); rt_damage_shaft = np.zeros((100, 100));
Ts = np.column_stack([2508044.70273628 * np.ones(100), 1.057738 * Pref[:, :100] / omega_r[:, :100]]);
Ft = 0.5 * np.pi * 1.225 * 63**2 * V[:, :101]**2 * Ct[:, :101] * Pref[:, :101];
for i in range(100):
    rt_damage_tower[i, :] = calc_damage(Ts[i]);
    rt_damage_shaft[i, :] = calc_damage(Ft[i]);
# ============ 4. 创建动画 ============
turbine_idx = 0  # 要显示的单台风机索引
# 创建图形
fig = plt.figure(figsize=(12, 8))
fig.suptitle('风电场实时功率分配 (t=0s)', fontsize=16, fontweight='bold')
ax1 = plt.subplot2grid((2, 2), (1, 0), colspan=2, rowspan=1)  # 100台风机的功率分配
ax2 = plt.subplot2grid((2, 2), (0, 1), colspan=1, rowspan=1)  # 单台风机功率对比
ax3 = plt.subplot2grid((2, 2), (0, 0), colspan=1, rowspan=1)  # 总功率目标函数值
# 子图1: 100台风机的功率分配
x_pos = np.arange(100)
bar_width = 0.5
bars_ref = ax1.bar(x_pos - bar_width/2, Pref[:, 0] / 1e7, bar_width, label='参考功率', color=colors[0], alpha=0.7)
bars_opt = ax1.bar(x_pos + bar_width/2, P_optimal[:, 0] / 1e7, bar_width, label='优化功率', color=colors[3], alpha=0.7)
ax1.set_xlabel('风机编号'); ax1.set_ylabel('功率 (MW)')
ax1.set_title('100台风机功率分配对比'); ax1.legend(loc='upper right')
ax1.grid(True, alpha=0.3); ax1.set_xlim(-1, 100); ax1.set_ylim(0, 6)
# 子图2: 单台风机功率对比
line_ref, = ax2.plot([], [], color=colors[0], linewidth=2, label=f'参考功率')
line_opt, = ax2.plot([], [], color=colors[3], linewidth=2, label=f'优化功率')
ax2.set_xlabel('时间 (s)'); ax2.set_ylabel('功率 (W)')
ax2.set_title(f'风机 {turbine_idx+1} 实时功率变化')
ax2.legend(loc='upper right'); ax2.grid(True, alpha=0.3)
# 子图3: 目标函数值
line_obj_ref, = ax3.plot([], [], color=colors[4], linewidth=1.5, label='参考目标值')
line_obj_opt, = ax3.plot([], [], color=colors[5], linewidth=1.5, label='优化目标值')
ax3.set_xlabel('时间 (s)'); ax3.set_title('总目标函数值')
ax3.set_ylabel('塔架推力累计疲劳损伤');
#ax3.set_ylabel('主轴扭矩累计疲劳损伤'); 
ax3.legend(loc='upper right'); ax3.grid(True, alpha=0.3)
# 统计信息
text_1 = ax2.text(0, 0, '', transform=ax2.transAxes, fontsize=12, verticalalignment='bottom');
text_2 = ax3.text(0, 0, '', transform=ax3.transAxes, fontsize=12, verticalalignment='bottom');
# 更新函数
def update(frame):
    current_time = frame % 100; t = current_time + 1
    P_opt, obj_val = optimize_Ts(t, Pref, P_opt_history[:, :t+1], omega_r[:, :t+1], Pt[t], Pt_ave[t])
    #P_opt, obj_val = optimize_Ft(t, Pref, P_opt_history[:, :t+1], Ct[:, :t+1], V[:, :t+1], Pt[t], Pt_ave[t])
    P_opt_history[:, t] = P_opt; P_optimal[:, t] = P_opt; obj_values[t] = obj_val/100;
    ref_values[t] = np.sum(rt_damage_tower[:, t-1])/100;
    #ref_values[t] = np.sum(rt_damage_shaft[:, t-1])/100;
    fig.suptitle(f'风电场实时功率分配 (t={Time[current_time]:.0f}s)', fontsize=16, fontweight='bold')
    # 更新子图1: 功率分配
    for bar, ref_val, opt_val in zip(bars_ref, Pref[:, current_time]/1e6, P_optimal[:, current_time]/1e6):
        bar.set_height(ref_val)
    for bar, opt_val in zip(bars_opt, P_optimal[:, current_time]/1e6):
        bar.set_height(opt_val)
    ax1.set_title(f'100台风机功率实时分配对比 (t={Time[current_time]:.0f}s)')
    # 更新子图2: 单台风机功率
    time_window = Time[0:current_time+1]
    ref_window = Pref[turbine_idx, 0:current_time+1]
    opt_window = P_optimal[turbine_idx, 0:current_time+1]
    line_ref.set_data(time_window, ref_window);  line_opt.set_data(time_window, opt_window)
    ax2.set_xlim(0, Time[current_time] + 1);    ax2.set_ylim(2e6, 6e6)
    # 更新子图3: 目标函数值
    time_obj = Time[0:current_time+1]
    ref_obj = ref_values[0:current_time+1]
    opt_obj = obj_values[0:current_time+1]
    line_obj_ref.set_data(time_obj, ref_obj);  line_obj_opt.set_data(time_obj, opt_obj)
    ax3.set_xlim(0, Time[current_time] + 1); ax3.set_ylim(0, max(obj_values[current_time], ref_values[current_time])*1.5+1e-12)
    # 更新统计信息
    stats_text_1 = f"""参考功率 {Pref[turbine_idx, current_time]:.3f} W,  优化功率 {P_optimal[turbine_idx, current_time]:.3f} W"""
    stats_text_2 = f"""参考目标值 {ref_values[current_time]:.8e},  优化目标值 {obj_values[current_time]:.8e}"""
    text_2.set_text(stats_text_2); text_1.set_text(stats_text_1)
    return bars_ref, bars_opt, line_ref, line_opt, line_obj_ref, line_obj_opt, text_1, text_2
ani = animation.FuncAnimation(fig, update, frames=range(0, 100), interval=200, blit=False, repeat=False)
#ani.save('wind_turbine_optimization.gif', writer=PillowWriter(fps=5))
plt.tight_layout()
plt.show()
