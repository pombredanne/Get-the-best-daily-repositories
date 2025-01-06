// Import required modules from the RLLM library for Anthropic integration
use rllm::{
    builder::{LLMBackend, LLMBuilder}, // Builder pattern components
    chat::{ChatMessage, ChatRole},     // Chat-related structures
};

fn main() {
    // Get Anthropic API key from environment variable or use test key as fallback
    let api_key = std::env::var("ANTHROPIC_API_KEY").unwrap_or("anthro-key".into());

    // Initialize and configure the LLM client
    let llm = LLMBuilder::new()
        .backend(LLMBackend::Anthropic) // Use Anthropic (Claude) as the LLM provider
        .api_key(api_key) // Set the API key
        .model("claude-3-5-sonnet-20240620") // Use Claude Instant model
        .max_tokens(512) // Limit response length
        .temperature(0.7) // Control response randomness (0.0-1.0)
        // Uncomment to set system prompt:
        // .system("You are a helpful assistant specialized in concurrency.")
        .build()
        .expect("Failed to build LLM (Anthropic)");

    // Prepare conversation history with example message about Rust concurrency
    let messages = vec![ChatMessage {
        role: ChatRole::User,
        content: "Tell me something about Rust concurrency".into(),
    }];

    // Send chat request and handle the response
    match llm.chat(&messages) {
        Ok(text) => println!("Anthropic chat response:\n{}", text),
        Err(e) => eprintln!("Chat error: {}", e),
    }
}
