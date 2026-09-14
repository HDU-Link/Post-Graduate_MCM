import ast
import glob
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
import matplotlib.pyplot as plt
plt.rcParams['font.family'] = 'Arial'
plt.rcParams['font.sans-serif'] = ['Arial']

# 1. 读取数据
train_2ap_files = glob.glob("training_set_2ap_*.csv")
train_2ap_list = []
for f in train_2ap_files:
    df = pd.read_csv(f)
    train_2ap_list.append(df)
train_df = pd.concat(train_2ap_list, ignore_index=True)
test_path = "test_set_1_2ap.csv"
test_df = pd.read_csv(test_path)

# 2. 列表列取平均值
list_cols = ['ap_from_ap_0_sum_ant_rssi',
   'ap_from_ap_0_max_ant_rssi',
   'ap_from_ap_0_mean_ant_rssi',
   'ap_from_ap_1_sum_ant_rssi',
   'ap_from_ap_1_max_ant_rssi',
   'ap_from_ap_1_mean_ant_rssi',
   'sta_to_ap_0_sum_ant_rssi',
   'sta_to_ap_0_max_ant_rssi',
   'sta_to_ap_0_mean_ant_rssi',
   'sta_to_ap_1_sum_ant_rssi',
   'sta_to_ap_1_max_ant_rssi',
   'sta_to_ap_1_mean_ant_rssi',
   'sta_from_ap_0_sum_ant_rssi',
   'sta_from_ap_0_max_ant_rssi',
   'sta_from_ap_0_mean_ant_rssi',
   'sta_from_ap_1_sum_ant_rssi',
   'sta_from_ap_1_max_ant_rssi',
   'sta_from_ap_1_mean_ant_rssi']

for col in list_cols:
    train_means = []
    for x in train_df[col]:
        if isinstance(x, str) and x.strip().startswith("["):
            v = ast.literal_eval(x)
            train_means.append(round(np.mean(v)))
        else:
            train_means.append(np.nan)
    train_df[col] = train_means

    test_means = []
    for x in test_df[col]:
        if isinstance(x, str) and x.strip().startswith("["):
            v = ast.literal_eval(x)
            test_means.append(round(np.mean(v)))
        else:
            test_means.append(np.nan)
    test_df[col] = test_means

# 3. 类别列 one-hot
cat_cols = ["protocol", "ap_id", "sta_id"]
train_df = pd.get_dummies(train_df, columns=cat_cols, prefix=cat_cols)
test_df = pd.get_dummies(test_df, columns=cat_cols, prefix=cat_cols)
drop_cols = ['test_id', 'pkt_len', 'test_dur', 'ap_mac', 'sta_mac',
            'eirp', 'nss', 'mcs', 'per', 'ap_name',
            'sta_from_sta_0_rssi', 'sta_from_sta_1_rssi', 'bss_id', 'loc_id',
            'ppdu_dur', 'num_ampdu', 'other_air_time', 'throughput']
train_df = train_df.drop(columns=drop_cols)
test_df = test_df.drop(columns=drop_cols
                            + ['seq_time', 'predict seq_time',
                            'predict throughput', 'error%', 'error%.1'])
# print(train_df.columns)
# print(test_df.columns)

# 4. 绘制相关系数热力图
num_df = train_df.select_dtypes(include=[np.number])
num_df = num_df.loc[:, num_df.std() > 0]
corr = num_df.corr()

plt.figure(figsize=(8, 8))
sns.heatmap(corr, cmap='coolwarm', vmin=-1, vmax=1, center=0,
            annot=True, fmt='.2f', annot_kws={'size': 8},
            square=True, linewidths=0.5, linecolor='white',
            cbar_kws={'shrink': 0.7, 'label': 'Pearson Correlation (2AP)'})
plt.xticks(rotation=45, ha='right', fontsize=9)
plt.yticks(fontsize=9)
plt.tight_layout()
plt.show()

# 5. 构建随机森林
y = train_df["seq_time"]
X = train_df.drop(columns=["seq_time"])
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.05, random_state=42)
rf = RandomForestRegressor(n_estimators=200, random_state=42)
rf.fit(X_train, y_train)
y_pred = rf.predict(X_test)
mse = mean_squared_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)

print(f'Mean Squared Error: {mse}')
print(f'R² Score: {r2}')

# 6. 绘制特征重要性条形图
imp = pd.Series(rf.feature_importances_, index=X.columns).sort_values(ascending=False)

print("\n特征重要性：")
print(imp)

fig, ax = plt.subplots(figsize=(8, 5))
imp = pd.Series(rf.feature_importances_, index=X.columns).sort_values(ascending=True)
#imp_top = imp.tail(15)
imp_top = imp
colors = plt.cm.Blues(np.linspace(0.2, 0.9, len(imp_top)))
bars = ax.barh(imp_top.index, imp_top.values, color=colors, edgecolor='none', linewidth=0.6)
for bar in bars:
    width = bar.get_width()
    ax.text(width + max(imp_top.values) * 0.01,
            bar.get_y() + bar.get_height() / 2,
            f'{width:.4f}', va='center', ha='left', fontsize=9, color='black')
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_xlabel('Importance')
ax.set_ylabel('Feature')
ax.set_title('Feature Importance (2AP)')
plt.tight_layout()
plt.show()

# 7. 预测结果
X_test = test_df.reindex(columns=X.columns, fill_value=0)
pred_seq_time = rf.predict(X_test)
print(pred_seq_time)

# 8. 输出结果
df = pd.read_csv(test_path)
df['predict seq_time'] = pred_seq_time
df.to_csv(test_path, index=False)

