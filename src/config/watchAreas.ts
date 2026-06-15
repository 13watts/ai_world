import type { WatchArea } from '../types/content.js';

export const watchAreas: WatchArea[] = [
  {
    slug: 'llms',
    name: 'Large Language Models',
    summary: 'Model releases, LLM architecture, reasoning, context windows, alignment, inference, fine-tuning, and deployment patterns.',
    modalitySlugs: ['text-llms', 'research-ml', 'infra-mlops', 'governance-safety'],
    keywords: [
      'llm', 'large language model', 'language model', 'foundation model', 'frontier model',
      'gpt', 'claude', 'gemini', 'llama', 'mistral', 'mixtral', 'qwen', 'deepseek',
      'reasoning model', 'context window', 'tokens', 'fine-tuning', 'instruction tuning',
      'alignment', 'prompting', 'inference', 'model release', 'benchmark'
    ]
  },
  {
    slug: 'agents',
    name: 'Agents & Tool Use',
    summary: 'Autonomous agents, tool calling, browser/computer use, MCP, coding agents, workflow execution, and long-running tasks.',
    modalitySlugs: ['code-agents', 'text-llms', 'infra-mlops', 'governance-safety'],
    keywords: [
      'agent', 'agents', 'agentic', 'tool use', 'tool calling', 'function calling',
      'mcp', 'model context protocol', 'computer use', 'browser use', 'workflow automation',
      'coding agent', 'autonomous', 'planner', 'multi-agent', 'orchestration'
    ]
  },
  {
    slug: 'rag-knowledge',
    name: 'RAG & Knowledge Systems',
    summary: 'Retrieval-augmented generation, vector search, embeddings, semantic search, document intelligence, and grounding.',
    modalitySlugs: ['text-llms', 'infra-mlops', 'research-ml'],
    keywords: [
      'rag', 'retrieval augmented generation', 'retrieval-augmented generation', 'retrieval',
      'vector database', 'vector search', 'semantic search', 'embedding', 'embeddings',
      'chunking', 'grounding', 'citations', 'knowledge base', 'document intelligence',
      'hybrid search', 'reranker', 'reranking'
    ]
  },
  {
    slug: 'multimodal-ai',
    name: 'Multimodal AI',
    summary: 'Systems combining text, image, video, audio, documents, charts, spatial context, and cross-modal reasoning.',
    modalitySlugs: ['text-llms', 'image-video', 'audio-speech', 'research-ml'],
    keywords: [
      'multimodal', 'multi-modal', 'vision language', 'vision-language', 'vlm', 'mlm',
      'image understanding', 'video understanding', 'audio understanding', 'document understanding',
      'ocr', 'layout', 'cross-modal', 'speech', 'vision', 'video'
    ]
  },
  {
    slug: 'evaluation-benchmarks',
    name: 'Evaluation & Benchmarks',
    summary: 'Model evaluation, benchmarks, safety testing, factuality, hallucination measurement, and real-world performance tracking.',
    modalitySlugs: ['research-ml', 'governance-safety', 'infra-mlops'],
    keywords: [
      'benchmark', 'benchmarks', 'eval', 'evaluation', 'leaderboard', 'mmlu', 'gpqa',
      'swe-bench', 'humaneval', 'mmmu', 'helm', 'safety benchmark', 'factuality',
      'hallucination', 'red team', 'red-teaming', 'model card', 'scorecard'
    ]
  },
  {
    slug: 'ai-infrastructure',
    name: 'AI Infrastructure & Inference',
    summary: 'GPUs, accelerators, inference servers, model serving, quantization, orchestration, observability, and production AI operations.',
    modalitySlugs: ['infra-mlops', 'code-agents', 'research-ml'],
    keywords: [
      'gpu', 'nvidia', 'cuda', 'accelerator', 'inference', 'serving', 'model serving',
      'quantization', 'distillation', 'latency', 'throughput', 'vllm', 'triton', 'onnx',
      'kubernetes', 'observability', 'mlops', 'monitoring', 'deployment'
    ]
  },
  {
    slug: 'ai-safety-governance',
    name: 'AI Safety, Governance & Policy',
    summary: 'AI regulation, safety research, governance frameworks, model risk, privacy, compliance, and responsible AI.',
    modalitySlugs: ['governance-safety', 'research-ml'],
    keywords: [
      'safety', 'governance', 'policy', 'regulation', 'regulatory', 'compliance',
      'privacy', 'security', 'responsible ai', 'model risk', 'risk management',
      'alignment', 'jailbreak', 'misuse', 'incident', 'transparency', 'audit'
    ]
  },
  {
    slug: 'data-datasets',
    name: 'Data, Datasets & Synthetic Data',
    summary: 'Training data, dataset releases, data quality, data governance, synthetic data, labeling, licensing, and provenance.',
    modalitySlugs: ['research-ml', 'infra-mlops', 'governance-safety'],
    keywords: [
      'dataset', 'datasets', 'training data', 'data quality', 'synthetic data', 'labeling',
      'annotation', 'data governance', 'provenance', 'license', 'licensing', 'copyright',
      'data curation', 'data pipeline'
    ]
  },
  {
    slug: 'robotics-embodied-ai',
    name: 'Robotics & Embodied AI',
    summary: 'Robotics, embodied agents, spatial reasoning, autonomous vehicles, manipulation, simulation, and physical-world AI.',
    modalitySlugs: ['research-ml', 'image-video', 'code-agents'],
    keywords: [
      'robot', 'robotics', 'embodied', 'embodied ai', 'autonomous vehicle', 'self-driving',
      'manipulation', 'simulator', 'simulation', 'navigation', 'spatial reasoning',
      'world model', 'humanoid', 'control policy'
    ]
  },
  {
    slug: 'edge-on-device-ai',
    name: 'Edge & On-Device AI',
    summary: 'Local inference, small models, NPUs, mobile AI, browser AI, private inference, and disconnected/low-latency deployment.',
    modalitySlugs: ['infra-mlops', 'text-llms', 'image-video', 'audio-speech'],
    keywords: [
      'edge ai', 'on-device', 'local ai', 'mobile ai', 'npu', 'small language model',
      'slm', 'tinyml', 'browser ai', 'webgpu', 'local inference', 'private inference',
      'offline', 'low latency'
    ]
  }
];

export function getWatchArea(slug: string): WatchArea | undefined {
  return watchAreas.find((watchArea) => watchArea.slug === slug);
}
