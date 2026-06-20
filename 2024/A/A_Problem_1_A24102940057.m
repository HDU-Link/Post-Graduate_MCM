%% 初始化并计时
clear;clc;tic;
%% 导入初始数据
filename = '附件1-疲劳评估数据.xls';
data1=table2array(readtable(filename, 'Sheet',2,'Range', 'B1:CW101'));      %主轴载荷数据
data2=table2array(readtable(filename, 'Sheet',3,'Range', 'B1:CW101'));      %塔架载荷数据
time1=size(data1,1); % 时间向量
%% 定义主轴扭矩存储库
initial_data1=cell(1,100);                                                  %定义主轴载荷数据极值存储库，100 台风机
realrainflow_data1=cell(1,100);                                             %定义实时雨流计算法预存库 1 号，100 台风机
realrainflow_data11=cell(1,100);                                            %定义实时雨流计算法预存库 11 号，100 台风机
marker1=cell(1,100);                                                        %载荷极小极大值编号（1 表示极大，2 表示极小），100 台风机
number1=cell(1,100);                                                        %极值存储库载荷数量计数，100 台风机
realrainflow_data1_number=cell(1,100);                                      %算法预存库载荷数量计数，100 台风机
u1=cell(1,100);v1=cell(1,100);w1=cell(1,100);                               %各风机实时雨流计数法三点数据库，100 台风机
cycle1number=cell(1,100);                                                   %载荷循环计数，100 台风机
cycle1=cell(1,100);                                                         %风机载荷循环全半计数，100 台风机
amplitude1=cell(1,100);                                                     %载荷循环幅值存储库，100 台风机
meanvalue1=cell(1,100);                                                     %载荷循环均值存储库，100 台风机
valueradius1=cell(1,100);                                                   %载荷循环起始时刻点存储库，100 台风机
eqamplitude1=cell(1,100);                                                   %修正的载荷循环幅值存储库，100 台风机
Ln1=cell(1,100);                                                            %等效疲劳载荷存储库，100 台风机
N1=cell(1,100);                                                             %最大载荷循环次数存储库，100 台风机
Df1=cell(1,100);                                                            %累积疲劳损伤存储库，100 台风机
judge1=cell(1,100);                                                         %判断器，判断载荷是否为极值，100 台风机
%% 定义塔架推力存储库
initial_data2=cell(1,100);                                                  %定义塔架载荷数据极值存储库，100 台风机
realrainflow_data2=cell(1,100);                                             %定义实时雨流计算法预存库 1 号，100 台风机
realrainflow_data22=cell(1,100);                                            %定义实时雨流计算法预存库 11 号，100 台风机
marker2=cell(1,100);                                                        %载荷极小极大值编号（1 表示极大，2 表示极小），100 台风机
number2=cell(1,100);                                                        %极值存储库载荷数量计数，100 台风机
realrainflow_data2_number=cell(1,100);                                      %算法预存库载荷数量计数，100 台风机
u2=cell(1,100);v2=cell(1,100);w2=cell(1,100);                               %各风机实时雨流计数法三点数据库，100 台风机
cycle2number=cell(1,100);                                                   %载荷循环计数，100 台风机
cycle2=cell(1,100);                                                         %风机载荷循环全半计数，100 台风机
amplitude2=cell(1,100);                                                     %载荷循环幅值存储库，100 台风机
meanvalue2=cell(1,100);                                                     %载荷循环均值存储库，100 台风机
valueradius2=cell(1,100);                                                   %载荷循环起始时刻点存储库，100 台风机
eqamplitude2=cell(1,100);                                                   %修正的载荷循环幅值存储库，100 台风机
Ln2=cell(1,100);                                                            %等效疲劳载荷存储库，100 台风机
N2=cell(1,100);                                                             %最大载荷循环次数存储库，100 台风机
Df2=cell(1,100);                                                            %累积疲劳损伤存储库，100 台风机
judge2=cell(1,100);                                                         %判断器，判断载荷是否为极值，100 台风机
%% 实时计算，从时刻 3 开始
for i=3:time1
%% 各风机计算当前主轴扭矩累计疲劳损伤
    for j=1:100
        if i==3
       %% 开始计算主轴扭矩累计疲劳损伤
        % 首先将各风机时刻 1，2 的载荷数据放入极值存储库，时刻 1 必为极值，时刻 2 需要后续判断
        % 主轴
            if data1(1,j)<=data1(2,j)
                marker1{j}(1)=2;
                marker1{j}(2)=1;
            else
                marker1{j}(1)=1;
                marker1{j}(2)=2;
            end
            initial_data1{j}(marker1{j}(1),1)=data1(1,j);
            initial_data1{j}(3,1)=1;
            initial_data1{j}(marker1{j}(2),2)=data1(2,j);
            initial_data1{j}(3,2)=2;
            % 将各风机极值存储库时刻 1,2 的载荷数据导入算法预存库
            realrainflow_data1{j}(1,1)=initial_data1{j}(marker1{j}(1),1); %时刻 1 的载荷数据值导入算法预存库
            realrainflow_data1{j}(2,1)=initial_data1{j}(3,1); %时刻 1 的载荷数据位置导入算法预存库
            realrainflow_data1{j}(1,2)=initial_data1{j}(marker1{j}(2),2); %时刻 2 的载荷数据值导入算法预存库
            realrainflow_data1{j}(2,2)=initial_data1{j}(3,2); %时刻 2 的载荷数据位置导入算法预存库
            realrainflow_data1_number{j}(1)=size(realrainflow_data1{j}(1,1:end),2); %各风机算法预存库载荷数量
            judge1{j}=0; %判断各风机极值存储库最新载荷是否替换过的标记
            number1{j}=2; %各风机极值存储库计数，从 2 开始
            cycle1number{j}(1)=0; %各风机实际载荷循环计数,从 0 开始
            cycle1number{j}(2)=0; %各风机暂时载荷循环计数,从 0 开始
        end
        % 判断各风机极值存储库前一时刻载荷是否为极值
        if (initial_data1{j}(marker1{j}(number1{j}),number1{j})-initial_data1{j}(marker1{j}(number1{j}-1),number1{j}-1))*...
            (initial_data1{j}(marker1{j}(number1{j}),number1{j})-data1(i,j))<0
            % 前一时刻载荷不为极值，当前时刻载荷替换各风机极值存储库的最新载荷
            judge1{j}=1;
            initial_data1{j}(marker1{j}(number1{j}),number1{j})=data1(i,j); %当前时刻载荷替换各风机极值存储库的最新载荷
            initial_data1{j}(3,number1{j})=i; %替换后的当前时刻载荷的时刻点
        else
            % 前一时刻载荷为极值，当前时刻载荷的时刻点导入各风机极值存储库
            marker1{j}(number1{j}+1)=(-1)^(marker1{j}(number1{j})-1)+marker1{j}(number1{j});
            initial_data1{j}(marker1{j}(number1{j}+1),number1{j}+1)=data1(i,j); %当前时刻载荷的时刻点导入各风机极值存储库
            initial_data1{j}(3,number1{j}+1)=i; %当前时刻载荷的时刻点
            number1{j}=number1{j}+1; %各风机极值存储库计数
        end
        % 各风机极值存储库最新载荷是否替换过
        if judge1{j}==0
        %未替换过，各风机极值存储库的最新载荷导入各风机算法预存库
            realrainflow_data1{j}(1,end+1)=initial_data1{j}(marker1{j}(number1{j}),number1{j}); %各风机极值存储库最新载荷导入各风机算法预存库
            realrainflow_data1{j}(2,end)=initial_data1{j}(3,number1{j}); %各风机算法预存库里最新载荷为哪一时刻的载荷
            realrainflow_data1_number{j}(1)=size(realrainflow_data1{j}(1,1:end),2); %各风机算法预存库载荷数量
        else
            %替换过，各风机极值存储库的最新载荷替换各风机算法预存库的最新载荷
            judge1{j}=0; %重置判断标记
            realrainflow_data1{j}(1,end)=initial_data1{j}(marker1{j}(number1{j}),number1{j});
            %各风机极值存储库的最新载荷替换各风机算法预存库的最新载荷
            realrainflow_data1{j}(2,end)=initial_data1{j}(3,number1{j}); %各风机算法预存库里最新载荷为哪一时刻的载荷
        end
        % 判断各风机算法预存库里载荷数量是否大于等于 3 个
        while realrainflow_data1_number{j}(1)>=3
            % 各风机算法预存库最新 3 个载荷作为实时雨流计数法三点数据
            u1{j}=realrainflow_data1{j}(1,end-2); 
            v1{j}=realrainflow_data1{j}(1,end-1);
            w1{j}=realrainflow_data1{j}(1,end);
            % 比较相邻两个点范围大小
            if abs(v1{j}-u1{j})<abs(v1{j}-w1{j})
                cycle1number{j}(1)=cycle1number{j}(1)+1; %各风机实际载荷循环计数
                % 各风机算法预存库载荷数量是否等于 3，进行全循环半循环判断
                if realrainflow_data1_number{j}(1)==3
                    cycle1{j}(cycle1number{j}(1),1)=0.5;
                    amplitude1{j}(cycle1number{j}(1),1)=abs(v1{j}-u1{j}); %各风机实际载荷循环幅值
                    meanvalue1{j}(cycle1number{j}(1),1)=(u1{j}+v1{j})/2; %各风机实际载荷循环均值
                    valueradius1{j}(cycle1number{j}(1),1)=realrainflow_data1{j}(2,end-2); %各风机实际载荷循环起点时刻
                    valueradius1{j}(cycle1number{j}(1),2)=realrainflow_data1{j}(2,end-1); %各风机实际载荷循环终点时刻
                    realrainflow_data1{j}(:,end-2)=[];
                    realrainflow_data1_number{j}(1)=size(realrainflow_data1{j}(1,1:end),2); %算法预存库里载荷数量
                else
                    cycle1{j}(cycle1number{j}(1),1)=1;
                    amplitude1{j}(cycle1number{j}(1),1)=abs(v1{j}-u1{j}); %各风机实际载荷循环幅值
                    meanvalue1{j}(cycle1number{j}(1),1)=(u1{j}+v1{j})/2; %各风机实际载荷循环均值
                    
                    valueradius1{j}(cycle1number{j}(1),1)=realrainflow_data1{j}(2,end-2); %各风机实际载荷循环起点时刻
                    valueradius1{j}(cycle1number{j}(1),2)=realrainflow_data1{j}(2,end-1); %各风机实际载荷循环终点时刻
                    realrainflow_data1{j}(:,end-2)=[];
                    realrainflow_data1{j}(:,end-1)=[];
                    
                    realrainflow_data1_number{j}(1)=size(realrainflow_data1{j}(1,1:end),2); %算法预存库里载荷数量
                end
            else
                break;
            end
        end
        % 各风机实际载荷循环计算实际累积疲劳损伤
        if cycle1number{j}(1)>=1
            eqamplitude1{j}(1:cycle1number{j}(1),1)=amplitude1{j}(1:cycle1number{j}(1),1)./(1-meanvalue1{j}(1:cycle1number{j},1)./50000000); %修正载荷循环，修正为均值为 0 的载荷循环幅值
            Ln1{j}(i,1)=sum((eqamplitude1{j}(1:cycle1number{j}(1),1).^10).*cycle1{j}(1:cycle1number{j}(1),1),1)./42565440.4361;
            N1{j}(1:cycle1number{j}(1),1)=9.77*10^70./(eqamplitude1{j}(1:cycle1number{j}(1),1).^10); %S-N 曲线判断同一载荷循环幅值的最大循环载荷次数
            Df1{j}(i,1)=sum((cycle1{j}(1:cycle1number{j}(1),1)./N1{j}(1:cycle1number{j}(1),1)).^(1-(exp(-valueradius1{j}(1:cycle1number{j}(1),1)./5))./40),1); %线性累积损伤理论计算实际累积疲劳损伤值
        end
 
        % 计算最后实际以及暂时载荷循环
        realrainflow_data11{j}=realrainflow_data1{j};
        realrainflow_data1_number{j}(2)=size(realrainflow_data11{j}(1,1:end),2);
        if i==time1
            while realrainflow_data1_number{j}(2)>=2
                cycle1number{j}(2)=cycle1number{j}(2)+1; %载荷循环计数
                cycle1{j}(cycle1number{j}(2),2)=0.5;
                amplitude1{j}(cycle1number{j}(2),2)=abs(realrainflow_data11{j}(1,1)-realrainflow_data11{j}(1,2));
                meanvalue1{j}(cycle1number{j}(2),2)=(realrainflow_data11{j}(1,1)+realrainflow_data11{j}(1,2))/2;
                valueradius1{j}(cycle1number{j}(2),3)=realrainflow_data11{j}(2,1);
                valueradius1{j}(cycle1number{j}(2),4)=realrainflow_data11{j}(2,2);
                realrainflow_data11{j}(:,1)=[];
                realrainflow_data1_number{j}(2)=size(realrainflow_data11{j}(1,1:end),2); 
            end
            % 各风机实际载荷循环计算实际累积疲劳损伤
            if cycle1number{j}(2)>=1
                eqamplitude1{j}(1:cycle1number{j}(2),2)=amplitude1{j}(1:cycle1number{j}(2),2)./(1-meanvalue1{j}(1:cycle1number{j}(2),2)./50000000); %修正载荷循环，修正为均值为 0 的载荷循环幅值
                Ln1{j}(i,2)=sum((eqamplitude1{j}(1:cycle1number{j}(2),2).^10).*cycle1{j}(1:cycle1number{j}(2),2),1)./42565440.4361;
                N1{j}(1:cycle1number{j}(2),2)=9.77*10^70./(eqamplitude1{j}(1:cycle1number{j}(2),2).^10); %S-N 曲线判断同一载荷循环幅值的最大循环载荷次数
                Df1{j}(i,2)=sum((cycle1{j}(1:cycle1number{j}(2),2)./N1{j}(1:cycle1number{j}(2),2)).^(1-(exp(-valueradius1{j}(1:cycle1number{j}(2),3)./5))./40),1); %非线性累积损伤理论计算暂时累积疲劳损伤值
            end
        else
            while realrainflow_data1_number{j}(2)>=2
                cycle1number{j}(2)=cycle1number{j}(2)+1; %载荷循环计数
                cycle1{j}(cycle1number{j}(2),2)=0.5;
                amplitude1{j}(cycle1number{j}(2),2)=abs(realrainflow_data11{j}(1,1)-realrainflow_data11{j}(1,2));
                meanvalue1{j}(cycle1number{j}(2),2)=(realrainflow_data11{j}(1,1)+realrainflow_data11{j}(1,2))/2;
                valueradius1{j}(cycle1number{j}(2),3)=realrainflow_data11{j}(2,1);
                valueradius1{j}(cycle1number{j}(2),4)=realrainflow_data11{j}(2,2);
                realrainflow_data11{j}(:,1)=[];
                realrainflow_data1_number{j}(2)=size(realrainflow_data11{j}(1,1:end),2); 
            end
            % 各风机暂时载荷循环计算暂时累积疲劳损伤
            if cycle1number{j}(2)>=1
                eqamplitude1{j}(1:cycle1number{j}(2),2)=amplitude1{j}(1:cycle1number{j}(2),2)./(1-meanvalue1{j}(1:cycle1number{j}(2),2)./50000000); %修正载荷循环，修正为均值为 0 的载荷循环幅值
                Ln1{j}(i,2)=sum((eqamplitude1{j}(1:cycle1number{j}(2),2).^10).*cycle1{j}(1:cycle1number{j}(2),2),1)./42565440.4361;
                N1{j}(1:cycle1number{j}(2),2)=9.77*10^70./(eqamplitude1{j}(1:cycle1number{j}(2),2).^10); %S-N 曲线判断同一载荷循环幅值的最大循环载荷次数
                Df1{j}(i,2)=sum((cycle1{j}(2:cycle1number{j}(2),2)./N1{j}(2:cycle1number{j}(2),2)),1)+(cycle1{j}(1,2)./N1{j}(1,2)).^(1-(exp(-valueradius1{j}(1,3)./5))./40); %非线性累积损伤理论计算暂时累积疲劳损伤值
            end
            realrainflow_data11{j}=[];
            amplitude1{j}(1:cycle1number{j}(2),2)=0;
            meanvalue1{j}(1:cycle1number{j}(2),2)=0;
            valueradius1{j}(1:cycle1number{j}(2),3)=0;
            valueradius1{j}(1:cycle1number{j}(2),4)=0;
            cycle1number{j}(2)=0;
        end
        % 计算总累积疲劳损伤
        if cycle1number{j}(1)>=1
            Lnall1(i,j)=(Ln1{j}(i,1)+Ln1{j}(i,2))^(1/10);
            Dfall1(i,j)=Df1{j}(i,1)+Df1{j}(i,2);
        else
            Lnall1(i,j)=(Ln1{j}(i,2))^(1/10);
            Dfall1(i,j)=Df1{j}(i,2);
        end
    end
    %% 各风机计算当前塔架推力累计疲劳损伤
    for j=1:100
        if i==3
        %% 开始计算塔架推力累计疲劳损伤
        % 首先将各风机时刻 1，2 的载荷数据放入极值存储库，时刻 1 必为极值，时刻 2 需要后续判断
        % 塔架
            if data2(1,j)<=data2(2,j)
                marker2{j}(1)=2;
                marker2{j}(2)=1;
            else
                marker2{j}(1)=1;
                marker2{j}(2)=2;
            end
            initial_data2{j}(marker2{j}(1),1)=data2(1,j);
            initial_data2{j}(3,1)=1;
            initial_data2{j}(marker2{j}(2),2)=data2(2,j);
            initial_data2{j}(3,2)=2;
            % 将各风机极值存储库时刻 1,2 的载荷数据导入算法预存库
            realrainflow_data2{j}(1,1)=initial_data2{j}(marker2{j}(1),1); %时刻 1 的载荷数据值导入算法预存库
            realrainflow_data2{j}(2,1)=initial_data2{j}(3,1); %时刻 1 的载荷数据位置导入算法预存库
            realrainflow_data2{j}(1,2)=initial_data2{j}(marker2{j}(2),2); %时刻 2 的载荷数据值导入算法预存库
            realrainflow_data2{j}(2,2)=initial_data2{j}(3,2); %时刻 2 的载荷数据位置导入算法预存库
            realrainflow_data2_number{j}(1)=size(realrainflow_data2{j}(1,1:end),2); %各风机算法预存库载荷数量
            judge2{j}=0; %判断各风机极值存储库最新载荷是否替换过的标记
            number2{j}=2; %各风机极值存储库计数，从 2 开始
            cycle2number{j}(1)=0; %各风机实际载荷循环计数,从 0 开始
            cycle2number{j}(2)=0; %各风机暂时载荷循环计数,从 0 开始
        end
        % 判断各风机极值存储库前一时刻载荷是否为极值
        if (initial_data2{j}(marker2{j}(number2{j}),number2{j})-initial_data2{j}(marker2{j}(number2{j}-1),number2{j}-1))*...
            (initial_data2{j}(marker2{j}(number2{j}),number2{j})-data2(i,j))<0
            % 前一时刻载荷不为极值，当前时刻载荷替换各风机极值存储库的最新载荷
            judge2{j}=1;
            initial_data2{j}(marker2{j}(number2{j}),number2{j})=data2(i,j); %当前时刻载荷替换各风机极值存储库的最新载荷
            initial_data2{j}(3,number2{j})=i; %替换后的当前时刻载荷的时刻点
        else
            % 前一时刻载荷为极值，当前时刻载荷的时刻点导入各风机极值存储库
            marker2{j}(number2{j}+1)=(-1)^(marker2{j}(number2{j})-1)+marker2{j}(number2{j});
            initial_data2{j}(marker2{j}(number2{j}+1),number2{j}+1)=data2(i,j); %当前时刻载荷的时刻点导入各风机极值存储库
            initial_data2{j}(3,number2{j}+1)=i; %当前时刻载荷的时刻点
            number2{j}=number2{j}+1; %各风机极值存储库计数
        end
        % 各风机极值存储库最新载荷是否替换过
        if judge2{j}==0
            %未替换过，各风机极值存储库的最新载荷导入各风机算法预存库
            realrainflow_data2{j}(1,end+1)=initial_data2{j}(marker2{j}(number2{j}),number2{j}); %各风机极值存储库最新载荷导入各风机算法预存库
            realrainflow_data2{j}(2,end)=initial_data2{j}(3,number2{j}); %各风机算法预存库里最新载荷为哪一时刻的载荷
            realrainflow_data2_number{j}(1)=size(realrainflow_data2{j}(1,1:end),2); %各风机算法预存库载荷数量
        else
            %替换过，各风机极值存储库的最新载荷替换各风机算法预存库的最新载荷
            judge2{j}=0; %重置判断标记
            realrainflow_data2{j}(1,end)=initial_data2{j}(marker2{j}(number2{j}),number2{j}); %各风机极值存储库的最新载荷替换各风机算法预存库的最新载荷
            realrainflow_data2{j}(2,end)=initial_data2{j}(3,number2{j}); %各风机算法预存库里最新载荷为哪一时刻的载荷
        end
        % 判断各风机算法预存库里载荷数量是否大于等于 3 个
        while realrainflow_data2_number{j}(1)>=3
            % 各风机算法预存库最新 3 个载荷作为实时雨流计数法三点数据
            u2{j}=realrainflow_data2{j}(1,end-2); 
            v2{j}=realrainflow_data2{j}(1,end-1);
            w2{j}=realrainflow_data2{j}(1,end);
            % 比较相邻两个点范围大小
            if abs(v2{j}-u2{j})<abs(v2{j}-w2{j})
                cycle2number{j}(1)=cycle2number{j}(1)+1; %各风机实际载荷循环计数
                % 各风机算法预存库载荷数量是否等于 3，进行全循环半循环判断
                if realrainflow_data2_number{j}(1)==3
                    cycle2{j}(cycle2number{j}(1),1)=0.5;
                    amplitude2{j}(cycle2number{j}(1),1)=abs(v2{j}-u2{j}); %各风机实际载荷循环幅值
                    meanvalue2{j}(cycle2number{j}(1),1)=(u2{j}+v2{j})/2; %各风机实际载荷循环均值
                    valueradius2{j}(cycle2number{j}(1),1)=realrainflow_data2{j}(2,end-2); %各风机实际载荷循环起点时刻
                    valueradius2{j}(cycle2number{j}(1),2)=realrainflow_data2{j}(2,end-1); %各风机实际载荷循环终点时刻
                    realrainflow_data2{j}(:,end-2)=[];
                    realrainflow_data2_number{j}(1)=size(realrainflow_data2{j}(1,1:end),2); %算法预存库里载荷数量
                else
                    cycle2{j}(cycle2number{j}(1),1)=1;
                    amplitude2{j}(cycle2number{j}(1),1)=abs(v2{j}-u2{j}); %各风机实际载荷循环幅值
                    meanvalue2{j}(cycle2number{j}(1),1)=(u2{j}+v2{j})/2; %各风机实际载荷循环均值
                    valueradius2{j}(cycle2number{j}(1),1)=realrainflow_data2{j}(2,end-2); %各风机实际载荷循环起点时刻
                    valueradius2{j}(cycle2number{j}(1),2)=realrainflow_data2{j}(2,end-1); %各风机实际载荷循环终点时刻
                    realrainflow_data2{j}(:,end-2)=[];
                    realrainflow_data2{j}(:,end-1)=[];
                    realrainflow_data2_number{j}(1)=size(realrainflow_data2{j}(1,1:end),2); %算法预存库里载荷数量
                end
            else
                break;
            end
        end
        % 各风机实际载荷循环计算实际累积疲劳损伤
        if cycle2number{j}(1)>=1
            eqamplitude2{j}(1:cycle2number{j}(1),1)=amplitude2{j}(1:cycle2number{j}(1),1)./(1-meanvalue2{j}(1:cycle2number{j},1)./50000000); %修正载荷循环，修正为均值为 0 的载荷循环幅值
            Ln2{j}(i,1)=sum((eqamplitude2{j}(1:cycle2number{j}(1),1).^10).*cycle2{j}(1:cycle2number{j}(1),1),1)./42565440.4361;
            N2{j}(1:cycle2number{j}(1),1)=9.77*10^70./(eqamplitude2{j}(1:cycle2number{j}(1),1).^10); %S-N 曲线判断同一载荷循环幅值的最大循环载荷次数
            Df2{j}(i,1)=sum((cycle2{j}(1:cycle2number{j}(1),1)./N2{j}(1:cycle2number{j}(1),1)).^(1-(exp(-valueradius2{j}(1:cycle2number{j}(1),1)./5))./40),1); %非线性累积损伤理论计算实际累积疲劳损伤值
        end
    
        % 计算最后实际以及暂时载荷循环
        realrainflow_data22{j}=realrainflow_data2{j};
        realrainflow_data2_number{j}(2)=size(realrainflow_data22{j}(1,1:end),2);
        if i==time1
            while realrainflow_data2_number{j}(2)>=2
                cycle2number{j}(2)=cycle2number{j}(2)+1; %载荷循环计数
                cycle2{j}(cycle2number{j}(2),2)=0.5;
                amplitude2{j}(cycle2number{j}(2),2)=abs(realrainflow_data22{j}(1,1)-realrainflow_data22{j}(1,2));
                meanvalue2{j}(cycle2number{j}(2),2)=(realrainflow_data22{j}(1,1)+realrainflow_data22{j}(1,2))/2;
                valueradius2{j}(cycle2number{j}(2),3)=realrainflow_data22{j}(2,1);
                valueradius2{j}(cycle2number{j}(2),4)=realrainflow_data22{j}(2,2);
                realrainflow_data22{j}(:,1)=[];
                realrainflow_data2_number{j}(2)=size(realrainflow_data22{j}(1,1:end),2); 
            end
            % 各风机暂时载荷循环计算暂时累积疲劳损伤
            if cycle2number{j}(2)>=1
                eqamplitude2{j}(1:cycle2number{j}(2),2)=amplitude2{j}(1:cycle2number{j}(2),2)./(1-meanvalue2{j}(1:cycle2number{j}(2),2)./50000000); %修正载荷循环，修正为均值为 0 的载荷循环幅值
                Ln2{j}(i,2)=sum((eqamplitude2{j}(1:cycle2number{j}(2),2).^10).*cycle2{j}(1:cycle2number{j}(2),2),1)./42565440.4361;
                N2{j}(1:cycle2number{j}(2),2)=9.77*10^70./(eqamplitude2{j}(1:cycle2number{j}(2),2).^10); %S-N 曲线判断同一载荷循环幅值的最大循环载荷次数
                Df2{j}(i,2)=sum((cycle2{j}(1:cycle2number{j}(2),2)./N2{j}(1:cycle2number{j}(2),2)).^(1-(exp(-valueradius2{j}(1:cycle2number{j}(2),3)./5))./40),1); %非线性累积损伤理论计算暂时累积疲劳损伤值
            end
        else 
            while realrainflow_data2_number{j}(2)>=2
                cycle2number{j}(2)=cycle2number{j}(2)+1; %载荷循环计数
                cycle2{j}(cycle2number{j}(2),2)=0.5;
                amplitude2{j}(cycle2number{j}(2),2)=abs(realrainflow_data22{j}(1,1)-realrainflow_data22{j}(1,2));
                meanvalue2{j}(cycle2number{j}(2),2)=(realrainflow_data22{j}(1,1)+realrainflow_data22{j}(1,2))/2;
                valueradius2{j}(cycle2number{j}(2),3)=realrainflow_data22{j}(2,1);
                valueradius2{j}(cycle2number{j}(2),4)=realrainflow_data22{j}(2,2);
                realrainflow_data22{j}(:,1)=[];
                realrainflow_data2_number{j}(2)=size(realrainflow_data22{j}(1,1:end),2); 
            end
            % 各风机暂时载荷循环计算暂时累积疲劳损伤
            if cycle2number{j}(2)>=1
                eqamplitude2{j}(1:cycle2number{j}(2),2)=amplitude2{j}(1:cycle2number{j}(2),2)./(1-meanvalue2{j}(1:cycle2number{j}(2),2)./50000000); %修正载荷循环，修正为均值为 0 的载荷循环幅值
                Ln2{j}(i,2)=sum((eqamplitude2{j}(1:cycle2number{j}(2),2).^10).*cycle2{j}(1:cycle2number{j}(2),2),1)./42565440.4361;
                N2{j}(1:cycle2number{j}(2),2)=9.77*10^70./(eqamplitude2{j}(1:cycle2number{j}(2),2).^10); %S-N 曲线判断同一载荷循环幅值的最大循环载荷次数
                Df2{j}(i,2)=sum((cycle2{j}(2:cycle2number{j}(2),2)./N2{j}(2:cycle2number{j}(2),2)),1)+(cycle2{j}(1,2)./N2{j}(1,2)).^(1-(exp(-valueradius2{j}(1,3)./5))./40); %非线性累积损伤理论计算暂时累积疲劳损伤值
            end
            realrainflow_data22{j}=[];
            amplitude2{j}(1:cycle2number{j}(2),2)=0;
            meanvalue2{j}(1:cycle2number{j}(2),2)=0;
            valueradius2{j}(1:cycle2number{j}(2),3)=0;
            valueradius2{j}(1:cycle2number{j}(2),4)=0;
            cycle2number{j}(2)=0;
        end
        % 计算总累积疲劳损伤
        if cycle2number{j}(1)>=1
            Lnall2(i,j)=(Ln2{j}(i,1)+Ln2{j}(i,2))^(1/10);
            Dfall2(i,j)=Df2{j}(i,1)+Df2{j}(i,2);
        else
            Lnall2(i,j)=(Ln2{j}(i,2))^(1/10);
            Dfall2(i,j)=Df2{j}(i,2);
        end
    end
end
toc;