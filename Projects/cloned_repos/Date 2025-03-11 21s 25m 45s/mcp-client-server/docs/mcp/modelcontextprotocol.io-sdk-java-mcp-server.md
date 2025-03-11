# MCP Server

> Learn how to implement and configure a Model Context Protocol (MCP) server

## Overview

The MCP Server is a foundational component in the Model Context Protocol (MCP) architecture that provides tools, resources, and capabilities to clients. It implements the server-side of the protocol, responsible for:

* Exposing tools that clients can discover and execute
* Managing resources with URI-based access patterns
* Providing prompt templates and handling prompt requests
* Supporting capability negotiation with clients
* Implementing server-side protocol operations
* Managing concurrent client connections
* Providing structured logging and notifications

The server supports both synchronous and asynchronous APIs, allowing for flexible integration in different application contexts.

<Tabs>
  <Tab title="Sync API">
    ```java
    // Create a server with custom configuration
    McpSyncServer syncServer = McpServer.sync(transport)
        .serverInfo("my-server", "1.0.0")
        .capabilities(ServerCapabilities.builder()
            .resources(true)     // Enable resource support
            .tools(true)         // Enable tool support
            .prompts(true)       // Enable prompt support
            .logging()           // Enable logging support
            .build())
        .build();

    // Register tools, resources, and prompts
    syncServer.addTool(syncToolRegistration);
    syncServer.addResource(syncResourceRegistration);
    syncServer.addPrompt(syncPromptRegistration);

    // Send logging notifications
    syncServer.loggingNotification(LoggingMessageNotification.builder()
        .level(LoggingLevel.INFO)
        .logger("custom-logger")
        .data("Server initialized")
        .build());

    // Close the server when done
    syncServer.close();
    ```
  </Tab>

  <Tab title="Async API">
    ```java
    // Create an async server with custom configuration
    McpAsyncServer asyncServer = McpServer.async(transport)
        .serverInfo("my-server", "1.0.0")
        .capabilities(ServerCapabilities.builder()
            .resources(true)     // Enable resource support
            .tools(true)         // Enable tool support
            .prompts(true)       // Enable prompt support
            .logging()           // Enable logging support
            .build())
        .build();

    // Register tools, resources, and prompts
    asyncServer.addTool(asyncToolRegistration)
        .doOnSuccess(v -> logger.info("Tool registered"))
        .subscribe();

    asyncServer.addResource(asyncResourceRegistration)
        .doOnSuccess(v -> logger.info("Resource registered"))
        .subscribe();

    asyncServer.addPrompt(asyncPromptRegistration)
        .doOnSuccess(v -> logger.info("Prompt registered"))
        .subscribe();

    // Send logging notifications
    asyncServer.loggingNotification(LoggingMessageNotification.builder()
        .level(LoggingLevel.INFO)
        .logger("custom-logger")
        .data("Server initialized")
        .build());

    // Close the server when done
    asyncServer.close()
        .doOnSuccess(v -> logger.info("Server closed"))
        .subscribe();
    ```
  </Tab>
</Tabs>

## Server Transport

The transport layer in the MCP SDK is responsible for handling the communication between clients and servers. It provides different implementations to support various communication protocols and patterns. The SDK includes several built-in transport implementations:

<Tabs>
  <Tab title="STDIO">
    <>
      Create in-process based transport:

      ```java
      StdioServerTransport transport = new StdioServerTransport(new ObjectMapper());
      ```

      Provides bidirectional JSON-RPC message handling over standard input/output streams with non-blocking message processing, serialization/deserialization, and graceful shutdown support.

      Key features:

      <ul>
        <li>Bidirectional communication through stdin/stdout</li>
        <li>Process-based integration support</li>
        <li>Simple setup and configuration</li>
        <li>Lightweight implementation</li>
      </ul>
    </>
  </Tab>

  <Tab title="SSE (WebFlux)">
    <>
      <p>Creates WebFlux-based SSE server transport.<br />Requires the <code>mcp-spring-webflux</code> dependency.</p>

      ```java
      @Configuration
      class McpConfig {
          @Bean
          WebFluxSseServerTransport webFluxSseServerTransport(ObjectMapper mapper) {
              return new WebFluxSseServerTransport(mapper, "/mcp/message");
          }

          @Bean
          RouterFunction<?> mcpRouterFunction(WebFluxSseServerTransport transport) {
              return transport.getRouterFunction();
          }
      }
      ```

      <p>Implements the MCP HTTP with SSE transport specification, providing:</p>

      <ul>
        <li>Reactive HTTP streaming with WebFlux</li>
        <li>Concurrent client connections through SSE endpoints</li>
        <li>Message routing and session management</li>
        <li>Graceful shutdown capabilities</li>
      </ul>
    </>
  </Tab>

  <Tab title="SSE (WebMvc)">
    <>
      <p>Creates WebMvc-based SSE server transport.<br />Requires the <code>mcp-spring-webmvc</code> dependency.</p>

      ```java
      @Configuration
      @EnableWebMvc
      class McpConfig {
          @Bean
          WebMvcSseServerTransport webMvcSseServerTransport(ObjectMapper mapper) {
              return new WebMvcSseServerTransport(mapper, "/mcp/message");
          }

          @Bean
          RouterFunction<ServerResponse> mcpRouterFunction(WebMvcSseServerTransport transport) {
              return transport.getRouterFunction();
          }
      }
      ```

      <p>Implements the MCP HTTP with SSE transport specification, providing:</p>

      <ul>
        <li>Server-side event streaming</li>
        <li>Integration with Spring WebMVC</li>
        <li>Support for traditional web applications</li>
        <li>Synchronous operation handling</li>
      </ul>
    </>
  </Tab>

  <Tab title="SSE (Servlet)">
    <>
      <p>
        Creates a Servlet-based SSE server transport. It is included in the core <code>mcp</code> module.<br />
        The <code>HttpServletSseServerTransport</code> can be used with any Servlet container.<br />
        To use it with a Spring Web application, you can register it as a Servlet bean:
      </p>

      ```java
      @Configuration
      @EnableWebMvc
      public class McpServerConfig implements WebMvcConfigurer {

          @Bean
          public HttpServletSseServerTransport servletSseServerTransport() {
              return new HttpServletSseServerTransport(new ObjectMapper(), "/mcp/message");
          }

          @Bean
          public ServletRegistrationBean customServletBean(HttpServletSseServerTransport servlet) {
              return new ServletRegistrationBean(servlet);
          }
      }
      ```

      <p>
        Implements the MCP HTTP with SSE transport specification using the traditional Servlet API, providing:
      </p>

      <ul>
        <li>Asynchronous message handling using Servlet 6.0 async support</li>
        <li>Session management for multiple client connections</li>

        <li>
          Two types of endpoints:

          <ul>
            <li>SSE endpoint (<code>/sse</code>) for server-to-client events</li>
            <li>Message endpoint (configurable) for client-to-server requests</li>
          </ul>
        </li>

        <li>Error handling and response formatting</li>
        <li>Graceful shutdown support</li>
      </ul>
    </>
  </Tab>
</Tabs>

## Server Capabilities

The server can be configured with various capabilities:

```java
var capabilities = ServerCapabilities.builder()
    .resources(false, true)  // Resource support with list changes notifications
    .tools(true)            // Tool support with list changes notifications
    .prompts(true)          // Prompt support with list changes notifications
    .logging()              // Enable logging support (enabled by default with loging level INFO)
    .build();
```

### Logging Support

The server provides structured logging capabilities that allow sending log messages to clients with different severity levels:

```java
// Send a log message to clients
server.loggingNotification(LoggingMessageNotification.builder()
    .level(LoggingLevel.INFO)
    .logger("custom-logger")
    .data("Custom log message")
    .build());
```

Clients can control the minimum logging level they receive through the `mcpClient.setLoggingLevel(level)` request. Messages below the set level will be filtered out.
Supported logging levels (in order of increasing severity): DEBUG (0), INFO (1), NOTICE (2), WARNING (3), ERROR (4), CRITICAL (5), ALERT (6), EMERGENCY (7)

### Tool Registration

<Tabs>
  <Tab title="Sync">
    ```java
    // Sync tool registration
    var syncToolRegistration = new McpServerFeatures.SyncToolRegistration(
        new Tool("calculator", "Basic calculator", Map.of(
            "operation", "string",
            "a", "number",
            "b", "number"
        )),
        arguments -> {
            // Tool implementation
            return new CallToolResult(result, false);
        }
    );
    ```
  </Tab>

  <Tab title="Async">
    ```java
    // Async tool registration
    var asyncToolRegistration = new McpServerFeatures.AsyncToolRegistration(
        new Tool("calculator", "Basic calculator", Map.of(
            "operation", "string",
            "a", "number",
            "b", "number"
        )),
        arguments -> {
            // Tool implementation
            return Mono.just(new CallToolResult(result, false));
        }
    );
    ```
  </Tab>
</Tabs>

### Resource Registration

<Tabs>
  <Tab title="Sync">
    ```java
    // Sync resource registration
    var syncResourceRegistration = new McpServerFeatures.SyncResourceRegistration(
        new Resource("custom://resource", "name", "description", "mime-type", null),
        request -> {
            // Resource read implementation
            return new ReadResourceResult(contents);
        }
    );
    ```
  </Tab>

  <Tab title="Async">
    ```java
    // Async resource registration
    var asyncResourceRegistration = new McpServerFeatures.AsyncResourceRegistration(
        new Resource("custom://resource", "name", "description", "mime-type", null),
        request -> {
            // Resource read implementation
            return Mono.just(new ReadResourceResult(contents));
        }
    );
    ```
  </Tab>
</Tabs>

### Prompt Registration

<Tabs>
  <Tab title="Sync">
    ```java
    // Sync prompt registration
    var syncPromptRegistration = new McpServerFeatures.SyncPromptRegistration(
        new Prompt("greeting", "description", List.of(
            new PromptArgument("name", "description", true)
        )),
        request -> {
            // Prompt implementation
            return new GetPromptResult(description, messages);
        }
    );
    ```
  </Tab>

  <Tab title="Async">
    ```java
    // Async prompt registration
    var asyncPromptRegistration = new McpServerFeatures.AsyncPromptRegistration(
        new Prompt("greeting", "description", List.of(
            new PromptArgument("name", "description", true)
        )),
        request -> {
            // Prompt implementation
            return Mono.just(new GetPromptResult(description, messages));
        }
    );
    ```
  </Tab>
</Tabs>

## Error Handling

The SDK provides comprehensive error handling through the McpError class, covering protocol compatibility, transport communication, JSON-RPC messaging, tool execution, resource management, prompt handling, timeouts, and connection issues. This unified error handling approach ensures consistent and reliable error management across both synchronous and asynchronous operations.
