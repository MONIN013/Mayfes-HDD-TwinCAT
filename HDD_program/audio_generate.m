% test program for audioread and Mayfes HDD
clear all; close all; clc;
%%
readfile1 = "menuetto_1.wav";

audioinfo(readfile1)
[y1, f_test1] = audioread(readfile1); % y_test is normalized from -1.0 ~ 1.0
y_test1 = y1(:,1);
duration = length(y_test1)/f_test1; % duration of the audio file
T_test1= 1/f_test1; % time resolution 1/44.1k
T1 = [0:T_test1:T_test1*(length(y_test1)-1)]';
plot(T1,y_test1) % plot select monoral channel

for i=1:length(y_test1)
   if y_test1(i) >= 0.1
      y_test1(i) = 0.1;
   elseif y_test1(i) <= -0.1
      y_test1(i) = -0.1;
   end
end

plot(T1,y_test1)
%%
readfile2 = "mario.wav";

audioinfo(readfile2)
[y2, f_test2] = audioread(readfile2); % y_test is normalized from -1.0 ~ 1.0
y_test2 = y2(:,1);
duration = length(y_test2)/f_test2; % duration of the audio file
T_test2= 1/f_test2; % time resolution 1/44.1k
T2 = [0:T_test2:T_test2*(length(y_test2)-1)]';
plot(T2,y_test2) % plot select monoral channel

for i=1:length(y_test2)
   if y_test2(i) >= 0.1
      y_test2(i) = 0.1;
   elseif y_test2(i) <= -0.1
      y_test2(i) = -0.1;
   end
end

plot(T2,y_test2)
%%
%input_voltage_music = 10.0;
%co_vol_music = input_voltage_music/0.1; % Coefficient of voltage for EL4732
co_vol_music = 3*40000; % Coefficient of voltage for Copley

input_music1 = co_vol_music * y_test1;
input_music2 = co_vol_music * y_test2(1:end-f_test2*17);

%sound(y_test2(1:end-f_test2*17),f_test2) % check monoral sound
%% movig the arm 
T_end_move = 1;
T_square = [0:T_test1:T_end_move]';
% y_sin = 0;
input_square = 0.3*40000*square(2*pi*1*T_square);
plot(T_square,input_square)
%% generate motor input data using y_test
Ts = T_test1;
input = [input_square; input_music1;input_square; input_music2;];
% input = [input_music1;input_music2;];
%input=input_music;
% K = 2^(15)/10; % Coefficient ?}10V -> 16bit
% motor_input_val = K*input;

T_all = [0:T_test1:T_test1*(length(input)-1)]';


%motor_input.signals.values = motor_input_val; % motor input voltage
motor_input.signals.values = input; % motor input voltage for copley

motor_input.signals.dimension = 1;
motor_input.time = [];

plot(T_all,input) % plot select monoral channel
