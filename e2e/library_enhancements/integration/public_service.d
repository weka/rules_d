module integration.public_service;

// Public API function - this is exported
// Simple implementation that consumers can use
int processValue(int x) {
    foreach (processor; processors) {
        x = processor(x);
    }
    return x;
}

package int delegate(int)[] processors;
