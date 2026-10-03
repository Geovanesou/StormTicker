-- ==============================================================================
-- [⚡] StormTicker - Asynchronous Multi-Line Ticker Engine (DirectWrite)
-- Copyright (c) 2026 Geovane Souza. All Rights Reserved.
-- v1.1.0: BBC Weather utility strip, split-flap board, panoramic single-line mode
-- ==============================================================================

local Lines = {}
local ActiveRows = 10
local BaseSpeed = 0.5
local Separator = "        |        "
local ContainerWidth = 360
local Initialized = false
local FirstSeen = {}
local HighlightColor = "254,240,138,255"
local InitializedFeeds = {}
local FRESH_DURATION = 420 -- 7 minutos em segundos
local TickCounter = 0
local BootTimer = 0

-- v1.1.0 state
local ViewMode = 0
local Weather = { available = false, city = "", temp = "", cond = "", wind = "", pressHum = "", tempCond = "", icon = "clear-day.png", forecast = {} }
local Forecast = { ready = false, text = "" }
local Utility = { text = "", panCond = "", target = "", phase = "idle", mode = "weather1", tick = 0, cycleTick = 0, flapTicks = 22, cycleTicks = 750, promoIdx = 0 }
local UTILITY_MODES = { 'weather1', 'weather2', 'weather3', 'promo', 'forecast1', 'forecast2', 'forecast3', 'promo' }
local DAY_SHORT = {
    English    = { Tonight='TONIGHT', Monday='MON', Tuesday='TUE', Wednesday='WED', Thursday='THU', Friday='FRI', Saturday='SAT', Sunday='SUN' },
    Portuguese = { Tonight='NOITE',   Monday='SEG', Tuesday='TER', Wednesday='QUA', Thursday='QUI', Friday='SEX', Saturday='S\193B', Sunday='DOM' },
    Spanish    = { Tonight='NOCHE',   Monday='LUN', Tuesday='MAR', Wednesday='MI\201', Thursday='JUE', Friday='VIE', Saturday='S\193B', Sunday='DOM' },
}
local Pan = { pos = 0, singleWidth = 0, speed = 1.0, paused = false, isReady = false }
local FLAP_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

-- Alinha o topo visual do icone diretamente contra o teto do espaco
local function GetIconY(iconName)
    iconName = iconName or 'clear-day.png'
    if iconName == 'clear-day.png' then
        return -7
    elseif iconName == 'partly-cloudy-day.png' then
        return -11
    elseif iconName == 'clear-night.png' or iconName == 'partly-cloudy-night.png' then
        return -14
    else
        -- nuvens (overcast, drizzle, rain, snow, fog, thunderstorms)
        return -17
    end
end

-- Manchetes Promocionais da Versão Pro (Linha 4 CTA)
function GetPromoHeadlines()
    local p1 = SKIN:GetVariable('PromoHeadline1', 'CONHECA O STORMTICKER PRO: 10 canais assincronos simultaneos e monitoramento de clima de ate 3 locais!')
    local p2 = SKIN:GetVariable('PromoHeadline2', 'MATRIZ COMPLETA DE 10 CANAIS: Monitore 10 portais simultaneos em tempo real e sem anuncios com o StormTicker Pro!')
    local p3 = SKIN:GetVariable('PromoHeadline3', 'ACESSE A EDICAO PRO NO DEVIANTART: Clique aqui para garantir sua licenca vitalicia da versao completa de 10 canais!')
    local link = SKIN:GetVariable('ProDeviantUrl', 'https://www.deviantart.com/geovanesou/art/1381771713')
    return {
        { title = p1, link = link },
        { title = p2, link = link },
        { title = p3, link = link }
    }
end

-- Escape special characters for Rainmeter regex matching
function EscapeRegex(str)
    if not str then return "" end
    local clean = str:gsub('^%b[]%s*', '')
    return clean:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
end

-- Clean XML/HTML residue, CDATA markers, and HTML entities
function CleanHeadline(str)
    if not str or str == "" then return "" end
    str = str:gsub('<!%[CDATA%[', ''):gsub('%]%]>', '')
    str = str:gsub('<[^>]+>', '')

    str = str:gsub('&#8243;', '"'):gsub('&Prime;', '"')
    str = str:gsub('&#8242;', "'"):gsub('&prime;', "'")
    str = str:gsub('&#8220;', '"'):gsub('&#8221;', '"'):gsub('&ldquo;', '"'):gsub('&rdquo;', '"')
    str = str:gsub('&#8216;', "'"):gsub('&#8217;', "'"):gsub('&lsquo;', "'"):gsub('&rsquo;', "'")
    str = str:gsub('&#8211;', '-'):gsub('&ndash;', '-')
    str = str:gsub('&#8212;', ' - '):gsub('&mdash;', ' - ')
    str = str:gsub('&#8230;', '...'):gsub('&hellip;', '...')
    str = str:gsub('&#039;', "'"):gsub('&#39;', "'"):gsub('&apos;', "'")
    str = str:gsub('&#034;', '"'):gsub('&#34;', '"'):gsub('&quot;', '"')
    str = str:gsub('&#038;', '&'):gsub('&#38;', '&'):gsub('&amp;', '&')
    str = str:gsub('&#060;', '<'):gsub('&#60;', '<'):gsub('&lt;', '<')
    str = str:gsub('&#062;', '>'):gsub('&#62;', '>'):gsub('&gt;', '>')
    str = str:gsub('&#160;', ' '):gsub('&nbsp;', ' ')
    str = str:gsub('&bull;', '•')
    str = str:gsub('&deg;', '\176')

    str = str:gsub('&#(%d+);', function(code)
        local n = tonumber(code)
        if n and n >= 32 and n <= 126 then
            return string.char(n)
        end
        return ""
    end)

    str = str:gsub('%s+', ' ')
    str = str:gsub('^%s+', ''):gsub('%s+$', '')
    return str
end

function Initialize()
    BaseSpeed = tonumber(SKIN:GetVariable('BaseSpeed', '0.5')) or 0.5
    HighlightColor = SKIN:GetVariable('HighlightColor', '254,240,138,255')
    ViewMode = tonumber(SKIN:GetVariable('ViewMode', '0')) or 0

    local tickerW = tonumber(SKIN:GetVariable('TickerWidth', '480')) or 480
    local tagW = tonumber(SKIN:GetVariable('TagWidth', '92')) or 92
    ContainerWidth = tickerW - tagW - 24

    local cycleSec = tonumber(SKIN:GetVariable('FlapCycleSeconds', '17')) or 17
    local flapMs = tonumber(SKIN:GetVariable('FlapDurationMs', '450')) or 450
    Utility.cycleTicks = math.max(200, math.floor(cycleSec * 50))
    Utility.flapTicks = math.max(10, math.min(40, math.floor(flapMs / 20)))
    Pan.speed = tonumber(SKIN:GetVariable('PanSpeed', '1.0')) or 1.0

    local DefaultSpeeds = { 1.20, 1.00, 0.80, 1.00, 1.20, 1.00, 0.80, 1.00, 1.20, 0.80 }

    for i = 1, 10 do
        local defSpd = DefaultSpeeds[i] or 1.0
        local spd = tonumber(SKIN:GetVariable('FeedSpeed' .. i, tostring(defSpd))) or defSpd
        Lines[i] = {
            pos = 0,
            text = "",
            singleWidth = 0,
            speed = spd,
            paused = false,
            items = {},
            isReady = false,
            isOffline = false,
            feedUrl = SKIN:GetVariable('FeedURL' .. i, ''),
            feedTag = SKIN:GetVariable('FeedTag' .. i, 'FEED ' .. i),
            currentActiveIndex = 1,
            slotY = nil,
            hasFreshItems = false
        }

        local meterName = 'MeterTickerText' .. i
        SKIN:Bang('!SetOption', meterName, 'InlineSetting', 'Color | ' .. HighlightColor)
        SKIN:Bang('!SetOption', meterName, 'InlinePattern', '^$')
    end

    -- Linha 4 (STORM PRO): strip utilitário split-flap - nao e marquee rolante
    local line4 = Lines[4]
    if line4 then
        line4.items = {}
        line4.isReady = false
        line4.isOffline = false
    end

    SKIN:Bang('!SetOption', 'MeterFooterStatus', 'Text', 'LIVE DESKTOP STREAM')
    SKIN:Bang('!UpdateMeter', 'MeterFooterStatus')
    Utility.text = ''
    UtilityCycle()

    LayoutRows()
    ApplyViewMode()
    RebuildPanMarquee()
    Initialized = true
end

-- Empilhamento dinâmico das linhas e barra de rodapé (modo stacked)
function LayoutRows()
    if ViewMode == 1 then return end

    local headerH = tonumber(SKIN:GetVariable('HeaderHeight', '32')) or 32
    local rowH = tonumber(SKIN:GetVariable('RowHeight', '26')) or 26
    local tickerW = tonumber(SKIN:GetVariable('TickerWidth', '480')) or 480
    local borderRadius = tonumber(SKIN:GetVariable('BorderRadius', '8')) or 8
    local bgColor = SKIN:GetVariable('BgColor', '8,12,20,235')
    local borderColor = SKIN:GetVariable('BorderColor', '30,41,59,255')

    local activeCount = 0
    for i = 1, 10 do
        local enabled = tonumber(SKIN:GetVariable('FeedEnabled' .. i, '1')) or 1
        local line = Lines[i]
        if enabled == 1 then
            local slotY = headerH + (activeCount * rowH)
            if line then
                line.slotY = slotY
                SKIN:Bang('!SetOption', 'MeterTagBg' .. i, 'Y', tostring(slotY + 4))
                SKIN:Bang('!SetOption', 'MeterTagText' .. i, 'Y', tostring(slotY + 5))
                SKIN:Bang('!SetOption', 'MeterContainer' .. i, 'Y', tostring(slotY))
                SKIN:Bang('!SetOption', 'MeterRowDivider' .. i, 'Y', tostring(slotY + rowH))
            end
            activeCount = activeCount + 1
        end
    end
    ActiveRows = activeCount

    -- Garantir que a linha 4 (utilitaria) fique centralizada sem botao de tag
    if (tonumber(SKIN:GetVariable('FeedEnabled4', '1')) or 1) == 1 then
        local slotY4 = headerH + (3 * rowH)
        SKIN:Bang('!SetOption', 'MeterTagBg4', 'Hidden', '1')
        SKIN:Bang('!SetOption', 'MeterTagText4', 'Hidden', '1')
        SKIN:Bang('!SetOption', 'MeterRowDivider4', 'Hidden', '1')
        SKIN:Bang('!SetOption', 'MeterContainer4', 'X', '8')
        SKIN:Bang('!SetOption', 'MeterContainer4', 'Y', tostring(slotY4))
        SKIN:Bang('!SetOption', 'MeterContainer4', 'Shape', string.format('Rectangle 0,0,%d,%d,3 | Fill Color %s | StrokeWidth 0', tickerW - 16, rowH - 2, bgColor))
        SKIN:Bang('!SetOption', 'MeterTickerText4', 'X', tostring(math.floor((tickerW - 16) / 2)))
        SKIN:Bang('!SetOption', 'MeterTickerText4', 'Y', tostring(math.floor(rowH / 2 - 1)))
        SKIN:Bang('!SetOption', 'MeterTickerText4', 'StringAlign', 'CenterCenter')
        SKIN:Bang('!SetOption', 'MeterTickerText4', 'W', tostring(tickerW - 24))
        SKIN:Bang('!SetOption', 'MeterTickerText4', 'Hidden', '0')
        SKIN:Bang('!UpdateMeter', 'MeterTagBg4')
        SKIN:Bang('!UpdateMeter', 'MeterTagText4')
        SKIN:Bang('!UpdateMeter', 'MeterRowDivider4')
        SKIN:Bang('!UpdateMeter', 'MeterContainer4')
        SKIN:Bang('!UpdateMeter', 'MeterTickerText4')
    end

    local footerY = headerH + (activeCount * rowH)
    SKIN:Bang('!SetOption', 'MeterFooterBg', 'Y', tostring(footerY))
    SKIN:Bang('!SetOption', 'MeterFooterStatus', 'Y', tostring(footerY + 6))

    local totalHeight = footerY + 26

    local bgShape = string.format('Rectangle 0,0,%d,%d,%d | Fill Color %s | StrokeWidth 1 | Stroke Color %s',
        tickerW, totalHeight, borderRadius, bgColor, borderColor)
    SKIN:Bang('!SetOption', 'MeterBg', 'Shape', bgShape)
    SKIN:Bang('!UpdateMeter', 'MeterBg')
    SKIN:Bang('!UpdateMeter', 'MeterFooterBg')
    SKIN:Bang('!UpdateMeter', 'MeterFooterStatus')
    SKIN:Bang('!Redraw')
end

-- Alterna a visibilidade entre modo empilhado e panorâmico (linha única)
function ApplyViewMode()
    local rowH = tonumber(SKIN:GetVariable('RowHeight', '26')) or 26
    local tickerW = tonumber(SKIN:GetVariable('TickerWidth', '480')) or 480
    local borderRadius = tonumber(SKIN:GetVariable('BorderRadius', '8')) or 8
    local bgColor = SKIN:GetVariable('BgColor', '8,12,20,235')
    local borderColor = SKIN:GetVariable('BorderColor', '30,41,59,255')
    local utilDivider = SKIN:GetVariable('UtilityDividerColor', '56,189,248,140')

    local headerH = tonumber(SKIN:GetVariable('HeaderHeight', '32')) or 32
    local headerBg = SKIN:GetVariable('HeaderBgColor', '15,23,42,255')

    if ViewMode == 1 then
        -- Panoramico full-width: barra superior (headerH) + linha unica (rowH + 4)
        local totalH = headerH + rowH + 4
        local swF = '(#SCREENAREAWIDTH#)'              -- builtin: resolve nas opcoes de meter
        local wthrW = tonumber(SKIN:GetVariable('WeatherPanelW', '340')) or 340
        local panXF = '((#SCREENAREAWIDTH#) - ' .. wthrW .. ')'   -- hairline antes do painel de clima

        -- Fundo e barra superior em largura total de tela
        SKIN:Bang('!SetOption', 'MeterBg', 'Shape', string.format('Rectangle 0,0,%s,%d,%d | Fill Color %s | StrokeWidth 1 | Stroke Color %s', swF, totalH, borderRadius, bgColor, borderColor))
        SKIN:Bang('!SetOption', 'MeterHeaderBg', 'Shape', string.format('Rectangle 0,0,%s,%d,%d,%d,0,0 | Fill Color %s | StrokeWidth 0', swF, headerH, borderRadius, borderRadius, headerBg))
        for _, m in ipairs({'MeterHeaderBg','MeterHeaderTitle','MeterHeaderBolt','MeterHeaderModeBox','MeterHeaderModeBtnPan','MeterHeaderSettingsBox','MeterHeaderSettingsBtn'}) do
            SKIN:Bang('!SetOption', m, 'Hidden', '0')
            SKIN:Bang('!UpdateMeter', m)
        end
        SKIN:Bang('!SetOption', 'MeterHeaderModeBtn', 'Hidden', '1')
        -- Botoes ancorados a esquerda do bloco utilitario (hairline)
        SKIN:Bang('!SetOption', 'MeterHeaderModeBox', 'X', '(' .. panXF .. ' - 114)')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBtnPan', 'X', '(' .. panXF .. ' - 101)')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBtnPan', 'FontFace', 'Segoe UI Symbol')
        SKIN:Bang('!SetOption', 'MeterHeaderSettingsBox', 'X', '(' .. panXF .. ' - 82)')
        SKIN:Bang('!SetOption', 'MeterHeaderSettingsBtn', 'X', '(' .. panXF .. ' - 45)')

        -- Linhas empilhadas ocultas
        for _, m in ipairs({'MeterFooterBg','MeterFooterStatus'}) do
            SKIN:Bang('!SetOption', m, 'Hidden', '1')
            SKIN:Bang('!UpdateMeter', m)
        end
        for i = 1, 10 do
            for _, prefix in ipairs({'MeterTagBg','MeterTagText','MeterContainer','MeterTickerText','MeterRowDivider'}) do
                SKIN:Bang('!SetOption', prefix .. i, 'Hidden', '1')
            end
        end

        -- Ribbon de noticias: 3/4 esquerdo, abaixo da barra
        SKIN:Bang('!SetOption', 'MeterPanContainer', 'Shape', string.format('Rectangle 0,0,%s,(%d - 2),3 | Fill Color #BgColor# | StrokeWidth 0', '(' .. panXF .. ' - 12)', rowH))
        SKIN:Bang('!SetOption', 'MeterPanContainer', 'X', '4')
        SKIN:Bang('!SetOption', 'MeterPanContainer', 'Y', tostring(headerH + 2))
        SKIN:Bang('!SetOption', 'MeterPanContainer', 'Hidden', '0')
        SKIN:Bang('!SetOption', 'MeterPanText', 'Hidden', '0')
        SKIN:Bang('!UpdateMeter', 'MeterPanContainer')
        SKIN:Bang('!UpdateMeter', 'MeterPanText')

        -- Hairline divider: altura total (barra + linha)
        SKIN:Bang('!SetOption', 'MeterPanDivider', 'Shape', string.format('Line 0,0,0,%d | StrokeWidth 1 | Stroke Color %s', totalH - 12, utilDivider))
        SKIN:Bang('!SetOption', 'MeterPanDivider', 'X', panXF)
        SKIN:Bang('!SetOption', 'MeterPanDivider', 'Y', '6')
        SKIN:Bang('!SetOption', 'MeterPanDivider', 'Hidden', '0')
        SKIN:Bang('!UpdateMeter', 'MeterPanDivider')

        -- Fundo solido do painel utilitario (elimina 100% o corte bicolor)
        SKIN:Bang('!SetOption', 'MeterPanWeatherPanel', 'X', '(' .. panXF .. ' + 1)')
        SKIN:Bang('!SetOption', 'MeterPanWeatherPanel', 'Y', '0')
        SKIN:Bang('!SetOption', 'MeterPanWeatherPanel', 'Shape', string.format('Rectangle 0,0,(#WeatherPanelW# - 1),%d | Fill Color %s | StrokeWidth 0', totalH, bgColor))
        SKIN:Bang('!SetOption', 'MeterPanWeatherPanel', 'Hidden', '0')
        SKIN:Bang('!UpdateMeter', 'MeterPanWeatherPanel')

        -- Geometria dos meters de Clima (conceito visual: icone 76x76 encostado no teto, localidade fonte 12 bold, condicao alinhada a direita)
        local iconSize = 76
        local iconY = GetIconY(Weather.icon or 'clear-day.png')

        SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'X', '(' .. panXF .. ' + 10)')
        SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'Y', tostring(iconY))
        SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'W', tostring(iconSize))
        SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'H', tostring(iconSize))

        SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'X', '(' .. panXF .. ' + 94)')
        SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'Y', '11')
        SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'FontSize', '12')
        SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'FontWeight', '700')
        SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'W', '300')

        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'X', '((#SCREENAREAWIDTH#) - 20)')
        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'Y', '33')
        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'StringAlign', 'Right')
        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'FontSize', '11')
        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'FontWeight', '600')
        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'StringStyle', 'Italic')
        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'FontColor', SKIN:GetVariable('AccentColor', '56,189,248,255'))
        SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'W', '420')

        -- Bloco utilitario fixo para Propaganda Centralizada
        SKIN:Bang('!SetOption', 'MeterUtilityContainer', 'Shape', string.format('Rectangle 0,0,(#WeatherPanelW# - 18),(%d - 8),3 | Fill Color %s | StrokeWidth 0', totalH, bgColor))
        SKIN:Bang('!SetOption', 'MeterUtilityContainer', 'X', '(' .. panXF .. ' + 6)')
        SKIN:Bang('!SetOption', 'MeterUtilityContainer', 'Y', '4')
        SKIN:Bang('!SetOption', 'MeterUtilityText', 'X', tostring(math.floor((wthrW - 18) / 2)))
        SKIN:Bang('!SetOption', 'MeterUtilityText', 'Y', tostring(math.floor((totalH - 8) / 2)))
        SKIN:Bang('!SetOption', 'MeterUtilityText', 'W', tostring(wthrW - 30))
        SKIN:Bang('!SetOption', 'MeterUtilityText', 'StringAlign', 'CenterCenter')
        SKIN:Bang('!UpdateMeter', 'MeterBg')
        UtilityApplyMode(Utility.mode)
    else
        -- Zera completamente meters panoramicos para que o Box mode nao tenha largura fantasma de 1920px
        for _, m in ipairs({'MeterPanContainer','MeterPanText','MeterPanDivider','MeterPanWeatherPanel','MeterPanWeatherIcon','MeterPanWeatherLocation','MeterPanWeatherCondition','MeterUtilityContainer','MeterUtilityText'}) do
            SKIN:Bang('!SetOption', m, 'X', '0')
            SKIN:Bang('!SetOption', m, 'Y', '0')
            SKIN:Bang('!SetOption', m, 'W', '0')
            SKIN:Bang('!SetOption', m, 'H', '0')
            SKIN:Bang('!SetOption', m, 'Hidden', '1')
            SKIN:Bang('!UpdateMeter', m)
        end

        for _, m in ipairs({'MeterHeaderBg','MeterHeaderTitle','MeterHeaderBolt','MeterHeaderSettingsBox','MeterHeaderSettingsBtn','MeterFooterBg','MeterFooterStatus'}) do
            SKIN:Bang('!SetOption', m, 'Hidden', '0')
            SKIN:Bang('!UpdateMeter', m)
        end
        -- Restaura geometria da barra para a largura empilhada
        SKIN:Bang('!SetOption', 'MeterHeaderBg', 'Shape', 'Rectangle 0,0,#TickerWidth#,#HeaderHeight#,#BorderRadius#,#BorderRadius#,0,0 | Fill Color #HeaderBgColor# | StrokeWidth 0')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBox', 'X', '(#TickerWidth# - 114)')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBtn', 'X', '(#TickerWidth# - 101)')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBtn', 'FontFace', '#FontName#')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBox', 'Hidden', '0')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBtn', 'Hidden', '0')
        SKIN:Bang('!SetOption', 'MeterHeaderModeBtnPan', 'Hidden', '1')
        SKIN:Bang('!SetOption', 'MeterHeaderSettingsBox', 'X', '(#TickerWidth# - 82)')
        SKIN:Bang('!SetOption', 'MeterHeaderSettingsBtn', 'X', '(#TickerWidth# - 45)')
        for _, m in ipairs({'MeterPanContainer','MeterPanText','MeterPanDivider','MeterPanWeatherPanel','MeterPanWeatherIcon','MeterPanWeatherLocation','MeterPanWeatherCondition','MeterUtilityContainer','MeterUtilityText'}) do
            SKIN:Bang('!SetOption', m, 'Hidden', '1')
            SKIN:Bang('!UpdateMeter', m)
        end
        for i = 1, 10 do
            local enabled = tonumber(SKIN:GetVariable('FeedEnabled' .. i, '1')) or 1
            local vis = (enabled == 1) and '0' or '1'
            -- linha 4 (utilitario): sem botao de tag, faixa em largura total
            local tagVis = (i == 4) and '1' or vis
            SKIN:Bang('!SetOption', 'MeterTagBg' .. i, 'Hidden', tagVis)
            SKIN:Bang('!SetOption', 'MeterTagText' .. i, 'Hidden', tagVis)
            for _, prefix in ipairs({'MeterContainer','MeterTickerText','MeterRowDivider'}) do
                SKIN:Bang('!SetOption', prefix .. i, 'Hidden', vis)
            end
        end
        LayoutRows()
    end
    SKIN:Bang('!Redraw')
end

-- Ribbon panorâmico: concatena os itens de todos os canais ativos e prontos
function RebuildPanMarquee()
    if ViewMode ~= 1 then return end

    local titles = {}
    for i = 1, 10 do
        if i ~= 4 then
            local enabled = tonumber(SKIN:GetVariable('FeedEnabled' .. i, '1')) or 1
            local line = Lines[i]
            if enabled == 1 and line and line.isReady and line.items then
                for _, item in ipairs(line.items) do
                    table.insert(titles, item.title)
                end
            end
        end
    end

    if #titles == 0 then
        Pan.isReady = false
        SKIN:Bang('!SetOption', 'MeterPanText', 'Text', SKIN:GetVariable('Lang_OfflineMessage', 'URL offline'))
        SKIN:Bang('!UpdateMeter', 'MeterPanText')
        return
    end

    local assembled = table.concat(titles, Separator) .. Separator
    Pan.text = assembled .. assembled
    SKIN:Bang('!SetOption', 'MeterPanText', 'Text', Pan.text)
    SKIN:Bang('!UpdateMeter', 'MeterPanText')

    local meter = SKIN:GetMeter('MeterPanText')
    if meter then
        Pan.singleWidth = math.floor(meter:GetW() / 2)
        if Pan.singleWidth <= 0 then Pan.singleWidth = ContainerWidth end
    else
        Pan.singleWidth = ContainerWidth
    end
    Pan.isReady = true
end

-- ==== MAPEAMENTO METEOCONS E OPEN-METEO ====

local function GetWindDirection(deg)
    deg = tonumber(deg) or 0
    local cardinals = { 'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW' }
    local idx = math.floor(((deg + 11.25) % 360) / 22.5) + 1
    return cardinals[idx] or 'N'
end

local function GetWeatherIcon(code, isDay)
    code = tonumber(code) or 0
    isDay = (tonumber(isDay) == 1)
    if code == 0 then
        return isDay and 'clear-day.png' or 'clear-night.png'
    elseif code == 1 or code == 2 then
        return isDay and 'partly-cloudy-day.png' or 'partly-cloudy-night.png'
    elseif code == 3 then
        return 'overcast.png'
    elseif code == 45 or code == 48 then
        return 'fog.png'
    elseif code >= 51 and code <= 55 then
        return 'drizzle.png'
    elseif code >= 61 and code <= 65 then
        return 'rain.png'
    elseif code >= 71 and code <= 75 then
        return 'snow.png'
    elseif code >= 80 and code <= 82 then
        return isDay and 'partly-cloudy-day.png' or 'partly-cloudy-night.png'
    elseif code >= 95 and code <= 99 then
        return 'thunderstorms.png'
    end
    return isDay and 'clear-day.png' or 'clear-night.png'
end

local function GetWeatherConditionText(code)
    code = tonumber(code) or 0
    local varName = 'Lang_Weather_' .. code
    local text = SKIN:GetVariable(varName, '')
    if text == '' then
        if code >= 51 and code <= 55 then text = SKIN:GetVariable('Lang_Weather_51', 'Chuvisco')
        elseif code >= 61 and code <= 65 then text = SKIN:GetVariable('Lang_Weather_61', 'Chuva')
        elseif code >= 71 and code <= 75 then text = SKIN:GetVariable('Lang_Weather_71', 'Neve')
        elseif code >= 80 and code <= 82 then text = SKIN:GetVariable('Lang_Weather_81', 'Pancadas')
        elseif code >= 95 then text = SKIN:GetVariable('Lang_Weather_95', 'Tempestade')
        else text = SKIN:GetVariable('Lang_Weather_0', 'Ceu Limpo')
        end
    end
    return text
end

function UtilityApplyMode(mode)
    local activeIcon = Weather.icon or 'clear-day.png'
    if mode == 'forecast1' and Weather.forecast and Weather.forecast[1] then
        activeIcon = Weather.forecast[1].icon or activeIcon
    elseif mode == 'forecast2' and Weather.forecast and Weather.forecast[2] then
        activeIcon = Weather.forecast[2].icon or activeIcon
    elseif mode == 'forecast3' and Weather.forecast and Weather.forecast[3] then
        activeIcon = Weather.forecast[3].icon or activeIcon
    end

    if ViewMode == 1 then
        if mode == 'promo' then
            SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'Hidden', '1')
            SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'Hidden', '1')
            SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'Hidden', '1')

            SKIN:Bang('!SetOption', 'MeterUtilityContainer', 'Hidden', '0')
            SKIN:Bang('!SetOption', 'MeterUtilityText', 'Hidden', '0')
            SKIN:Bang('!SetOption', 'MeterUtilityText', 'Text', Utility.text)
            SKIN:Bang('!SetOption', 'MeterUtilityText', 'FontColor', SKIN:GetVariable('AmberAccent', '245,158,11,255'))

            SKIN:Bang('!UpdateMeter', 'MeterPanWeatherIcon')
            SKIN:Bang('!UpdateMeter', 'MeterPanWeatherLocation')
            SKIN:Bang('!UpdateMeter', 'MeterPanWeatherCondition')
            SKIN:Bang('!UpdateMeter', 'MeterUtilityContainer')
            SKIN:Bang('!UpdateMeter', 'MeterUtilityText')
        else
            -- weather1, weather2, weather3, forecast1, forecast2, forecast3
            local wthrW = tonumber(SKIN:GetVariable('WeatherPanelW', '340')) or 340
            local panXF = '((#SCREENAREAWIDTH#) - ' .. wthrW .. ')'
            local iconPath = '#@#WeatherIcons\\' .. activeIcon
            SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'X', '(' .. panXF .. ' + 10)')
            SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'ImageName', iconPath)
            SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'Y', tostring(GetIconY(activeIcon)))
            SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'X', '(' .. panXF .. ' + 94)')
            SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'Text', (Weather.city ~= '') and Weather.city or 'Rio de Janeiro, BR')
            SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'X', '((#SCREENAREAWIDTH#) - 20)')

            local condStr = ""
            if mode == 'weather1' then
                condStr = (Weather.tempCond ~= '') and Weather.tempCond or ((Weather.temp ~= '' and Weather.temp or '--') .. ' / ' .. (Weather.cond ~= '' and Weather.cond or SKIN:GetVariable('Lang_WeatherOffline', 'CLIMA OFFLINE')))
            elseif mode == 'weather2' then
                condStr = (Weather.wind ~= '') and Weather.wind or 'Vento: --'
            elseif mode == 'weather3' then
                condStr = (Weather.pressHum ~= '') and Weather.pressHum or 'Pressao: -- | Umidade: --'
            elseif mode == 'forecast1' and Weather.forecast and Weather.forecast[1] then
                condStr = Weather.forecast[1].textPan
            elseif mode == 'forecast2' and Weather.forecast and Weather.forecast[2] then
                condStr = Weather.forecast[2].textPan
            elseif mode == 'forecast3' and Weather.forecast and Weather.forecast[3] then
                condStr = Weather.forecast[3].textPan
            else
                condStr = Weather.tempCond or ''
            end
            Utility.panCond = condStr
            SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'Text', condStr)

            SKIN:Bang('!SetOption', 'MeterPanWeatherIcon', 'Hidden', '0')
            SKIN:Bang('!SetOption', 'MeterPanWeatherLocation', 'Hidden', '0')
            SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'Hidden', '0')
            SKIN:Bang('!SetOption', 'MeterUtilityContainer', 'Hidden', '1')
            SKIN:Bang('!SetOption', 'MeterUtilityText', 'Hidden', '1')

            SKIN:Bang('!UpdateMeter', 'MeterPanWeatherIcon')
            SKIN:Bang('!UpdateMeter', 'MeterPanWeatherLocation')
            SKIN:Bang('!UpdateMeter', 'MeterPanWeatherCondition')
            SKIN:Bang('!UpdateMeter', 'MeterUtilityContainer')
            SKIN:Bang('!UpdateMeter', 'MeterUtilityText')
        end
        SKIN:Bang('!Redraw')
    else
        -- Box mode (Linha 4)
        if mode == 'promo' then
            SKIN:Bang('!SetOption', 'MeterTickerText4', 'Text', Utility.text)
            SKIN:Bang('!SetOption', 'MeterTickerText4', 'FontColor', SKIN:GetVariable('AmberAccent', '245,158,11,255'))
            SKIN:Bang('!SetOption', 'MeterTickerText4', 'StringStyle', 'Bold')
        else
            local condStr = ""
            local cityStr = (Weather.city ~= '') and Weather.city or 'Rio de Janeiro, BR'
            if mode == 'weather1' then
                local tc = (Weather.tempCond ~= '') and Weather.tempCond or ((Weather.temp ~= '' and Weather.temp or '--') .. ' / ' .. (Weather.cond ~= '' and Weather.cond or SKIN:GetVariable('Lang_WeatherOffline', 'CLIMA OFFLINE')))
                condStr = cityStr .. ' - ' .. tc
            elseif mode == 'weather2' then
                condStr = cityStr .. ' - ' .. ((Weather.wind ~= '') and Weather.wind or 'Vento: --')
            elseif mode == 'weather3' then
                condStr = cityStr .. ' - ' .. ((Weather.pressHum ~= '') and Weather.pressHum or 'Pressao: -- | Umidade: --')
            elseif mode == 'forecast1' and Weather.forecast and Weather.forecast[1] then
                condStr = cityStr .. ' - ' .. Weather.forecast[1].textPan
            elseif mode == 'forecast2' and Weather.forecast and Weather.forecast[2] then
                condStr = cityStr .. ' - ' .. Weather.forecast[2].textPan
            elseif mode == 'forecast3' and Weather.forecast and Weather.forecast[3] then
                condStr = cityStr .. ' - ' .. Weather.forecast[3].textPan
            else
                condStr = cityStr .. ' - ' .. (Weather.tempCond or '')
            end
            Utility.text = condStr
            SKIN:Bang('!SetOption', 'MeterTickerText4', 'Text', condStr)
            SKIN:Bang('!SetOption', 'MeterTickerText4', 'FontColor', SKIN:GetVariable('AccentColor', '56,189,248,255'))
            SKIN:Bang('!SetOption', 'MeterTickerText4', 'StringStyle', 'Normal')
        end
        SKIN:Bang('!UpdateMeter', 'MeterTickerText4')
        SKIN:Bang('!Redraw')
    end
end

function UtilityCycle()
    Utility.cycleTick = 0
    local idx = 1
    for i, m in ipairs(UTILITY_MODES) do
        if m == Utility.mode then idx = i break end
    end
    Utility.mode = UTILITY_MODES[(idx % #UTILITY_MODES) + 1]

    if Utility.mode == 'weather1' then
        Utility.cycleTicks = math.floor(15 * 50) -- 15 segundos
    elseif Utility.mode == 'weather2' then
        Utility.cycleTicks = math.floor(7.5 * 50) -- 7.5 segundos
    elseif Utility.mode == 'weather3' then
        Utility.cycleTicks = math.floor(7.5 * 50) -- 7.5 segundos
    elseif Utility.mode == 'forecast1' or Utility.mode == 'forecast2' or Utility.mode == 'forecast3' then
        Utility.cycleTicks = math.floor(10 * 50) -- 10 segundos para cada previsao
    elseif Utility.mode == 'promo' then
        Utility.promoIdx = Utility.promoIdx + 1
        Utility.cycleTicks = math.floor(10 * 50) -- 10 segundos
    end

    local newText = ""
    local newPanCond = ""

    if Utility.mode == 'weather1' then
        newPanCond = (Weather.tempCond ~= '') and Weather.tempCond or ((Weather.temp ~= '' and Weather.temp or '--') .. ' / ' .. (Weather.cond ~= '' and Weather.cond or 'CLIMA'))
        newText = (Weather.city ~= '' and Weather.city or 'Rio de Janeiro, BR') .. ' - ' .. newPanCond
    elseif Utility.mode == 'weather2' then
        newPanCond = (Weather.wind ~= '') and Weather.wind or 'Vento: --'
        newText = (Weather.city ~= '' and Weather.city or 'Rio de Janeiro, BR') .. ' - ' .. newPanCond
    elseif Utility.mode == 'weather3' then
        newPanCond = (Weather.pressHum ~= '') and Weather.pressHum or 'Pressao: -- | Umidade: --'
        newText = (Weather.city ~= '' and Weather.city or 'Rio de Janeiro, BR') .. ' - ' .. newPanCond
    elseif Utility.mode == 'forecast1' then
        if Weather.forecast and Weather.forecast[1] then
            newPanCond = Weather.forecast[1].textPan
        else
            newPanCond = (Weather.tempCond ~= '') and Weather.tempCond or 'Previsao indisponivel'
        end
        newText = (Weather.city ~= '' and Weather.city or 'Rio de Janeiro, BR') .. ' - ' .. newPanCond
    elseif Utility.mode == 'forecast2' then
        if Weather.forecast and Weather.forecast[2] then
            newPanCond = Weather.forecast[2].textPan
        else
            newPanCond = (Weather.tempCond ~= '') and Weather.tempCond or 'Previsao indisponivel'
        end
        newText = (Weather.city ~= '' and Weather.city or 'Rio de Janeiro, BR') .. ' - ' .. newPanCond
    elseif Utility.mode == 'forecast3' then
        if Weather.forecast and Weather.forecast[3] then
            newPanCond = Weather.forecast[3].textPan
        else
            newPanCond = (Weather.tempCond ~= '') and Weather.tempCond or 'Previsao indisponivel'
        end
        newText = (Weather.city ~= '' and Weather.city or 'Rio de Janeiro, BR') .. ' - ' .. newPanCond
    elseif Utility.mode == 'promo' then
        newText = SKIN:GetVariable('Lang_UtilityPromo' .. ((Utility.promoIdx % 3) + 1), 'STORMTICKER PRO: INFORMACOES SEMPRE ATUALIZADAS!')
    end

    if ViewMode == 1 then
        if Utility.mode == 'promo' then
            if newText ~= Utility.text then
                Utility.target = newText
                Utility.phase = 'flap'
                Utility.tick = 0
            else
                Utility.text = newText
                UtilityApplyMode(Utility.mode)
            end
        else
            if newPanCond ~= Utility.panCond then
                Utility.target = newPanCond
                Utility.phase = 'flap'
                Utility.tick = 0
            else
                Utility.panCond = newPanCond
                UtilityApplyMode(Utility.mode)
            end
        end
    else
        if newText ~= Utility.text then
            Utility.target = newText
            Utility.phase = 'flap'
            Utility.tick = 0
        else
            Utility.text = newText
            UtilityApplyMode(Utility.mode)
        end
    end
end

local function UtilityUpdate()
    if Utility.phase == 'flap' then
        Utility.tick = Utility.tick + 1
        local target = Utility.target
        local progress = Utility.tick / Utility.flapTicks
        if progress >= 1 then
            Utility.text = target
            Utility.panCond = target
            Utility.phase = 'idle'
            UtilityApplyMode(Utility.mode)
        else
            local resolved = math.floor(progress * #target)
            local buf = {}
            for i = 1, #target do
                local c = target:sub(i, i)
                if i <= resolved or c == ' ' or c == ':' or c == '/' or c == '-' or c == '|' or c == '%' or c:byte() >= 128 then
                    buf[i] = c
                else
                    local r = math.random(1, #FLAP_CHARS)
                    buf[i] = FLAP_CHARS:sub(r, r)
                end
            end
            local scrambled = table.concat(buf)
            if ViewMode == 1 then
                if Utility.mode == 'promo' then
                    SKIN:Bang('!SetOption', 'MeterUtilityText', 'Text', scrambled)
                    SKIN:Bang('!UpdateMeter', 'MeterUtilityText')
                else
                    SKIN:Bang('!SetOption', 'MeterPanWeatherCondition', 'Text', scrambled)
                    SKIN:Bang('!UpdateMeter', 'MeterPanWeatherCondition')
                end
                SKIN:Bang('!Redraw')
            else
                SKIN:Bang('!SetOption', 'MeterTickerText4', 'Text', scrambled)
                SKIN:Bang('!UpdateMeter', 'MeterTickerText4')
                SKIN:Bang('!Redraw')
            end
        end
        return
    end

    Utility.cycleTick = Utility.cycleTick + 1
    if Utility.cycleTick >= Utility.cycleTicks then
        UtilityCycle()
    end
end

-- Callback do WebParser Open-Meteo (JSON)
function UpdateWeather()
    local mCurrent = SKIN:GetMeasure('MeasureWeatherCurrent')
    local raw = mCurrent and (mCurrent:GetStringValue() or '') or ''
    if raw == '' then
        WeatherOffline()
        return
    end

    local tempStr = raw:match('"temperature[_%w]*":%s*([%-%d%.]+)')
    local codeStr = raw:match('"weather[_]?code":%s*(%d+)')
    local isDayStr = raw:match('"is_day":%s*(%d+)')
    local windStr = raw:match('"wind_speed[_%w]*":%s*([%-%d%.]+)')
    local windDirStr = raw:match('"wind_direction[_%w]*":%s*([%-%d%.]+)')
    local humStr = raw:match('"relative_humidity[_%w]*":%s*([%-%d%.]+)')
    local pressStr = raw:match('"surface_pressure":%s*([%-%d%.]+)')

    if not tempStr then
        WeatherOffline()
        return
    end

    local tempVal = tonumber(tempStr) or 0
    local unit = SKIN:GetVariable('WeatherUnit', 'C'):upper()
    local unitSymbol = (unit == 'F') and '\176F' or '\176C'
    Weather.temp = string.format('%.0f%s', tempVal, unitSymbol)

    local code = tonumber(codeStr) or 0
    local isDay = tonumber(isDayStr) or 1

    Weather.icon = GetWeatherIcon(code, isDay)
    Weather.cond = GetWeatherConditionText(code)
    Weather.tempCond = Weather.temp .. ' / ' .. Weather.cond

    -- Vento
    local windVal = tonumber(windStr) or 0
    local windDeg = tonumber(windDirStr) or 0
    local windUnit = SKIN:GetVariable('WeatherWindUnit', 'kmh')
    local windUnitStr = (windUnit == 'mph') and 'mph' or 'Km/h'
    local windDirStr = GetWindDirection(windDeg)
    local lblWind = SKIN:GetVariable('Lang_WeatherWind', 'Vento')
    Weather.wind = string.format('%s: %.0f %s %s', lblWind, windVal, windUnitStr, windDirStr)

    -- Pressao e Umidade
    local pressVal = tonumber(pressStr) or 1013.2
    local humVal = tonumber(humStr) or 0
    local isImperial = (SKIN:GetVariable('WeatherSystem', 'metric'):lower() == 'imperial')
    local pressText = ""
    if isImperial then
        pressText = string.format('%.2f inHg', pressVal * 0.02953)
    else
        pressText = string.format('%.0f hPa', pressVal)
    end
    local lblPress = SKIN:GetVariable('Lang_WeatherPressure', 'Pressao')
    local lblHum = SKIN:GetVariable('Lang_WeatherHumidity', 'Umidade')
    Weather.pressHum = string.format('%s: %s | %s: %.0f%%', lblPress, pressText, lblHum, humVal)

    -- Parser da Previsao Diaria (Open-Meteo Daily)
    Weather.forecast = {}
    local mDaily = SKIN:GetMeasure('MeasureWeatherDaily')
    local rawDaily = mDaily and (mDaily:GetStringValue() or '') or ''
    if rawDaily ~= '' then
        local times = {}
        local timePart = rawDaily:match('"time":%s*%[(.-)%]')
        if timePart then
            for dt in timePart:gmatch('"(%d%d%d%d%-%d%d%-%d%d)"') do
                table.insert(times, dt)
            end
        end

        local codes = {}
        local codePart = rawDaily:match('"weather[_]?code":%s*%[(.-)%]')
        if codePart then
            for c in codePart:gmatch('(%d+)') do
                table.insert(codes, tonumber(c) or 0)
            end
        end

        local maxTemps = {}
        local maxPart = rawDaily:match('"temperature_2m_max":%s*%[(.-)%]')
        if maxPart then
            for t in maxPart:gmatch('([%-%d%.]+)') do
                table.insert(maxTemps, tonumber(t) or 0)
            end
        end

        -- Dicionario de nomes de dias com encoding compativel CP_ACP (Windows-1252)
        local DAYS_LOOKUP = {
            Portuguese = { 'Domingo', 'Segunda', 'Ter\231a', 'Quarta', 'Quinta', 'Sexta', 'S\225bado' },
            English = { 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' },
            Spanish = { 'Domingo', 'Lunes', 'Martes', 'Mi\233rcoles', 'Jueves', 'Viernes', 'S\225bado' }
        }
        local curLang = SKIN:GetVariable('Language', 'Portuguese')
        local daysTable = DAYS_LOOKUP[curLang] or DAYS_LOOKUP['Portuguese']

        -- Dias 2, 3 e 4 representam Amanha, Depois de Amanha e Terceiro Dia (indice 1 e hoje)
        for i = 2, math.min(4, #times) do
            local dt = times[i]
            local y, m, d = dt:match('(%d%d%d%d)%-(%d%d)%-(%d%d)')
            local dayName = ""
            if y and m and d then
                local ts = os.time({year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=12})
                local wday = os.date('*t', ts).wday
                dayName = daysTable[wday] or ""
            end
            local fCode = codes[i] or 0
            local fMax = maxTemps[i] or 0
            local fCond = GetWeatherConditionText(fCode)
            local fIcon = GetWeatherIcon(fCode, 1) -- Icone diurno para previsao
            local fTemp = string.format('%.0f%s', fMax, unitSymbol)

            table.insert(Weather.forecast, {
                dayName = dayName,
                dateStr = (d and m) and (d .. '/' .. m) or "",
                cond = fCond,
                temp = fTemp,
                icon = fIcon,
                textPan = string.format('%s (%s/%s) - %s, %s', dayName, d, m, fCond, fTemp)
            })
        end
    end

    Weather.available = true

    local city = SKIN:GetVariable('WeatherCity', 'Rio de Janeiro, BR')
    Weather.city = (city ~= '') and city or 'Rio de Janeiro, BR'

    if Utility.mode ~= 'promo' then
        UtilityApplyMode(Utility.mode)
    end
end

function WeatherOffline()
    Weather.available = false
    Weather.cond = SKIN:GetVariable('Lang_WeatherOffline', 'CLIMA OFFLINE')
    Weather.tempCond = Weather.cond
    Weather.wind = 'Vento: --'
    Weather.pressHum = 'Pressao: -- | Umidade: --'
    if Utility.mode ~= 'promo' then
        UtilityApplyMode(Utility.mode)
    end
end

function OpenUtilityLink()
    if Utility.mode == 'promo' then
        local proUrl = SKIN:GetVariable('ProDeviantUrl', 'https://www.deviantart.com/geovanesou/art/1381771713')
        SKIN:Bang('["' .. proUrl .. '"]')
    else
        local lat = SKIN:GetVariable('WeatherLatitude', '-22.9068')
        local lon = SKIN:GetVariable('WeatherLongitude', '-43.1729')
        SKIN:Bang('["https://open-meteo.com/en/docs#latitude=' .. lat .. '&longitude=' .. lon .. '"]')
    end
end

function SetFeedOffline(lineIndex)
    if tonumber(lineIndex) == 4 then return end
    local line = Lines[lineIndex]
    if not line or line.isOffline then return end
    line.isOffline = true
    line.isReady = false
    line.pos = 0

    local offColor = SKIN:GetVariable('OfflineColor', '245,158,11,255')
    local offTextColor = SKIN:GetVariable('OfflineTextColor', '248,113,113,255')

    local tagBg = 'MeterTagBg' .. lineIndex
    SKIN:Bang('!SetOption', tagBg, 'Shape', 'Rectangle 0,0,(#TagWidth# - 6),(#RowHeight# - 8),3 | Fill Color 0,0,0,255 | StrokeWidth 1 | Stroke Color ' .. offColor)
    SKIN:Bang('!UpdateMeter', tagBg)

    local tagMeter = 'MeterTagText' .. lineIndex
    SKIN:Bang('!SetOption', tagMeter, 'FontColor', offColor)
    SKIN:Bang('!UpdateMeter', tagMeter)

    local textMeter = 'MeterTickerText' .. lineIndex
    SKIN:Bang('!SetOption', textMeter, 'X', '0')
    SKIN:Bang('!SetOption', textMeter, 'Text', '#OfflineMessage#')
    SKIN:Bang('!SetOption', textMeter, 'InlinePattern', '^$')
    SKIN:Bang('!SetOption', textMeter, 'FontColor', offTextColor)
    SKIN:Bang('!UpdateMeter', textMeter)
    SKIN:Bang('!Redraw')
end

-- Reconstrói a linha com highlight amarelo dos itens frescos via regex
function RebuildMarquee(lineIndex)
    local line = Lines[lineIndex]
    if not line or not line.items or #line.items == 0 then return end

    local now = os.time()
    local titles = {}
    local freshPatterns = {}
    local hasFresh = false

    for _, item in ipairs(line.items) do
        table.insert(titles, item.title)
        local age = now - (item.firstSeen or 0)
        if age <= FRESH_DURATION then
            local escaped = EscapeRegex(item.title)
            table.insert(freshPatterns, escaped)
            hasFresh = true
        end
    end

    if #titles > 0 then
        local assembled = table.concat(titles, Separator) .. Separator
        local fullText = assembled .. assembled

        local meterName = 'MeterTickerText' .. lineIndex
        SKIN:Bang('!SetOption', meterName, 'FontColor', '#TextColor#')

        if #freshPatterns > 0 then
            local pattern = table.concat(freshPatterns, '|')
            SKIN:Bang('!SetOption', meterName, 'InlinePattern', pattern)
        else
            SKIN:Bang('!SetOption', meterName, 'InlinePattern', '^$')
        end

        if line.text ~= fullText then
            line.text = fullText
            SKIN:Bang('!SetOption', meterName, 'Text', fullText)
            SKIN:Bang('!UpdateMeter', meterName)

            local meter = SKIN:GetMeter(meterName)
            if meter then
                local totalW = meter:GetW()
                line.singleWidth = math.floor(totalW / 2)
                if line.singleWidth <= 0 then line.singleWidth = ContainerWidth end
            else
                line.singleWidth = ContainerWidth
            end
        else
            SKIN:Bang('!UpdateMeter', meterName)
        end

        line.hasFreshItems = hasFresh
    end
end

-- Chamado quando o WebParser de um feed conclui download/parse
function UpdateFeed(lineIndex)
    lineIndex = tonumber(lineIndex)
    if not lineIndex or lineIndex < 1 or lineIndex > 10 then return end

    local line = Lines[lineIndex]
    if not line then return end

    line.items = {}
    local channelSpeed = tonumber(SKIN:GetVariable('FeedSpeed' .. lineIndex, '1.0')) or 1.0
    line.speed = channelSpeed

    local now = os.time()
    local isInitialFeedRun = (InitializedFeeds[lineIndex] == nil)

    for itemIdx = 1, 10 do
        local measureName = string.format('MeasureF%dItem%d', lineIndex, itemIdx)
        local linkMeasureName = string.format('MeasureF%dLink%d', lineIndex, itemIdx)

        local mTitle = SKIN:GetMeasure(measureName)
        local mLink = SKIN:GetMeasure(linkMeasureName)

        if mTitle then
            local titleStr = mTitle:GetStringValue() or ""
            titleStr = CleanHeadline(titleStr)

            if titleStr ~= "" and titleStr ~= "..." then
                local linkStr = ""
                if mLink then
                    linkStr = mLink:GetStringValue() or ""
                end

                if isInitialFeedRun then
                    if itemIdx == 1 then
                        FirstSeen[titleStr] = now
                    else
                        FirstSeen[titleStr] = now - (FRESH_DURATION + 1)
                    end
                else
                    if not FirstSeen[titleStr] then
                        FirstSeen[titleStr] = now
                    end
                end

                table.insert(line.items, {
                    title = titleStr,
                    link = linkStr,
                    firstSeen = FirstSeen[titleStr] or 0
                })
            end
        end
    end

    InitializedFeeds[lineIndex] = true

    if #line.items > 0 then
        line.isOffline = false
        local tagBg = 'MeterTagBg' .. lineIndex
        SKIN:Bang('!SetOption', tagBg, 'Shape', 'Rectangle 0,0,(#TagWidth# - 6),(#RowHeight# - 8),3 | Fill Color #TagBgColor# | StrokeWidth 1 | Stroke Color #FeedTagColor' .. lineIndex .. '#')
        SKIN:Bang('!UpdateMeter', tagBg)

        local tagMeter = 'MeterTagText' .. lineIndex
        SKIN:Bang('!SetOption', tagMeter, 'Text', line.feedTag)
        SKIN:Bang('!SetOption', tagMeter, 'FontColor', SKIN:GetVariable('FeedTagColor' .. lineIndex, '226,232,240,255'))
        SKIN:Bang('!UpdateMeter', tagMeter)

        RebuildMarquee(lineIndex)
        line.pos = 0
        line.isReady = true
    else
        SetFeedOffline(lineIndex)
    end

    RebuildPanMarquee()
end

-- Loop de animação contínua (50 FPS a cada 20ms)
function Update()
    if not Initialized then return end

    if ViewMode == 1 then
        if Pan.isReady and not Pan.paused and Pan.singleWidth > 0 then
            Pan.pos = Pan.pos - (Pan.speed * BaseSpeed)
            if Pan.pos <= -Pan.singleWidth then
                Pan.pos = Pan.pos + Pan.singleWidth
            end
            SKIN:Bang('!SetOption', 'MeterPanText', 'X', math.floor(Pan.pos))
            SKIN:Bang('!UpdateMeter', 'MeterPanText')
        end
    else
        for i = 1, 10 do
            local line = Lines[i]
            if line and line.isReady and not line.paused and line.singleWidth > 0 and line.slotY then
                line.pos = line.pos - (line.speed * BaseSpeed)

                if line.pos <= -line.singleWidth then
                    line.pos = line.pos + line.singleWidth
                end

                local meterName = 'MeterTickerText' .. i
                SKIN:Bang('!SetOption', meterName, 'X', math.floor(line.pos))
                SKIN:Bang('!UpdateMeter', meterName)
            end
        end
    end

    UtilityUpdate()

    -- Timeout de Boot (após 25s, feeds ativos sem resposta viram OFFLINE)
    BootTimer = BootTimer + 1
    if BootTimer == 1250 then
        for i = 1, 10 do
            local enabled = tonumber(SKIN:GetVariable('FeedEnabled' .. i, '1')) or 1
            local line = Lines[i]
            if enabled == 1 and line and not line.isReady and not line.isOffline then
                SetFeedOffline(i)
            end
        end
    end

    -- A cada 5 segundos (250 ticks), verifica se alguma notícia completou os 7 minutos
    TickCounter = TickCounter + 1
    if TickCounter % 250 == 0 then
        for i = 1, 10 do
            local line = Lines[i]
            if line and line.isReady and line.hasFreshItems then
                RebuildMarquee(i)
            end
        end
    end
end

-- Renderiza o tooltip de extrapolação inteligente
function ShowHeadlineTooltip(lineIndex)
    local line = Lines[lineIndex]
    if not line or not line.items or #line.items == 0 or line.singleWidth <= 0 then return end

    local numItems = #line.items
    local windowCenter = ContainerWidth / 2
    local currentOffset = (-line.pos + windowCenter) % line.singleWidth

    local totalChars = 0
    for k = 1, numItems do
        totalChars = totalChars + #line.items[k].title + 10
    end
    if totalChars <= 0 then totalChars = 1 end

    local accumOffset = 0
    local activeIdx = 1
    for k = 1, numItems do
        local itemWidth = ((#line.items[k].title + 10) / totalChars) * line.singleWidth
        if currentOffset >= accumOffset and currentOffset < (accumOffset + itemWidth) then
            activeIdx = k
            break
        end
        accumOffset = accumOffset + itemWidth
    end

    line.currentActiveIndex = activeIdx
    local activeItem = line.items[activeIdx]
    if activeItem then
        local headerH = 32
        local rowH = 26
        local rowY = line.slotY or (headerH + (lineIndex - 1) * rowH)

        local isLong = (#activeItem.title > 75)
        local tipH = isLong and 44 or 28
        local tipW = 620

        local tipY = rowY + rowH + 2
        local totalWidgetHeight = headerH + (ActiveRows * rowH) + 6
        if tipY + tipH > totalWidgetHeight then
            tipY = rowY - tipH - 2
        end

        local tipBg = SKIN:GetVariable('TooltipBgColor', '15,23,42,252')
        local tipBorder = SKIN:GetVariable('TooltipBorderColor', '56,189,248,220')
        local tipText = SKIN:GetVariable('TooltipTextColor', '248,250,252,255')

        local bgShape = string.format('Rectangle 0,0,%d,%d,4 | Fill Color %s | StrokeWidth 1 | Stroke Color %s', tipW, tipH, tipBg, tipBorder)
        SKIN:Bang('!SetOption', 'TipContainer', 'Shape', bgShape)
        SKIN:Bang('!SetOption', 'TipContainer', 'X', '10')
        SKIN:Bang('!SetOption', 'TipContainer', 'Y', tostring(tipY))

        SKIN:Bang('!SetOption', 'TipText', 'W', tostring(tipW - 20))
        SKIN:Bang('!SetOption', 'TipText', 'H', tostring(tipH - 8))
        SKIN:Bang('!SetOption', 'TipText', 'X', '18')
        SKIN:Bang('!SetOption', 'TipText', 'Y', tostring(tipY + (isLong and 4 or 6)))
        SKIN:Bang('!SetOption', 'TipText', 'FontColor', tipText)
        SKIN:Bang('!SetOption', 'TipText', 'Text', activeItem.title)

        SKIN:Bang('!ShowMeterGroup', 'SingularTipGroup')
        SKIN:Bang('!UpdateMeterGroup', 'SingularTipGroup')
        SKIN:Bang('!Redraw')
    end
end

function PauseLine(lineIndex)
    lineIndex = tonumber(lineIndex)
    if not lineIndex or not Lines[lineIndex] then return end

    local line = Lines[lineIndex]
    line.paused = true
    ShowHeadlineTooltip(lineIndex)
end

function ResumeLine(lineIndex)
    if lineIndex and Lines[lineIndex] then
        Lines[lineIndex].paused = false
        SKIN:Bang('!HideMeterGroup', 'SingularTipGroup')
        SKIN:Bang('!UpdateMeterGroup', 'SingularTipGroup')
        SKIN:Bang('!Redraw')
    end
end

function PausePan()
    Pan.paused = true
end

function ResumePan()
    Pan.paused = false
end

function ScrollLine(lineIndex, direction)
    lineIndex = tonumber(lineIndex)
    if not lineIndex or not Lines[lineIndex] then return end

    local line = Lines[lineIndex]
    if not line.isReady or line.singleWidth <= 0 then return end

    local step = 50
    line.pos = line.pos - (direction * step)

    if line.pos <= -line.singleWidth then
        line.pos = line.pos + line.singleWidth
    elseif line.pos > 0 then
        line.pos = line.pos - line.singleWidth
    end

    local meterName = 'MeterTickerText' .. lineIndex
    SKIN:Bang('!SetOption', meterName, 'X', math.floor(line.pos))
    SKIN:Bang('!UpdateMeter', meterName)
    SKIN:Bang('!Redraw')

    if line.paused then
        ShowHeadlineTooltip(lineIndex)
    end
end

function OpenLink(lineIndex)
    lineIndex = tonumber(lineIndex)
    if lineIndex == 4 then
        local proUrl = SKIN:GetVariable('ProDeviantUrl', 'https://www.deviantart.com/geovanesou/art/1381771713')
        SKIN:Bang('["' .. proUrl .. '"]')
        return
    end
    if lineIndex and Lines[lineIndex] then
        local line = Lines[lineIndex]
        local activeIdx = line.currentActiveIndex or 1
        local targetItem = line.items[activeIdx] or line.items[1]

        if targetItem and targetItem.link and targetItem.link ~= "" then
            SKIN:Bang('["' .. targetItem.link .. '"]')
        elseif line.feedUrl and line.feedUrl ~= "" then
            SKIN:Bang('["' .. line.feedUrl .. '"]')
        end
    end
end

-- Extrai o domínio raiz/home do portal de notícias a partir de um link ou feed
function GetPortalRoot(url)
    if not url or url == "" then return nil end
    local root = url:match('^(https?://[^/]+)')
    if not root then return nil end

    root = root:gsub('^https?://feeds%.bbci%.co%.uk', 'https://www.bbc.com')
    root = root:gsub('^https?://feeds%.bloomberg%.com', 'https://www.bloomberg.com')
    root = root:gsub('^https?://rss%.cnn%.com', 'https://edition.cnn.com')
    root = root:gsub('^https?://feeds%.reuters%.com', 'https://www.reuters.com')
    root = root:gsub('^https?://feeds%.feedburner%.com', 'https://www.google.com')

    return root
end

-- Abre a página principal do portal de notícias correspondente à tag do canal
function OpenChannelRoot(lineIndex)
    lineIndex = tonumber(lineIndex)
    if lineIndex == 4 then
        local proUrl = SKIN:GetVariable('ProDeviantUrl', 'https://www.deviantart.com/geovanesou/art/1381771713')
        SKIN:Bang('["' .. proUrl .. '"]')
        return
    end
    if not lineIndex or not Lines[lineIndex] then return end
    local line = Lines[lineIndex]

    local rootUrl = nil

    if line.items and #line.items > 0 and line.items[1].link and line.items[1].link ~= "" then
        rootUrl = GetPortalRoot(line.items[1].link)
    end

    if not rootUrl and line.feedUrl and line.feedUrl ~= "" then
        rootUrl = GetPortalRoot(line.feedUrl)
    end

    if rootUrl and rootUrl ~= "" then
        SKIN:Bang('["' .. rootUrl .. '"]')
    end
end

