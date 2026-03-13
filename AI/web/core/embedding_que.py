from google import generativeai as genai


class EmbeddingQuery:
    def __init__(self, api_key, model_name, embedding_dimension):
        self.api_key = api_key
        self.model_name = str(model_name) if isinstance(model_name, tuple) else model_name
        self.embedding_dimension = embedding_dimension
        genai.configure(api_key=self.api_key)

    def _extract_values(self, embedding_response):
        """
        Chuẩn hóa việc lấy vector từ response của embed_content
        Hỗ trợ cả kiểu object cũ và dict mới.
        """
        # Trường hợp mới: response là dict
        if isinstance(embedding_response, dict):
            # Kiểu 1: {'embedding': {'values': [...]}}
            if "embedding" in embedding_response and isinstance(embedding_response["embedding"], dict):
                return embedding_response["embedding"].get("values")

            # Kiểu 2: {'embeddings': [{'values': [...]}]}
            if "embeddings" in embedding_response and embedding_response["embeddings"]:
                first = embedding_response["embeddings"][0]
                if isinstance(first, dict):
                    return first.get("values")

            return None

        # Trường hợp cũ: object có .embedding hoặc .embeddings
        if hasattr(embedding_response, "embedding") and hasattr(embedding_response.embedding, "values"):
            return embedding_response.embedding.values

        if hasattr(embedding_response, "embeddings") and embedding_response.embeddings:
            first = embedding_response.embeddings[0]
            if hasattr(first, "values"):
                return first.values

        return None

    def embed_text(self, text):
        try:
            embedding = genai.embed_content(
                model=self.model_name,
                content=text,
                task_type="semantic_similarity"
            )

            values = self._extract_values(embedding)
            if not values:
                print(f"Embedding response không đúng format, response = {embedding}")
                return None

            return values
        except Exception as e:
            print(f"Error embedding text: {e}")
            return None
