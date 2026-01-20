% RESOLUTION object that determines if an event published into the view was successful and that contains any information that the view sends back to the model
classdef Resolution
    properties
        % > SUCCESS flag indicating if the view could process correctly the event
        Success (1,1) logical
        % > DATA any information that the view wants to send back to the model after processing the event
        Data % any
    end

    methods
        function this = Resolution(success, data)
            this.Success = success;
            this.Data = data;
        end
    end
end
