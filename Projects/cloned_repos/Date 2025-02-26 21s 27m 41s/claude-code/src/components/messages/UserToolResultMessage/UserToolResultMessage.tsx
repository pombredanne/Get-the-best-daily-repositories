import { ToolResultBlockParam } from '@anthropic-ai/sdk/resources/index.mjs'
import * as React from 'react'
import { Tool } from '../../../Tool.js'
import { Message, UserMessage } from '../../../query.js'
import { CANCEL_MESSAGE, REJECT_MESSAGE } from '../../../utils/messages.js'
import { UserToolCanceledMessage } from './UserToolCanceledMessage.js'
import { UserToolErrorMessage } from './UserToolErrorMessage.js'
import { UserToolRejectMessage } from './UserToolRejectMessage.js'
import { UserToolSuccessMessage } from './UserToolSuccessMessage.js'

type Props = {
  param: ToolResultBlockParam
  message: UserMessage
  messages: Message[]
  tools: Tool[]
  verbose: boolean
  width: number | string
}

export function UserToolResultMessage({
  param,
  message,
  messages,
  tools,
  verbose,
  width,
}: Props): React.ReactNode {
  if (param.content === CANCEL_MESSAGE) {
    return <UserToolCanceledMessage />
  }

  if (param.content === REJECT_MESSAGE) {
    return (
      <UserToolRejectMessage
        toolUseID={param.tool_use_id}
        tools={tools}
        messages={messages}
        verbose={verbose}
      />
    )
  }

  if (param.is_error) {
    return <UserToolErrorMessage param={param} verbose={verbose} />
  }

  return (
    <UserToolSuccessMessage
      param={param}
      message={message}
      messages={messages}
      tools={tools}
      verbose={verbose}
      width={width}
    />
  )
}
