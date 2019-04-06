function [sv, others] = sv_ecef(ephemeris, tr, ts0)
% 给定接收信号的时间和名义上信号发射的时间，计算在接收信号时刻地心固连坐标系下，卫星在发射信号时的坐标和信号路径长度
% 接收信号的时间需要是准确的GPS时间，需要将本地钟的钟差修正，剩余误差是本地钟的抖动
% 名义上信号发射的时间是接收到的C/A码理论上的发射时间，由于卫星钟的误差，需要补偿才能得到信号实际的发射时间，误差源是码环的跟踪误差
% 接收到的时间减信号实际的发射时间为信号的传播时间，用来对卫星位置进行坐标变换
% 传播时间并不等于路径长度，需要减去对流层、电离层、相对论效应的影响
% 因为校正电离层延迟需要位置信息，所以在外面校正，这里输出的路径长度包含电离层延迟误差，比真实值长
% 伪距等于接收信号时的本地钟时间减去信号名义上的发射时间乘以光速，伪距包含本地钟差和卫星钟差
% sv = [x,y,z, r, vx,vy,vz, 0]
% tr,ts0 = [s,ms,us]

% 卫星钟差正值--卫星钟快，信号发射早，实际发射时间提前，接收时间提前，伪距变小，伪距补偿是加
% 接收机钟差正值--接收机钟快，信号接收时间变长，伪距增大，伪距补偿是减
% 电离层和对流层是延迟影响，使信号传播时间变长，伪距增加，伪距补偿是减

sv = zeros(1,8);

w = 7.2921151467e-5;
F = -4.442807633e-10;
c = 299792458;

af0 = ephemeris(10);
af1 = ephemeris(9);
af2 = ephemeris(8);
toc = ephemeris(5);
sqa = ephemeris(17);
e = ephemeris(15);
tGD = ephemeris(7);

% 1.计算信号实际发射时间
dt = ts0(1) - toc + ts0(2)/1e3 + ts0(3)/1e6; %s
dtsv = af0 + af1*dt + af2*dt^2; %卫星钟差，s
ts = ts0(1) + ts0(2)/1e3 + ts0(3)/1e6 - dtsv; %信号实际发射时间，[s,ms,us]

% 2.计算卫星在信号发射时刻的位置
[sv0, E] = sv_ecef_ephemeris(ephemeris, ts);

% 3.考虑地球在信号传播时间内的自转，将卫星发射信号时刻的位置转到接收时刻的坐标系下
% 地球自转引起的卫星移动速度为：7.2921151467e-5 * 26560e3 = 1.94km/s
dt = tr - ts0; %[s,ms,us]
tt = dt(1) + dt(2)/1e3 + dt(3)/1e6 + dtsv; %信号传播时间
theta = w*tt; %传播时间内地球转过的角度
C = [ cos(theta), sin(theta), 0;
     -sin(theta), cos(theta), 0;
               0,          0, 1]; %坐标旋转阵
sv(1:3) = (C*sv0(1:3)')';

% 4.相对论效应校正
dtr = F*e*sqa*sin(E);
sv(4) = (tt + dtr - tGD)*c; %路径长度，此时还包含电离层延迟，路径长度比真实值大，需要在以后的处理中减去
% sv(4) = tt * c;

% 5.卫星速度
% 由于卫星速度在信号传播时间内变化不大，在哪个坐标系下表示都可以
sv(5:7) = (C*sv0(4:6)')';
% sv(5:7) = sv0(4:6);

% 6.其他输出
others = [dtr, tGD];

end