function testUniversalRepresentation()

    fprintf("\n========================================\n");
    fprintf(" UNIVERSAL CIRCUIT REPRESENTATION TEST\n");
    fprintf("========================================\n\n");


    %% CE amplifier

    ce = buildCEAmplifier();
    ceReport = validateCircuit(ce);

    fprintf("CE Amplifier     : %s\n", ...
        passFail(ceReport.Valid));


    %% RC low-pass

    rc = buildRCLowPass();
    rcReport = validateCircuit(rc);

    fprintf("RC Low-Pass      : %s\n", ...
        passFail(rcReport.Valid));


    %% MOSFET

    mos = buildCommonSource();
    mosReport = validateCircuit(mos);

    fprintf("Common Source    : %s\n", ...
        passFail(mosReport.Valid));


    %% Op-Amp

    opamp = buildOpAmp();
    opReport = validateCircuit(opamp);

    fprintf("Op-Amp           : %s\n", ...
        passFail(opReport.Valid));


    %% Overall

    allPassed = ...
        ceReport.Valid && ...
        rcReport.Valid && ...
        mosReport.Valid && ...
        opReport.Valid;


    fprintf("\n----------------------------------------\n");

    if allPassed
        fprintf("PHASE 1 UNIVERSAL REPRESENTATION: PASS\n");
    else
        fprintf("PHASE 1 UNIVERSAL REPRESENTATION: FAIL\n");
    end

    fprintf("----------------------------------------\n\n");

end


function result = passFail(value)

    if value
        result = "PASS";
    else
        result = "FAIL";
    end

end