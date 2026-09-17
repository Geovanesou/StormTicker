-- ==============================================================================
-- ⚡ StormTicker Pro - Asynchronous Multi-Line Ticker Engine (DirectWrite)
-- Copyright (c) 2026 Geovane Souza. All Rights Reserved.
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

-- Manchetes Promocionais da Versão Pro (Linha 4 CTA)
local PromoHeadlines = {
    {
        title = "⚡ CONHEÇA O STORMTICKER PRO: Matriz assíncrona completa com 10 canais simultâneos em DirectWrite a 60 FPS!",
        link = "https://www.deviantart.com/geovanesou/art/1381771713"
    },
    {
        title = "⚡ DESBLOQUEIE TODOS OS RECURSOS: Velocidades independentes por canal, seletor de cadência (15m a 6h) e presets instantâneos!",
        link = "https://www.deviantart.com/geovanesou/art/1381771713"
    },
    {
        title = "⚡ ACESSE A EDIÇÃO PRO NO DEVIANTART: Clique aqui para garantir sua licença vitalícia da versão completa de 10 canais!",
        link = "https://www.deviantart.com/geovanesou/art/1381771713"
    }
}




-- Escape special characters for Rainmeter regex matching
function EscapeRegex(str)
    if not str then return "" end
    return str:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
end

-- Clean XML/HTML residue, CDATA markers, and HTML entities
function CleanHeadline(str)
    if not str or str == "" then return "" end
    str = str:gsub('<!%[CDATA%[', ''):gsub('%]%]>', '')
    str = str:gsub('<[^>]+>', '')
    
    -- Aspas especiais, prime e símbolos comuns em feeds (ex: TVs 50″, citações)
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
    
    -- Conversão genérica de entidades decimais ASCII (< 128)
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
    
    local tickerW = tonumber(SKIN:GetVariable('TickerWidth', '480')) or 480
    local tagW = tonumber(SKIN:GetVariable('TagWidth', '92')) or 92
    ContainerWidth = tickerW - tagW - 24

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

    -- Inicializa a Linha 4 como canal especial de Showcase do StormTicker Pro
    local line4 = Lines[4]
    if line4 then
        line4.items = {}
        for _, p in ipairs(PromoHeadlines) do
            table.insert(line4.items, {
                title = CleanHeadline(p.title),
                link = SKIN:GetVariable('ProDeviantUrl', p.link),
                firstSeen = os.time()
            })
        end
        line4.isReady = true
        line4.isOffline = false
        RebuildMarquee(4)
    end

    LayoutRows()
    Initialized = true
end

-- Empilhamento dinâmico, barra de rodapé e gaveta de galeria
function LayoutRows()
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
            end
            
            SKIN:Bang('!SetOption', 'MeterTagBg' .. i, 'Y', tostring(slotY + 4))
            SKIN:Bang('!SetOption', 'MeterTagText' .. i, 'Y', tostring(slotY + 6))
            SKIN:Bang('!SetOption', 'MeterContainer' .. i, 'Y', tostring(slotY))
            SKIN:Bang('!SetOption', 'MeterRowDivider' .. i, 'Y', tostring(slotY + rowH))
            
            SKIN:Bang('!ShowMeter', 'MeterTagBg' .. i)
            SKIN:Bang('!ShowMeter', 'MeterTagText' .. i)
            SKIN:Bang('!ShowMeter', 'MeterContainer' .. i)
            SKIN:Bang('!ShowMeter', 'MeterTickerText' .. i)
            SKIN:Bang('!ShowMeter', 'MeterRowDivider' .. i)
            
            activeCount = activeCount + 1
        else
            if line then
                line.slotY = nil
            end
            SKIN:Bang('!HideMeter', 'MeterTagBg' .. i)
            SKIN:Bang('!HideMeter', 'MeterTagText' .. i)
            SKIN:Bang('!HideMeter', 'MeterContainer' .. i)
            SKIN:Bang('!HideMeter', 'MeterTickerText' .. i)
            SKIN:Bang('!HideMeter', 'MeterRowDivider' .. i)
        end
    end
    
    ActiveRows = activeCount
    
    -- Posicionar a barra de rodapé exatamente abaixo da última linha ativa
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

-- Marca visualmente uma linha como OFFLINE se falhar
function SetFeedOffline(lineIndex)
    if tonumber(lineIndex) == 4 then return end -- Linha Pro nunca fica offline
    local line = Lines[lineIndex]
    if not line or line.isOffline then return end
    line.isOffline = true
    line.isReady = false
    line.pos = 0
    
    local tagBg = 'MeterTagBg' .. lineIndex
    SKIN:Bang('!SetOption', tagBg, 'Shape', 'Rectangle 0,0,(#TagWidth# - 6),(#RowHeight# - 8),3 | Fill Color 0,0,0,255 | StrokeWidth 1 | Stroke Color 245,158,11,255')
    SKIN:Bang('!UpdateMeter', tagBg)

    local tagMeter = 'MeterTagText' .. lineIndex
    SKIN:Bang('!SetOption', tagMeter, 'FontColor', '245,158,11,255')
    SKIN:Bang('!UpdateMeter', tagMeter)
    
    local textMeter = 'MeterTickerText' .. lineIndex
    SKIN:Bang('!SetOption', textMeter, 'X', '0')
    SKIN:Bang('!SetOption', textMeter, 'Text', '#OfflineMessage#')
    SKIN:Bang('!SetOption', textMeter, 'InlinePattern', '^$')
    SKIN:Bang('!SetOption', textMeter, 'FontColor', '248,113,113,255')
    SKIN:Bang('!UpdateMeter', textMeter)
    SKIN:Bang('!Redraw')
end

-- Reconstrói a linha sem o prefixo [NOVO], usando cor amarela via regex
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
        SKIN:Bang('!SetOption', tagBg, 'Shape', 'Rectangle 0,0,(#TagWidth# - 6),(#RowHeight# - 8),3 | Fill Color 15,23,42,255 | StrokeWidth 1 | Stroke Color #FeedTagColor' .. lineIndex .. '#')
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
end

-- Loop de animação contínua (50 FPS a cada 20ms)
function Update()
    if not Initialized then return end

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

-- Renderiza o tooltip extrapolação inteligente
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
        
        local bgShape = string.format('Rectangle 0,0,%d,%d,4 | Fill Color 15,23,42,252 | StrokeWidth 1 | Stroke Color 56,189,248,220', tipW, tipH)
        SKIN:Bang('!SetOption', 'TipContainer', 'Shape', bgShape)
        SKIN:Bang('!SetOption', 'TipContainer', 'X', '10')
        SKIN:Bang('!SetOption', 'TipContainer', 'Y', tostring(tipY))
        
        SKIN:Bang('!SetOption', 'TipText', 'W', tostring(tipW - 20))
        SKIN:Bang('!SetOption', 'TipText', 'H', tostring(tipH - 8))
        SKIN:Bang('!SetOption', 'TipText', 'X', '18')
        SKIN:Bang('!SetOption', 'TipText', 'Y', tostring(tipY + (isLong and 4 or 6)))
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
    lineIndex = tonumber(lineIndex)
    if lineIndex and Lines[lineIndex] then
        Lines[lineIndex].paused = false
        SKIN:Bang('!HideMeterGroup', 'SingularTipGroup')
        SKIN:Bang('!UpdateMeterGroup', 'SingularTipGroup')
        SKIN:Bang('!Redraw')
    end
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
    
    -- Normaliza subdomínios conhecidos de syndication/feeds para o portal principal
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
    
    -- 1. Prioridade: item de notícia (aponta direto para o portal de publicação)
    if line.items and #line.items > 0 and line.items[1].link and line.items[1].link ~= "" then
        rootUrl = GetPortalRoot(line.items[1].link)
    end
    
    -- 2. Fallback: URL do feed configurado
    if not rootUrl and line.feedUrl and line.feedUrl ~= "" then
        rootUrl = GetPortalRoot(line.feedUrl)
    end
    
    if rootUrl and rootUrl ~= "" then
        SKIN:Bang('["' .. rootUrl .. '"]')
    end
end




