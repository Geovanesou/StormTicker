-- ==============================================================================
-- StormTicker Pro - Settings Manager Helper Script
-- ==============================================================================

function UpdateUI()
    local tab = SKIN:GetVariable('CurrentTab', '1')
    
    -- Highlight active tab button
    for i = 1, 10 do
        if tostring(i) == tab then
            SKIN:Bang('!SetOption', 'MeterTab' .. i, 'SolidColor', '30,41,59,255')
            SKIN:Bang('!SetOption', 'MeterTab' .. i, 'FontColor', '241,245,249,255')
        else
            SKIN:Bang('!SetOption', 'MeterTab' .. i, 'SolidColor', '15,23,42,255')
            SKIN:Bang('!SetOption', 'MeterTab' .. i, 'FontColor', '148,163,184,255')
        end
    end
    
    -- Update Text Fields
    local tagVal = SKIN:GetVariable('FeedTag' .. tab, '')
    local urlVal = SKIN:GetVariable('FeedURL' .. tab, '')
    SKIN:Bang('!SetOption', 'MeterValTag', 'Text', tagVal)
    SKIN:Bang('!SetOption', 'MeterValUrl', 'Text', urlVal)

    -- Update Toggle
    local enabled = SKIN:GetVariable('FeedEnabled' .. tab, '1')
    if enabled == '1' then
        SKIN:Bang('!SetOption', 'MeterEnableToggle', 'Text', '[ ON ]  Ativado')
        SKIN:Bang('!SetOption', 'MeterEnableToggle', 'FontColor', '52,211,153,255')
    else
        SKIN:Bang('!SetOption', 'MeterEnableToggle', 'Text', '[ OFF ]  Desativado')
        SKIN:Bang('!SetOption', 'MeterEnableToggle', 'FontColor', '148,163,184,255')
    end
    
    -- Update Speed Buttons
    local speed = tonumber(SKIN:GetVariable('FeedSpeed' .. tab, '1.0')) or 1.0
    
    SKIN:Bang('!SetOption', 'MeterSpeedSlow', 'SolidColor', '30,41,59,255')
    SKIN:Bang('!SetOption', 'MeterSpeedSlow', 'FontColor', '148,163,184,255')
    SKIN:Bang('!SetOption', 'MeterSpeedNormal', 'SolidColor', '30,41,59,255')
    SKIN:Bang('!SetOption', 'MeterSpeedNormal', 'FontColor', '148,163,184,255')
    SKIN:Bang('!SetOption', 'MeterSpeedFast', 'SolidColor', '30,41,59,255')
    SKIN:Bang('!SetOption', 'MeterSpeedFast', 'FontColor', '148,163,184,255')
    
    if speed == 0.5 then
        SKIN:Bang('!SetOption', 'MeterSpeedSlow', 'SolidColor', '14,165,233,255')
        SKIN:Bang('!SetOption', 'MeterSpeedSlow', 'FontColor', '255,255,255,255')
    elseif speed == 1.5 then
        SKIN:Bang('!SetOption', 'MeterSpeedFast', 'SolidColor', '14,165,233,255')
        SKIN:Bang('!SetOption', 'MeterSpeedFast', 'FontColor', '255,255,255,255')
    else
        SKIN:Bang('!SetOption', 'MeterSpeedNormal', 'SolidColor', '14,165,233,255')
        SKIN:Bang('!SetOption', 'MeterSpeedNormal', 'FontColor', '255,255,255,255')
    end
    
    UpdateIntervalUI()
end

function UpdateIntervalUI()
    local interval = tonumber(SKIN:GetVariable('UpdateIntervalMinutes', '15')) or 15
    local intervals = { 15, 30, 60, 120, 360 }
    
    for _, m in ipairs(intervals) do
        local bgMeter = 'MeterInt' .. m .. '_Bg'
        local txtMeter = 'MeterInt' .. m .. '_Text'
        
        if m == interval then
            SKIN:Bang('!SetOption', bgMeter, 'Shape', 'Rectangle 0,0,50,24,4 | Fill Color 14,165,233,255 | StrokeWidth 1 | Stroke Color 56,189,248,255')
            SKIN:Bang('!SetOption', txtMeter, 'FontColor', '255,255,255,255')
        else
            SKIN:Bang('!SetOption', bgMeter, 'Shape', 'Rectangle 0,0,50,24,4 | Fill Color 30,41,59,255 | StrokeWidth 1 | Stroke Color 51,65,85,255')
            SKIN:Bang('!SetOption', txtMeter, 'FontColor', '148,163,184,255')
        end
    end
end

function SetInterval(minutes)
    minutes = tonumber(minutes) or 15
    SKIN:Bang('!WriteKeyValue', 'Variables', 'UpdateIntervalMinutes', tostring(minutes), '#@#Config.inc')
    SKIN:Bang('!SetVariable', 'UpdateIntervalMinutes', tostring(minutes))
    
    -- Cada minuto corresponde a 3.000 ciclos de 20ms
    local baseCycles = minutes * 3000
    local iniFile = SKIN:GetVariable('SKINSPATH') .. 'StormTicker\\StormTicker.ini'
    
    for f = 1, 10 do
        local staggered = baseCycles + (f - 1) * 150
        SKIN:Bang('!WriteKeyValue', 'MeasureFeed' .. f, 'UpdateRate', tostring(staggered), iniFile)
    end
    
    UpdateIntervalUI()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
    SKIN:Bang('!Refresh', 'StormTicker', 'StormTicker.ini')
end

function ToggleFeed()
    local tab = SKIN:GetVariable('CurrentTab', '1')
    local current = SKIN:GetVariable('FeedEnabled' .. tab, '1')
    local nextVal = (tostring(current) == '1') and '0' or '1'
    SKIN:Bang('!WriteKeyValue', 'Variables', 'FeedEnabled' .. tab, nextVal, '#@#Feeds.inc')
    SKIN:Bang('!SetVariable', 'FeedEnabled' .. tab, nextVal)
    UpdateUI()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
    SKIN:Bang('!Refresh', 'StormTicker', 'StormTicker.ini')
end

function SetSpeed(speedVal)
    local tab = SKIN:GetVariable('CurrentTab', '1')
    SKIN:Bang('!WriteKeyValue', 'Variables', 'FeedSpeed' .. tab, tostring(speedVal), '#@#Feeds.inc')
    SKIN:Bang('!SetVariable', 'FeedSpeed' .. tab, tostring(speedVal))
    UpdateUI()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
    SKIN:Bang('!Refresh', 'StormTicker', 'StormTicker.ini')
end

function EditField(fieldType)
    local tab = SKIN:GetVariable('CurrentTab', '1')
    if fieldType == 'url' then
        SKIN:Bang('["#@#Scripts\\EditUrl' .. tab .. '.bat"]')
    else
        SKIN:Bang('["#@#Scripts\\EditTag' .. tab .. '.bat"]')
    end
end
