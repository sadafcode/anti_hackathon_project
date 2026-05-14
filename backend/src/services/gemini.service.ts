/**
 * Gemini Service — Wrapper for Google Generative AI API
 * Used by NLU, Pricing, Dispute, and Orchestrator agents
 */

import { GoogleGenerativeAI, GenerativeModel } from '@google/generative-ai';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(process.cwd(), '.env'), override: true });

export class GeminiService {
  private model: GenerativeModel;
  private static instance: GeminiService;

  private constructor() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not set in environment variables. Copy .env.example to .env and add your key.');
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    this.model = genAI.getGenerativeModel({
      model: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
      generationConfig: {
        temperature: 0.1,        // Low temperature for consistent structured output
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 2048,
      },
    });
  }

  /**
   * Singleton pattern — reuse same model instance across agents
   */
  static getInstance(): GeminiService {
    if (!GeminiService.instance) {
      GeminiService.instance = new GeminiService();
    }
    return GeminiService.instance;
  }

  /**
   * Generate text from a prompt — returns raw string
   */
  async generateText(prompt: string): Promise<string> {
    try {
      const result = await this.model.generateContent(prompt);
      const response = result.response;
      const text = response.text();
      return text;
    } catch (error: any) {
      console.error('[GeminiService] Generation failed:', error.message);
      throw new Error(`Gemini API call failed: ${error.message}`);
    }
  }

  /**
   * Generate structured JSON from a prompt
   * Attempts to parse the response as JSON, with cleanup for markdown fences
   */
  async generateJSON<T>(prompt: string): Promise<T> {
    const rawText = await this.generateText(prompt);

    // Clean up: Gemini sometimes wraps JSON in ```json ... ``` blocks
    let cleanText = rawText.trim();
    if (cleanText.startsWith('```json')) {
      cleanText = cleanText.slice(7);
    } else if (cleanText.startsWith('```')) {
      cleanText = cleanText.slice(3);
    }
    if (cleanText.endsWith('```')) {
      cleanText = cleanText.slice(0, -3);
    }
    cleanText = cleanText.trim();

    try {
      return JSON.parse(cleanText) as T;
    } catch (parseError: any) {
      console.error('[GeminiService] JSON parse failed. Raw output:', rawText);
      throw new Error(`Failed to parse Gemini response as JSON: ${parseError.message}`);
    }
  }
}
