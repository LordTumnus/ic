classdef Resolution
   % result of a client-side request. The MATLAB mirror of the TypeScript type Resolution = {success: boolean, data: unknown}.

   properties
      % whether the view processed the event successfully
      Success (1,1) logical

      % value returned by the view, or error message if Success is false
      Data % any
   end

   methods
      function this = Resolution(success, data)
         this.Success = success;
         this.Data = data;
      end
   end
end
