import type { FeedSource } from '../types/content.js';

export const feedSources: FeedSource[] = [
  {
    id: 'openai-news',
    title: 'OpenAI News',
    url: 'https://openai.com/news/rss.xml',
    homepage: 'https://openai.com/news/',
    modalitySlugs: ['text-llms', 'image-video', 'audio-speech', 'code-agents', 'research-ml', 'governance-safety'],
    tags: ['frontier models', 'product', 'research'],
    reliability: 'official'
  },

{
  id: 'aws-machine-learning',
  title: 'AWS Machine Learning Blog',
  url: 'https://aws.amazon.com/blogs/machine-learning/feed/',
  homepage: 'https://aws.amazon.com/blogs/machine-learning/',
  modalitySlugs: ['infra-mlops', 'code-agents', 'text-llms', 'research-ml'],
  tags: ['AWS', 'Bedrock', 'MLOps', 'agents', 'machine learning'],
  reliability: 'official'
},
{
  id: 'nvidia-blog',
  title: 'NVIDIA Blog',
  url: 'https://feeds.feedburner.com/nvidiablog',
  homepage: 'https://blogs.nvidia.com/',
  modalitySlugs: ['infra-mlops', 'image-video', 'research-ml', 'code-agents'],
  tags: ['GPU', 'accelerated computing', 'AI infrastructure', 'robotics'],
  reliability: 'official'
},
{
  id: 'nvidia-developer-blog',
  title: 'NVIDIA Developer Blog',
  url: 'https://developer.nvidia.com/blog/feed',
  homepage: 'https://developer.nvidia.com/blog/',
  modalitySlugs: ['infra-mlops', 'code-agents', 'image-video', 'research-ml'],
  tags: ['CUDA', 'inference', 'GPU engineering', 'developer tooling'],
  reliability: 'official'
},
{
  id: 'mit-news-ai',
  title: 'MIT News — Artificial Intelligence',
  url: 'https://news.mit.edu/topic/mitartificial-intelligence2-rss.xml',
  homepage: 'https://news.mit.edu/topic/artificial-intelligence2',
  modalitySlugs: ['research-ml', 'text-llms', 'image-video', 'governance-safety'],
  tags: ['MIT', 'research', 'academic', 'AI applications'],
  reliability: 'official'
},
{
  id: 'bair-blog',
  title: 'Berkeley Artificial Intelligence Research Blog',
  url: 'https://bair.berkeley.edu/blog/feed.xml',
  homepage: 'https://bair.berkeley.edu/blog/',
  modalitySlugs: ['research-ml', 'text-llms', 'image-video', 'code-agents', 'governance-safety'],
  tags: ['academic research', 'deep learning', 'robotics', 'NLP', 'vision'],
  reliability: 'research'
},
{
  id: 'stanford-sail-blog',
  title: 'Stanford AI Lab Blog',
  url: 'https://ai.stanford.edu/blog/feed.xml',
  homepage: 'https://ai.stanford.edu/blog/',
  modalitySlugs: ['research-ml', 'text-llms', 'image-video', 'audio-speech', 'governance-safety'],
  tags: ['Stanford', 'academic research', 'NLP', 'vision', 'robotics'],
  reliability: 'research'
},
{
  id: 'ibm-ai-newsroom',
  title: 'IBM Newsroom — Artificial Intelligence',
  url: 'https://newsroom.ibm.com/press-releases-artificial-intelligence?pagetemplate=rss',
  homepage: 'https://newsroom.ibm.com/press-releases-artificial-intelligence',
  modalitySlugs: ['text-llms', 'infra-mlops', 'research-ml', 'governance-safety'],
  tags: ['IBM', 'enterprise AI', 'research', 'hybrid cloud'],
  reliability: 'official'
},
  
  {
    id: 'google-ai-blog',
    title: 'Google AI Blog',
    url: 'https://blog.google/technology/ai/rss/',
    homepage: 'https://blog.google/technology/ai/',
    modalitySlugs: ['text-llms', 'image-video', 'audio-speech', 'research-ml', 'infra-mlops', 'governance-safety'],
    tags: ['Gemini', 'research', 'products'],
    reliability: 'official'
  },
  {
    id: 'google-deepmind',
    title: 'Google DeepMind via Google Blog',
    url: 'https://blog.google/innovation-and-ai/models-and-research/google-deepmind/rss/',
    homepage: 'https://blog.google/innovation-and-ai/models-and-research/google-deepmind/',
    fallbackUrls: ['https://blog.google/technology/ai/rss/'],
    modalitySlugs: ['research-ml', 'text-llms', 'image-video', 'governance-safety'],
    tags: ['research', 'frontier models', 'science'],
    reliability: 'official'
  },
  {
    id: 'huggingface-blog',
    title: 'Hugging Face Blog',
    url: 'https://huggingface.co/blog/feed.xml',
    homepage: 'https://huggingface.co/blog',
    modalitySlugs: ['text-llms', 'image-video', 'audio-speech', 'research-ml', 'infra-mlops', 'code-agents'],
    tags: ['open models', 'datasets', 'ML engineering'],
    reliability: 'official'
  },
  {
    id: 'arxiv-ai',
    title: 'arXiv Artificial Intelligence',
    url: 'https://rss.arxiv.org/rss/cs.AI',
    homepage: 'https://arxiv.org/list/cs.AI/recent',
    modalitySlugs: ['research-ml'],
    tags: ['papers', 'research'],
    reliability: 'research'
  },
  {
    id: 'arxiv-cl',
    title: 'arXiv Computation and Language',
    url: 'https://rss.arxiv.org/rss/cs.CL',
    homepage: 'https://arxiv.org/list/cs.CL/recent',
    modalitySlugs: ['text-llms', 'research-ml'],
    tags: ['NLP', 'LLMs', 'papers'],
    reliability: 'research'
  },
  {
    id: 'arxiv-cv',
    title: 'arXiv Computer Vision',
    url: 'https://rss.arxiv.org/rss/cs.CV',
    homepage: 'https://arxiv.org/list/cs.CV/recent',
    modalitySlugs: ['image-video', 'research-ml'],
    tags: ['vision', 'multimodal', 'papers'],
    reliability: 'research'
  },
  {
    id: 'arxiv-lg',
    title: 'arXiv Machine Learning',
    url: 'https://rss.arxiv.org/rss/cs.LG',
    homepage: 'https://arxiv.org/list/cs.LG/recent',
    modalitySlugs: ['research-ml', 'infra-mlops'],
    tags: ['machine learning', 'papers'],
    reliability: 'research'
  },
  {
    id: 'mit-tech-review-ai',
    title: 'MIT Technology Review AI',
    url: 'https://www.technologyreview.com/feed/',
    homepage: 'https://www.technologyreview.com/topic/artificial-intelligence/',
    modalitySlugs: ['text-llms', 'image-video', 'research-ml', 'governance-safety'],
    tags: ['news', 'analysis', 'policy'],
    reliability: 'editorial'
  },
  {
    id: 'the-gradient',
    title: 'The Gradient',
    url: 'https://thegradient.pub/rss/',
    homepage: 'https://thegradient.pub/',
    modalitySlugs: ['research-ml', 'text-llms', 'governance-safety'],
    tags: ['analysis', 'research commentary'],
    reliability: 'editorial'
  },
{
  id: 'arxiv-stat-ml',
  title: 'arXiv Statistics — Machine Learning',
  url: 'https://rss.arxiv.org/rss/stat.ML',
  homepage: 'https://arxiv.org/list/stat.ML/recent',
  modalitySlugs: ['research-ml'],
  tags: ['papers', 'statistics', 'machine learning'],
  reliability: 'research'
},
{
  id: 'arxiv-robotics',
  title: 'arXiv Robotics',
  url: 'https://rss.arxiv.org/rss/cs.RO',
  homepage: 'https://arxiv.org/list/cs.RO/recent',
  modalitySlugs: ['research-ml', 'image-video', 'code-agents'],
  tags: ['robotics', 'embodied AI', 'agents', 'papers'],
  reliability: 'research'
},
{
  id: 'arxiv-audio-speech',
  title: 'arXiv Audio and Speech Processing',
  url: 'https://rss.arxiv.org/rss/eess.AS',
  homepage: 'https://arxiv.org/list/eess.AS/recent',
  modalitySlugs: ['audio-speech', 'research-ml'],
  tags: ['speech', 'audio', 'signal processing', 'papers'],
  reliability: 'research'
}
];
