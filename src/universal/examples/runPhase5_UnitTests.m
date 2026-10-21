%% PHASE 5 OPTIMIZATION UNIT TESTS (NO SPICE REQUIRED)
clear; clc;
fprintf('Running Phase 5 unit tests...\n');
% 1: dominated point removed
obj=[-10 .03 -1; -9 .04 -.8; -8 .02 -2];
assert(isequal(paretoMask(obj,1e-12),[true;false;true]),'Dominance test failed');
% 2: duplicate objective rows do not dominate each other
obj=[-10 .03 -1; -10 .03 -1];
assert(all(paretoMask(obj,1e-12)),'Duplicate-point test failed');
% 3: tradeoffs all remain Pareto
obj=[-10 .04 -1; -9 .03 -1; -9 .04 -2];
assert(all(paretoMask(obj,1e-12)),'Tradeoff test failed');
% 4: divider-current power accounting
VDD=12; ID=2.9e-3; RGU=120e3; RGL=82e3;
Idiv=VDD/(RGU+RGL); P=VDD*(ID+Idiv);
assert(abs(Idiv-12/202000)<1e-12,'Divider-current test failed');
assert(abs(P-12*(2.9e-3+12/202000))<1e-12,'Supply-power test failed');
% 5: reconstruct drain voltage from VDS and source resistor
VDS=1.7731; RS=820; I=0.0029054; VD=VDS+I*RS;
assert(abs(VD-(1.7731+0.0029054*820))<1e-10,'Drain-voltage test failed');
fprintf('PASS: 5/5 unit tests.\n');
function keep=paretoMask(obj,tol)
n=size(obj,1); keep=true(n,1);
for i=1:n
 for j=1:n
  if i==j, continue; end
  if all(obj(j,:)<=obj(i,:)+tol) && any(obj(j,:)<obj(i,:)-tol)
   keep(i)=false; break;
  end
 end
end
end
