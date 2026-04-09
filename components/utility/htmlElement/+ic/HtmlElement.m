classdef HtmlElement < ic.core.ComponentContainer
    % generic DOM element that creates any HTML tag and mirrors the HTMLElement API.
    % use this component to insert semantic markup (div, p, h1, section, etc.)
    % into a figure, with full access to text content, attributes, and DOM events.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % HTML tag name of the element (e.g. "div", "p", "h1", "span", "section")
        Tag string = "div"

        % text content of the element (mirrors element.innerText)
        InnerText string = ""

        % raw HTML content, overrides InnerText and children when non-empty
        InnerHTML string = ""

        % space-separated CSS class names (mirrors element.className)
        ClassName string = ""

        % tooltip text shown on hover (mirrors element.title)
        Title string = ""

        % whether the element is hidden (mirrors element.hidden)
        Hidden logical = false
    end

    events (Description = "Reactive")
        % fires when the element is clicked
        % {payload}
        % timestamp | double: time of the click event
        % {/payload}
        Clicked

        % fires when the element is double-clicked
        % {payload}
        % timestamp | double: time of the double-click event
        % {/payload}
        DoubleClicked

        % fires when the mouse pointer enters the element
        MouseEntered

        % fires when the mouse pointer leaves the element
        MouseLeft

        % fires on right-click / context menu
        % {payload}
        % x | double: horizontal mouse coordinate relative to the viewport
        % y | double: vertical mouse coordinate relative to the viewport
        % {/payload}
        ContextMenuOpened

        % fires when a key is pressed while the element has focus
        % {payload}
        % key | char: the key value (e.g. "Enter", "a", "Escape")
        % code | char: the physical key code (e.g. "KeyA", "Space")
        % shiftKey | logical: whether Shift was held
        % ctrlKey | logical: whether Ctrl was held
        % altKey | logical: whether Alt was held
        % metaKey | logical: whether Meta/Cmd was held
        % {/payload}
        KeyPressed

        % fires when the element gains focus
        FocusGained

        % fires when the element loses focus
        FocusLost

        % fires when the element is scrolled
        % {payload}
        % scrollTop | double: vertical scroll position in pixels
        % scrollLeft | double: horizontal scroll position in pixels
        % {/payload}
        Scrolled
    end

    methods
        function this = HtmlElement(props)
            arguments
                props.?ic.HtmlElement
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the element
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % programmatically blur (unfocus) the element
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("blur", []);
        end

        function out = click(this)
            % programmatically click the element
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("click", []);
        end

        function out = scrollIntoView(this)
            % scroll the element into the visible area of the viewport
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("scrollIntoView", []);
        end

        function out = setAttribute(this, name, value)
            % set an arbitrary HTML attribute on the element
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            % {example}
            %   el.setAttribute("data-index", "5");
            %   el.setAttribute("role", "listitem");
            % {/example}
            arguments
                this
                % attribute name
                name (1,1) string
                % attribute value
                value (1,1) string
            end
            out = this.publish("setAttribute", struct('name', name, 'value', value));
        end

        function out = removeAttribute(this, name)
            % remove an HTML attribute from the element
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            % {example}
            %   el.removeAttribute("data-index");
            % {/example}
            arguments
                this
                % attribute name to remove
                name (1,1) string
            end
            out = this.publish("removeAttribute", struct('name', name));
        end
    end
end
