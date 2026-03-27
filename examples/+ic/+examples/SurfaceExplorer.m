function SurfaceExplorer()
% 3D surface explorer with TweakPane controls.

darkBg = [0.08 0.09 0.12];
fig = uifigure( ...
    "Name", "Surface Explorer", ...
    "Position", [100 60 1400 850], ...
    "Color", darkBg);
gl = uigridlayout(fig, ...
    "RowHeight", {'1x'}, ...
    "ColumnWidth", {'3x', '1x'}, ...
    "Padding", [0 0 10 0], ...
    "ColumnSpacing", 0, ...
    "BackgroundColor", darkBg);

ax = uiaxes(gl);
ax.Layout.Row = 1; ax.Layout.Column = 1;
ax.Color = darkBg;
ax.BackgroundColor = darkBg;
ax.XColor = [0.3 0.3 0.35];
ax.YColor = [0.3 0.3 0.35];
ax.ZColor = [0.3 0.3 0.35];
ax.GridColor = [0.2 0.2 0.25];
ax.GridAlpha = 0.3;
ax.Box = 'off';
ax.XTickLabel = [];
ax.YTickLabel = [];
ax.ZTickLabel = [];

rightPanel = uigridlayout(gl, ...
    "RowHeight", {'1x'}, ...
    "ColumnWidth", {'1x'}, ...
    "Padding", [8 8 8 8], ...
    "BackgroundColor", darkBg);
rightPanel.Layout.Row = 1;
rightPanel.Layout.Column = 2;

frame = ic.Frame("Parent", rightPanel);
frame.ColorScheme = "dark";
frame.Debug = true;
frame.css.style("", "backgroundColor", ...
    sprintf("#%02x%02x%02x", round(darkBg(1)*255), round(darkBg(2)*255), round(darkBg(3)*255)));

pane = ic.TweakPane("Title", "Surface Explorer");
frame.addChild(pane);

% surface folder
fSurface = pane.addFolder("Label", "Surface");
tp.surfType = fSurface.addList( ...
    "Label", "Type", ...
    "Items", ["membrane", "peaks", "sphere", "torus", "trefoil"], ...
    "Value", "membrane");
tp.resolution = fSurface.addSlider( ...
    "Label", "Resolution", ...
    "Min", 20, "Max", 200, "Step", 5, "Value", 80);
tp.wireframe = fSurface.addCheckbox( ...
    "Label", "Wireframe", "Value", false);
tp.alpha = fSurface.addSlider( ...
    "Label", "Opacity", ...
    "Min", 0, "Max", 1, "Step", 0.05, "Value", 1);

% camera folder
fCamera = pane.addFolder("Label", "Camera");
tp.rotation = fCamera.addRotation( ...
    "Label", "Orientation", ...
    "Mode", "euler", "Unit", "deg", "Picker", "inline", ...
    "Value", struct('x', 37.5, 'y', 30, 'z', 0));
tp.presetView = fCamera.addList( ...
    "Label", "Preset", ...
    "Items", ["Isometric", "Front", "Top", "Side", "Bottom"], ...
    "Value", "Isometric");
tp.zoom = fCamera.addSlider( ...
    "Label", "Zoom", ...
    "Min", 0.5, "Max", 5, "Step", 0.1, "Value", 1);

% lighting folder
fLighting = pane.addFolder("Label", "Lighting", "Expanded", true);
tp.lightPos = fLighting.addPoint( ...
    "Label", "Position", ...
    "Value", struct('x', 1, 'y', 0, 'z', 1));
tp.lightColor = fLighting.addColor( ...
    "Label", "Color", "Value", "#ffffff");
tp.material = fLighting.addList( ...
    "Label", "Material", ...
    "Items", ["default", "shiny", "dull", "metal"], ...
    "Value", "default");
tp.ambient = fLighting.addSlider( ...
    "Label", "Ambient", ...
    "Min", 0, "Max", 1, "Step", 0.05, "Value", 0.3);

% colormap folder
fColormap = pane.addFolder("Label", "Colormap", "Expanded", false);
tp.cmapPreset = fColormap.addList( ...
    "Label", "Preset", ...
    "Items", ["MATLAB Logo", "parula", "jet", "hot", "cool", "turbo", "copper"], ...
    "Value", "MATLAB Logo");
tp.cmapReverse = fColormap.addCheckbox( ...
    "Label", "Reverse", "Value", false);

pane.addSeparator();

% performance folder
fPerf = pane.addFolder("Label", "Performance", "Expanded", true);
tp.renderMonitor = fPerf.addMonitor( ...
    "Label", "Render (ms)", ...
    "View", "graph", "GraphMin", 0, "GraphMax", 100);

surfHandle = [];
lightHandle = [];
currentSurfName = "membrane";
currentResolution = 80;
syncing = false;

% event wiring — read from e.Data.value (the event payload); blade .Value
% property may not have synced yet when ValueChanged fires.
addlistener(tp.surfType,    'ValueChanged', @(~,e) onSurfTypeChanged(e));
addlistener(tp.resolution,  'ValueChanged', @(~,e) onResolutionChanged(e));
addlistener(tp.wireframe,   'ValueChanged', @(~,e) onWireframeChanged(e));
addlistener(tp.alpha,       'ValueChanging', @(~,e) onAlphaChanged(e));
addlistener(tp.rotation,    'ValueChanged', @(~,e) onRotationChanged(e));
addlistener(tp.presetView,  'ValueChanged', @(~,e) onPresetView(e));
addlistener(tp.zoom,        'ValueChanging', @(~,e) onZoomChanged(e));
addlistener(tp.lightPos,    'ValueChanged', @(~,e) onLightPosChanged(e));
addlistener(tp.lightColor,  'ValueChanged', @(~,e) onLightColorChanged(e));
addlistener(tp.material,    'ValueChanged', @(~,e) onMaterialChanged(e));
addlistener(tp.ambient,     'ValueChanging', @(~,e) onAmbientChanged(e));
addlistener(tp.cmapPreset,  'ValueChanged', @(~,e) onColormapChanged(e));
addlistener(tp.cmapReverse, 'ValueChanged', @(~,e) onColormapReverseChanged(e));

% sync axes rotation back to TweakPane
addlistener(ax, 'View', 'PostSet', @(~,~) onAxesViewChanged());

renderSurface();

% =====================================================================

function renderSurface()
    tic;
    [X, Y, Z] = generateSurface(currentSurfName, currentResolution);

    cla(ax);
    hold(ax, 'on');
    surfHandle = surf(ax, X, Y, Z, ...
        'EdgeColor', 'none', ...
        'FaceLighting', 'gouraud');
    lp = tp.lightPos.Value;
    lightHandle = light(ax, ...
        'Position', [lp.x, lp.y, lp.z], ...
        'Color', hex2rgb(string(tp.lightColor.Value)));
    hold(ax, 'off');

    % apply current visual state
    surfHandle.FaceAlpha = tp.alpha.Value;
    surfHandle.AmbientStrength = tp.ambient.Value;
    applyWireframe(tp.wireframe.Value);
    applyMaterial(string(tp.material.Value));
    applyColormap(string(tp.cmapPreset.Value), tp.cmapReverse.Value);
    axis(ax, 'equal', 'tight');
    view(ax, tp.rotation.Value.x, tp.rotation.Value.y);

    renderMs = toc * 1000;
    tp.renderMonitor.Value = renderMs;
end

function onSurfTypeChanged(e)
    currentSurfName = string(e.Data.value);
    renderSurface();
end

function onResolutionChanged(e)
    currentResolution = e.Data.value;
    renderSurface();
end

function onWireframeChanged(e)
    applyWireframe(e.Data.value);
end

function onAlphaChanged(e)
    if ~isempty(surfHandle) && isvalid(surfHandle)
        surfHandle.FaceAlpha = e.Data.value;
    end
end

function onRotationChanged(e)
    if syncing, return; end
    syncing = true;
    val = e.Data.value;
    view(ax, val.x, val.y);
    syncing = false;
end

function onPresetView(e)
    syncing = true;
    name = string(e.Data.value);
    switch name
        case "Isometric", az = 37.5; el = 30;
        case "Front",     az = 0;    el = 0;
        case "Top",       az = 0;    el = 90;
        case "Side",      az = 90;   el = 0;
        case "Bottom",    az = 0;    el = -90;
        otherwise,        az = 37.5; el = 30;
    end
    tp.rotation.Value = struct('x', az, 'y', el, 'z', 0);
    view(ax, az, el);
    syncing = false;
end

function onZoomChanged(e)
    camva(ax, 10.34 / e.Data.value);
end

function onLightPosChanged(e)
    val = e.Data.value;
    if ~isempty(lightHandle) && isvalid(lightHandle)
        lightHandle.Position = [val.x, val.y, val.z];
    end
end

function onLightColorChanged(e)
    if ~isempty(lightHandle) && isvalid(lightHandle)
        lightHandle.Color = hex2rgb(string(e.Data.value));
    end
end

function onMaterialChanged(e)
    applyMaterial(string(e.Data.value));
end

function onAmbientChanged(e)
    if ~isempty(surfHandle) && isvalid(surfHandle)
        surfHandle.AmbientStrength = e.Data.value;
    end
end

function onColormapChanged(e)
    applyColormap(string(e.Data.value), tp.cmapReverse.Value);
end

function onColormapReverseChanged(e)
    applyColormap(string(tp.cmapPreset.Value), e.Data.value);
end

% axes interaction → TweakPane sync
function onAxesViewChanged()
    if syncing, return; end
    syncing = true;
    [az, el] = view(ax);
    tp.rotation.Value = struct('x', az, 'y', el, 'z', 0);
    syncing = false;
end

function applyWireframe(on)
    if ~isempty(surfHandle) && isvalid(surfHandle)
        if on
            surfHandle.EdgeColor = [0.3 0.3 0.35];
            surfHandle.EdgeAlpha = 0.15;
        else
            surfHandle.EdgeColor = 'none';
        end
    end
end

function applyMaterial(name)
    if ~isempty(surfHandle) && isvalid(surfHandle)
        material(surfHandle, char(name));
    end
end

function applyColormap(preset, reverse)
    if preset == "MATLAB Logo"
        cmap = matlabLogoColormap(256);
    else
        cmap = feval(char(preset), 256);
    end
    if reverse
        cmap = flipud(cmap);
    end
    colormap(ax, cmap);
end

end % SurfaceExplorer


%% helper functions

function [X, Y, Z] = generateSurface(name, n)
    switch name
        case "membrane"
            Z = membrane(1, n);
            sz = size(Z, 1);
            [X, Y] = meshgrid(linspace(-1, 1, sz), linspace(-1, 1, sz));

        case "peaks"
            [X, Y, Z] = peaks(n);

        case "sphere"
            [X, Y, Z] = sphere(n);

        case "torus"
            R = 1; r = 0.4;
            [u, v] = meshgrid(linspace(0, 2*pi, n));
            X = (R + r*cos(v)) .* cos(u);
            Y = (R + r*cos(v)) .* sin(u);
            Z = r * sin(v);

        case "trefoil"
            [X, Y, Z] = trefoilSurface(n);

        otherwise
            [X, Y, Z] = peaks(n);
    end
end

function [X, Y, Z] = trefoilSurface(n)
    % tube mesh around a trefoil knot curve
    nPts = max(n, 60);
    nSides = max(round(n / 4), 12);
    t = linspace(0, 2*pi, nPts);

    % trefoil knot parametric curve
    cx = sin(t) + 2*sin(2*t);
    cy = cos(t) - 2*cos(2*t);
    cz = -sin(3*t);

    X = zeros(nSides, nPts);
    Y = zeros(nSides, nPts);
    Z = zeros(nSides, nPts);
    r = 0.35;
    theta = linspace(0, 2*pi, nSides);

    prevNormal = [];
    for k = 1:nPts
        % tangent via central differences
        if k == 1
            tang = [cx(2)-cx(nPts-1), cy(2)-cy(nPts-1), cz(2)-cz(nPts-1)];
        elseif k == nPts
            tang = [cx(2)-cx(nPts-1), cy(2)-cy(nPts-1), cz(2)-cz(nPts-1)];
        else
            tang = [cx(k+1)-cx(k-1), cy(k+1)-cy(k-1), cz(k+1)-cz(k-1)];
        end
        tang = tang / norm(tang);

        % stable normal via double-reflection (rotation-minimizing frame)
        if isempty(prevNormal)
            if abs(tang(1)) < 0.9
                up = [1 0 0];
            else
                up = [0 1 0];
            end
            normal = cross(tang, up);
            normal = normal / norm(normal);
        else
            % project previous normal onto plane perpendicular to new tangent
            normal = prevNormal - dot(prevNormal, tang) * tang;
            normal = normal / norm(normal);
        end
        binormal = cross(tang, normal);
        prevNormal = normal;

        for j = 1:nSides
            X(j,k) = cx(k) + r*(normal(1)*cos(theta(j)) + binormal(1)*sin(theta(j)));
            Y(j,k) = cy(k) + r*(normal(2)*cos(theta(j)) + binormal(2)*sin(theta(j)));
            Z(j,k) = cz(k) + r*(normal(3)*cos(theta(j)) + binormal(3)*sin(theta(j)));
        end
    end
end

function cmap = matlabLogoColormap(n)
    % sampled from the actual MATLAB logo gradient
    anchors = [
        0.00  0.15  0.42   % deep blue (valley)
        0.02  0.30  0.62   % medium blue
        0.40  0.18  0.52   % violet
        0.75  0.00  0.22   % crimson
        0.93  0.35  0.00   % burnt orange
        1.00  0.60  0.00   % bright orange (peak)
    ];
    xi = linspace(0, 1, size(anchors, 1));
    xq = linspace(0, 1, n);
    cmap = interp1(xi, anchors, xq);
end

function rgb = hex2rgb(hexStr)
    hexStr = char(hexStr);
    if hexStr(1) == '#', hexStr = hexStr(2:end); end
    rgb = [hex2dec(hexStr(1:2)), hex2dec(hexStr(3:4)), hex2dec(hexStr(5:6))] / 255;
end
