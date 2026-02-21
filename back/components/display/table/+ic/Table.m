classdef Table < ic.TableBase
    % > TABLE Flat data table with rich column types.
    %
    %   Displays tabular data from a MATLAB table with sortable/filterable
    %   columns. Supports text, number, badge, sparkline, progress, boolean,
    %   button, link, icon, and avatar cell renderers.
    %
    %   Example:
    %       t = ic.Table();
    %       t.Data = table(["Alice";"Bob"], [30;25], ...
    %           'VariableNames', ["Name","Age"]);
    %       t.Columns = [
    %           ic.table.Column("Name", Sortable=true)
    %           ic.table.Column("Age", Type="number", Sortable=true)
    %       ];
    %       t.Striped = true;
    %       addlistener(t, 'RowClicked', @(~,e) disp(e.Data));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > DATA the table data (MATLAB table)
        Data table = table()
    end

    properties (Dependent)
        % > SELECTION selected rows as a subtable
        Selection
    end

    methods
        function this = Table(props)
            arguments
                props.?ic.Table
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TableBase(props);
        end

        function set.Data(this, val)
            % Clear selection when data changes
            this.setValueSilently('Value', []);
            % Auto-infer columns if empty
            if isempty(this.Columns) && ~isempty(val) && height(val) > 0
                this.setValueSilently('Columns', ic.table.Column.fromTable(val));
            end
            this.Data = val;
        end

        function tbl = get.Selection(this)
            idx = this.Value;
            if isempty(idx) || isempty(this.Data)
                tbl = this.Data([], :);
                return;
            end
            % Value is 0-based from Svelte, convert to 1-based
            matlabIdx = double(idx) + 1;
            valid = matlabIdx >= 1 & matlabIdx <= height(this.Data);
            tbl = this.Data(matlabIdx(valid), :);
        end
    end
end
