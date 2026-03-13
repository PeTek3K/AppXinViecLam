from qdrant_client import QdrantClient, models
from read_cv import PDFProcessor

from FlagEmbedding import BGEM3FlagModel
import os 


class EmbeddingProcessor:
    def __init__(self, model_name: str = 'BAAI/bge-m3', use_fp16: bool = True, cache_dir: str = None):
        self.model = BGEM3FlagModel(model_name,
                                    use_fp16=use_fp16,
                                    cache_dir=cache_dir)

    def generate_embeddings(self,
                            texts: list[str],
                            batch_size: int = 12,
                            max_length: int = 8192) -> list:
        
        embeddings = self.model.encode(texts,
                                       batch_size=batch_size,
                                       max_length=max_length)['dense_vecs']
        return embeddings








def retrieve_context(embeddings, top_k: int = 3) -> list:



    return search_result

a = retrieve_context(embeddings)
print(a)
