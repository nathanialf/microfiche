# MICROFICHE — Godot 4.6 Project

## Concept
3D investigation game about the developer's experience at Amazon, told through a vintage microfiche reader terminal with a Hypnospace Outlaw / Commodore SX-64 / Her Story aesthetic.

## Core Loop
- Player sits at a cramped desk with mechanical hands
- Microfiche reader terminal (amber CRT, retro) in front of them
- Cartridges can be slotted into the reader
- Documents contain classified in-universe text (Amazon experience as sci-fi allegory)
- Reading documents surfaces keywords → keywords unlock new cartridges
- One cartridge (CLASSIFIED-7) is always present but always access-denied — messages get increasingly personal with each insert attempt
- Notepad [N] for writing observations (Marathon 2026 PDA style, auto-saves)

## Cartridge Progression
- **Start with:** ALPHA (intake/orientation — Threshold Accords + Omicron Collapse), BETA (personnel/mox — Yael Mox + Sable Threshold), CLASSIFIED-7 (access denied)
- **Unlock via keywords:** GAMMA (vex/equipment), DELTA (entities/glass litany), EPSILON (expanse/kaya), ZETA (watcher/hollow blade)

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
- [N] Toggle notepad
- [ESC] Back / cancel
- Mouse wheel: scroll documents

## Key Files
- `scripts/autoloads/game_state.gd` — central state, save/load
- `scripts/autoloads/cartridge_database.gd` — loads all JSON data
- `scripts/ui/terminal_ui.gd` — master UI controller
- `scripts/ui/document_reader.gd` — document display + keyword highlighting
- `data/cartridges/*.json` — all content
- `data/keywords.json` — keyword→cartridge unlock map
