import tests.mix_sources_and_generated.b;

void main() {
    // This is a test to check if the mix of sources and generated code works
    // The generated code is in the `generated` directory
    // The source code is in the `src` directory
    // The test should pass if the mix works
    assert(bfun() == 42);
}
