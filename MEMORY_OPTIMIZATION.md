# MouseOn Memory Optimization Notes

## Current Memory Practices

### Thread Safety
- All services use `@MainActor` isolation
- Internal state queues for cross-thread operations
- `nonisolated(unsafe)` for queue-protected properties

### Timer Management
- All timers invalidated in `deinit`
- Weak self in timer closures to prevent retain cycles
- Combine publishers with `AnyCancellable` storage

### Observer Cleanup
- NotificationCenter observers removed in `deinit`
- Event monitors (NSEvent) removed in `deinit`

### Singleton Patterns
- `CursorHighlighter.shared` - properly manages window lifecycle
- `LargeCursorManager.shared` - auto-dismisses overlays
- `HotkeyManager.shared` - removes monitors in deinit

## Memory Optimization Checklist

### Implemented ✅
- [x] Weak references in closures (`[weak self]`)
- [x] Timer invalidation in deinit
- [x] Combine cancellable cleanup
- [x] NotificationCenter observer removal
- [x] NSEvent monitor removal
- [x] Window cleanup on deinit

### Best Practices
- Use `weak` for delegates and parent references
- Prefer value types (struct) over reference types where possible
- Avoid capturing self strongly in escaping closures
- Use `@Published` sparingly - only for UI bindings

## Profiling (Requires Xcode)

To profile memory usage:
1. Product → Profile (⌘I)
2. Choose "Allocations" instrument
3. Run and use the app
4. Look for:
   - Memory growth over time
   - Leaked objects
   - Abandoned memory

### Expected Memory Usage
- Target: < 30MB idle
- Menu bar apps should be lightweight
- Overlay windows cleaned up after dismiss

## Known Areas for Optimization

1. **DisplayTracker polling**
   - Battery-aware already implemented
   - Could add longer intervals when app not in focus

2. **Stats persistence**
   - Currently saves on every switch
   - Could batch saves every N seconds

3. **Overlay windows**
   - Created/destroyed on demand
   - Could pool and reuse (micro-optimization)
