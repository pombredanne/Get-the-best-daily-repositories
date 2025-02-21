import type { AIProviderClient, AIProviderService } from '../../types/provider';
import type { QAItem } from '../../types/types';
import { generateQuestionPrompt, processQuestionResponse } from '../../utils/prompt';
import { extractContent, extractThinkingContent } from '../../utils/stream';

/**
 * Base AI service implementation with common functionality
 */
export abstract class BaseAIService implements AIProviderService {
  protected constructor(
    protected readonly client: AIProviderClient,
    protected readonly defaultModel?: string
  ) {}

  /**
   * Generates answer for a given question with retry mechanism
   * @param question - Question to generate answer for
   * @param maxAttempts - Maximum number of retry attempts
   * @returns Promise<QAItem> Generated QA pair
   */
  async generateAnswer(question: string, maxAttempts: number = 3): Promise<QAItem> {
    let lastError: Error | null = null;
    
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        console.log(`\n[API Call] Answer attempt ${attempt}/${maxAttempts}`);
        console.time('[API] Response time');
        
        const response = await this.client.chat({
          messages: [{ role: "user", content: question }],
          stream: true,
        }, this.defaultModel);

        console.timeEnd('[API] Response time');
        
        if (!response) {
          throw new Error('Null response received from API');
        }
        
        const { content: rawContent, reasoning_content: rawReasoningContent } = await this.processStreamResponse(response);
        
        if (!rawContent && !rawReasoningContent) {
          throw new Error('Empty response received from API');
        }
        
        const content = extractContent(rawContent);
        const reasoningContent = rawReasoningContent || extractThinkingContent(rawContent);
        
        if (!content) {
          throw new Error('Failed to extract content from response');
        }
        
        return {
          question,
          content: content,
          reasoning_content: reasoningContent || '未提供思考过程'
        };
      } catch (error) {
        console.error(`[API Error] Attempt ${attempt}:`, error);
        lastError = error as Error;
        if (attempt < maxAttempts) {
          const waitTime = attempt * 2000;
          await new Promise(resolve => setTimeout(resolve, waitTime));
        }
      }
    }
    
    return {
      question,
      content: '在多次尝试后未能获取答案',
      reasoning_content: lastError ? `错误信息: ${lastError.message}` : '未提供思考过程'
    };
  }

  /**
   * Generates questions using AI API
   * @param regionName - Name of the region
   * @param batchSize - Number of questions to generate
   * @param maxAttempts - Maximum number of retry attempts
   * @returns Promise<string> Processed questions in JSON format
   */
  async generateQuestionsFromPrompt(regionName: string, batchSize: number, maxAttempts: number = 3): Promise<string> {
    const prompt = generateQuestionPrompt(regionName, batchSize);
    
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        console.log(`\nBatch attempt ${attempt}/${maxAttempts}...`);
        
        const response = await this.client.chat({
          messages: [{ 
            role: "user", 
            content: prompt
          }],
          stream: true,
        }, this.defaultModel);

        const { content: rawContent } = await this.processStreamResponse(response);
        return processQuestionResponse(rawContent, regionName);
      } catch (error) {
        console.error(`Error in batch attempt ${attempt}:`, error);
        if (attempt < maxAttempts) {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
        if (attempt === maxAttempts) {
          throw error;
        }
      }
    }
    
    throw new Error('Failed to generate questions after all attempts');
  }

  /**
   * Process stream response from provider
   * @param response - Stream response from provider
   * @returns Promise<{content: string, reasoning_content: string}>
   */
  protected abstract processStreamResponse(response: any): Promise<{content: string, reasoning_content: string}>;
} 