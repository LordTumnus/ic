classdef TestStaticContainer < ic.core.ComponentContainer
% TESTSTATICCONTAINER Test helper with pre-declared static children
%
%   Used by ContainerTest to verify static children behavior

    properties (SetAccess = immutable)
        Child1 ic.core.Component
        Child2 ic.core.Component
    end

    methods
        function this = TestStaticContainer(id)
            this@ic.core.ComponentContainer(id);
            this.Child1 = ic.core.Component(id + "-child1");
            this.Child2 = ic.core.Component(id + "-child2");
            this.addStaticChild(this.Child1);
            this.addStaticChild(this.Child2);
        end
    end
end
