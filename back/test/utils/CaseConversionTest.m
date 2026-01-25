classdef CaseConversionTest < matlab.unittest.TestCase
% CASECONVERSIONTEST Tests the case conversion utility functions
%
%   Tests cover:
%     - toSnakeCase: various input formats to snake_case
%     - toCamelCase: various input formats to camelCase
%     - toPascalCase: various input formats to PascalCase
%     - Event-style strings with @ and / prefixes

    methods (Test)
        function testSnakeCaseFromCamelCase(testCase)
            testCase.verifyEqual(ic.utils.toSnakeCase("myVariable"), "my_variable");
            testCase.verifyEqual(ic.utils.toSnakeCase("someTestValue"), "some_test_value");
        end

        function testSnakeCaseFromPascalCase(testCase)
            testCase.verifyEqual(ic.utils.toSnakeCase("MyVariable"), "my_variable");
            testCase.verifyEqual(ic.utils.toSnakeCase("SomeTestValue"), "some_test_value");
        end

        function testSnakeCaseWithEventPrefix(testCase)
            % Event-style strings used in MATLAB-Svelte communication
            testCase.verifyEqual(ic.utils.toSnakeCase("@prop/MyValue"), "@prop/my_value");
            testCase.verifyEqual(ic.utils.toSnakeCase("@event/OnClick"), "@event/on_click");
        end

        function testSnakeCasePreservesSnakeCase(testCase)
            testCase.verifyEqual(ic.utils.toSnakeCase("already_snake"), "already_snake");
        end

        function testSnakeCaseEmpty(testCase)
            testCase.verifyEqual(ic.utils.toSnakeCase(""), "");
        end

        function testCamelCaseFromSnakeCase(testCase)
            testCase.verifyEqual(ic.utils.toCamelCase("my_variable"), "myVariable");
            testCase.verifyEqual(ic.utils.toCamelCase("some_test_value"), "someTestValue");
        end

        function testCamelCaseFromPascalCase(testCase)
            testCase.verifyEqual(ic.utils.toCamelCase("MyVariable"), "myVariable");
            testCase.verifyEqual(ic.utils.toCamelCase("SomeTestValue"), "someTestValue");
        end

        function testCamelCaseWithEventPrefix(testCase)
            % Event-style strings used in MATLAB-Svelte communication
            testCase.verifyEqual(ic.utils.toCamelCase("@prop/my_value"), "@prop/myValue");
            testCase.verifyEqual(ic.utils.toCamelCase("@prop/MyValue"), "@prop/myValue");
            testCase.verifyEqual(ic.utils.toCamelCase("@event/on_click"), "@event/onClick");
        end

        function testCamelCasePreservesCamelCase(testCase)
            testCase.verifyEqual(ic.utils.toCamelCase("alreadyCamel"), "alreadyCamel");
        end

        function testCamelCaseEmpty(testCase)
            testCase.verifyEqual(ic.utils.toCamelCase(""), "");
        end

        function testPascalCaseFromSnakeCase(testCase)
            testCase.verifyEqual(ic.utils.toPascalCase("my_variable"), "MyVariable");
            testCase.verifyEqual(ic.utils.toPascalCase("some_test_value"), "SomeTestValue");
        end

        function testPascalCaseFromCamelCase(testCase)
            testCase.verifyEqual(ic.utils.toPascalCase("myVariable"), "MyVariable");
            testCase.verifyEqual(ic.utils.toPascalCase("someTestValue"), "SomeTestValue");
        end

        function testPascalCaseWithEventPrefix(testCase)
            % Event-style strings used in MATLAB-Svelte communication
            % Note: @ prefix doesn't capitalize (non-letter), so behavior matches toCamelCase
            testCase.verifyEqual(ic.utils.toPascalCase("@prop/my_value"), "@prop/myValue");
            testCase.verifyEqual(ic.utils.toPascalCase("@event/on_click"), "@event/onClick");
        end

        function testPascalCasePreservesPascalCase(testCase)
            testCase.verifyEqual(ic.utils.toPascalCase("AlreadyPascal"), "AlreadyPascal");
        end

        function testPascalCaseEmpty(testCase)
            testCase.verifyEqual(ic.utils.toPascalCase(""), "");
        end

        function testStringArrayInput(testCase)
            % All functions should handle string arrays element-wise
            input = ["myVariable", "some_value", "@prop/TestName"];

            testCase.verifyEqual(ic.utils.toSnakeCase(input), ...
                ["my_variable", "some_value", "@prop/test_name"]);
            testCase.verifyEqual(ic.utils.toCamelCase(input), ...
                ["myVariable", "someValue", "@prop/testName"]);
            testCase.verifyEqual(ic.utils.toPascalCase(input), ...
                ["MyVariable", "SomeValue", "@prop/testName"]);
        end
    end
end
