from qdrant_client import QdrantClient


class JobRetriever:
    def __init__(self, url, api, collection_name, embedding_dimension):
        self.client = QdrantClient(url=url, api_key=api)
        self.collection_name = collection_name
        self.embedding_dimension = embedding_dimension

    def retrieve_jobs(self, query_embedding, limit=10):
        try:
            self.results = self.client.query_points(
                collection_name=self.collection_name,
                query=query_embedding,
                limit=limit,
                using="skills_experience"
            )
            return self.results
        except Exception as e:
            print(f"Error retrieving jobs: {e}")
            return []
    
    


