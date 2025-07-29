# RPCombat - Turn-Based RP Combat Tracker

A POC of a World of Warcraft addon for managing turn-based roleplay combat with synchronized initiative tracking across party/raid members.

## Overview

RPCombat is an attempt at providing a clean, easy & intuitive interface for organizing combat in RP. Party/Raid leaders can start combat encounters, prompting all participants to roll for intiative. The addon automatically manages turn order with real-time synchronization across all party members. (Given that they have the addon installed)


## Features

### Core Combat Management
- **Turn-based initiative system** using the in-game /roll commands
- **Automatic turn order sorting** by highest initiative roll
- **Real-time synchronization** across all party members
- **Party leader controls** for starting/ending combat and managing participants

### User Interface
- **Clean, resizable main window** with drag-and-drop positioning
- **Pre-combat party list** showing all members and marked enemies
- **Combat turn order display** with current turn highlighting
- **Minimap icon** for quick access (LibDBIcon integration)
- **Right-click context menus** for player management

### Advanced Features
- **Offline player detection** and visual indicators
- **Raid marker integration** for enemy tracking
- **Leader-only controls** with permission validation
