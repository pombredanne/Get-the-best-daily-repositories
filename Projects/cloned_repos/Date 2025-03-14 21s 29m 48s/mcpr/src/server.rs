//! High-level server implementation for MCP

use crate::{
    constants::LATEST_PROTOCOL_VERSION,
    error::MCPError,
    schema::{
        common::Tool,
        json_rpc::{JSONRPCMessage, JSONRPCResponse, RequestId},
    },
    transport::Transport,
};
use log::{error, info};
use serde_json::Value;
use std::collections::HashMap;

/// Server configuration
pub struct ServerConfig {
    /// Server name
    pub name: String,
    /// Server version
    pub version: String,
    /// Available tools
    pub tools: Vec<Tool>,
}

impl ServerConfig {
    /// Create a new server configuration
    pub fn new() -> Self {
        Self {
            name: "MCP Server".to_string(),
            version: "1.0.0".to_string(),
            tools: Vec::new(),
        }
    }

    /// Set the server name
    pub fn with_name(mut self, name: &str) -> Self {
        self.name = name.to_string();
        self
    }

    /// Set the server version
    pub fn with_version(mut self, version: &str) -> Self {
        self.version = version.to_string();
        self
    }

    /// Add a tool to the server
    pub fn with_tool(mut self, tool: Tool) -> Self {
        self.tools.push(tool);
        self
    }
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self::new()
    }
}

/// Tool handler function type
pub type ToolHandler = Box<dyn Fn(Value) -> Result<Value, MCPError> + Send + Sync>;

/// High-level MCP server
pub struct Server<T: Transport> {
    config: ServerConfig,
    tool_handlers: HashMap<String, ToolHandler>,
    transport: Option<T>,
}

impl<T: Transport> Server<T> {
    /// Create a new MCP server with the given configuration
    pub fn new(config: ServerConfig) -> Self {
        Self {
            config,
            tool_handlers: HashMap::new(),
            transport: None,
        }
    }

    /// Register a tool handler
    pub fn register_tool_handler<F>(&mut self, tool_name: &str, handler: F) -> Result<(), MCPError>
    where
        F: Fn(Value) -> Result<Value, MCPError> + Send + Sync + 'static,
    {
        // Check if the tool exists in the configuration
        if !self.config.tools.iter().any(|t| t.name == tool_name) {
            return Err(MCPError::Protocol(format!(
                "Tool '{}' not found in server configuration",
                tool_name
            )));
        }

        // Register the handler
        self.tool_handlers
            .insert(tool_name.to_string(), Box::new(handler));

        Ok(())
    }

    /// Start the server with the given transport
    pub fn start(&mut self, mut transport: T) -> Result<(), MCPError> {
        // Start the transport
        transport.start()?;

        // Store the transport
        self.transport = Some(transport);

        // Process messages
        self.process_messages()
    }

    /// Process incoming messages
    fn process_messages(&mut self) -> Result<(), MCPError> {
        loop {
            let message = {
                let transport = self
                    .transport
                    .as_mut()
                    .ok_or_else(|| MCPError::Protocol("Transport not initialized".to_string()))?;

                // Receive a message
                match transport.receive() {
                    Ok(msg) => msg,
                    Err(e) => {
                        error!("Error receiving message: {}", e);
                        continue;
                    }
                }
            };

            // Handle the message
            match message {
                JSONRPCMessage::Request(request) => {
                    let id = request.id.clone();
                    let method = request.method.clone();
                    let params = request.params.clone();

                    match method.as_str() {
                        "initialize" => {
                            info!("Received initialization request");
                            self.handle_initialize(id, params)?;
                        }
                        "tool_call" => {
                            info!("Received tool call request");
                            self.handle_tool_call(id, params)?;
                        }
                        "shutdown" => {
                            info!("Received shutdown request");
                            self.handle_shutdown(id)?;
                            break;
                        }
                        _ => {
                            error!("Unknown method: {}", method);
                            self.send_error(
                                id,
                                -32601,
                                format!("Method not found: {}", method),
                                None,
                            )?;
                        }
                    }
                }
                _ => {
                    error!("Unexpected message type");
                    continue;
                }
            }
        }

        Ok(())
    }

    /// Handle initialization request
    fn handle_initialize(&mut self, id: RequestId, _params: Option<Value>) -> Result<(), MCPError> {
        let transport = self
            .transport
            .as_mut()
            .ok_or_else(|| MCPError::Protocol("Transport not initialized".to_string()))?;

        // Create initialization response
        let response = JSONRPCResponse::new(
            id,
            serde_json::json!({
                "protocol_version": LATEST_PROTOCOL_VERSION,
                "server_info": {
                    "name": self.config.name,
                    "version": self.config.version
                },
                "tools": self.config.tools
            }),
        );

        // Send the response
        transport.send(&JSONRPCMessage::Response(response))?;

        Ok(())
    }

    /// Handle tool call request
    fn handle_tool_call(&mut self, id: RequestId, params: Option<Value>) -> Result<(), MCPError> {
        let transport = self
            .transport
            .as_mut()
            .ok_or_else(|| MCPError::Protocol("Transport not initialized".to_string()))?;

        // Extract tool name and parameters
        let params = params.ok_or_else(|| {
            MCPError::Protocol("Missing parameters in tool call request".to_string())
        })?;

        let tool_name = params
            .get("name")
            .and_then(|v| v.as_str())
            .ok_or_else(|| MCPError::Protocol("Missing tool name in parameters".to_string()))?;

        let tool_params = params.get("parameters").cloned().unwrap_or(Value::Null);

        // Find the tool handler
        let handler = self.tool_handlers.get(tool_name).ok_or_else(|| {
            MCPError::Protocol(format!("No handler registered for tool '{}'", tool_name))
        })?;

        // Call the handler
        match handler(tool_params) {
            Ok(result) => {
                // Create tool result response
                let response = JSONRPCResponse::new(
                    id,
                    serde_json::json!({
                        "result": result
                    }),
                );

                // Send the response
                transport.send(&JSONRPCMessage::Response(response))?;
            }
            Err(e) => {
                // Send error response
                self.send_error(id, -32000, format!("Tool execution failed: {}", e), None)?;
            }
        }

        Ok(())
    }

    /// Handle shutdown request
    fn handle_shutdown(&mut self, id: RequestId) -> Result<(), MCPError> {
        let transport = self
            .transport
            .as_mut()
            .ok_or_else(|| MCPError::Protocol("Transport not initialized".to_string()))?;

        // Create shutdown response
        let response = JSONRPCResponse::new(id, serde_json::json!({}));

        // Send the response
        transport.send(&JSONRPCMessage::Response(response))?;

        // Close the transport
        transport.close()?;

        Ok(())
    }

    /// Send an error response
    fn send_error(
        &mut self,
        id: RequestId,
        code: i32,
        message: String,
        data: Option<Value>,
    ) -> Result<(), MCPError> {
        let transport = self
            .transport
            .as_mut()
            .ok_or_else(|| MCPError::Protocol("Transport not initialized".to_string()))?;

        // Create error response
        let error = JSONRPCMessage::Error(crate::schema::json_rpc::JSONRPCError::new(
            id, code, message, data,
        ));

        // Send the error
        transport.send(&error)?;

        Ok(())
    }
}
