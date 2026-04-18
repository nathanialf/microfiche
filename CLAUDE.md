# MICROFICHE — Godot 4.6 Project

## Concept
3D investigation game about the developer's experience at Amazon, told through a vintage microfiche reader terminal with a Hypnospace Outlaw / Commodore SX-64 / Her Story aesthetic.

## Core Loop
- Player sits at a cramped desk with mechanical hands
- Microfiche reader terminal (amber CRT, retro) in front of them
- Cartridges can be slotted into the reader — one document per cartridge
- Documents contain classified in-universe text (Amazon experience as sci-fi allegory)
- Reading documents surfaces keywords → keywords unlock new cartridges
- One cartridge (CLASSIFIED-7) is always present but always access-denied — messages get increasingly personal with each insert attempt
- Notepad lives on the separate computer terminal (not the microfiche)

## Cartridge Progression
One document per cartridge. Cart IDs use the doc's short name (threshold, mox, etc.).
- **Start with:** THRESHOLD, OMICRON, MOX, SABLE, CLASSIFIED-7
- **Unlock via keywords:** VEX, CAUL, CHOIR, LITANY, EXPANSE, KAYA, WATCHER, BLADE

## Content Allegory
The sci-fi setting maps to Amazon workplace experience:
- Threshold Accords = HR policies / Leadership Principles
- Omicron Collapse = A major workplace incident / systemic failure
- Pallid Watcher = The algorithm / the system / surveillance
- Grey Fugue = Burnout / dissociation
- Greyfield Choir = Middle management
- Cognitive monitoring = Metric tracking / PIPs
- Article 7 (Unreliable Testimony) = Complaint suppression
- Void exposure / void-touched = Permanent psychological impact
- Yael Mox = The sole survivor who knows things

## Aesthetic References
- Commodore SX-64 (portable terminal body, chunky keys)
- Hypnospace Outlaw (retro UI, sense of discovery, dark themes under cheerful surface)
- Her Story (keyword discovery drives exploration)
- Marathon 2026 (PDA notepad interface)
- CRT amber phosphor glow throughout

## Tech Stack
- Godot 4.6, GL Compatibility renderer
- JSON data files for all cartridge content (data/cartridges/*.json)
- Keywords mapped in data/keywords.json
- Save file: user://microfiche_save.json

## Controls
- Mouse look (constrained — player is seated)
- [E] Interact / insert cartridge
- [R] Eject cartridge
- [ESC] Back / cancel
- Mouse wheel: scroll documents

## Key Files
- `scripts/autoloads/game_state.gd` — central state, save/load
- `scripts/autoloads/cartridge_database.gd` — loads all JSON data
- `scripts/ui/microfiche_ui.gd` — master UI controller (boot / idle / document / access-denied)
- `scripts/ui/document_reader.gd` — document display + keyword highlighting
- `data/cartridges/*.json` — all content (one doc per cartridge)
- `data/keywords.json` — keyword→cartridge unlock map
