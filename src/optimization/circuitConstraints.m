function [c, ceq] = circuitConstraints(x)
% ============================================================
% ANALYTICAL SCREENING CONSTRAINTS FOR CE AMPLIFIER
%
% x =
% [R1 R2 RC RE RL Cin Cout Ce VCC]
%
% These constraints are ONLY preliminary screening constraints.
% SPICE is the final physical validity check.
% ============================================================


%% ------------------------------------------------------------
% Extract parameters
% ------------------------------------------------------------

R1  = x(1);
R2  = x(2);
RC  = x(3);
RE  = x(4);
RL  = x(5);
Cin = x(6);
Cout = x(7);
Ce  = x(8);
VCC = x(9);


%% ------------------------------------------------------------
% Approximate base voltage
% ------------------------------------------------------------

VB = VCC * R2 / (R1 + R2);


%% ------------------------------------------------------------
% Basic analytical constraints
%
% We only enforce conditions that are sufficiently robust
% without pretending that the simplified DC model is SPICE.
%
% VB > 0.55 V
% IC approximation > 0
%
% VCE / VCB are intentionally NOT hard constraints here.
% ------------------------------------------------------------

VBE = 0.70;

VE = VB - VBE;

IE = VE / RE;

IC = IE;


%% ------------------------------------------------------------
% fmincon inequality constraints
%
% c <= 0
% ------------------------------------------------------------

c = [

    VBE - VB;     % VB >= 0.70 V

    -IC           % IC >= 0

];


%% ------------------------------------------------------------
% No equality constraints
% ------------------------------------------------------------

ceq = [];


end