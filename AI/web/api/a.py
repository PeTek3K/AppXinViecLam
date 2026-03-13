from qdrant_client import QdrantClient, models
from read_cv import PDFProcessor
import numpy as np
from cv_job_matching_rag.core.embedding_model import EmbeddingProcessor
import os 

a = PDFProcessor(r"D:\web\uploads\1.pdf")
a.read_pdf()
text_pdf = a.get_text_content()

b = EmbeddingProcessor()
embeddings = b.generate_embeddings([text_pdf])
print("--------------------------------")
# Get the first embedding since we only have one text
embeddings = embeddings[0]

QDRANT_COLLECTION_NAME = "job_embeddings_nor1"
URL = "https://98a226f2-3ab7-493b-9416-30c76e9a7535.us-west-2-0.aws.cloud.qdrant.io"
API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIiwiZXhwIjoxNzUwNTQ0MjcxfQ.yGKJTM3nY-B3hQ18WJ8Zm63RfgIUKuWGPBMNFc1tsuU"
client = QdrantClient(url=URL, api_key=API_KEY)
collection_info = client.get_collection(collection_name=QDRANT_COLLECTION_NAME)
print("Collection already exists")

search_result = client.query_points(
        collection_name=QDRANT_COLLECTION_NAME,
        query=embeddings,
        limit=3,
        using="skills_experience"
)

print(search_result)