classdef ClassNode < ic.node.Node
    % > CLASSNODE UML class diagram box with PropertyList, MethodList, and EventList sections.
    %   Each section is separated by horizontal lines. Every member gets an input
    %   and output port (with invisible handles). Header ports support class hierarchy
    %   linking: inherit (top input), sub-left / sub-right (header outputs).
    %
    %   n = ic.node.ClassNode(Label="Person", PropertyList=["name: string", "age: int"], MethodList=["getName()"])
    %   n = ic.node.ClassNode(Label="Vehicle", Position=[300 100])

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL class name displayed in the header
        Label (1,1) string = "ClassName"

        % > PROPERTYLIST class property definitions (e.g. ["name: string", "age: int"])
        PropertyList (1,:) string = string.empty

        % > METHODLIST class method signatures (e.g. ["getName()", "setName(value)"])
        MethodList (1,:) string = string.empty

        % > EVENTLIST class event names (e.g. ["onClick", "onHover"])
        EventList (1,:) string = string.empty

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = ClassNode(props)
            % > CLASSNODE Construct a UML class diagram node.
            arguments
                props.?ic.node.ClassNode
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
            addlistener(this, 'PropertyList', 'PostSet', @(~,~) this.syncMemberPorts());
            addlistener(this, 'MethodList', 'PostSet', @(~,~) this.syncMemberPorts());
            addlistener(this, 'EventList', 'PostSet', @(~,~) this.syncMemberPorts());
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            % Header ports for class hierarchy
            this.addPort(ic.node.Port("inherit"), "inputs");
            this.addPort(ic.node.Port("sub-left"), "outputs");
            this.addPort(ic.node.Port("sub-right"), "outputs");
            % Member ports from initial property values
            this.syncMemberPorts();
        end
    end

    methods (Access = private)
        function syncMemberPorts(this)
            % > SYNCMEMBERPORTS Add/remove per-member ports to match current arrays.
            headerInputs = "inherit";
            headerOutputs = ["sub-left", "sub-right"];

            % Build desired member port basenames
            desired = string.empty;
            for ii = 1:numel(this.PropertyList)
                desired(end+1) = "prop-" + ii; %#ok<AGROW>
            end
            for ii = 1:numel(this.MethodList)
                desired(end+1) = "meth-" + ii; %#ok<AGROW>
            end
            for ii = 1:numel(this.EventList)
                desired(end+1) = "evt-" + ii; %#ok<AGROW>
            end

            % Remove stale input ports
            inputs = this.Inputs;
            for jj = numel(inputs):-1:1
                p = inputs(jj);
                if ismember(p.Name, headerInputs), continue; end
                base = regexprep(p.Name, '-in$', '');
                if ~ismember(base, desired)
                    this.removePort(p);
                end
            end

            % Remove stale output ports
            outputs = this.Outputs;
            for jj = numel(outputs):-1:1
                p = outputs(jj);
                if ismember(p.Name, headerOutputs), continue; end
                base = regexprep(p.Name, '-out$', '');
                if ~ismember(base, desired)
                    this.removePort(p);
                end
            end

            % Add missing ports
            existIn = string.empty;
            if ~isempty(this.Inputs)
                existIn = arrayfun(@(p) p.Name, this.Inputs);
            end
            existOut = string.empty;
            if ~isempty(this.Outputs)
                existOut = arrayfun(@(p) p.Name, this.Outputs);
            end

            for ii = 1:numel(desired)
                d = desired(ii);
                inName = d + "-in";
                outName = d + "-out";
                if ~ismember(inName, existIn)
                    this.addPort(ic.node.Port(inName), "inputs");
                end
                if ~ismember(outName, existOut)
                    this.addPort(ic.node.Port(outName), "outputs");
                end
            end
        end
    end
end
