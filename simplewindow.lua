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
local D_BORDERWIDTH = 3
local D_TITLEALIGNMENT = swindow.Alignments.Start
local D_SAVESTATE = true
local D_ALLOWRESIZE = true
local D_MINWIDTH = 100
local D_MINHEIGHT = 50
local D_CONTAINERSTYLE = swindow.ContainerStyles.RowWrap
local D_CONTAINERALIGNMENT_X = swindow.Alignments.Start
local D_CONTAINERALIGNMENT_Y = swindow.Alignments.Center

swindow.DefaultClasses = {}

function string:split(sep)
    local sep, fields = sep or ':', {}
    local pattern = string.format('([^%s]+)', sep)
    self:gsub(
        pattern,
        function(c)
            fields[#fields + 1] = c
        end
    )
    return fields
end
function swindow.CreateDefaultClasses()
    local classes = {}

    -- blank name is a base we are applying first
    table.insert(
        classes,
        swindow.CreateClass {
            Name = '',
            Font = D_FONT,
            FontSize = D_FONTSIZE,
            FontColor = D_FONTCOLOR,
            Padding = 1,
            Margin = 0,
            Alignment = {X = D_CONTAINERALIGNMENT_X, Y = D_CONTAINERALIGNMENT_Y}
        }
    )

    -- text decorators
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'bold',
            Bold = true
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'underline',
            Underline = true
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'strike',
            Strikeout = true
        }
    )

    -- some basic margins
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'm-sm',
            Margin = 1
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'm-md',
            Margin = 3
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'm-lg',
            Margin = 5
        }
    )

    -- some basic padding
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'p-sm',
            Margin = 1
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'p-md',
            Margin = 3
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'p-lg',
            Margin = 5
        }
    )

    -- basic colour scheme
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'primary',
            FontColor = 'white'
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'primary-b',
            BackColor = 'white'
        }
    )

    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'secondary',
            FontColor = 'teal'
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'secondary-b',
            BackColor = 'teal'
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'warning',
            FontColor = 'red'
        }
    )
    table.insert(
        classes,
        swindow.CreateClass {
            Name = 'warning-b',
            BackColor = 'red'
        }
    )

    -- some alignment

    return classes
end

function SplitRGB(hx)
    hx = tostring(hx):gsub('#', '')
    return tonumber('0x' .. hx:sub(1, 2)), tonumber('0x' .. hx:sub(3, 4)), tonumber('0x' .. hx:sub(5, 6))
end

function ColorToRGBHex(color)
    if (color == nil) then
        color = 0
    end
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
    return tonumber(hexadecimal, 16)
end

function swindow.ColorAdjust(color, percent)
    if (type(color) == 'string') then
        color = ColourNameToRGB(color)
    end
    if (type(color) == 'table') then
        color = swindow.MergeRGB(color)
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

function swindow.Paint(win)
    if (win.__state.hasPaintBuffer == true) then
        -- https://github.com/fiendish/aardwolfclientpackage/wiki/Repaint-Buffer
        BroadcastPlugin(999, 'repaint')
    else
        Redraw()
    end
end

function swindow.CreateWindow(config, theme)
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
            fontsLoaded = {},
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

    function window.GetTextWidth(styling, text)
        return WindowTextWidth(window.Config.Id, styling.FontKey, text, false)
    end

    function window.GetFontKey(styling)
        return (styling.Font or 'f') ..
            '_' ..
                (styling.FontSize or 'fs') ..
                    '_' ..
                        tostring((styling.Bold or 'false')) ..
                            '_' ..
                                tostring((styling.Italic or 'false')) ..
                                    '_' ..
                                        tostring((styling.Underline or 'false')) ..
                                            '_' ..
                                                tostring((styling.Strikeout or 'false')) ..
                                                    '_' .. (styling.Charset or '') .. '_' .. (styling.FontFamily or '')
    end

    function window.GetMergedClass(classNames)
        local result = {}

        if (classNames == nil) then
            print('no class names')
            return result
        end

        if (type(classNames) == 'string') then
            classNames = classNames:split(' ')
        end

        local loadeddefault = false
        for _, name in ipairs(classNames) do
            for _, c in pairs(window.Theme.Classes) do
                if ((loadeddefault == false and c.Name == '') or string.lower(name) == string.lower(c.Name)) then
                    if (c.Name == '') then
                        loadeddefault = true
                    end
                    for i, s in pairs(c) do
                        local handled = false
                        if (s ~= nil) then
                            if (handled == false) then
                                result[i] = s or result[i]
                            end
                        end
                    end
                end
            end
        end

        -- attach a font key here
        result.FontKey = window.GetFontKey(result)

        local found = false
        for _, l in ipairs(window.__state.fontsLoaded) do
            if (found == false and l == result.FontKey) then
                found = true
            end
        end
        if (found == false) then
            local addresult =
                WindowFont(
                window.Config.Id,
                result.FontKey,
                result.Font,
                result.FontSize,
                result.Bold,
                result.Italic,
                result.Underline,
                result.Strikeout,
                result.Charset,
                result.FontFamily
            )
            if (addresult == 0) then
                table.insert(window.__state.fontsLoaded, result.FontKey)
            end
        end
        return result
    end

    function window.GetTextHeight(styling)
        return WindowFontInfo(window.Config.Id, styling.FontKey, 1)
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
                Bounds = {Left = 0, Top = 0, Right = 0, Bottom = 0},
                Classes = {'warning'}
            }
            return
        end

        if (view == nil) then
            window.DrawText {
                Text = 'Invalid view state',
                Bounds = {Left = 0, Top = 0, Right = 0, Bottom = 0},
                Classes = {'warning'}
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
                {Name = 'sm', From = 150},
                {Name = 'md', From = 250},
                {Name = 'lg', From = 400},
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

            local bodyStyle = window.GetMergedClass(window.Theme.BodyClasses)

            local viewbounds = {
                Left = window.Theme.BorderWidth + bodyStyle.Margin.Left,
                Top = window.__state.contentTop + bodyStyle.Margin.Top,
                Right = (window.Config.Width - window.Theme.BorderWidth) - bodyStyle.Margin.Right,
                Bottom = (window.Config.Height - window.Theme.BorderWidth) - bodyStyle.Margin.Bottom
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
            local styling = window.GetMergedClass(content.Classes)
            local contentheight = content.Height or styling.Height or (window.GetTextHeight(styling))
            local margin = content.Margin or styling.Margin

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
            contentbounds.Bottom = contentbounds.Top + margin.Top + contentheight + margin.Bottom

            styling.Alignment = content.Alignment or styling.Alignment
            styling.Padding = content.Padding or styling.Padding
            styling.Margin = margin
            styling.FontColor = content.FontColor or styling.FontColor
            styling.BackColor = content.BackColor or styling.BackColor
            styling.Font = content.Font or styling.Font
            styling.FontSize = content.FontSize or styling.FontSize
            styling.Charset = content.Charset or styling.Charset
            styling.FontFamily = content.FontFamily or styling.FontFamily
            -- update the font key to account for all the changes
            styling.FontKey = window.GetFontKey(styling)

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
                Styling = styling,
                Bounds = textbounds,
                Tooltip = content.Tooltip,
                BackAttached = content.BackAttached,
                Action = content.Action
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
            container.Classes = options.Classes
            container.ContentSizes = options.ContentSizes
            container.ContentClasses = options.ContentClasses or theme.ContentClasses
            container.Height = options.Height
            container.Content = options.Content or {}
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
                content.Padding = options.Padding
                content.BackAttached = options.BackAttached

                content.Classes = options.Classes or container.ContentClasses

                content.Alignment = options.Alignment

                if (type(options.Classes) == 'string') then
                    options.Classes = options.Classes:split(' ')
                end

                content.Sizes =
                    options.Sizes or
                    (container.ContentSizes or
                        {
                            {Name = 'xs', Percent = 100}
                        })

                content.BackColor = options.BackColor
                content.FontColor = options.FontColor
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
        end

        local styling = window.GetMergedClass(window.Theme.TitleClasses)
        local bodystyling = window.GetMergedClass(window.Theme.BodyClasses)
        -- create our window
        WindowCreate(
            drawConfig.Id,
            drawConfig.Left,
            drawConfig.Top,
            drawConfig.Width,
            drawConfig.Height,
            0,
            miniwin.create_absolute_location + miniwin.create_keep_hotspots,
            swindow.SantizeColor(styling.BackColor or 0)
        )

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
            swindow.SantizeColor(window.Theme.BorderColor),
            6,
            window.Theme.BorderWidth,
            swindow.SantizeColor(bodystyling.BackColor)
        )

        -- draw our window title
        if (drawConfig.Title ~= nil) then
            local v = window.__state.views[0] or {}
            local vname = v.Name or ''

            local tstyle = window.GetMergedClass(window.Theme.TitleClasses)
            local title = string.gsub(drawConfig.Title, ' {viewname}', vname)

            local textHeight = window.GetTextHeight(tstyle)
            local titleBounds = {
                Left = window.Theme.BorderWidth,
                Top = window.Theme.BorderWidth,
                Right = drawConfig.Width - window.Theme.BorderWidth
            }

            titleBounds.Bottom = titleBounds.Top + textHeight

            -- shade it darker
            local colorBR = swindow.ColorAdjust(window.Theme.BorderColor, -.3)

            local textBounds = titleBounds
            textBounds.Top = textBounds.Top + tstyle.Margin.Top
            textBounds.Left = textBounds.Left + tstyle.Margin.Left
            textBounds.Right = textBounds.Right - tstyle.Margin.Right
            textBounds.Bottom = textBounds.Bottom + tstyle.Margin.Bottom

            local drawnPosition =
                window.DrawText {
                Text = title,
                Styling = tstyle,
                Bounds = textBounds,
                TextStyle = tstyle
            }

            -- -- draw title line with darker shade
            WindowLine(
                drawConfig.Id,
                window.Theme.BorderWidth + (window.Theme.BorderWidth / 2),
                titleBounds.Bottom + tstyle.Margin.Bottom + (window.Theme.BorderWidth / 2),
                (drawConfig.Width - window.Theme.BorderWidth) - (window.Theme.BorderWidth / 2),
                titleBounds.Bottom + tstyle.Margin.Bottom + (window.Theme.BorderWidth / 2),
                colorBR,
                0x0100,
                window.Theme.BorderWidth
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
                    drawConfig.Width - (window.Theme.BorderWidth),
                    drawConfig.Height - (window.Theme.BorderWidth) - 2,
                    drawConfig.Width - (window.Theme.BorderWidth) - 2,
                    drawConfig.Height - (window.Theme.BorderWidth),
                    swindow.SantizeColor(window.Theme.BorderColor),
                    0 and 0x1000,
                    1
                )
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - (window.Theme.BorderWidth),
                    drawConfig.Height - (window.Theme.BorderWidth) - 5,
                    drawConfig.Width - (window.Theme.BorderWidth) - 5,
                    drawConfig.Height - (window.Theme.BorderWidth),
                    swindow.SantizeColor(window.Theme.BorderColor),
                    0 and 0x1000,
                    1
                )
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - (window.Theme.BorderWidth),
                    drawConfig.Height - (window.Theme.BorderWidth) - 8,
                    drawConfig.Width - (window.Theme.BorderWidth) - 8,
                    drawConfig.Height - (window.Theme.BorderWidth),
                    swindow.SantizeColor(window.Theme.BorderColor),
                    0 and 0x1000,
                    1
                )

                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - (window.Theme.BorderWidth),
                    drawConfig.Height - (window.Theme.BorderWidth) - 11,
                    drawConfig.Width - (window.Theme.BorderWidth) - 11,
                    drawConfig.Height - (window.Theme.BorderWidth),
                    swindow.SantizeColor(window.Theme.BorderColor),
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

                    local styling = window.GetMergedClass(window.Theme.BodyClasses)
                    WindowCircleOp(
                        drawConfig.Id,
                        2,
                        0,
                        0,
                        drawConfig.Width,
                        drawConfig.Height,
                        swindow.SantizeColor(styling.BackColor or 0),
                        0,
                        window.Theme.BorderWidth,
                        swindow.SantizeColor(styling.BackColor or 0),
                        6
                    )

                    local txt = 'X: ' .. window.Config.Width .. ' Y: ' .. window.Config.Height

                    local textwidth = window.GetTextWidth(styling, txt)

                    styling.Alignment = {
                        X = swindow.Alignments.Center,
                        Y = swindow.Alignments.Center
                    }

                    window.DrawText {
                        Text = txt,
                        Styling = styling,
                        Bounds = {
                            Left = 0,
                            Top = 0,
                            Right = window.Config.Width,
                            Bottom = window.Config.Height
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
                    drawConfig.Width - (window.Theme.BorderWidth) - 12,
                    drawConfig.Height - (window.Theme.BorderWidth) - 12,
                    drawConfig.Width - (window.Theme.BorderWidth),
                    drawConfig.Height - (window.Theme.BorderWidth),
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

            window.__state.contentTop = titleBounds.Bottom + tstyle.Margin.Bottom + (window.Theme.BorderWidth)
            window.__state.contentLeft = window.Theme.BorderWidth
        end
    end

    function window.DrawText(options)
        --  id, txt, textStyle, pos, tooltip, action
        options = options or {}
        options.Id = options.Id or (options.Text:gsub('%s+', ''):gsub('%W', ''):sub(1, 10) .. math.random(1, 100000))

        assert(
            options.Styling ~= nil or options.Classes ~= nil,
            'Styling or Classes is required to draw text. Check your (theme|container|content).Classes configurations'
        )

        if (options.Styling == nil) then
            options.Classes = options.Classes or theme.Classes
            options.Styling = window.GetMergedClass(options.Classes)
        end

        local styling = options.Styling

        -- is this font loaded?
        local found = false
        for _, l in ipairs(window.__state.fontsLoaded) do
            if (found == false and l == styling.FontKey) then
                found = true
            end
        end
        if (found == false) then
            WindowFont(
                window.Config.Id,
                styling.FontKey,
                styling.Font,
                styling.FontSize,
                styling.Bold,
                styling.Italic,
                styling.Underline,
                styling.Strikeout,
                styling.Charset,
                styling.FontFamily
            )
            table.insert(window.__state.fontsLoaded, styling.FontKey)
        end

        options.Bounds = options.Bounds

        -- so the bounds = a border really ... it needs to be expanded to accomidate padding
        options.Bounds.Left = (options.Bounds.Left or window.__state.contentLeft)
        options.Bounds.Top = options.Bounds.Top or window.__state.contentTop
        options.Bounds.Right = (options.Bounds.Right or window.Config.Width)
        options.Bounds.Bottom =
            (options.Bounds.Bottom or window.Config.Height) + styling.Padding.Bottom + styling.Padding.Top

        if (options.BackAttached == nil) then
            options.BackAttached = false
        end

        options.Text = options.Text or 'Omnium rerum principia parva sunt'

        local textWidth = window.GetTextWidth(styling, options.Text)
        local textHeight = window.GetTextHeight(styling)

        -- by default everything is setup for start/start alignments so we just need to tweak positions for the rest
        local left = options.Bounds.Left
        local top = options.Bounds.Top

        if (styling.Alignment.X == swindow.Alignments.Start) then
            left = options.Bounds.Left + styling.Padding.Left
        end
        if (styling.Alignment.X == swindow.Alignments.Center) then
            left = options.Bounds.Left + (((options.Bounds.Right - options.Bounds.Left) / 2) - (textWidth / 2))
        end
        if (styling.Alignment.X == swindow.Alignments.End) then
            left = (options.Bounds.Right - textWidth) - styling.Padding.Right
        end

        if (styling.Alignment.Y == swindow.Alignments.Start) then
            top = options.Bounds.Top + styling.Padding.Top
        end

        if (styling.Alignment.Y == swindow.Alignments.Center) then
            top =
                (((options.Bounds.Bottom - options.Bounds.Top) / 2) - (textHeight / 2)) -
                ((styling.Padding.Top + styling.Padding.Bottom) / 2)
        end
        if (styling.Alignment.Y == swindow.Alignments.End) then
            top = (options.Bounds.Bottom - textHeight) - styling.Padding.Bottom
        end

        -- centering can attempt to force this left .. we will force it back to align left basically
        if (left < options.Bounds.Left) then
            left = options.Bounds.Left + styling.Padding.Left
        end

        -- again centering a huge font could mess u up here..we just align top
        if (top < options.Bounds.Top) then
            top = options.Bounds.Top + styling.Padding.Top
        end

        local right = options.Bounds.Right - styling.Padding.Right
        local bottom = (top + textHeight) + styling.Padding.Bottom

        if (right > options.Bounds.Right) then
            right = options.Bounds.Right
        end

        if (options.Bounds.Bottom > (window.Config.Height - window.Theme.BorderWidth) - styling.Padding.Bottom) then
            options.Bounds.Bottom = (window.Config.Height - window.Theme.BorderWidth) - styling.Padding.Bottom
        end

        if (bottom > options.Bounds.Bottom) then
            bottom = options.Bounds.Bottom
        end

        -- in order to support background colors we need to just draw a rect behind the text
        if (styling.BackColor ~= nil) then
            local backcolor = swindow.SantizeColor(styling.BackColor)
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
            styling.FontKey,
            options.Text or 'Omnium enim rerum principia parva sunt',
            left,
            top,
            right,
            bottom,
            swindow.SantizeColor(styling.FontColor)
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

function swindow.CreateClass(options)
    assert(options.Name, 'Name is required to create a class')
    local cls = {}
    cls.Name = options.Name
    cls.Font = options.Font
    cls.FontFamily = options.FontFamily
    cls.FontSize = options.FontSize
    cls.Bold = options.Bold
    cls.Italic = options.Italic
    cls.Underline = options.Underline
    cls.Height = options.Height
    cls.BackColor = options.BackColor
    cls.FontColor = options.FontColor
    cls.Strikeout = options.Strikeout
    cls.Alignment = options.Alignment
    cls.Padding = options.Padding
    cls.Margin = options.Margin

    if (type(cls.Padding) == 'number') then
        cls.Padding = {Left = cls.Padding, Top = cls.Padding, Right = cls.Padding, Bottom = cls.Padding}
    end
    if (type(cls.Margin) == 'number') then
        cls.Margin = {Left = cls.Margin, Top = cls.Margin, Right = cls.Margin, Bottom = cls.Margin}
    end
    if (type(cls.Alignment) == 'number') then
        cls.Alignment = {X = cls.Alignment, Y = cls.Alignment}
    end

    return cls
end

function swindow.CreateTheme(options)
    local theme = {}
    options = options or {}
    theme.BorderWidth = options.BorderWidth or D_BORDERWIDTH
    theme.BorderColor = options.BorderColor or D_BORDERCOLOR

    theme.TitleClasses = options.TitleClasses or {''}
    theme.BodyClasses = options.BodyClasses or {''}
    theme.ContentClasses = options.ContentClasses or {''}
    theme.Classes = swindow.CreateDefaultClasses() -- add our default classes

    if (options.BorderColor ~= nil and type(options.BorderColor) == 'string') then
        options.BorderColor = ColourNameToRGB(options.BorderColor)
    end

    function theme.AddClass(cls)
        theme.Classes[cls.Name] = cls
    end

    if (options.Classes == nil) then
        swindow.CreateClass {
            Name = '',
            Font = D_FONT,
            FontColor = D_FONTCOLOR,
            FontSize = D_FONTSIZE,
            BackColor = D_BACKCOLOR,
            Margin = 0,
            Padding = 0,
            Alignment = {X = D_CONTAINERALIGNMENT_X, Y = D_CONTAINERALIGNMENT_Y}
        }
    else
        for _, c in pairs(options.Classes) do
            theme.AddClass(c)
        end
    end

    return theme
end

function swindow.SantizeColor(color)
    local t = type(color)
    if (t == 'string') then
        if (color.sub(1, 1) == '#') then
            local hx = tostring(hx):gsub('#', '')
            return tonumber('0x' .. hx:sub(1, 2) .. hx:sub(3, 4)) .. hx:sub(5, 6)
        else
            return ColourNameToRGB(color)
        end
    end
    if (t == 'table') then
        return swindow.MergeRGB(color)
    end
    if (t == 'number') then
        return color
    end

    return D_BACKCOLOR
end

function swindow.CreateConfig(options)
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

return swindow
