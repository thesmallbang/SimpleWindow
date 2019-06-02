local swindow = {}

swindow.Alignments = {
    Start = 0,
    Center = 1,
    End = 2
}
swindow.ContainerStyles = {
    Column = 0,
    Row = 1,
    RowWrap = 2
}

local D_FONT = 'Lucida Console'
local D_FONTSIZE = 9
local D_FONTCOLOR = ColourNameToRGB('white')
local D_BACKCOLOR = ColourNameToRGB('black')
local D_WIDTH = 300
local D_HEIGHT = 300
local D_LAYER = 100
local D_UPDATEINTERVAL = 1
local D_LEFT = 0
local D_TOP = 0
local D_TITLE = 'Simple Window by Tamon'
local D_BORDERWIDTH = 1
local D_TITLEALIGNMENT = swindow.Alignments.Start
local D_SAVESTATE = true
local D_ALLOWRESIZE = true
local D_MINWIDTH = 100
local D_MINHEIGHT = 50
local D_CONTAINERSTYLE = swindow.ContainerStyles.RowWrap
local D_CONTAINERALIGNMENT_X = swindow.Alignments.Start
local D_CONTAINERALIGNMENT_Y = swindow.Alignments.Center

local D_CONTAINERSPACING = 3

local function isModuleAvailable(name)
    if package.loaded[name] then
        return true
    else
        for _, searcher in ipairs(package.searchers or package.loaders) do
            local loader = searcher(name)
            if type(loader) == 'function' then
                package.preload[name] = loader
                return true
            end
        end
        return false
    end
end

function SplitRGB(hx)
    hx = tostring(hx):gsub('#', '')
    return tonumber('0x' .. hx:sub(1, 2)), tonumber('0x' .. hx:sub(3, 4)), tonumber('0x' .. hx:sub(5, 6))
end

function ColorToRGBHex(color)
    low = math.floor(color / 65536)
    color = color - low * 65536
    mid = math.floor(color / 256) * 256
    color = color - mid
    high = color * 65536
    return string.format('#%06x', high + mid + low)
end

function swindow.MergeRGB(rgb)
    local hexadecimal = '0X'

    for i = #rgb, 1, -1 do
        local value = rgb[i]

        local hex = ''
        while (value > 0) do
            local index = math.fmod(value, 16) + 1
            value = math.floor(value / 16)
            hex = string.sub('0123456789ABCDEF', index, index) .. hex
        end

        if (string.len(hex) == 0) then
            hex = '00'
        elseif (string.len(hex) == 1) then
            hex = '0' .. hex
        end

        hexadecimal = hexadecimal .. hex
    end

    for key, value in pairs(rgb) do
    end

    return tonumber(hexadecimal, 16)
end

function swindow.ColorAdjust(color, percent)
    if (type(color) == 'string') then
        color = ColourNameToRGB(color)
    end

    local r, g, b = SplitRGB(ColorToRGBHex(color))
    return swindow.MergeRGB(
        {
            (r or 0) * (1 + percent),
            (g or 0) * (1 + percent),
            (b or 0) * (1 + percent)
        },
        16
    )
end

swindow.Paint = function(win)
    if (win.__state.hasPaintBuffer == true) then
        -- https://github.com/fiendish/aardwolfclientpackage/wiki/Repaint-Buffer
        BroadcastPlugin(999, 'repaint')
    else
        Redraw()
    end
end

swindow.CreateWindow = function(config, theme)
    -- THE OPTIONS PASSED IN ON CONFIG MAY NOT RESPOND TO CHANGES AFTER CREATION

    local window = {
        __state = {
            views = {},
            viewIndex = 1, -- the currently "selected" view
            lastDraw = 0, -- time we last drew the window
            lastDrawConfig = nil, -- the config when we last drew our window, used to detect/apply window changes like updating a layer
            isMoving = false,
            isResizing = false,
            canMove = true,
            movingPositions = {X = 0, Y = 0},
            resizePositions = {X = 0, Y = 0},
            fontsLoaded = false,
            contentTop = 0,
            hasPaintBuffer = false
        }
    }

    window.Config = config or swindow.CreateConfig()
    window.Theme = theme or swindow.CreateTheme()

    if (window.Config.SaveState == true) then
        window.Config.Left = tonumber(GetVariable(window.Config.Id .. '_left')) or window.Config.Left
        window.Config.Top = tonumber(GetVariable(window.Config.Id .. '_top')) or window.Config.Top
        window.Config.Width = tonumber(GetVariable(window.Config.Id .. '_width')) or window.Config.Width
        window.Config.Height = tonumber(GetVariable(window.Config.Id .. '_height')) or window.Config.Height
    end

    --------------------------------------------------
    -- Assign all the methods to our window function -
    --------------------------------------------------

    function window.RegisterView(view)
        window.__state.hasPaintBuffer = IsPluginInstalled('abc1a0944ae4af7586ce88dc')

        table.insert(window.__state.views, view)
    end

    function window.GetTextStyle(name)
        local textStyle = nil

        if (name ~= nil) then
            for key, value in pairs(window.Theme.TextStyles) do
                if (textStyle == nil and key == name) then
                    textStyle = value
                end
            end
        end

        if (textStyle == nil) then
            for key, value in pairs(window.Theme.TextStyles) do
                if (textStyle == nil and value.Default == true) then
                    textStyle = value
                end
            end
        end

        if (textStyle == nil) then
            textStyle = window.Theme.TextStyles[0]
        end

        return textStyle
    end

    function window.GetTextWidth(textStyle, text)
        if (type(textStyle) ~= 'string') then
            textStyle = textStyle.Name
        end

        return WindowTextWidth(window.Config.Id, textStyle, text, false)
    end

    function window.GetTextHeight(textStyle)
        if (type(textStyle) ~= 'string') then
            textStyle = textStyle.Name
        end
        return WindowFontInfo(window.Config.Id, textStyle, 1)
    end

    function window.Tick()
        if (window.__state.isMoving or window.__state.isResizing) then
            return
        end

        local view = window.__state.views[window.__state.viewIndex]

        if (window.__state.lastDraw > (os.time() - window.Config.UpdateInterval)) then
            if (view ~= nil) then
                view.Containers = nil
            end
            return
        end

        window.__state.lastDraw = os.time()
        window.DrawWindow()

        if (window.__state.views == nil or #window.__state.views == 0) then
            window.DrawText {
                Text = 'No views are registered',
                TextStyle = window.GetTextStyle(),
                BackColor = 'red'
            }
            return
        end

        if (view == nil) then
            window.DrawText {
                Text = 'Invalid view state',
                TextStyle = window.GetTextStyle(),
                BackColor = 'red'
            }
            return
        end

        view.Draw()
    end

    function window.CreateView(options)
        local view = {Name = options.Name or 'A View', Containers = nil}

        view.Sizes =
            options.Sizes or
            {
                {Name = 'xs', From = 0},
                {Name = 'sm', From = 100},
                {Name = 'md', From = 200},
                {Name = 'lg', From = 350},
                {Name = 'xl', From = 500}
            }

        view.QuerySize = function()
            local size = {From = -1}
            local width = window.Config.Width
            assert(view.Sizes ~= nil, 'No sizes are configured in the view')

            for _, s in ipairs(view.Sizes) do
                if (size.From < s.From and s.From <= width) then
                    size = s
                end
            end
            if (size.Name == nil) then
                size = view.Sizes[1] -- take the first
            end

            assert(size.Name ~= nil, 'responsive query sizes are not configured (view.Sizes)')

            return size
        end

        view.GetSizePercent = function(name, definedSizes)
            -- can we just find a straight up match first?
            for _, s in ipairs(definedSizes) do
                if (s.Name == name) then
                    return s.Percent
                end
            end

            -- get a list of all the sizes available
            -- searching for lg ..

            -- viewconf -- containerconf    --
            ------------------------------------
            -- xs   -- xs 100           -- matches view and container so add to matches table
            -- sm   --              -- nope
            -- md   -- md 50        -- matches view and container so add to matches table
            -- lg   --              -- matches search size return last matches.percent
            -- xl   --
            local lastmatch = {}
            for _, vs in ipairs(view.Sizes) do
                for _, cs in ipairs(definedSizes) do
                    if (vs.Name == cs.Name) then
                        lastmatch = cs
                    end
                end
                if (vs.Name == name) then
                    return lastmatch.Percent
                end
            end
        end

        view.OnUpdate = options.OnUpdate

        view.DrawContainers = function()
            local cursor = {X = 0}
            local viewbounds = {
                Left = theme.BorderWidth + theme.BodyMargin.Left,
                Top = window.__state.contentTop + theme.BodyMargin.Top,
                Right = (window.Config.Width - theme.BorderWidth) - theme.BodyMargin.Right,
                Bottom = (window.Config.Height - theme.BorderWidth) - theme.BodyMargin.Bottom
            }

            local size = view.QuerySize()
            if (size == nil) then
                print('no size')
                return
            end

            local furthestYInRow = 0
            local bounds = viewbounds
            for containerIndex, container in ipairs(view.Containers) do
                local lastBounds = view.DrawContainer(containerIndex, container, cursor.X, size, bounds)

                cursor.X = cursor.X + (lastBounds.Right - lastBounds.Left) -- + margin etc etc
                -- keep track of the tallest container on the row
                if (furthestYInRow < lastBounds.Bottom) then
                    furthestYInRow = lastBounds.Bottom
                end

                if (cursor.X >= bounds.Right) then
                    cursor.X = 0
                    bounds.Top = furthestYInRow
                else
                    -- check if the next container needs to wrap
                    local nextcontainer = view.Containers[containerIndex + 1]
                    if (nextcontainer ~= nil) then
                        local nextwidth = view.GetContainerWidth(nextcontainer, size, (bounds.Right - bounds.Left))
                        if ((cursor.X + nextwidth) >= bounds.Right) then
                            cursor.X = 0
                            bounds.Top = furthestYInRow
                        end
                    end
                end

                if (bounds.Top >= bounds.Bottom) then
                    -- dont bother to keep going it would be off our window
                    return
                end
            end
        end

        view.GetContainerWidth = function(container, size, parentwidth)
            local containerwidth = (parentwidth / 100) * view.GetSizePercent(size.Name, container.Sizes)
            return containerwidth
        end

        view.GetContentWidth = function(content, size, parentwidth)
            return (parentwidth / 100) * view.GetSizePercent(size.Name, content.Sizes)
        end

        view.DrawContainer = function(containerIndex, container, left, size, parentBounds)
            local containerCursor = {X = 0}
            local containerwidth = view.GetContainerWidth(container, size, (parentBounds.Right - parentBounds.Left))
            local containerheight = 0 -- for counting height when not explicitly specified

            local containerbounds = {
                Left = parentBounds.Left + containerCursor.X + left,
                Top = parentBounds.Top
            }

            containerbounds.Bottom = containerbounds.Top + (container.Height or parentBounds.Bottom)
            if (containerbounds.Bottom > parentBounds.Bottom) then
                containerbounds.Bottom = parentBounds.Bottom
            end
            containerbounds.Right = containerbounds.Left + containerwidth

            --  if (container.BackColor) then
            -- window.DrawText {
            --     Text = '',
            --     Bounds = containerbounds,
            --     BackColor = container.BackColor or math.random(1, 30000)
            -- }
            --  end

            local height = view.DrawContents(container, containerCursor.X, size, containerbounds)
            containerbounds.Bottom = containerbounds.Top + (container.Height or height)

            return containerbounds
        end

        view.DrawContents = function(container, left, size, parentBounds)
            local contentcursor = {X = 0, Y = 0}
            local tallestContentInRow = 0

            for contentIndex, content in ipairs(container.Content) do
                local contentbounds =
                    view.DrawContent(contentIndex, content, contentcursor, size, parentBounds, container)

                if (tallestContentInRow < contentbounds.Bottom - contentbounds.Top) then
                    tallestContentInRow = contentbounds.Bottom - contentbounds.Top
                end

                contentcursor.X = contentcursor.X + (contentbounds.Right - contentbounds.Left) -- + margin etc etc

                -- check if the next container needs to wrap
                local nextcontent = container.Content[contentIndex + 1]
                if (nextcontent ~= nil) then
                    local nextwidth =
                        view.GetContentWidth(nextcontent, size, (parentBounds.Right) - (parentBounds.Left)) - 1
                    -- had to add this -1 .. that means... something is off...

                    if (parentBounds.Left + (contentcursor.X + nextwidth) > parentBounds.Right) then
                        contentcursor.X = 0
                        contentcursor.Y = contentcursor.Y + tallestContentInRow
                        tallestContentInRow = 0
                    end
                end

                if (contentcursor.Y >= parentBounds.Bottom) then
                    -- dont bother to keep going it would be off our window
                    return contentcursor.Y
                end
            end

            return contentcursor.Y + tallestContentInRow
        end

        view.DrawContent = function(contentIndex, content, cursor, size, parentBounds, container)
            local contentheight = content.Height or (window.GetTextHeight(content.TextStyle))
            local margin = content.Margin or container.ContentMargin or theme.ContentMargin
            local padding = (content.Padding or container.ContentPadding) or theme.ContentPadding

            local contentbounds = {
                Left = parentBounds.Left + cursor.X,
                Top = parentBounds.Top + cursor.Y
            }

            local contentwidth = view.GetContentWidth(content, size, (parentBounds.Right) - (parentBounds.Left))

            if (contentwidth == 0) then
                contentbounds.Bottom = contentbounds.Top
                contentbounds.Right = contentbounds.Left
                return contentbounds
            end

            contentbounds.Right = (contentbounds.Left + contentwidth)
            contentbounds.Bottom = contentbounds.Top + margin.Top + contentheight + margin.Bottom --+ padding.Top + padding.Bottom

            -- for testing so i can see =)
            -- window.DrawText {
            --     Text = '',
            --     Bounds = contentbounds,
            --     BackColor = math.random(1, 100000)
            -- }

            -- adjust for our text by the margin
            -- move in x/y and shrink right/bottom
            local textbounds = {}
            textbounds.Left = contentbounds.Left + margin.Left
            textbounds.Top = contentbounds.Top + margin.Top --+ padding.Top
            textbounds.Right = (contentbounds.Right - margin.Right)
            textbounds.Bottom = (contentbounds.Bottom - margin.Bottom) --+ padding.Bottom + padding.Top

            local drewBounds =
                window.DrawText {
                Text = content.Text,
                Alignment = content.Alignment,
                Bounds = textbounds,
                Tooltip = content.Tooltip,
                BackAttached = content.BackAttached,
                Action = content.Action,
                FontColor = content.FontColor,
                BackColor = content.BackColor,
                TextStyle = content.TextStyle,
                Padding = content.Padding
            }
            contentbounds.Bottom = drewBounds.Bottom

            return contentbounds
        end

        view.Draw = function(options)
            -- no content yet or we cache expired
            if (view.Containers == nil) then
                if (view.OnUpdate ~= nil) then
                    view:OnUpdate()
                end
            end

            -- ok now finally working on drawing some content...
            view.DrawContainers()
        end

        view.AddContainer = function(options)
            view.Containers = view.Containers or {}

            local container = {}

            container.Name = options.Name or 'Lorem ipsum'
            container.Style = options.Style or D_CONTAINERSTYLE
            container.Height = options.Height
            container.Alignment = options.Alignment or {X = D_CONTAINERALIGNMENT_X, Y = D_CONTAINERALIGNMENT_Y}
            container.Spacing = options.Spacing or D_CONTAINERSPACING
            container.Content = options.Content or {}
            container.BackColor = options.BackColor
            container.ContentSizes = options.ContentSizes
            container.ContentPadding = options.ContentPadding or theme.ContentPadding
            container.ContentMargin = options.ContentMargin or theme.ContentMargin
            container.ContentAlignment = options.ContentAlignment or theme.ContentAlignment
            if (type(container.BackColor) == 'string') then
                container.BackColor = ColourNameToRGB(container.BackColor)
            end

            container.TextStyle = options.TextStyle
            if (container.TextStyle == nil or type(container.TextStyle) == 'string') then
                container.TextStyle = window.GetTextStyle(container.TextStyle)
            end

            container.Sizes =
                options.Sizes or
                {
                    {Name = 'xs', Percent = 100},
                    {Name = 'md', Percent = 50},
                    {Name = 'xl', Percent = 25}
                }

            container.AddContent = function(options)
                container.Content = container.Content or {}

                local content = {}
                content.Id = options.Id or 'content_' .. math.random(1, 100000)
                content.Text = options.Text or 'Lorem ipsum'
                content.Action = options.Action
                content.Tooltip = options.Tooltip
                content.Height = options.Height
                content.Margin = options.Margin
                content.Padding =
                    options.Padding or container.ContentPadding or theme.ContentPadding or
                    {Left = 0, Top = 0, Right = 0, Bottom = 0}
                content.BackAttached = options.BackAttached
                content.TextStyle = options.TextStyle or container.TextStyle
                content.Alignment =
                    options.Alignment or container.ContentAlignment or
                    {X = D_CONTAINERALIGNMENT_X, Y = D_CONTAINERALIGNMENT_Y}

                content.Sizes =
                    options.Sizes or
                    (container.ContentSizes or
                        {
                            {Name = 'xs', Percent = 100}
                        })
                content.GetSizePercent = function(name)
                end

                if (content.TextStyle == nil or type(content.TextStyle) == 'string') then
                    content.TextStyle = window.GetTextStyle(content.TextStyle)
                end
                content.BackColor = options.BackColor or content.TextStyle.BackColor or window.Theme.BackColor
                content.FontColor = options.FontColor or content.TextStyle.FontColor or window.Theme.FontColor
                table.insert(container.Content, content)
                return content
            end

            table.insert(view.Containers, container)
            return container
        end

        return view
    end

    function window.DrawWindow()
        local lastConfig = window.__state.lastDrawConfig
        local drawConfig = window.Config

        -- we could give it a default but it's a teachable moment
        assert(drawConfig ~= nil, 'A configuration was not supplied to the window')
        assert(drawConfig.Id ~= nil and drawConfig.Id ~= '', 'Invalid id for a window')

        -- check previous config for changes we can apply before the window is created
        if (lastConfig ~= nil and lastConfig.Id ~= drawConfig.Id) then
            -- we need to remove the last window id
            WindowDelete(lastConfig.Id)
            window.__state.fontsLoaded = false
        end

        -- create our window
        WindowCreate(
            drawConfig.Id,
            drawConfig.Left,
            drawConfig.Top,
            drawConfig.Width,
            drawConfig.Height,
            0,
            miniwin.create_absolute_location + miniwin.create_keep_hotspots,
            window.Theme.BackColor
        )

        -- do we have fonts to load?
        -- we could just look through the text styles here for a loaded flag to catch new ones but i'm not sure i want that atm
        if (window.__state.fontsLoaded == false) then
            for _, textStyle in pairs(window.Theme.TextStyles) do
                WindowFont(
                    drawConfig.Id,
                    textStyle.Name,
                    textStyle.Font,
                    textStyle.FontSize,
                    textStyle.Bold or false,
                    textStyle.Italic or false,
                    textStyle.Underline or false,
                    textStyle.Strike or false,
                    textStyle.Charset or 1,
                    textStyle.Family or 0
                )
            end
        end

        -- check previous configs for changes we can apply after the window was created
        if (lastConfig == nil or lastConfig.Visible ~= drawConfig.Visible) then
            WindowShow(drawConfig.Id, drawConfig.Visible)
        end
        if (lastConfig == nil or lastConfig.Layer ~= drawConfig.Layer) then
            WindowSetZOrder(drawConfig.Id, drawConfig.Layer)
        end

        -- draw border
        WindowCircleOp(
            drawConfig.Id,
            2,
            0,
            0,
            drawConfig.Width,
            drawConfig.Height,
            theme.BorderColor,
            6,
            theme.BorderWidth,
            theme.BackColor
        )

        -- draw our window title
        if (drawConfig.Title ~= nil) then
            local v = window.__state.views[0] or {}
            local vname = v.Name or ''

            local tstyle = window.GetTextStyle('title')
            local title = string.gsub(drawConfig.Title, ' {viewname}', vname)

            local textHeight = window.GetTextHeight(tstyle)
            local titleBounds = {
                Left = theme.BorderWidth,
                Top = theme.BorderWidth,
                Right = drawConfig.Width - theme.BorderWidth
            }

            titleBounds.Bottom = titleBounds.Top + textHeight

            -- shade it darker
            local colorBR = swindow.ColorAdjust(theme.BorderColor, -.3)

            local textBounds = titleBounds
            textBounds.Top = textBounds.Top + theme.TitleMargin.Top
            textBounds.Left = textBounds.Left + theme.TitleMargin.Left
            textBounds.Right = textBounds.Right - theme.TitleMargin.Right
            textBounds.Bottom = textBounds.Bottom + theme.TitleMargin.Bottom

            local drawnPosition =
                window.DrawText {
                Text = title,
                BackColor = theme.TitleBackColor,
                Bounds = textBounds,
                Alignment = {X = theme.TitleAlignment, Y = swindow.Alignments.Center},
                TextStyle = tstyle
            }

            -- -- draw title line with darker shade
            WindowLine(
                drawConfig.Id,
                theme.BorderWidth + (theme.BorderWidth / 2),
                titleBounds.Bottom + theme.TitleMargin.Bottom + (theme.BorderWidth / 2),
                (drawConfig.Width - theme.BorderWidth) - (theme.BorderWidth / 2),
                titleBounds.Bottom + theme.TitleMargin.Bottom + (theme.BorderWidth / 2),
                colorBR,
                0x0100,
                theme.BorderWidth
            )

            _G['TitleMouseDown' .. window.Config.Id] = function(flags)
                if bit.band(flags, 0x10) ~= 0 then
                    window.__state.movingPositions.X = WindowInfo(window.Config.Id, 14)
                    window.__state.movingPositions.Y = WindowInfo(window.Config.Id, 15)
                else
                    print('show options')
                end
            end
            _G['TitleMoveStart' .. window.Config.Id] = function(flags)
                if bit.band(flags, 0x10) == 0 then
                    return
                end

                local posx = WindowInfo(window.Config.Id, 17)
                local posy = WindowInfo(window.Config.Id, 18)
                window.__state.isMoving = true
                if posx < 0 or posx > GetInfo(281) or posy < 0 or posy > GetInfo(280) then
                    check(SetCursor(11)) -- X cursor
                else
                    check(SetCursor(10)) -- move cursor
                    -- move the window to the new location
                    WindowPosition(
                        window.Config.Id,
                        posx - window.__state.movingPositions.X,
                        posy - window.__state.movingPositions.Y,
                        0,
                        2
                    )
                end
            end
            _G['TitleMoveStop' .. window.Config.Id] = function()
                window.__state.isMoving = false
                window.Config.Left = WindowInfo(window.Config.Id, 10)
                window.Config.Top = WindowInfo(window.Config.Id, 11)

                if (window.Config.SaveState == true) then
                    SetVariable(window.Config.Id .. '_left', window.Config.Left)
                    SetVariable(window.Config.Id .. '_top', window.Config.Top)
                    SetVariable(window.Config.Id .. '_width', window.Config.Width)
                    SetVariable(window.Config.Id .. '_height', window.Config.Height)
                end
            end

            WindowAddHotspot(
                drawConfig.Id,
                'titlehs',
                titleBounds.Left,
                titleBounds.Top,
                titleBounds.Right,
                titleBounds.Bottom,
                '',
                '',
                'TitleMouseDown' .. window.Config.Id,
                '',
                '',
                'Left click to move. Right click for options',
                1,
                0
            )
            WindowDragHandler(
                drawConfig.Id,
                'titlehs',
                'TitleMoveStart' .. window.Config.Id,
                'TitleMoveStop' .. window.Config.Id,
                0
            )

            if (drawConfig.AllowResize == true) then
                -- draw our resizer
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - (theme.BorderWidth),
                    drawConfig.Height - (theme.BorderWidth) - 2,
                    drawConfig.Width - (theme.BorderWidth) - 2,
                    drawConfig.Height - (theme.BorderWidth),
                    window.Theme.BorderColor,
                    0 and 0x1000,
                    1
                )
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - (theme.BorderWidth),
                    drawConfig.Height - (theme.BorderWidth) - 5,
                    drawConfig.Width - (theme.BorderWidth) - 5,
                    drawConfig.Height - (theme.BorderWidth),
                    window.Theme.BorderColor,
                    0 and 0x1000,
                    1
                )
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - (theme.BorderWidth),
                    drawConfig.Height - (theme.BorderWidth) - 8,
                    drawConfig.Width - (theme.BorderWidth) - 8,
                    drawConfig.Height - (theme.BorderWidth),
                    window.Theme.BorderColor,
                    0 and 0x1000,
                    1
                )

                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - (theme.BorderWidth),
                    drawConfig.Height - (theme.BorderWidth) - 11,
                    drawConfig.Width - (theme.BorderWidth) - 11,
                    drawConfig.Height - (theme.BorderWidth),
                    window.Theme.BorderColor,
                    0 and 0x1000,
                    1
                )

                _G['ResizeMouseDown' .. window.Config.Id] = function(flags)
                    window.__state.resizePositions.X = WindowInfo(window.Config.Id, 14) -- window.Config.Left
                    window.__state.resizePositions.Y = WindowInfo(window.Config.Id, 15) -- window.Config.Top
                end
                _G['ResizeStart' .. window.Config.Id] = function(flags)
                    local posx = WindowInfo(window.Config.Id, 17) - window.Config.Left
                    local posy = WindowInfo(window.Config.Id, 18) - window.Config.Top

                    window.__state.isResizing = true

                    window.Config.Width = posx
                    window.Config.Height = posy
                    WindowResize(window.Config.Id, window.Config.Width, window.Config.Height, 35434)
                    -- draw border
                    WindowCircleOp(
                        drawConfig.Id,
                        2,
                        0,
                        0,
                        drawConfig.Width,
                        drawConfig.Height,
                        window.Theme.BorderColor,
                        0,
                        theme.BorderWidth,
                        ColourNameToRGB('gold'),
                        6
                    )

                    local txt = 'X: ' .. window.Config.Width .. ' Y: ' .. window.Config.Height
                    local textwidth = window.GetTextWidth(window.GetTextStyle(), txt)

                    window.DrawText {
                        Text = txt,
                        TextStyle = 'title',
                        Bounds = {
                            Left = 0,
                            Top = 0,
                            Right = window.Config.Width,
                            Bottom = window.Config.Height
                        },
                        Alignment = {
                            X = swindow.Alignments.Center,
                            Y = swindow.Alignments.Center
                        }
                    }

                    swindow.Paint(window)
                end
                _G['ResizeStop' .. window.Config.Id] = function()
                    window.__state.isResizing = false
                    window.__state.lastDraw = 0
                    if (window.Config.SaveState == true) then
                        SetVariable(window.Config.Id .. '_left', window.Config.Left)
                        SetVariable(window.Config.Id .. '_top', window.Config.Top)
                        SetVariable(window.Config.Id .. '_width', window.Config.Width)
                        SetVariable(window.Config.Id .. '_height', window.Config.Height)
                    end
                end

                WindowAddHotspot(
                    drawConfig.Id,
                    'resizehs',
                    drawConfig.Width - (theme.BorderWidth) - 12,
                    drawConfig.Height - (theme.BorderWidth) - 12,
                    drawConfig.Width - (theme.BorderWidth),
                    drawConfig.Height - (theme.BorderWidth),
                    '',
                    '',
                    'ResizeMouseDown' .. window.Config.Id,
                    '',
                    '',
                    'Drag to resize window',
                    6,
                    0
                )
                WindowDragHandler(
                    drawConfig.Id,
                    'resizehs',
                    'ResizeStart' .. window.Config.Id,
                    'ResizeStop' .. window.Config.Id,
                    0
                )
            end

            window.__state.contentTop = titleBounds.Bottom + theme.TitleMargin.Bottom + (theme.BorderWidth)
            window.__state.contentLeft = theme.BorderWidth
        end
    end

    function window.DrawText(options)
        --  id, txt, textStyle, pos, tooltip, action
        options = options or {}

        options.Id = options.Id or (options.Text:gsub('%s+', ''):gsub('%W', ''):sub(1, 10) .. math.random(1, 100000))
        if (options.TextStyle == nil) then
            options.TextStyle = window.GetTextStyle()
            assert(options.TextStyle ~= nil, 'Attempted to draw text with no matching style or default')
        end

        if (type(options.TextStyle) == 'string') then
            options.TextStyle = window.GetTextStyle(options.TextStyle)
        end
        if (type(options.FontColor) == 'string') then
            options.FontColor = ColourNameToRGB(options.FontColor)
        end
        options.Alignment = options.Alignment or {X = swindow.Alignments.Start, Y = swindow.Alignments.Start}
        options.Bounds = options.Bounds
        options.Padding = options.Padding or {Left = 0, Top = 0, Right = 0, Bottom = 0}

        -- so the bounds = a border really ... it needs to be expanded to accomidate padding
        options.Bounds.Left = (options.Bounds.Left or window.__state.contentLeft)
        options.Bounds.Top = options.Bounds.Top or window.__state.contentTop
        options.Bounds.Right = (options.Bounds.Right or window.Config.Width)
        options.Bounds.Bottom =
            (options.Bounds.Bottom or window.Config.Height) + options.Padding.Bottom + options.Padding.Top

        if (options.BackAttached == nil) then
            options.BackAttached = false
        end
        options.Text = options.Text or 'Omnium rerum principia parva sunt'
        local textWidth = window.GetTextWidth(options.TextStyle, options.Text)
        local textHeight = window.GetTextHeight(options.TextStyle)

        -- by default everything is setup for start/start alignments so we just need to tweak positions for the rest
        local left = options.Bounds.Left
        local top = options.Bounds.Top

        if (options.Alignment.X == swindow.Alignments.Start) then
            left = options.Bounds.Left + options.Padding.Left
        end
        if (options.Alignment.X == swindow.Alignments.Center) then
            left = options.Bounds.Left + (((options.Bounds.Right - options.Bounds.Left) / 2) - (textWidth / 2))
        end
        if (options.Alignment.X == swindow.Alignments.End) then
            left = (options.Bounds.Right - textWidth) - options.Padding.Right
        end

        if (options.Alignment.Y == swindow.Alignments.Start) then
            top = options.Bounds.Top + options.Padding.Top
        end

        if (options.Alignment.Y == swindow.Alignments.Center) then
            top =
                (((options.Bounds.Bottom - options.Bounds.Top) / 2) - (textHeight / 2)) -
                ((options.Padding.Top + options.Padding.Bottom) / 2)
        end
        if (options.Alignment.Y == swindow.Alignments.End) then
            top = (options.Bounds.Bottom - textHeight) - options.Padding.Bottom
        end

        -- centering can attempt to force this left .. we will force it back to align left basically
        if (left < options.Bounds.Left) then
            left = options.Bounds.Left + options.Padding.Left
        end

        -- again centering a huge font could mess u up here..we just align top
        if (top < options.Bounds.Top) then
            top = options.Bounds.Top + options.Padding.Top
        end

        local right = options.Bounds.Right - options.Padding.Right
        local bottom = (top + textHeight) + options.Padding.Bottom

        if (right > options.Bounds.Right) then
            right = options.Bounds.Right
        end

        if (options.Bounds.Bottom > (window.Config.Height - theme.BorderWidth) - options.Padding.Bottom) then
            options.Bounds.Bottom = (window.Config.Height - theme.BorderWidth) - options.Padding.Bottom
        end

        if (bottom > options.Bounds.Bottom) then
            bottom = options.Bounds.Bottom
        end

        -- print(json.encode(options.Bounds))
        -- print(json.encode({bottom, left, right, top}))
        -- print('----')

        -- in order to support background colors we need to just draw a rect behind the text
        if (options.BackColor ~= nil or options.TextStyle.BackColor ~= nil) then
            local backcolor = options.BackColor or options.TextStyle.BackColor
            if (type(backcolor) == 'string') then
                backcolor = ColourNameToRGB(backcolor)
            end

            if (options.BackAttached == true) then
                WindowCircleOp(window.Config.Id, 2, left, top, right, bottom, backcolor, 0, 0, backcolor)
            else
                WindowCircleOp(
                    window.Config.Id,
                    2,
                    options.Bounds.Left,
                    options.Bounds.Top,
                    options.Bounds.Right,
                    options.Bounds.Bottom,
                    backcolor,
                    0,
                    0,
                    backcolor
                )
            end
        end

        -- put our text down
        WindowText(
            window.Config.Id,
            options.TextStyle.Name,
            options.Text or 'Omnium enim rerum principia parva sunt',
            left,
            top,
            right,
            bottom,
            options.FontColor or options.TextStyle.Color
        )

        -- add a hotspot if we have an action or tooltip
        if (options.Action ~= nil or options.Tooltip ~= nil) then
            if (options.Action ~= nil) then
                cursor = 1
            end

            callback = ''
            if (options.Action ~= nil) then
                callback = 'ContentClick' .. window.Config.Id .. '_' .. options.Id

                _G[callback] = function(flags)
                    options.Action(options)
                end
            end

            if (options.BackAttached == true) then
                WindowAddHotspot(
                    window.Config.Id,
                    'content' .. options.Id,
                    left,
                    top,
                    right,
                    bottom,
                    '',
                    '',
                    callback,
                    '',
                    '',
                    options.Tooltip or '',
                    cursor, -- hand cursor
                    0
                )
            else
                WindowAddHotspot(
                    window.Config.Id,
                    'content' .. options.Id,
                    options.Bounds.Left,
                    options.Bounds.Top,
                    options.Bounds.Right,
                    options.Bounds.Bottom,
                    '',
                    '',
                    callback,
                    '',
                    '',
                    options.Tooltip or '',
                    cursor, -- hand cursor
                    0
                )
            end
        end

        return options.Bounds
    end

    function window.Destroy()
        WindowDelete(window.Config.Id)
        return nil
    end

    return window
end

swindow.CreateTheme = function(options)
    local theme = {}
    options = options or {}

    theme.BorderWidth = options.BorderWidth or D_BORDERWIDTH
    theme.TitleAlignment = options.TitleAlignment or D_TITLEALIGNMENT
    theme.TitleBackColor = options.TitleBackColor
    theme.TitleMargin = options.TitleMargin or {Left = 0, Top = 0, Right = 0, Bottom = 0}
    theme.BodyMargin = options.BodyMargin or {Left = 3, Top = 3, Right = 3, Bottom = 3}
    theme.ContentMargin = options.ContentMargin or {Left = 3, Top = 3, Right = 3, Bottom = 3}
    theme.ContentPadding = options.ContentPadding or {Left = 3, Top = 3, Right = 3, Bottom = 3}
    theme.ContentAlignment = options.ContentAlignment or {X = swindow.Alignments.Start, swindow.Alignments.Center}
    if (options.BackColor ~= nil and type(options.BackColor) == 'string') then
        options.BackColor = ColourNameToRGB(options.BackColor)
    end

    if (options.BorderColor ~= nil and type(options.BorderColor) == 'string') then
        options.BorderColor = ColourNameToRGB(options.BorderColor)
    end

    theme.BackColor = options.BackColor or ColourNameToRGB('black')
    theme.BorderColor = options.BorderColor or ColourNameToRGB('teal')

    theme.DefaultFont = options.DefaultFont or D_FONT
    theme.DefaultFontSize = options.DefaultFontSize or D_FONTSIZE

    theme.TextStyles = {}

    function theme.AddTextStyle(textStyle)
        if (theme.TextStyles == nil) then
            theme.TextStyles = {}
        end

        -- just to make sure all our values are correctly set we are going to run this through a create text style and pickup anything missing
        textStyle =
            swindow.CreateTextStyle(
            textStyle.Name,
            textStyle.Color,
            textStyle.Default,
            textStyle.FontSize or theme.DefaultFontSize,
            textStyle.Font or theme.DefaultFont,
            textStyle.BackColor
        )

        theme.TextStyles[textStyle.Name] = textStyle
    end

    if (options.TextStyles == nil) then
        theme.AddTextStyle(swindow.CreateTextStyle('text', 'white', true))
    else
        -- again we want to run passed in styles through some validation/correction
        for _, ts in ipairs(options.TextStyles) do
            theme.AddTextStyle(ts)
        end
    end

    return theme
end

swindow.CreateConfig = function(options)
    local config = {}
    if (options == nil) then
        options = {}
    end

    config.Id = options.Id or ('swin_' .. math.random(1, 100000))
    config.Width = options.Width or D_WIDTH
    config.Height = options.Height or D_HEIGHT
    config.Left = options.Left or D_LEFT
    config.Top = options.Top or D_TOP
    config.Title = options.Title or D_TITLE
    config.UpdateInterval = options.UpdateInterval or D_UPDATEINTERVAL
    config.Layer = options.Layer or D_LAYER

    if (options.AllowResize == nil) then
        config.AllowResize = D_ALLOWRESIZE
    else
        config.AllowResize = options.AllowResize
    end

    config.Visible = options.Visible or true

    config.SaveState = options.SaveState or D_SAVESTATE

    return config
end

swindow.CreateTextStyle = function(name, color, isDefault, fontSize, font, backcolor)
    assert(name, 'Name is required to create a text style')
    if (color ~= nil and type(color) == 'string') then
        color = ColourNameToRGB(color)
    end

    return {
        -- leaving some values nil so theme defaults can be used later
        Name = name,
        Color = color or D_FONTCOLOR,
        BackColor = backcolor,
        Font = font,
        FontSize = fontSize,
        Default = isDefault or false
    }
end

return swindow
