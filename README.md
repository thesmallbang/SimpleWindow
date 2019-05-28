# SimpleWindow
A lua library for creating "responsive" windows in mushclient

*This is still very experimental and I am still really working out I think it should work.*



####
##### Creating the simplest window

Step 1: Somewhere before you want your window to first appear
```lua
local simplewindow = require('simplewindow')

mywindow = simplewindow.CreateWindow()
```


Step 2: Add a view
```lua
  local view =
        mywindow.CreateView {
        Name = 'Main'
    }

    -- OnUpdate will be called after the UpdateInterval has passed or a refresh is being forced
    view.OnUpdate = function(v)
        -- we need a container to put our content in
        local mycontainer =
            v.AddContainer {
            Style = simplewindow.ContainerStyles.RowWrap,
            Sizes = {{Name = 'xs', Percent = '100'}}, -- on this container we want 100% width no matter how wide
            ContentSizes = {
                {Name = 'xs', Percent = '100'},
                {Name = 'sm', Percent = '100'},
                {Name = 'md', Percent = '50'},
                {Name = 'lg', Percent = '25'}, -- anything large and up we stick with 25% width
            },
            TextStyle = 'body'
            -- for more on text styles see the configuration section.
        }

        mycontainer.AddContent {
            Text = 'Hola'
        }
        mycontainer.AddContent {
            Text = 'Hello',
            BackColor = 'red'
        }
        mycontainer.AddContent {
            Text = 'Aloha',
            TextStyle = 'title'
        }
    end

    mywindow.RegisterView(view)
```


Step 3: Enable updating the window
```lua
function OnPluginTick ()
    if (mywindow) then
        mywindow.Tick()
    end
end
```


##### Configuration and Theming

```lua

mywindow = simplewindow.CreateWindow(
    simplewindow.CreateConfig {
        Id = 'hellowindow',
        Title = 'Hello Window {viewname}'
    },
     simplewindow.CreateTheme {
        TextStyles = {
        -- function(name, color, isDefault, fontSize, font, backcolor)
        simplewindow.CreateTextStyle('title', 'teal', false, 10),
        simplewindow.CreateTextStyle('header', 'teal'),
        simplewindow.CreateTextStyle('body', 'white', true)
    })
```


##### Configuration Options
| Param Name     | Description                                                         | DefaultValue |
| -------------- | ------------------------------------------------------------------- | ------------ |
| Id             | A unique id for your window.                                        |
| UpdateInterval | How often should the callback for refreshing data and drawing occur |
| Layer          | The higher the layer the more likely to draw ontop of other windows |
| Title          | Text to display at the top of your window.                          |
| TitleAlignment | simplewindow.Alignments.(Start,Center,End)                          |
| Width          | The default width of the window                                     |
| Height         | The default height of the window                                    |
| Left           | The distance from the left side of the screen                       |
| Top            | The distance from the top of the screen                             |
| AllowResize    | Allow the window to be resized by the user                          |
| SaveState      | Automatically save/load the last size/position the window was in    |
| --             | These settings will be moved to theme soon                          |
| BorderWidth    | How wide of the border pen. Yes it should be in theme but.. not yet |
| BodyPadding    | The content in the view is what distance from the border            |
| TitlePadding   | The title what distance from the borders                            |
| BodyPadding    | The content in the view is what distance from the border            |



##### Theme Options
| Param Name      | Description                                     | DefaultValue |
| --------------- | ----------------------------------------------- | ------------ |
| BackColor       | string or number for window background color    |
| BorderColor     | string or number for window border color        |
| DefaultFont     | Font name to use when nothing has been set      |
| DefaultFontSize | Font size to use when nothing has been set      |
| TextStyles[]    | Name, Color, Default, FontSize, Font, BackColor |


##### Container Options
| Param Name   | Description                                                  | DefaultValue |
| ------------ | ------------------------------------------------------------ | ------------ |
| Name         | a name for the container pretty useless atm except logging   |
| Style        | simplewindow.ContainerStyles. (Column, Row, RowWrap)         |
| Sizes        | specify the sizes for the container at specific width states |
| ContentSizes | default size for content at specific width states            |
| TextStyle    | default textstyle for content                                |

##### Content Options
| Param Name      | Description                                                 | DefaultValue |
| --------------- | ----------------------------------------------------------- | ------------ |
| Id              | unique id for the content, used in callbacks from links etc | Random       |
| Text            | What text is in the content                                 |
| Alignment.(X,Y) | simplewindow.Alignments.(Start,Center,End)                  | Start        |
| TextStyle       |                                                             |
| Sizes           |                                                             |
| BackColor       |                                                             |
| FontColor       |                                                             |
| Action          | Function callback on content click                          |
| Tooltip         | Tooltip for content mouse hover                             |


### Structure
| Object                          | Description                                                                                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Window                          | The parent object                                                                                                            |
| Window.Config                   | The main configuration object                                                                                                |
| Window.Theme                    | Font / color information                                                                                                     |
| Window.View[]                   | An array of views can be added to a window to give the user an option of displaying completely different sets of information |
| Window.View.Container[]         | Each container is a grouping of text                                                                                         |
| Window.View.Container.Content[] | Text                                                                                                                         |


