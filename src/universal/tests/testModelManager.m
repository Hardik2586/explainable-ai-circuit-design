function testModelManager()

    fprintf("\n");
    fprintf("============================================\n");
    fprintf(" UNIVERSAL MODEL MANAGER TEST\n");
    fprintf("============================================\n\n");


    mm = ModelManager();


    %% Register BJT

    mm = mm.registerInlineModel( ...
        "2N3904", ...
        "BJT", ...
        ".model 2N3904 NPN(Is=1e-14 Bf=200 Vaf=100)");

    assert(mm.hasModel("2N3904"));

    fprintf("BJT registration   : PASS\n");


    %% Register MOSFET

    mm = mm.registerInlineModel( ...
        "2N7000", ...
        "MOSFET", ...
        ".model 2N7000 NMOS(Level=1 VTO=2 KP=0.01)");

    assert(mm.hasModel("2N7000"));

    fprintf("MOSFET registration: PASS\n");


    %% Retrieve model

    model = mm.getModel("2N3904");

    assert(model.Name == "2N3904");
    assert(model.Type == "BJT");
    assert(model.Source == "inline");

    fprintf("Model retrieval     : PASS\n");


    %% Unknown model

    caught = false;

    try
        mm.getModel("DOES_NOT_EXIST");
    catch
        caught = true;
    end

    assert(caught);

    fprintf("Unknown model check : PASS\n");


    %% Final

    fprintf("\n--------------------------------------------\n");
    fprintf("PHASE 2C MODEL MANAGER: PASS\n");
    fprintf("--------------------------------------------\n\n");

end