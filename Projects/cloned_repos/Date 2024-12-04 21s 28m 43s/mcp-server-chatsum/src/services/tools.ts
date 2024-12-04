export const queryChatMessagesTool = {
  name: "query_chat_messages",
  description: "query chat messages with given parameters",
  inputSchema: {
    type: "object",
    properties: {
      room_names: {
        type: "array",
        description: "chat room names",
        items: {
          type: "string",
          description: "chat room name",
        },
      },
      talker_names: {
        type: "array",
        description: "talker names",
        items: {
          type: "string",
          description: "talker name",
        },
      },
      limit: {
        type: "number",
        description: "chat messages limit",
        default: 100,
      },
    },
    required: [],
  },
};
