# Copilot Instructions for sm-plugin-Status

## Repository Overview

This repository contains **Status Fixer**, a SourceMod plugin that enhances the default `status` command for Source engine game servers. The plugin provides detailed server information, player statistics, and administrative features while maintaining compatibility with optional extensions.

**Key Features:**
- Enhanced status command with server performance metrics
- Player information with geographic location (GeoIP integration)
- Admin-only features (IP address visibility)
- Optional PlayerManager integration for Steam validation
- Cross-platform compatibility (Windows, Linux, macOS)

## Technical Environment

### Core Dependencies
- **SourceMod**: 1.11.0+ (specified in sourceknight.yaml)
- **Language**: SourcePawn
- **Compiler**: SourceMod Compiler (spcomp) via SourceKnight build system
- **Minimum SourceMod API**: 1.12+ for production deployment

### Optional Dependencies
- **GeoIP Extension**: For country code display in player listings
- **PlayerManager Plugin**: For Steam account validation (`PM_IsPlayerSteam` native)
- **ServerFPS Extension**: For accurate server performance monitoring

### Build System
- **Primary**: SourceKnight build tool (configured in `sourceknight.yaml`)
- **CI/CD**: GitHub Actions workflow (`.github/workflows/ci.yml`)
- **Package Management**: Automated dependency resolution and packaging

## Project Structure

```
addons/sourcemod/
├── scripting/
│   ├── Status.sp              # Main plugin source
│   └── include/
│       └── serverfps.inc      # Custom server FPS monitoring
└── gamedata/
    └── serverfps.games.txt    # Memory signatures for FPS monitoring
```

### Key Files
- **Status.sp**: Main plugin implementing the enhanced status command
- **serverfps.inc**: Custom include for server performance monitoring
- **serverfps.games.txt**: GameData file containing memory signatures
- **sourceknight.yaml**: Build configuration and dependency management

## Code Standards & Style

### SourcePawn Conventions (Strictly Enforced)
```sourcepawn
#pragma semicolon 1          // Required at top of file
#pragma newdecls required    // Use new declaration syntax

// Variable naming
ConVar g_Cvar_AuthIdType;    // Global vars: g_ prefix + PascalCase
int iServerTickRate;         // Local vars: hungarian notation + camelCase
bool bIsAdmin;               // Booleans: b prefix
char sPlayerName[64];        // Strings: s prefix
float fServerFPS;            // Floats: f prefix
```

### Memory Management Rules
```sourcepawn
// Proper handle cleanup
delete hGameConf;            // Use delete directly, no null check needed
hGameConf = null;           // Set to null after deletion

// StringMap/ArrayList management
delete g_MapData;           // Never use .Clear() - creates memory leaks
g_MapData = new StringMap(); // Create new instance instead
```

### Error Handling Patterns
```sourcepawn
// Feature detection for optional dependencies
if (GetFeatureStatus(FeatureType_Native, "GeoipCode3") == FeatureStatus_Available)
    bGeoIP = true;

// Safe API calls with fallbacks
if (!GetClientAuthId(player, authType, sPlayerAuth, sizeof(sPlayerAuth)))
    FormatEx(sPlayerAuth, sizeof(sPlayerAuth), "STEAM_ID_PENDING");
```

## Development Workflow

### Building the Plugin
```bash
# Using SourceKnight (preferred method)
sourceknight build

# Manual compilation (if SourceKnight unavailable)
spcomp -i"addons/sourcemod/scripting/include" addons/sourcemod/scripting/Status.sp
```

### Testing Checklist
1. **Compilation**: Ensure clean compilation without warnings
2. **Feature Detection**: Test with/without optional dependencies
3. **Performance**: Verify minimal impact on server tick rate
4. **Admin Functions**: Test IP display permissions
5. **Cross-Platform**: Validate gamedata signatures work on target platforms

### Common Development Tasks

#### Adding New ConVars
```sourcepawn
// In OnPluginStart()
g_Cvar_NewSetting = CreateConVar("sm_status_newsetting", "1", 
    "Description of setting", FCVAR_NONE, true, 0.0, true, 10.0);
AutoExecConfig(true);  // Auto-generate config file
```

#### Extending Status Output
```sourcepawn
// Add new info to header section around line 144
FormatEx(sNewInfo, sizeof(sNewInfo), "newinfo : %s", sValue);
FormatEx(sHeader, sizeof(sHeader), "%s \n%s", sHeader, sNewInfo);
```

#### Adding Optional Features
```sourcepawn
// Feature detection pattern
bool bNewFeature = GetFeatureStatus(FeatureType_Native, "NewFeature") == FeatureStatus_Available;

// Use in logic
if (bNewFeature)
    NewFeature_DoSomething();
```

## Performance Considerations

### Critical Performance Areas
- **OnGameFrame()**: Only used for FPS fallback calculation (line 216-229)
- **Command_Status()**: Main command handler - optimize for minimal execution time
- **Player Iteration**: Loops through all clients - avoid expensive operations

### Optimization Guidelines
- Cache expensive calculations (server info, network stats)
- Use static variables for repeated string operations
- Minimize string formatting in player loops
- Prefer direct API calls over complex calculations

## Debugging & Troubleshooting

### Common Issues
1. **GameData Signatures**: Update `serverfps.games.txt` for new game versions
2. **Optional Dependencies**: Check feature availability before native calls
3. **Memory Leaks**: Ensure proper handle cleanup with `delete`
4. **Performance Impact**: Monitor server tick rate after changes

### Debugging Tools
```sourcepawn
// Debug output (remove before production)
LogMessage("Debug: %s", sValue);
PrintToServer("Server debug: %d", iValue);

// Error handling
if (hHandle == null)
    SetFailState("Failed to initialize: %s", sReason);
```

## CI/CD Pipeline

### Automated Processes
- **Build**: Compiles plugin using SourceKnight action
- **Package**: Creates distribution-ready archive with gamedata
- **Release**: Generates tagged releases with downloadable assets
- **Versioning**: Automatic latest tag management

### Manual Release Process
1. Update version in plugin info (line 32)
2. Test compilation and functionality
3. Create git tag with semantic version
4. Push tag to trigger release workflow

## Integration Guidelines

### Adding New Optional Dependencies
1. Add feature detection in `OnPluginStart()`
2. Use `#undef REQUIRE_PLUGIN` / `#tryinclude` pattern
3. Implement fallback behavior for missing features
4. Test with and without the dependency

### Modifying Server Performance Monitoring
- Primary: Use ServerFPS extension if available
- Fallback: Custom implementation in `OnGameFrame()`
- GameData: Update signatures in `serverfps.games.txt` as needed

## Best Practices Summary

### Do
- Use feature detection for all optional dependencies
- Implement proper fallbacks for missing extensions
- Test cross-platform compatibility
- Follow established variable naming conventions
- Use `delete` for handle cleanup
- Cache expensive operations

### Don't
- Use `.Clear()` on StringMap/ArrayList (memory leak)
- Add blocking operations in frequently called functions
- Hardcode values that should be configurable
- Skip error handling for API calls
- Modify core functionality without comprehensive testing
- Add dependencies without proper optional handling

### Security Considerations
- Validate admin permissions before showing sensitive data (IP addresses)
- Sanitize user input if adding new command parameters
- Use proper auth ID types for player identification
- Respect privacy settings for non-admin users

## Version Management

Current version: **2.1.5** (as of Status.sp line 32)

When updating:
1. Increment version in plugin info
2. Update any breaking changes in this documentation
3. Test with minimum required SourceMod version
4. Update dependency versions in sourceknight.yaml if needed