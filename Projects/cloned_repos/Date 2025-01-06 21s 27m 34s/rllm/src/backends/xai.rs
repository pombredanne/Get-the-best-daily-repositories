//! X.AI API client implementation for chat and completion functionality.
//!
//! This module provides integration with X.AI's models through their API.
//! It implements chat and completion capabilities using the X.AI API endpoints.

#[cfg(feature = "xai")]
use crate::{
    chat::{ChatMessage, ChatProvider, ChatRole},
    completion::{CompletionProvider, CompletionRequest, CompletionResponse},
    embedding::EmbeddingProvider,
    error::RllmError,
    LLMProvider,
};
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};

/// Client for interacting with X.AI's API.
///
/// This struct provides methods for making chat and completion requests to X.AI's language models.
/// It handles authentication, request configuration, and response parsing.
pub struct XAI {
    /// API key for authentication with X.AI services
    pub api_key: String,
    /// Model identifier to use for requests (e.g. "grok-2-latest")
    pub model: String,
    /// Maximum number of tokens to generate in responses
    pub max_tokens: Option<u32>,
    /// Temperature parameter for controlling response randomness (0.0 to 1.0)
    pub temperature: Option<f32>,
    /// Optional system prompt to provide context
    pub system: Option<String>,
    /// Request timeout duration in seconds
    pub timeout_seconds: Option<u64>,
    /// Whether to enable streaming responses
    pub stream: Option<bool>,
    /// Top-p sampling parameter for controlling response diversity
    pub top_p: Option<f32>,
    /// Top-k sampling parameter for controlling response diversity
    pub top_k: Option<u32>,
    /// Embedding encoding format
    pub embedding_encoding_format: Option<String>,
    /// Embedding dimensions
    pub embedding_dimensions: Option<u32>,
    /// HTTP client for making API requests
    client: Client,
}

/// Individual message in an X.AI chat conversation.
#[derive(Serialize)]
struct XAIChatMessage<'a> {
    /// Role of the message sender (user, assistant, or system)
    role: &'a str,
    /// Content of the message
    content: &'a str,
}

/// Request payload for X.AI's chat API endpoint.
#[derive(Serialize)]
struct XAIChatRequest<'a> {
    /// Model identifier to use
    model: &'a str,
    /// Array of conversation messages
    messages: Vec<XAIChatMessage<'a>>,
    /// Maximum tokens to generate
    #[serde(skip_serializing_if = "Option::is_none")]
    max_tokens: Option<u32>,
    /// Temperature parameter
    #[serde(skip_serializing_if = "Option::is_none")]
    temperature: Option<f32>,
    /// Whether to stream the response
    stream: bool,
    /// Top-p sampling parameter
    #[serde(skip_serializing_if = "Option::is_none")]
    top_p: Option<f32>,
    /// Top-k sampling parameter
    #[serde(skip_serializing_if = "Option::is_none")]
    top_k: Option<u32>,
}

/// Response from X.AI's chat API endpoint.
#[derive(Deserialize)]
struct XAIChatResponse {
    /// Array of generated responses
    choices: Vec<XAIChatChoice>,
}

/// Individual response choice from the chat API.
#[derive(Deserialize)]
struct XAIChatChoice {
    /// Message content and metadata
    message: XAIChatMsg,
}

/// Message content from a chat response.
#[derive(Deserialize)]
struct XAIChatMsg {
    /// Generated text content
    content: String,
}

#[derive(Debug, Serialize)]
struct XAIEmbeddingRequest<'a> {
    model: &'a str,
    input: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    encoding_format: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    dimensions: Option<u32>,
}

#[derive(Deserialize)]
struct XAIEmbeddingData {
    embedding: Vec<f32>,
}
#[derive(Deserialize)]
struct XAIEmbeddingResponse {
    data: Vec<XAIEmbeddingData>,
}

impl XAI {
    /// Creates a new X.AI client with the specified configuration.
    ///
    /// # Arguments
    ///
    /// * `api_key` - Authentication key for X.AI API access
    /// * `model` - Model identifier (defaults to "grok-2-latest" if None)
    /// * `max_tokens` - Maximum number of tokens to generate in responses
    /// * `temperature` - Sampling temperature for controlling randomness
    /// * `timeout_seconds` - Request timeout duration in seconds
    /// * `system` - System prompt for providing context
    /// * `stream` - Whether to enable streaming responses
    /// * `top_p` - Top-p sampling parameter
    /// * `top_k` - Top-k sampling parameter
    ///
    /// # Returns
    ///
    /// A configured X.AI client instance ready to make API requests.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        api_key: impl Into<String>,
        model: Option<String>,
        max_tokens: Option<u32>,
        temperature: Option<f32>,
        timeout_seconds: Option<u64>,
        system: Option<String>,
        stream: Option<bool>,
        top_p: Option<f32>,
        top_k: Option<u32>,
        embedding_encoding_format: Option<String>,
        embedding_dimensions: Option<u32>,
    ) -> Self {
        let mut builder = Client::builder();
        if let Some(sec) = timeout_seconds {
            builder = builder.timeout(std::time::Duration::from_secs(sec));
        }
        Self {
            api_key: api_key.into(),
            model: model.unwrap_or("grok-2-latest".to_string()),
            max_tokens,
            temperature,
            system,
            timeout_seconds,
            stream,
            top_p,
            top_k,
            embedding_encoding_format,
            embedding_dimensions,
            client: builder.build().expect("Failed to build reqwest Client"),
        }
    }
}

impl ChatProvider for XAI {
    /// Sends a chat request to the X.AI API and returns the response.
    ///
    /// # Arguments
    ///
    /// * `messages` - Array of chat messages representing the conversation
    ///
    /// # Returns
    ///
    /// The generated response text, or an error if the request fails.
    fn chat(&self, messages: &[ChatMessage]) -> Result<String, RllmError> {
        if self.api_key.is_empty() {
            return Err(RllmError::AuthError("Missing X.AI API key".to_string()));
        }

        let mut xai_msgs: Vec<XAIChatMessage> = messages
            .iter()
            .map(|m| XAIChatMessage {
                role: match m.role {
                    ChatRole::User => "user",
                    ChatRole::Assistant => "assistant",
                },
                content: &m.content,
            })
            .collect();

        if let Some(system) = &self.system {
            xai_msgs.insert(
                0,
                XAIChatMessage {
                    role: "system",
                    content: system,
                },
            );
        }

        let body = XAIChatRequest {
            model: &self.model,
            messages: xai_msgs,
            max_tokens: self.max_tokens,
            temperature: self.temperature,
            stream: self.stream.unwrap_or(false),
            top_p: self.top_p,
            top_k: self.top_k,
        };

        let resp = self
            .client
            .post("https://api.x.ai/v1/chat/completions")
            .bearer_auth(&self.api_key)
            .json(&body)
            .send()?
            .error_for_status()?;

        let json_resp: XAIChatResponse = resp.json()?;
        let first_choice =
            json_resp.choices.into_iter().next().ok_or_else(|| {
                RllmError::ProviderError("No choices returned by X.AI".to_string())
            })?;

        Ok(first_choice.message.content)
    }
}

impl CompletionProvider for XAI {
    /// Sends a completion request to X.AI's API.
    ///
    /// This functionality is currently not implemented.
    ///
    /// # Arguments
    ///
    /// * `_req` - The completion request parameters
    ///
    /// # Returns
    ///
    /// A placeholder response indicating the functionality is not implemented.
    fn complete(&self, _req: &CompletionRequest) -> Result<CompletionResponse, RllmError> {
        Ok(CompletionResponse {
            text: "X.AI completion not implemented.".into(),
        })
    }
}

impl EmbeddingProvider for XAI {
    fn embed(&self, text: Vec<String>) -> Result<Vec<Vec<f32>>, RllmError> {
        if self.api_key.is_empty() {
            return Err(RllmError::AuthError("Missing X.AI API key".into()));
        }

        let emb_format = self
            .embedding_encoding_format
            .clone()
            .unwrap_or_else(|| "float".to_string());

        let body = XAIEmbeddingRequest {
            model: &self.model,
            input: text,
            encoding_format: Some(&emb_format),
            dimensions: self.embedding_dimensions,
        };

        let resp = self
            .client
            .post("https://api.x.ai/v1/embeddings")
            .bearer_auth(&self.api_key)
            .json(&body)
            .send()?
            .error_for_status()?;

        let json_resp: XAIEmbeddingResponse = resp.json()?;

        let embeddings = json_resp.data.into_iter().map(|d| d.embedding).collect();
        Ok(embeddings)
    }
}

impl LLMProvider for XAI {}
