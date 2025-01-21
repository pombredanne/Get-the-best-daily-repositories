import OpenAI from 'openai';
import { environment } from './environment';

if (!environment.openaiApiKey) {
  throw new Error('Missing OpenAI API key. Check OPENAI_API_KEY in .env');
}

export const openai = new OpenAI({
  apiKey: environment.openaiApiKey
}); 