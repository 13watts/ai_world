export const modalities = [
    {
        slug: 'text-llms',
        name: 'Text & Large Language Models',
        summary: 'Chatbots, assistants, retrieval, reasoning models, long-context systems, and enterprise knowledge workflows.',
        examples: ['LLMs', 'RAG', 'summarization', 'document analysis', 'enterprise assistants']
    },
    {
        slug: 'image-video',
        name: 'Image & Video Generation',
        summary: 'Image generation, video generation, multimodal understanding, design tools, and synthetic media workflows.',
        examples: ['image models', 'video models', 'vision-language models', 'creative tooling']
    },
    {
        slug: 'audio-speech',
        name: 'Audio & Speech',
        summary: 'Speech-to-text, text-to-speech, voice agents, music generation, audio understanding, and accessibility tooling.',
        examples: ['TTS', 'STT', 'voice assistants', 'audio analysis']
    },
    {
        slug: 'code-agents',
        name: 'Code & Agents',
        summary: 'Coding assistants, autonomous agents, tool use, browser/computer use, MCP, and workflow automation.',
        examples: ['coding agents', 'MCP', 'tool calling', 'automation', 'developer copilots']
    },
    {
        slug: 'research-ml',
        name: 'Research & Machine Learning',
        summary: 'Papers, benchmarks, model architecture, training methods, evaluation, datasets, and applied ML research.',
        examples: ['arXiv', 'benchmarks', 'model training', 'datasets', 'ML theory']
    },
    {
        slug: 'infra-mlops',
        name: 'Infrastructure & MLOps',
        summary: 'Inference platforms, GPUs, vector databases, model serving, monitoring, orchestration, and production operations.',
        examples: ['inference', 'vector DBs', 'observability', 'model serving', 'GPU platforms']
    },
    {
        slug: 'governance-safety',
        name: 'Governance, Safety & Policy',
        summary: 'AI safety, regulation, privacy, ethics, model risk, governance, legal issues, and enterprise controls.',
        examples: ['AI safety', 'policy', 'privacy', 'model risk', 'compliance']
    }
];
export function getModality(slug) {
    return modalities.find((modality) => modality.slug === slug);
}
