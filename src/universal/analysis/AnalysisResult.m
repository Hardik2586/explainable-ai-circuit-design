classdef AnalysisResult
    
    properties
        Success logical = false
        
        CircuitName string = ""
        Topology string = ""
        AnalysisType string = ""
        
        Measurements struct = struct()
        
        Warnings string = strings(0,1)
        Errors string = strings(0,1)
        
        Metadata struct = struct()
    end
    
    methods
        
        function obj = AnalysisResult(varargin)
            % Constructor with optional name-value arguments.
            
            if nargin == 0
                return;
            end
            
            if mod(nargin,2) ~= 0
                error("AnalysisResult:InvalidArguments", ...
                    "Arguments must be supplied as name-value pairs.");
            end
            
            for k = 1:2:nargin
                
                name = string(varargin{k});
                value = varargin{k+1};
                
                if isprop(obj,name)
                    obj.(name) = value;
                else
                    error("AnalysisResult:UnknownProperty", ...
                        "Unknown property '%s'.",name);
                end
            end
        end
        
        
        function obj = setMeasurement(obj,name,value)
            %SETMEASUREMENT Add or replace a measurement.
            
            name = char(name);
            
            if isempty(strtrim(name))
                error("AnalysisResult:InvalidMeasurementName", ...
                    "Measurement name cannot be empty.");
            end
            
            obj.Measurements.(name) = value;
        end
        
        
        function value = getMeasurement(obj,name,defaultValue)
            %GETMEASUREMENT Retrieve a measurement safely.
            
            name = char(name);
            
            if isfield(obj.Measurements,name)
                value = obj.Measurements.(name);
                
            elseif nargin >= 3
                value = defaultValue;
                
            else
                value = [];
            end
        end
        
        
        function tf = hasMeasurement(obj,name)
            %HASMEASUREMENT Check whether a measurement exists.
            
            tf = isfield(obj.Measurements,char(name));
        end
        
        
        function obj = addWarning(obj,message)
            %ADDWARNING Add an analysis warning.
            
            obj.Warnings(end+1,1) = string(message);
        end
        
        
        function obj = addError(obj,message)
            %ADDERROR Add an analysis error.
            
            obj.Errors(end+1,1) = string(message);
            obj.Success = false;
        end
        
        
        function displaySummary(obj)
            %DISPLAYSUMMARY Display a compact analysis summary.
            
            fprintf("\n");
            fprintf("========================================\n");
            fprintf("        UNIVERSAL ANALYSIS RESULT\n");
            fprintf("========================================\n");
            
            fprintf("Success    : %d\n",obj.Success);
            fprintf("Circuit    : %s\n",obj.CircuitName);
            fprintf("Topology   : %s\n",obj.Topology);
            fprintf("Analysis   : %s\n",obj.AnalysisType);
            
            names = fieldnames(obj.Measurements);
            
            if ~isempty(names)
                
                fprintf("\nMeasurements:\n");
                
                for k = 1:numel(names)
                    
                    value = obj.Measurements.(names{k});
                    
                    if isnumeric(value) && isscalar(value)
                        
                        fprintf("  %-22s : %.6g\n", ...
                            names{k},value);
                        
                    elseif isstring(value) && isscalar(value)
                        
                        fprintf("  %-22s : %s\n", ...
                            names{k},value);
                        
                    elseif ischar(value) && isscalar(value)
                        
                        fprintf("  %-22s : %s\n", ...
                            names{k},value);
                        
                    else
                        
                        fprintf("  %-22s : [%s]\n", ...
                            names{k},class(value));
                    end
                end
            end
            
            if ~isempty(obj.Warnings)
                
                fprintf("\nWarnings:\n");
                
                for k = 1:numel(obj.Warnings)
                    fprintf("  - %s\n",obj.Warnings(k));
                end
            end
            
            if ~isempty(obj.Errors)
                
                fprintf("\nErrors:\n");
                
                for k = 1:numel(obj.Errors)
                    fprintf("  - %s\n",obj.Errors(k));
                end
            end
            
            fprintf("========================================\n");
        end
    end
end