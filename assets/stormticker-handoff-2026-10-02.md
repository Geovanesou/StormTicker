---
type: Note
status: Active
---

# StormTicker — Handoff Ops Room → Antigravity (2026-10-02)

Relatório do estado atual das skins **StormTicker (Standard)** e **StormTicker-Pro**, para continuidade do trabalho no Antigravity.

## Arquitetura atual

Ambas as edições usam a mesma estrutura de pastas (menu de contexto nativo do Rainmeter = hierarquia de diretórios):

```
StormTicker\                      StormTicker-Pro\
├── Box\                          ├── Box\
│   ├── Box StormTicker.ini       │   └── (variants por canal/tema)
│   ├── Box Cyberpunk.ini         ├── Panoramic\
│   └── Box Stealth.ini           │   └── (variants por canal/tema)
├── Panoramic\                    ├── Settings\
│   ├── Panoramic StormTicker.ini ├── TickerEngine.lua
│   ├── Panoramic Cyberpunk.ini   └── @Resources\
│   └── Panoramic Stealth.ini         ├── StormTickerCore.inc
├── Settings\                         ├── Panoramic.inc
│   ├── Settings.ini                  ├── Config.inc
│   └── Settings.lua                  ├── Themes\<7 temas>.inc
├── TickerEngine.lua                  └── Languages\
└── @Resources\
    ├── StormTickerCore.inc   ← todo o miolo (measures + meters)
    ├── Config.inc            ← variáveis default (geometria, cores, weather)
    ├── Themes\{StormTicker,Cyberpunk,Stealth}.inc
    ├── Languages\{English,Portuguese,Spanish}.inc
    ├── LanguageOverride.inc
    ├── Feeds.inc
    ├── ModeOverride.inc      ← código morto (ver pendências)
    └── ThemeOverride.inc     ← código morto (ver pendências)
```

**Padrão de variante**: cada `.ini` é um wrapper fino (~20 linhas): `[Rainmeter]` + `[Metadata]` + `[Variables]` com `@IncludeTheme` hardcoded e `@IncludeCore=#@#StormTickerCore.inc` na última linha — a include puxa o arquivo inteiro dentro de `[Variables]`. Idêntico ao Pro.

**Troca de modo** (Box ↔ Panoramic): `ModeSwitchAction` no `.ini` faz `[!ActivateConfig]` na variante irmã de mesmo tema + `[!DeactivateConfig]` na atual. `ViewMode=0/1` vem do `.ini` da variante; `ApplyViewMode()` no Lua lê essa variável e aplica a geometria.

**SkinPath real**: `X:\OneDrive\Documentos\Rainmeter\Skins\` com junctions `StormTicker` e `StormTicker-Pro` → `X:\OneDrive\Customizations\RainMeter\...` (editar na fonte, deploy automático via junction).

## O que foi feito nesta sessão

### 1. Settings do Standard alinhado ao Pro
- Botões convertidos de `String` para pares **Shape+String** (RoundedRectangle raio 4 + texto centrado `CenterCenter`), fonte 9→8 — mesma estética do Pro.
- **Armadilha resolvida**: com `StringAlign=CenterCenter`, X/Y do texto é o *centro* da caixa → texto usa `X=(W/2)r Y=13r` (metade da altura do shape de 26px). E shape encadeado após texto usa `Y=-13r` para compensar o offset herdado.
- **Armadilha 2**: `X=NR` mede `X+W` do meter anterior; com âncora central isso soma `W/2` a mais → espaçamento explode. Solução: **X absolutos** `(#MenuWidth# + N)` em todos os `_Bg`.
- Layout final: labels em `MenuWidth+25`, blocos de botões a partir de `+28`, gaps 8–12px. Posições em `Settings\Settings.ini`.
- Abas de canal voltaram a `Canal 1…10` + 🔒 (nomes de canais são exclusivos do Pro — não reverter).
- Título "Opções Gerais" em âmbar `245,158,11`.
- Corrigido `Text=ATUALIZAÇÃO:` e `...POSIÇÃO (PRO)` — estavam truncados porque bytes UTF-8 de `ÇÃ`/`ÇÃO` ficaram orfãos em linhas separadas após reescritas.

### 2. Menu de contexto idêntico ao Pro
- Removido todo `ContextTitle`/`ContextAction` customizado (inclusive o submenu de idiomas — idioma só via Settings).
- Variantes movidas para `Box\` e `Panoramic\` → menu nativo: `StormTicker ▸ Box ▸ …`, `Panoramic ▸ …`, `Settings ▸`.

### 3. Bloco meteorológico
- **Standard**: ocupa header+linha (altura total), à direita. Ciclo `weather → forecast → promo` no `UtilityCycle()`/`UpdateWeather()`/`UpdateForecast()`. Dados: cidade+temp+condição, vento (dir+vel), umidade, e previsão 3 dias (`NOITE 20° … | SÁB 19/21° … | DOM …`) via BBC RSS — feeds em `Config.inc` (`WeatherFeedURL`, `WeatherForecastURL`, `WeatherPanelW=480`, `WeatherLocationID=3451190`).
- **Pro**: herda o painel sem promo — 3 linhas estáticas em `Panoramic.inc` (`MeterPanWeatherMain/Sub/Fcst`), funções portadas no `TickerEngine.lua` do Pro, streams passam por baixo do painel opaco. Clique abre `bbc.com/weather/3451190`; hover pausa.
- Controles `□`/`—` e `FONTES` ancorados à esquerda do painel (`panXF - N`).

### 4. Painel 480px + fundo 100% opaco
- `WeatherPanelW=480` nas duas edições (espaço reservado para futura imagem ilustrativa). Standard: `panXF = SCREENAREAWIDTH - 480`.
- `BgColor` alpha 235→255 em **todas** as themes: 3 do Standard + 7 do Pro. `Config.inc` do Standard ainda tem `BgColor=8,12,20,235` mas a theme sobrescreve.

### 5. Bug "sem fundo no Standard" — RESOLVIDO
- Causa: instância zumbi — a skin foi carregada enquanto os arquivos de variante estavam corrompidos (placeholders literais `Themes$name.inc`), a include da theme falhava → `#BgColor#` sem resolver → Shape inválido → `MeterBg` não desenhava (textos flutuavam sem fundo). Correções posteriores não surtiam efeito porque `Active=3` no `Rainmeter.ini` (variantes empilhadas) fazia `!Refresh` mirar a instância errada.
- Fix: `!DeactivateConfig 'StormTicker\Panoramic'` completo + `!ActivateConfig` de uma única variante. Debug temporário confirmou: `MeterBg X=0 W=1921 H=63 Shape=Rectangle 0,0,(1920),62,8 | Fill Color 8,12,20,255` — correto.

## Estado atual verificado

- `StormTicker\Panoramic\Panoramic StormTicker.ini` ativo, refresh limpo 19:28, zero erros no log.
- `[StormTicker\Panoramic] Active=3` no `Rainmeter.ini` — provavelmente stale; a skin ativa responde por `StormTicker\Panoramic` (config-mãe).

## Pendências

1. **"Bicolor" residual** — usuário notou o fundo panorâmico em dois tons (captura 31). Provável: diferença `HeaderBgColor` vs `BgColor` na faixa superior, ou shape sobreposto. Deixado de lado a pedido do usuário.
2. **Imagem meteorológica ilustrativa** — o painel de 480px foi dimensionado para isso. Usuário quer imagem antes do texto. Fonte/formato/posição não definidos.
3. **Código morto no Standard**: `ToggleViewMode()` no Lua (modo agora é variante), `ModeOverride.inc`, `ThemeOverride.inc`, `SetTheme` no `Settings.lua` — inertes, removíveis.
4. **Git**: working tree do Standard tem muitas mudanças não commitadas (reestruturação inteira). Avaliar commit.

## Gotchas operacionais (críticos)

- **Encoding**: `.ini`/`.inc` do Standard são **UTF-16LE+BOM**; `Config.inc` do **Pro é ASCII**. O log `Rainmeter.log` é UTF-8. NUNCA iconv cego — sempre `file` + `xxd -l 16` antes. Mojibake no log = iconv duplo.
- **Targeting Rainmeter**: `!Refresh`/`!SetOption`/`!CommandMeasure` aceitam config-mãe (`StormTicker\Panoramic`); com nome de arquivo completo pode dar "not active" mesmo estando ativa. Se suspeitar de zumbi: `!DeactivateConfig` + `!ActivateConfig`.
- **`Active=N`** em `Rainmeter.ini` (UTF-16): indica variantes carregadas do config — N>1 = várias empilhadas na mesma posição.
- **Python não existe** no host (redireciona pra Store). Usar perl/sed. Cuidado com heredocs aninhados e escapes de `\` — preferir script em arquivo a one-liners.
- **Lua**: `IsHidden()` não existe como método de Meter — usar `GetOption('Hidden')`. Debug via `SKIN:Bang('!Log', ...)` + `!CommandMeasure MeasureTickerEngine "Func()"`.
