# Pet Merging System - Implementation Guide

## Overview

This is a complete server-authoritative Pet Merging System for Roblox, designed for 60 FPS performance with strict type safety. The system prevents client-side exploits by validating all merge operations on the server.

## Architecture

### Shared Modules (`src/ReplicatedStorage/Modules/`)

- **PetsConfig.lua**: Core types, rarity progression, stat validation
- **Logger.lua**: Structured JSON logging with batching for performance
- **MergeService.lua**: Pure merge logic and validation rules

### Server Components (`src/ServerScriptService/`)

- **Adapters/DataStoreAdapter.lua**: Abstract interface for data persistence
- **Adapters/MockDataStoreAdapter.lua**: In-memory implementation with concurrency locks
- **Controllers/MergeController.server.lua**: Server-authoritative merge handler

### Client Components (`src/StarterPlayer/StarterPlayerScripts/`)

- **MergeUI.client.lua**: Lightweight client UI with 60 FPS animation

### Tests (`tests/`)

- **MergeService.spec.lua**: Unit tests for core merge logic
- **MergeSimulation.lua**: Integration testing simulation

## Key Features

### 🔒 Security & Authority
- **Server-authoritative**: All merge validation happens on server
- **Concurrency locks**: Prevents duping through simultaneous requests
- **Ownership validation**: Ensures players can only merge pets they own
- **Transaction IDs**: Deterministic merge operations for idempotency

### ⚡ Performance
- **Lightweight client**: Minimal per-frame allocations
- **Batched logging**: Reduces console spam and improves performance
- **Pure functions**: Merge logic has no side effects
- **Optimized data structures**: Efficient pet lookup and manipulation

### 🎮 Game Logic
- **Rarity progression**: Common → Uncommon → Rare → Epic → Legendary
- **Stat averaging**: Merged pets inherit averaged stats from parents
- **Species matching**: Only same-species pets can merge
- **Rarity matching**: Only same-rarity pets can merge
- **Top rarity protection**: Legendary pets cannot be merged further

### 🔧 Developer Experience
- **Strict typing**: Full Luau type coverage for better IDE support
- **Comprehensive logging**: Structured events for debugging and analytics
- **Modular design**: Easy to extend with new species or rarity tiers
- **Test coverage**: Unit tests and simulation scripts included

## Integration Steps

### 1. File Structure
Copy the `src/` directory to your Roblox project, maintaining the folder structure:
```
ReplicatedStorage/
├── Modules/
│   ├── PetsConfig.lua
│   ├── Logger.lua
│   └── MergeService.lua

ServerScriptService/
├── Adapters/
│   ├── DataStoreAdapter.lua
│   └── MockDataStoreAdapter.lua
└── Controllers/
    └── MergeController.server.lua

StarterPlayer/
└── StarterPlayerScripts/
    └── MergeUI.client.lua
```

### 2. Production Data Store
Replace `MockDataStoreAdapter` with your production implementation:

```lua
-- In MergeController.server.lua, replace this line:
local MockDataStoreAdapter = require(ServerScriptService:WaitForChild("Adapters"):WaitForChild("MockDataStoreAdapter"))
local dataStoreAdapter = MockDataStoreAdapter.new()

-- With your production adapter:
local ProductionAdapter = require(ServerScriptService:WaitForChild("Adapters"):WaitForChild("ProductionAdapter"))
local dataStoreAdapter = ProductionAdapter.new()
```

### 3. UI Integration
The `MergeUI.client.lua` provides a basic API. Integrate with your existing UI:

```lua
local MergeUI = require(StarterPlayer.StarterPlayerScripts:WaitForChild("MergeUI"))

-- When player clicks on a pet in your inventory UI:
MergeUI.selectPet(petId)

-- When player clicks merge button:
MergeUI.tryMerge()
```

### 4. Logging Integration
Configure logging for your telemetry system:

```lua
local Logger = require(ReplicatedStorage.Modules:WaitForChild("Logger"))

-- Adjust batch interval (default: 0.25 seconds)
Logger.setBatchInterval(0.5)

-- Enable/disable logging
Logger.setEnabled(true)
```

## Configuration

### Adding New Species
Edit `PetsConfig.lua`:

```lua
PetsConfig.ALLOWED_SPECIES: { [string]: true } = {
    ["Dog"] = true,
    ["Cat"] = true,
    ["Dragon"] = true,
    ["Phoenix"] = true,
    ["NewSpecies"] = true, -- Add here
}
```

### Adjusting Stat Bounds
Edit `PetsConfig.lua`:

```lua
PetsConfig.STAT_BOUNDS = {
    power = { min = 0, max = 1_000_000 },
    speed = { min = 0, max = 1_000_000 },
    luck = { min = 0, max = 1_000_000 },
}
```

### Custom Rarity Progression
Edit `PetsConfig.lua`:

```lua
PetsConfig.RARITY_LADDER: { Rarity } = { 
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" -- Add new rarities
}
```

## Testing

### Running Unit Tests
```lua
-- In Studio or test environment:
local testRunner = require(game.ReplicatedStorage.Tests:WaitForChild("MergeService.spec"))
testRunner()
```

### Running Simulation
```lua
-- In Studio or test environment:
local simulation = require(game.ReplicatedStorage.Tests:WaitForChild("MergeSimulation"))
simulation()
```

## Error Handling

The system provides comprehensive error messages:

- `"Cannot merge the same pet."` - Client sent same pet ID twice
- `"Pets must be the same species."` - Species mismatch
- `"Pets must share the same rarity."` - Rarity mismatch  
- `"Top rarity cannot be merged further."` - Legendary merge attempt
- `"You do not own both pets."` - Ownership validation failed
- `"Another merge is in progress for these pets."` - Concurrency protection
- `"Inventory over capacity."` - Capacity validation failed

## Performance Considerations

### Client Side
- Animation loop uses `RenderStepped` but with minimal per-frame work
- No heavy allocations during merge animations
- Efficient state management for pet selection

### Server Side
- Concurrency locks prevent race conditions
- Efficient pet lookup using indexed arrays
- Batched logging reduces console overhead
- Pure functions enable easy testing and optimization

## Security Features

### Anti-Exploit Measures
- Server validates all merge operations
- Client input is never trusted for authoritative actions
- Concurrency locks prevent duping exploits
- Deterministic pet ID generation prevents ID collision attacks
- Ownership validation prevents trading exploits

### Data Integrity
- Transaction IDs ensure operation idempotency
- Stat clamping prevents overflow exploits
- Type safety prevents malformed data
- Comprehensive error handling prevents crashes

This system is production-ready and follows Roblox best practices for server-authoritative game systems.