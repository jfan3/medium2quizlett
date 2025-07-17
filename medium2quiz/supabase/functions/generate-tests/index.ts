import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

interface Flashcard {
  id: string
  question: string
  answer: string
  explanation?: string
  difficulty: string
  tags: string[]
}

interface TestQuestion {
  flashcard_id: string
  question_type: string
  question_data: any
  difficulty_level: number
}

const CLAUDE_API_KEY = Deno.env.get('CLAUDE_API_KEY')

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { flashcards } = await req.json() as { flashcards: Flashcard[] }
    
    if (!flashcards || flashcards.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No flashcards provided' }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Generate test questions using Claude
    const testQuestions = await generateTestQuestions(flashcards)
    
    return new Response(
      JSON.stringify(testQuestions),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    console.error('Error generating test questions:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})

async function generateTestQuestions(flashcards: Flashcard[]): Promise<TestQuestion[]> {
  const prompt = `
You are an expert educator creating test questions from flashcards. 
Generate diverse test questions from the following flashcards.

For each flashcard, create one of these question types:
1. Multiple Choice (4 options, with plausible distractors)
2. True/False (with a statement that tests understanding)
3. Fill in the Blank (with key terms removed)
4. Short Answer (requiring brief explanation)

Flashcards:
${flashcards.map((fc, i) => `
${i + 1}. Question: ${fc.question}
   Answer: ${fc.answer}
   ${fc.explanation ? `Explanation: ${fc.explanation}` : ''}
`).join('\n')}

Return a JSON array with test questions in this format:
{
  "flashcard_id": "uuid",
  "question_type": "multiple_choice|true_false|fill_blank|short_answer",
  "question_data": {
    // For multiple_choice:
    "question": "string",
    "options": ["string", "string", "string", "string"],
    "correctIndex": number,
    "explanation": "string"
    
    // For true_false:
    "statement": "string",
    "isTrue": boolean,
    "explanation": "string"
    
    // For fill_blank:
    "sentence": "string with ___ blanks",
    "blanks": ["blank1"],
    "correctAnswers": ["answer1"]
    
    // For short_answer:
    "question": "string",
    "acceptableAnswers": ["answer1", "answer2"],
    "caseSensitive": false
  },
  "difficulty_level": 1-5
}
`

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY!,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-3-haiku-20240307',
        max_tokens: 4000,
        messages: [{
          role: 'user',
          content: prompt
        }],
        temperature: 0.7
      })
    })

    if (!response.ok) {
      throw new Error(`Claude API error: ${response.status}`)
    }

    const data = await response.json()
    const content = data.content[0].text
    
    // Extract JSON from the response
    const jsonMatch = content.match(/\[[\s\S]*\]/)
    if (!jsonMatch) {
      throw new Error('No JSON found in Claude response')
    }
    
    const questions = JSON.parse(jsonMatch[0])
    
    // Map flashcard IDs and ensure proper format
    return questions.map((q: any, index: number) => ({
      flashcard_id: flashcards[index % flashcards.length].id,
      question_type: q.question_type,
      question_data: q.question_data,
      difficulty_level: q.difficulty_level || 2
    }))
  } catch (error) {
    console.error('Error calling Claude:', error)
    
    // Fallback: Generate simple multiple choice questions
    return flashcards.map(fc => ({
      flashcard_id: fc.id,
      question_type: 'multiple_choice',
      question_data: {
        question: fc.question,
        options: [
          fc.answer,
          generateDistractor(fc.answer, 1),
          generateDistractor(fc.answer, 2),
          generateDistractor(fc.answer, 3)
        ].sort(() => Math.random() - 0.5),
        correctIndex: 0, // Will be updated after shuffle
        explanation: fc.explanation || `The correct answer is: ${fc.answer}`
      },
      difficulty_level: fc.difficulty === 'advanced' ? 4 : fc.difficulty === 'intermediate' ? 3 : 2
    })).map(q => {
      // Fix correct index after shuffle
      const correctAnswer = flashcards.find(fc => fc.id === q.flashcard_id)!.answer
      q.question_data.correctIndex = q.question_data.options.indexOf(correctAnswer)
      return q
    })
  }
}

function generateDistractor(correctAnswer: string, variant: number): string {
  // Simple distractor generation - in production, this would be more sophisticated
  const distractors = [
    'This is not the correct answer',
    'An alternative option',
    'Another possible choice',
    'A different response'
  ]
  return distractors[variant] || 'Incorrect option'
}