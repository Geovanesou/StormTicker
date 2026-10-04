-- ==============================================================================
-- StormTicker - Settings Manager Helper Script (Standard Edition)
-- ==============================================================================

-- v1.2.0: persiste CurrentTab no proprio Settings.ini para que qualquer
-- refresh (self, RefreshApp, EditFeed.ps1) retorne a mesma aba
function SetTab(tabId)
    SKIN:Bang('!SetVariable', 'CurrentTab', tostring(tabId))
    SKIN:Bang('!WriteKeyValue', 'Variables', 'CurrentTab', tostring(tabId))
    UpdateUI()
end

function UpdateUI()
    local tab = SKIN:GetVariable('CurrentTab', '0')

    -- Highlight da aba de Opcoes Gerais
    if tab == '0' then
        SKIN:Bang('!SetOption', 'MeterTab0', 'SolidColor', '30,41,59,255')
        SKIN:Bang('!SetOption', 'MeterTab0', 'FontColor', '251,191,36,255')
    else
        SKIN:Bang('!SetOption', 'MeterTab0', 'SolidColor', '15,23,42,255')
        SKIN:Bang('!SetOption', 'MeterTab0', 'FontColor', '148,163,184,255')
    end

    -- Highlight da aba de Clima
    if tab == 'weather' then
        SKIN:Bang('!SetOption', 'MeterTabWeather', 'SolidColor', '30,41,59,255')
        SKIN:Bang('!SetOption', 'MeterTabWeather', 'FontColor', '56,189,248,255')
    else
        SKIN:Bang('!SetOption', 'MeterTabWeather', 'SolidColor', '15,23,42,255')
        SKIN:Bang('!SetOption', 'MeterTabWeather', 'FontColor', '148,163,184,255')
    end

    local tabNum = tonumber(tab) or -1

    -- Highlight active channel buttons
    for i = 1, 10 do
        if i == tabNum then
            SKIN:Bang('!SetOption', 'MeterTab' .. i, 'SolidColor', '30,41,59,255')
            if i >= 4 then
                SKIN:Bang('!SetOption', 'MeterTab' .. i, 'FontColor', '245,158,11,255')
            else
                SKIN:Bang('!SetOption', 'MeterTab' .. i, 'FontColor', '241,245,249,255')
            end
        else
            SKIN:Bang('!SetOption', 'MeterTab' .. i, 'SolidColor', '15,23,42,255')
            if i >= 4 then
                SKIN:Bang('!SetOption', 'MeterTab' .. i, 'FontColor', '180,130,50,220')
            else
                SKIN:Bang('!SetOption', 'MeterTab' .. i, 'FontColor', '148,163,184,255')
            end
        end
    end
    
    if tab == '0' then
        -- Opcoes Gerais: idioma, tema e modo de exibicao
        SKIN:Bang('!SetOption', 'MeterHeader', 'Text', '#Lang_HeaderGeneral#')
        SKIN:Bang('!HideMeterGroup', 'ChannelEditGroup')
        SKIN:Bang('!HideMeterGroup', 'ProLockGroup')
        SKIN:Bang('!HideMeterGroup', 'WeatherGroup')
        SKIN:Bang('!ShowMeterGroup', 'GeneralGroup')
        UpdateGeneralUI()
    elseif tab == 'weather' then
        -- Aba Exclusiva de Clima
        SKIN:Bang('!SetOption', 'MeterHeader', 'Text', '#Lang_HeaderWeather#')
        SKIN:Bang('!HideMeterGroup', 'ChannelEditGroup')
        SKIN:Bang('!HideMeterGroup', 'ProLockGroup')
        SKIN:Bang('!HideMeterGroup', 'GeneralGroup')
        SKIN:Bang('!ShowMeterGroup', 'WeatherGroup')
        UpdateWeatherUI()
    elseif tabNum >= 1 and tabNum <= 3 then
        -- Modo Edição Normal (Canais 1 a 3)
        SKIN:Bang('!SetOption', 'MeterHeader', 'Text', '#Lang_HeaderChannel# ' .. tabNum)
        SKIN:Bang('!HideMeterGroup', 'GeneralGroup')
        SKIN:Bang('!HideMeterGroup', 'WeatherGroup')
        SKIN:Bang('!ShowMeterGroup', 'ChannelEditGroup')
        SKIN:Bang('!HideMeterGroup', 'ProLockGroup')
        
        -- Update Text Fields
        local tagVal = SKIN:GetVariable('FeedTag' .. tabNum, '')
        local urlVal = SKIN:GetVariable('FeedURL' .. tabNum, '')
        SKIN:Bang('!SetOption', 'MeterValTag', 'Text', tagVal)
        SKIN:Bang('!SetOption', 'MeterValUrl', 'Text', urlVal)

        -- Update Toggle
        local enabled = SKIN:GetVariable('FeedEnabled' .. tabNum, '1')
        if enabled == '1' then
            SKIN:Bang('!SetOption', 'MeterEnableToggle', 'Text', SKIN:GetVariable('Lang_StateEnabled', '[ ON ]  Ativado'))
            SKIN:Bang('!SetOption', 'MeterEnableToggle', 'FontColor', '52,211,153,255')
        else
            SKIN:Bang('!SetOption', 'MeterEnableToggle', 'Text', SKIN:GetVariable('Lang_StateDisabled', '[ OFF ]  Desativado'))
            SKIN:Bang('!SetOption', 'MeterEnableToggle', 'FontColor', '148,163,184,255')
        end
        
        -- Update Speed Buttons
        local speed = tonumber(SKIN:GetVariable('FeedSpeed' .. tabNum, '1.0')) or 1.0
        
        for _, sp in ipairs({{'MeterSpeedSlow', 0.5}, {'MeterSpeedNormal', 1.0}, {'MeterSpeedFast', 1.5}}) do
            local sel = (speed == sp[2])
            SKIN:Bang('!SetOption', sp[1] .. '_Bg', 'Shape', 'Rectangle 0,0,70,26,4 | Fill Color ' .. (sel and '245,158,11,255' or '30,41,59,255') .. ' | StrokeWidth 1 | Stroke Color ' .. (sel and '251,191,36,255' or '51,65,85,255'))
            SKIN:Bang('!SetOption', sp[1], 'FontColor', sel and '255,255,255,255' or '148,163,184,255')
        end
    else
        -- Modo Showcase Pro (Canais 4 a 10 Bloqueados com CTA)
        SKIN:Bang('!SetOption', 'MeterHeader', 'Text', '#Lang_HeaderChannel# ' .. tabNum .. ' #Lang_HeaderProSuffix#')
        SKIN:Bang('!HideMeterGroup', 'ChannelEditGroup')
        SKIN:Bang('!HideMeterGroup', 'GeneralGroup')
        SKIN:Bang('!HideMeterGroup', 'WeatherGroup')
        SKIN:Bang('!ShowMeterGroup', 'ProLockGroup')
    end
    
    UpdateIntervalUI()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function UpdateIntervalUI()
    local interval = tonumber(SKIN:GetVariable('UpdateIntervalMinutes', '15')) or 15
    local intervals = { 15, 30, 60, 120, 360 }
    
    for _, m in ipairs(intervals) do
        local sel = (m == interval)
        SKIN:Bang('!SetOption', 'MeterGInt' .. m .. '_Bg', 'Shape', 'Rectangle 0,0,60,26,4 | Fill Color ' .. (sel and '245,158,11,255' or '30,41,59,255') .. ' | StrokeWidth 1 | Stroke Color ' .. (sel and '251,191,36,255' or '51,65,85,255'))
        SKIN:Bang('!SetOption', 'MeterGInt' .. m, 'FontColor', sel and '255,255,255,255' or '148,163,184,255')
    end
end

function SetInterval(minutes)
    minutes = tonumber(minutes) or 15
    SKIN:Bang('!WriteKeyValue', 'Variables', 'UpdateIntervalMinutes', tostring(minutes), '#@#Config.inc')
    SKIN:Bang('!SetVariable', 'UpdateIntervalMinutes', tostring(minutes))
    
    -- Cada minuto corresponde a 3.000 ciclos de 20ms
    local baseCycles = minutes * 3000
    local coreFile = SKIN:GetVariable('@') .. 'StormTickerCore.inc'
    
    for f = 1, 10 do
        local staggered = baseCycles + (f - 1) * 150
        SKIN:Bang('!WriteKeyValue', 'MeasureFeed' .. f, 'UpdateRate', tostring(staggered), coreFile)
    end
    
    UpdateIntervalUI()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
    SKIN:Bang('!Refresh', 'StormTicker\\Panoramic')
    SKIN:Bang('!Refresh', 'StormTicker\\Box')
end

function ToggleFeed()
    local tab = tonumber(SKIN:GetVariable('CurrentTab', '1')) or 1
    if tab < 1 or tab > 3 then return end
    
    local current = SKIN:GetVariable('FeedEnabled' .. tab, '1')
    local nextVal = (tostring(current) == '1') and '0' or '1'
    SKIN:Bang('!WriteKeyValue', 'Variables', 'FeedEnabled' .. tab, nextVal, '#@#Feeds.inc')
    SKIN:Bang('!SetVariable', 'FeedEnabled' .. tab, nextVal)
    UpdateUI()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
    SKIN:Bang('!Refresh', 'StormTicker\\Panoramic')
    SKIN:Bang('!Refresh', 'StormTicker\\Box')
end

function SetSpeed(speedVal)
    local tab = tonumber(SKIN:GetVariable('CurrentTab', '1')) or 1
    if tab < 1 or tab > 3 then return end
    
    SKIN:Bang('!WriteKeyValue', 'Variables', 'FeedSpeed' .. tab, tostring(speedVal), '#@#Feeds.inc')
    SKIN:Bang('!SetVariable', 'FeedSpeed' .. tab, tostring(speedVal))
    UpdateUI()
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
    SKIN:Bang('!Refresh', 'StormTicker\\Panoramic')
    SKIN:Bang('!Refresh', 'StormTicker\\Box')
end

function EditField(fieldType)
    local tab = tonumber(SKIN:GetVariable('CurrentTab', '1')) or 1
    if tab < 1 or tab > 3 then return end
    
    if fieldType == 'url' then
        SKIN:Bang('["#@#Scripts\\EditUrl' .. tab .. '.bat"]')
    else
        SKIN:Bang('["#@#Scripts\\EditTag' .. tab .. '.bat"]')
    end
end

-- ==============================================================================
-- OPCOES GERAIS (idioma, tema, modo) - persistidas nos arquivos Override
-- ==============================================================================

function UpdateGeneralUI()
    local function mark(meter, active)
        SKIN:Bang('!SetOption', meter .. '_Bg', 'Shape', 'Rectangle 0,0,80,26,4 | Fill Color ' .. (active and '245,158,11,255' or '30,41,59,255') .. ' | StrokeWidth 1 | Stroke Color ' .. (active and '251,191,36,255' or '51,65,85,255'))
        SKIN:Bang('!SetOption', meter, 'FontColor', active and '255,255,255,255' or '148,163,184,255')
    end
    local lang = SKIN:GetVariable('Language', 'Portuguese')
    mark('MeterLangPT', lang == 'Portuguese')
    mark('MeterLangEN', lang == 'English')
    mark('MeterLangES', lang == 'Spanish')
    UpdateWeatherUI()
end

function SetLanguage(lang)
    local tab = SKIN:GetVariable('CurrentTab', '0')
    SKIN:Bang('!WriteKeyValue', 'Variables', 'Language', lang, '#@#LanguageOverride.inc')
    SKIN:Bang('!WriteKeyValue', 'Variables', 'CurrentTab', tostring(tab))
    SKIN:Bang('!SetVariable', 'Language', lang)
    SKIN:Bang('!Refresh', 'StormTicker\\Panoramic')
    SKIN:Bang('!Refresh', 'StormTicker\\Box')
    SKIN:Bang('!Refresh')
end

function SetTheme(theme)
    local tab = SKIN:GetVariable('CurrentTab', '0')
    SKIN:Bang('!WriteKeyValue', 'Variables', 'ThemeName', theme, '#@#ThemeOverride.inc')
    SKIN:Bang('!WriteKeyValue', 'Variables', 'CurrentTab', tostring(tab))
    SKIN:Bang('!SetVariable', 'ThemeName', theme)
    SKIN:Bang('!Refresh', 'StormTicker\\Panoramic')
    SKIN:Bang('!Refresh', 'StormTicker\\Box')
    SKIN:Bang('!Refresh')
end


function UpdateWeatherUI()
    local system = (SKIN:GetVariable('WeatherSystem', 'metric') or 'metric'):lower()
    local isMetric = (system ~= 'imperial')
    
    SKIN:Bang('!SetOption', 'MeterWtrMetric_Bg', 'Shape', 'Rectangle 0,0,105,28,4 | Fill Color ' .. (isMetric and '245,158,11,255' or '30,41,59,255') .. ' | StrokeWidth 1 | Stroke Color ' .. (isMetric and '251,191,36,255' or '51,65,85,255'))
    SKIN:Bang('!SetOption', 'MeterWtrMetric', 'FontColor', isMetric and '255,255,255,255' or '148,163,184,255')

    SKIN:Bang('!SetOption', 'MeterWtrImperial_Bg', 'Shape', 'Rectangle 0,0,105,28,4 | Fill Color ' .. (not isMetric and '245,158,11,255' or '30,41,59,255') .. ' | StrokeWidth 1 | Stroke Color ' .. (not isMetric and '251,191,36,255' or '51,65,85,255'))
    SKIN:Bang('!SetOption', 'MeterWtrImperial', 'FontColor', not isMetric and '255,255,255,255' or '148,163,184,255')
    SKIN:Bang('!UpdateMeterGroup', 'WeatherGroup')
    SKIN:Bang('!Redraw')
end

function SetWeatherSystem(sys)
    sys = (sys == 'imperial') and 'imperial' or 'metric'
    local unit = (sys == 'imperial') and 'F' or 'C'
    local apiUnit = (sys == 'imperial') and 'fahrenheit' or 'celsius'
    local windUnit = (sys == 'imperial') and 'mph' or 'kmh'
    
    local configPath = SKIN:GetVariable('@') .. 'Config.inc'
    WriteIniKey(configPath, 'Variables', 'WeatherSystem', sys)
    WriteIniKey(configPath, 'Variables', 'WeatherUnit', unit)
    WriteIniKey(configPath, 'Variables', 'WeatherApiUnit', apiUnit)
    WriteIniKey(configPath, 'Variables', 'WeatherWindUnit', windUnit)

    SKIN:Bang('!SetVariable', 'WeatherSystem', sys)
    SKIN:Bang('!SetVariable', 'WeatherUnit', unit)
    SKIN:Bang('!SetVariable', 'WeatherApiUnit', apiUnit)
    SKIN:Bang('!SetVariable', 'WeatherWindUnit', windUnit)
    UpdateWeatherUI()
    SKIN:Bang('!Refresh', 'StormTicker/Box')
    SKIN:Bang('!Refresh', 'StormTicker/Panoramic')
end

function SetCoordinates(inputStr)
    if not inputStr or inputStr == '' then return end
    local lat, lon = inputStr:match('([%-%d%.]+)[,%s]+([%-%d%.]+)')
    if lat and lon then
        SKIN:Bang('!WriteKeyValue', 'Variables', 'WeatherLatitude', lat, '#@#Config.inc')
        SKIN:Bang('!WriteKeyValue', 'Variables', 'WeatherLongitude', lon, '#@#Config.inc')
        SKIN:Bang('!SetVariable', 'WeatherLatitude', lat)
        SKIN:Bang('!SetVariable', 'WeatherLongitude', lon)
        SKIN:Bang('!SetOption', 'MeterWtrValCoords', 'Text', lat .. ', ' .. lon)
        SKIN:Bang('!UpdateMeter', 'MeterWtrValCoords')
        SKIN:Bang('!Redraw')
        
        -- Dispara geocodificacao reversa
        local geoUrl = 'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=' .. lat .. '&longitude=' .. lon .. '&localityLanguage=en'
        SKIN:Bang('!SetOption', 'MeasureGeocoding', 'Url', geoUrl)
        SKIN:Bang('!CommandMeasure', 'MeasureGeocoding', 'Update')
    end
end

function OnLocationResolved()
    local mGeo = SKIN:GetMeasure('MeasureGeocoding')
    local raw = mGeo and mGeo:GetStringValue() or ''
    if raw == '' then return end

    local city = raw:match('"city"%s*:%s*"([^"]+)"')
    if not city or city == '' then
        city = raw:match('"locality"%s*:%s*"([^"]+)"')
    end
    local cc = raw:match('"countryCode"%s*:%s*"([^"]+)"') or ''

    if city and city ~= '' then
        local loc = city .. (cc ~= '' and (', ' .. cc:upper()) or '')
        SKIN:Bang('!WriteKeyValue', 'Variables', 'WeatherCity', loc, '#@#Config.inc')
        SKIN:Bang('!SetVariable', 'WeatherCity', loc)
        SKIN:Bang('!SetOption', 'MeterWtrValCity', 'Text', loc)
        SKIN:Bang('!UpdateMeter', 'MeterWtrValCity')
        SKIN:Bang('!Redraw')

        -- Atualiza nas skins ativas (Panoramic e Box)
        SKIN:Bang('!SetVariable', 'WeatherCity', loc, 'StormTicker\\Panoramic')
        SKIN:Bang('!CommandMeasure', 'MeasureWeatherApi', 'Update', 'StormTicker\\Panoramic')
        SKIN:Bang('!SetVariable', 'WeatherCity', loc, 'StormTicker\\Box')
        SKIN:Bang('!CommandMeasure', 'MeasureWeatherApi', 'Update', 'StormTicker\\Box')
    end
end
